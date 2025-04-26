-- lua/lazyllm/file_utils.lua (or wherever you place your modules)
local M = {}

local pickers = require("telescope.pickers")
-- local finders = require("telescope.finders") -- Not strictly needed if using telescope.builtin
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
-- local previewers = require("telescope.previewers") -- Not needed if using default find_files previewer
local builtin = require("telescope.builtin")

--- Opens a Telescope fuzzy finder for files in the current working directory.
-- On selection, reads the file content and passes it to the provided handler function.
--
-- @param handle_file_fn function: The function to call with the file content string.
--        Expected signature: handle_file_fn(file_content_string)
-- @param wrap_file boolean|nil: If true, wrap the file content with comments
--        and a markdown code block indicating filename and type. Defaults to false.
function M.select_file_and_get_text(handle_file_fn, wrap_file)
	-- Ensure a handler function is provided
	if not handle_file_fn or type(handle_file_fn) ~= "function" then
		vim.notify("No handler function provided for file selection.", vim.log.levels.ERROR, { title = "LazyLLM" })
		return
	end

	-- Use Telescope's built-in find_files
	builtin.find_files({
		prompt_title = "Select File to Add to Context",
		-- cwd = vim.fn.getcwd(), -- Default is usually fine
		-- You can add options here like hidden = true, find_command, etc. if needed
		attach_mappings = function(prompt_bufnr)
			-- Replace the default selection action ('select_default' usually opens the file)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr) -- Close telescope picker window

				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					vim.notify("Invalid selection.", vim.log.levels.WARN, { title = "LazyLLM" })
					return
				end

				-- selection.value from find_files is the full path to the file
				local file_path = selection.value

				-- Read the entire file content safely
				local ok, lines = pcall(vim.fn.readfile, file_path)

				if not ok or type(lines) ~= "table" then
					vim.notify(
						"Error reading file: " .. file_path .. "\nReason: " .. tostring(lines), -- 'lines' contains error msg on pcall failure
						vim.log.levels.ERROR,
						{ title = "LazyLLM" }
					)
					return
				end

				-- Concatenate lines into a single string
				local fileText = table.concat(lines, "\n")

				-- Wrap the content if requested
				if wrap_file then
					local filename = vim.fn.fnamemodify(file_path, ":t") -- Get filename only
					local filetype = vim.fn.fnamemodify(file_path, ":e") -- Get extension as simple filetype hint
					if filetype == "" then
						filetype = "text"
					end -- Fallback for files without extension

					local wrapped = {
						"<!-- File: " .. filename .. " -->",
						"```" .. filetype,
						fileText,
						"```",
					}
					fileText = table.concat(wrapped, "\n")
				end

				-- Call the provided handler function with the final text
				handle_file_fn(fileText)
			end)

			-- Keep default mappings like Ctrl+X, Ctrl+V, Ctrl+T if desired
			-- actions.select_split:enhance({...}) -- example

			return true -- Indicate that mappings were attached/modified
		end,
	})
end

return M
