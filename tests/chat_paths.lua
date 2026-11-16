-- Run with `lua tests/chat_paths.lua` (or `fengari tests/chat_paths.lua`).
package.path = "./lua/?.lua;" .. package.path

local calls = {}
local directories = { ["/project"] = true }
local builtin = {
	find_files = function(opts)
		calls.find = opts
	end,
	live_grep = function(opts)
		calls.grep = opts
	end,
}

for _, name in ipairs({
	"plenary.job",
	"promp_utils",
	"symbol_utils",
	"diff_utils",
	"git_utils",
	"opencode_utils",
	"telescope.pickers",
	"telescope.actions",
	"telescope.actions.state",
}) do
	package.preload[name] = function()
		return {}
	end
end
package.preload["telescope.config"] = function()
	return { values = {} }
end
package.preload["telescope.builtin"] = function()
	return builtin
end

vim = {
	fn = {
		getcwd = function()
			return "/project"
		end,
		isdirectory = function(path)
			return directories[path] and 1 or 0
		end,
		mkdir = function(path, mode)
			assert(mode == "p")
			directories[path] = true
		end,
		fnamemodify = function(path, modifier)
			assert(modifier == ":p")
			return path
		end,
		fnameescape = function(path)
			return path
		end,
		executable = function()
			return 1
		end,
	},
	api = {
		nvim_create_user_command = function() end,
		nvim_create_augroup = function()
			return 1
		end,
	},
	log = { levels = { WARN = 1, ERROR = 2 } },
	notify = function(message)
		calls.notification = message
	end,
	cmd = function(command)
		calls.command = command
	end,
}

local lazyllm = require("lazyllm")
local path = lazyllm.open_markdown_scratchpad({ filename = "test.md" })
assert(path:match("^/project/%.agents/lazyllm/test_%d+_%d+%.md$"), path)
assert(directories["/project/.agents/lazyllm"])
assert(not directories["/project/llm/chats"])
assert(calls.command == "edit " .. path)

for _, root in ipairs({ "/project", "/another" }) do
	directories[root] = true
	directories[root .. "/.agents/lazyllm"] = true
	lazyllm.open_markdown_scratchpad({ dir = root })
	assert(calls.command:find(root .. "/.agents/lazyllm/", 1, true))
	lazyllm.select_chat_file_and_get_text(function() end, nil, { dir = root })
	assert(calls.find.cwd == root .. "/.agents/lazyllm")
	lazyllm.select_chat_file_and_open({ dir = root })
	assert(calls.find.cwd == root .. "/.agents/lazyllm")
	lazyllm.search_chat_files({ dir = root })
	assert(calls.grep.cwd == root .. "/.agents/lazyllm")
	assert(calls.grep.glob_pattern == "*.md")
	local grep_args = calls.grep.additional_args()
	assert(table.concat(grep_args, " ") == "--hidden --no-ignore --no-ignore-parent")
end

directories["/custom/chats"] = true
lazyllm.select_chat_file_and_get_text(function() end, nil, { chat_dir = "/custom/chats" })
assert(calls.find.cwd == "/custom/chats")
lazyllm.select_chat_file_and_open({ chat_dir = "/custom/chats" })
assert(calls.find.cwd == "/custom/chats")
lazyllm.search_chat_files({ chat_dir = "/custom/chats" })
assert(calls.grep.cwd == "/custom/chats")

calls.find = nil
lazyllm.select_chat_file_and_open({ dir = "/missing" })
assert(calls.find == nil)
assert(calls.notification == "Chat directory not found: /missing/.agents/lazyllm")

print("Chat path tests passed")
