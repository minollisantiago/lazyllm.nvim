local M = {}

local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local builtin = require("telescope.builtin")

-- Opens a Telescope fuzzy finder for files in the current working directory.
-- On selection, reads the file content and passes it to the provided handler function.

-- @param handle_file_fn function: The function to call with the file content string.
-- Expected signature: handle_file_fn(file_content_string)
-- @param wrap_tag string|nil: If truthy, wrap the file content with xml tags (wrap_tag)
-- and a markdown code block indicating filename and type. Defaults to nil.
local function resolve_file_path(selection, base_dir)
	local file_path = selection.path or selection.value
	if not file_path then
		return nil
	end

	if base_dir and vim.fn.fnamemodify(file_path, ":p") == file_path then
		return file_path
	end

	if base_dir then
		return vim.fn.fnamemodify(base_dir .. "/" .. file_path, ":p")
	end

	return vim.fn.fnamemodify(file_path, ":p")
end

local function read_selected_file(selection, base_dir)
	local file_path = resolve_file_path(selection, base_dir)
	if not file_path then
		vim.notify("Invalid selection.", vim.log.levels.WARN, { title = "LazyLLM" })
		return
	end

	local ok, lines = pcall(vim.fn.readfile, file_path)
	if not ok or type(lines) ~= "table" then
		vim.notify(
			"Error reading file: " .. file_path .. "\nReason: " .. tostring(lines),
			vim.log.levels.ERROR,
			{ title = "LazyLLM" }
		)
		return
	end

	return file_path, table.concat(lines, "\n")
end

local function wrap_file_content(file_path, file_text, wrap_tag, metadata)
	if not wrap_tag then
		return file_text
	end

	local wrap = require("promp_utils")
	local filename = vim.fn.fnamemodify(file_path, ":t")
	local filetype = vim.fn.fnamemodify(file_path, ":e")
	if filetype == "" then
		filetype = "text"
	end

	local file_code_block = table.concat({ "```" .. filetype, file_text, "```" }, "\n")
	return wrap.wrap_context_xml(wrap_tag, file_code_block, metadata)
end

local function default_chat_find_command()
	if vim.fn.executable("rg") == 1 then
		return { "rg", "--files", "--hidden", "--no-ignore", "--no-ignore-parent", "--glob", "*.md" }
	end
	return nil
end

local function pick_file_and_handle_text(opts)
	if not opts.handle_file_fn or type(opts.handle_file_fn) ~= "function" then
		vim.notify("No handler function provided for file selection.", vim.log.levels.ERROR, { title = "LazyLLM" })
		return
	end

	builtin.find_files({
		prompt_title = opts.prompt_title,
		cwd = opts.cwd,
		find_command = opts.find_command,
		hidden = opts.hidden,
		no_ignore = opts.no_ignore,
		no_ignore_parent = opts.no_ignore_parent,
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)

				local selection = action_state.get_selected_entry()
				if not selection then
					vim.notify("Invalid selection.", vim.log.levels.WARN, { title = "LazyLLM" })
					return
				end

				local file_path, file_text = read_selected_file(selection, opts.cwd)
				if not file_path then
					return
				end

				local wrapped = wrap_file_content(file_path, file_text, opts.wrap_tag, {
					name = vim.fn.fnamemodify(file_path, ":t"),
					filetype = vim.fn.fnamemodify(file_path, ":e"),
					file = selection.file,
					path = file_path,
				})

				opts.handle_file_fn(wrapped)
			end)

			return true
		end,
	})
end

function M.select_file_and_get_text(handle_file_fn, wrap_tag)
	pick_file_and_handle_text({
		handle_file_fn = handle_file_fn,
		wrap_tag = wrap_tag,
		prompt_title = "Select File to Add to Context",
	})
end

function M.select_chat_file_and_get_text(handle_file_fn, wrap_tag, opts)
	opts = opts or {}
	local root_dir = opts.dir or vim.fn.getcwd()
	local chat_dir = opts.chat_dir or (root_dir .. "/llm/chats")
	if vim.fn.isdirectory(chat_dir) == 0 then
		vim.notify("Chat directory not found: " .. chat_dir, vim.log.levels.WARN, { title = "LazyLLM" })
		return
	end

	local find_command = opts.find_command or default_chat_find_command()
	if not find_command and opts.require_markdown then
		vim.notify("Markdown-only chat listing requires ripgrep (rg).", vim.log.levels.WARN, { title = "LazyLLM" })
	end

	pick_file_and_handle_text({
		handle_file_fn = handle_file_fn,
		wrap_tag = wrap_tag,
		cwd = chat_dir,
		prompt_title = opts.prompt_title or "Select Chat to Add to Context",
		find_command = find_command,
		hidden = opts.hidden ~= false,
		no_ignore = opts.no_ignore ~= false,
		no_ignore_parent = opts.no_ignore_parent ~= false,
	})
end

function M.select_chat_file_and_open(opts)
	opts = opts or {}
	local root_dir = opts.dir or vim.fn.getcwd()
	local chat_dir = opts.chat_dir or (root_dir .. "/llm/chats")
	if vim.fn.isdirectory(chat_dir) == 0 then
		vim.notify("Chat directory not found: " .. chat_dir, vim.log.levels.WARN, { title = "LazyLLM" })
		return
	end

	local find_command = opts.find_command or default_chat_find_command()
	if not find_command and opts.require_markdown then
		vim.notify("Markdown-only chat listing requires ripgrep (rg).", vim.log.levels.WARN, { title = "LazyLLM" })
	end

	builtin.find_files({
		prompt_title = opts.prompt_title or "Open Chat Scratchpad",
		cwd = chat_dir,
		find_command = find_command,
		hidden = opts.hidden ~= false,
		no_ignore = opts.no_ignore ~= false,
		no_ignore_parent = opts.no_ignore_parent ~= false,
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)

				local selection = action_state.get_selected_entry()
				if not selection then
					vim.notify("Invalid selection.", vim.log.levels.WARN, { title = "LazyLLM" })
					return
				end

				local file_path = resolve_file_path(selection, chat_dir)
				if not file_path then
					vim.notify("Invalid selection.", vim.log.levels.WARN, { title = "LazyLLM" })
					return
				end

				local open_cmd = opts.open_cmd or "edit"
				vim.cmd(string.format("%s %s", open_cmd, vim.fn.fnameescape(file_path)))
			end)

			return true
		end,
	})
end

function M.search_chat_files(opts)
	opts = opts or {}
	local root_dir = opts.dir or vim.fn.getcwd()
	local chat_dir = opts.chat_dir or (root_dir .. "/llm/chats")
	if vim.fn.isdirectory(chat_dir) == 0 then
		vim.notify("Chat directory not found: " .. chat_dir, vim.log.levels.WARN, { title = "LazyLLM" })
		return
	end

	builtin.live_grep({
		prompt_title = opts.prompt_title or "Search Chat Files",
		cwd = chat_dir,
		glob_pattern = opts.glob_pattern or "*.md",
	})
end

return M
