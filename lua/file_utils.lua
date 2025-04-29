local M = {}

local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local builtin = require("telescope.builtin")

--- Opens a Telescope fuzzy finder for files in the current working directory.
-- On selection, reads the file content and passes it to the provided handler function.

-- @param handle_file_fn function: The function to call with the file content string.
-- Expected signature: handle_file_fn(file_content_string)
-- @param wrap_tag string|nil: If truthy, wrap the file content with xml tags (wrap_tag)
-- and a markdown code block indicating filename and type. Defaults to nil.
function M.select_file_and_get_text(handle_file_fn, wrap_tag)
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
				if wrap_tag then
					local wrap = require("promp_utils")
					local filename = vim.fn.fnamemodify(file_path, ":t") -- Get filename only
					local filetype = vim.fn.fnamemodify(file_path, ":e") -- Get extension as simple filetype hint
					if filetype == "" then
						filetype = "text"
					end -- Fallback for files without extension
					local file_code_block = table.concat({ "```" .. filetype, fileText, "```" }, "\n")
					local wrapped = {
						wrap.wrap_context_xml(wrap_tag, file_code_block, {
							name = filename,
							filetype = filetype,
							file = selection.file,
							path = selection.path,
						}),
					}
					fileText = table.concat(wrapped, "\n")
				end

				-- Call the provided handler function with the final text
				if handle_file_fn then
					handle_file_fn(fileText)
				else
					print("Selected file contents:\n\n" .. fileText)
				end
			end)

			return true -- Indicate that mappings were attached/modified
		end,
	})
end

return M
