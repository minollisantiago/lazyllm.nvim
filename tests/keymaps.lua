-- Run with `lua tests/keymaps.lua [path/to/local/plugin/config.lua]` (or fengari).
local calls = {}
package.preload.lazyllm = function()
	return setmetatable({}, {
		__index = function(_, name)
			return function(opts)
				calls[name] = opts or true
			end
		end,
	})
end

local mappings = {}
vim = {
	api = { nvim_create_user_command = function() end },
	keymap = {
		set = function(_, lhs, callback)
			assert(not mappings[lhs], "Duplicate keymapping: " .. lhs)
			mappings[lhs] = callback
		end,
	},
}

local function check(config)
	mappings = {}
	config.config()
	for lhs, method in pairs({
		["<leader>ps"] = "open_markdown_scratchpad",
		["<leader>p<leader>"] = "select_chat_file_and_open",
		["<leader>p<leader><leader>"] = "search_chat_files",
	}) do
		calls = {}
		assert(mappings[lhs], "Missing mapping: " .. lhs)()
		assert(calls[method], lhs .. " must call " .. method)
		if type(calls[method]) == "table" then
			assert(not calls[method].chat_dir, "Mapping must use the plugin's chat directory default")
		end
	end
end

local readme = README_CONTENT or assert(io.open("README.md")):read("*a")
local example = assert(readme:match("```lua\n(.-)\n```"))
check(assert((loadstring or load)(example))())

if arg[1] then
	local config = assert(loadfile(arg[1]))()
	assert(config.dir == "/home/santiago/projects/lazyllm.nvim", "Local config must load the updated checkout")
	check(config)
end

print("Keymapping tests passed")
