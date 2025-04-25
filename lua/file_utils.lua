local M = {}

function M.select_file_and_get_text(handle_symbol_fn)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local devicons = require("nvim-web-devicons")

	local cwd = vim.fn.getcwd()
	local files = vim.fn.glob("**/*", true, true)

	local make_entry = function(filepath)
		local shortname = vim.fn.fnamemodify(filepath, ":t")
		local ext = vim.fn.fnamemodify(filepath, ":e")
		local icon, iconhl = devicons.get_icon(shortname, ext, { default = true })

		return {
			value = filepath,
			display = icon .. " " .. filepath,
			ordinal = filepath,
			filename = filepath,
		}
	end

	pickers
		.new({}, {
			prompt_title = "Select a file to add contents to context",
			finder = finders.new_table({
				results = files,
				entry_maker = make_entry,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					return { "bat", "--style=plain", "--color=always", entry.value }
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					local filepath = entry.value

					local fileContents = {}
					for line in io.lines(filepath) do
						table.insert(fileContents, line)
					end

					if handle_symbol_fn then
						handle_symbol_fn(fileContents)
					else
						print("Here is the selected file contents:\n\n" .. fileContents)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
