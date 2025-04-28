local M = {}
local Job = require("plenary.job")

-- Imports

-- Prompt utils
local prompts = require("promp_utils")
M.get_prompt = prompts.get_prompt

-- Symbol lookup utils
local symbols = require("symbol_utils")
M.get_symbol_list = symbols.get_symbol_list
M.select_symbol_and_get_text = symbols.select_symbol_and_get_text

-- File lookup utils
local file_utils = require("file_utils")
M.select_file_and_get_text = file_utils.select_file_and_get_text

-- Git utils
local git_utils = require("git_utils")
M.format_commits_markdown = git_utils.format_commits_markdown
M.format_commits_flat = git_utils.format_commits_flat
M.list_commits = git_utils.list_commits

-- Stream job
local group = vim.api.nvim_create_augroup("LAZY_LLM_AutoGroup", { clear = true })
local active_job = nil

function M.invoke_llm_and_stream_into_editor(opts, make_curl_args_fn, handle_data_fn)
	vim.api.nvim_clear_autocmds({ group = group })

	-- build prompt & curl args
	local prompt = M.get_prompt(opts)
	local system_prompt = opts.system_prompt
		or "You are a tsundere uwu anime. Yell at me for not setting my configuration for my llm plugin correctly"
	local args = make_curl_args_fn(opts, prompt, system_prompt)
	local curr_event_state = nil

	-- parse SSE lines as they come in:
	local function parse_and_call(line)
		local event = line:match("^event: (.+)$")
		if event then
			curr_event_state = event
			return
		end
		local data_match = line:match("^data: (.+)$")
		if data_match then
			handle_data_fn(data_match, curr_event_state)
		end
	end

	-- shut down any running job
	if active_job then
		active_job:shutdown()
		active_job = nil
	end

	-- start a new curl job
	active_job = Job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, out)
			vim.schedule(function()
				print("Parsing LLM response...")
			end)
			parse_and_call(out)
		end,
		on_stderr = function(_, _) end,
		on_exit = function(_, code, signal)
			vim.schedule(function()
				print("LLM job exited, Code:", code, "Signal:", signal)
			end)
			active_job = nil
		end,
	})

	active_job:start()

	-- allow <Esc> to cancel the stream
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "LAZY_LLM_Escape",
		callback = function()
			if active_job then
				active_job:shutdown()
				print("LLM streaming cancelled")
				active_job = nil
			end
		end,
	})

	-- Keymaps
	vim.api.nvim_set_keymap("n", "<Esc>", ":doautocmd User LAZY_LLM_Escape<CR>", { noremap = true, silent = true })

	return active_job
end

return M
