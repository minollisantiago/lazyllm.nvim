local M = {}

function M.select_file_and_paste_contents()
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

					local lines = {}
					for line in io.lines(filepath) do
						table.insert(lines, line)
					end

					-- Insert into the current buffer at the cursor position
					local row, col = unpack(vim.api.nvim_win_get_cursor(0))
					vim.api.nvim_buf_set_lines(0, row, row, false, lines)
				end)
				return true
			end,
		})
		:find()
end

return M
