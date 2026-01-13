local M = {}

local function is_windows()
	return vim.fn.has("win32") == 1
end

local function exec(command)
	local handle = io.popen(command)
	if not handle then
		error("Couldn't execute command: " .. command, 0)
	end

	local output = handle:read("*a")
	handle:close()
	return output
end

local function run_system(command)
	if vim.system then
		local result = vim.system(command):wait()
		return result.code, result.stdout
	end

	local output = vim.fn.system(command)
	return vim.v.shell_error, output
end

local function get_processes_unix()
	assert(vim.fn.executable("pgrep") == 1, "`pgrep` executable not found")
	assert(vim.fn.executable("lsof") == 1, "`lsof` executable not found")

	local pgrep_output = exec("pgrep -f 'opencode' 2>/dev/null || true")
	if pgrep_output == "" then
		return {}
	end

	local processes = {}
	for pid_str in pgrep_output:gmatch("[^\r\n]+") do
		local pid = tonumber(pid_str)
		if pid then
			local lsof_output = exec("lsof -w -iTCP -sTCP:LISTEN -P -n -a -p " .. pid .. " 2>/dev/null || true")

			if lsof_output ~= "" then
				for line in lsof_output:gmatch("[^\r\n]+") do
					local parts = vim.split(line, "%s+")

					if parts[1] ~= "COMMAND" then
						local port = parts[9] and parts[9]:match(":(%d+)$")
						if port then
							table.insert(processes, {
								pid = pid,
								port = tonumber(port),
							})
						end
					end
				end
			end
		end
	end

	return processes
end

local function get_processes_windows()
	local ps_script = [[
Get-Process -Name '*opencode*' -ErrorAction SilentlyContinue |
ForEach-Object {
  $ports = Get-NetTCPConnection -State Listen -OwningProcess $_.Id -ErrorAction SilentlyContinue
  if ($ports) {
    foreach ($port in $ports) {
      [PSCustomObject]@{pid=$_.Id; port=$port.LocalPort}
    }
  }
} | ConvertTo-Json -Compress
]]

	local code, output
	if vim.system then
		local result = vim.system({ "powershell", "-NoProfile", "-Command", ps_script }):wait()
		code = result.code
		output = result.stdout
	else
		code, output = run_system({ "powershell", "-NoProfile", "-Command", ps_script })
	end

	if code ~= 0 then
		error("PowerShell command failed with code: " .. code, 0)
	end

	if not output or output == "" then
		return {}
	end

	local ok, processes = pcall(vim.fn.json_decode, output)
	if not ok then
		error("Failed to parse PowerShell output: " .. tostring(processes), 0)
	end

	if processes.pid then
		processes = { processes }
	end

	return processes
end

local function get_processes()
	if is_windows() then
		return get_processes_windows()
	end

	return get_processes_unix()
end

local function get_path(port)
	assert(vim.fn.executable("curl") == 1, "`curl` executable not found")

	local args = {
		"curl",
		"-s",
		"--connect-timeout",
		"1",
		"http://localhost:" .. port .. "/path",
	}
	local code, output = run_system(args)

	if code == 0 and output and output ~= "" then
		local ok, path_data = pcall(vim.fn.json_decode, output)
		if ok and (path_data.directory or path_data.worktree) then
			return path_data
		end
	end

	error("Failed to get working directory for `opencode` port: " .. port, 0)
end

local function find_servers()
	local processes = get_processes()
	if #processes == 0 then
		error("No `opencode` processes found", 0)
	end

	local servers = {}
	for _, process in ipairs(processes) do
		local ok, path = pcall(get_path, process.port)
		if ok then
			table.insert(servers, {
				pid = process.pid,
				port = process.port,
				cwd = path.directory or path.worktree,
			})
		end
	end

	if #servers == 0 then
		error("No valid `opencode` servers found", 0)
	end

	return servers
end

local function is_descendant_of_neovim(pid)
	if is_windows() then
		return false
	end

	assert(vim.fn.executable("ps") == 1, "`ps` executable not found")

	local neovim_pid = vim.fn.getpid()
	local current_pid = pid

	for _ = 1, 10 do
		local parent_pid = tonumber(exec("ps -o ppid= -p " .. current_pid))
		if not parent_pid then
			error("Couldn't determine parent PID for: " .. current_pid, 0)
		end

		if parent_pid == 1 then
			return false
		elseif parent_pid == neovim_pid then
			return true
		end

		current_pid = parent_pid
	end

	return false
end

local function find_server_inside_nvim_cwd()
	local found_server
	local nvim_cwd = vim.fn.getcwd()
	for _, server in ipairs(find_servers()) do
		local normalized_server_cwd = server.cwd
		local normalized_nvim_cwd = nvim_cwd

		if is_windows() then
			normalized_server_cwd = server.cwd:gsub("/", "\\")
			normalized_nvim_cwd = nvim_cwd:gsub("/", "\\")
		end

		if normalized_server_cwd:find(normalized_nvim_cwd, 1, true) == 1 then
			found_server = server
			if not is_windows() and is_descendant_of_neovim(server.pid) then
				break
			end
		end
	end

	if not found_server then
		error("No `opencode` servers inside Neovim's CWD", 0)
	end

	return found_server
end

local function call(port, path, method, body)
	assert(vim.fn.executable("curl") == 1, "`curl` executable not found")

	local args = {
		"curl",
		"-s",
		"--connect-timeout",
		"1",
		"-X",
		method,
		"-H",
		"Content-Type: application/json",
		body and "-d" or nil,
		body and vim.fn.json_encode(body) or nil,
		"http://localhost:" .. port .. path,
	}

	local code, output = run_system(vim.tbl_filter(function(item)
		return item ~= nil
	end, args))

	if code ~= 0 then
		error("Failed to call opencode server: " .. output, 0)
	end
end

function M.get_port()
	return find_server_inside_nvim_cwd().port
end

function M.append_prompt(prompt, opts)
	opts = opts or {}
	local ok, port = pcall(M.get_port)
	if not ok then
		vim.notify(port, vim.log.levels.ERROR, { title = "LazyLLM" })
		return false
	end

	local ok_publish, publish_err = pcall(call, port, "/tui/publish", "POST", {
		type = "tui.prompt.append",
		properties = { text = prompt },
	})

	if not ok_publish then
		vim.notify(publish_err, vim.log.levels.ERROR, { title = "LazyLLM" })
		return false
	end

	if opts.submit then
		local ok_submit, submit_err = pcall(call, port, "/tui/publish", "POST", {
			type = "tui.command.execute",
			properties = { command = "prompt.submit" },
		})
		if not ok_submit then
			vim.notify(submit_err, vim.log.levels.ERROR, { title = "LazyLLM" })
			return false
		end
	end

	return true
end

return M
