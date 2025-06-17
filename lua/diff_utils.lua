local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")

local M = {}

----------------------------------------------------------------------
-- Helpers -----------------------------------------------------------
----------------------------------------------------------------------

-- Parses current buffer for ```diff fenced blocks.
-- Returns table of { filename, linenr (1‑based), full (array of lines) }
function M.parse_diff_blocks(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local diffs, inside, start_ln, block = {}, false, nil, {}

	local function push_block()
		-- grab filename from first '---' header, fall back to ??? if absent
		local target = "???"
		for _, l in ipairs(block) do
			local m = l:match("^%-%-%-%s+%S+%s+(.+)")
			if m then
				target = m
				break
			end
		end
		table.insert(diffs, {
			filename = target,
			linenr = start_ln,
			full = vim.deepcopy(block),
		})
	end

	for i, line in ipairs(lines) do
		if line:match("^```diff%s*$") then
			inside, start_ln, block = true, i, {}
		elseif line:match("^```%s*$") and inside then
			inside = false
			push_block()
		elseif inside then
			table.insert(block, line)
		end
	end
	return diffs
end

----------------------------------------------------------------------
-- Previewer ---------------------------------------------------------
----------------------------------------------------------------------

local function diff_previewer(entry, _)
	-- entry.value.full is an array of diff lines
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, entry.value.full)
	return buf
end

local DiffPreviewer = previewers.new_buffer_previewer({
	title = "Diff",
	define_preview = function(self, entry, _)
		-- build / reuse buffer each time selection changes
		local buf = diff_previewer(entry, self)
		self.state.bufnr = buf
	end,
})

----------------------------------------------------------------------
-- Picker ------------------------------------------------------------
----------------------------------------------------------------------

function M.select_diff_and_get_text(diff_lookup_fn)
	local bufnr = vim.api.nvim_get_current_buf()
	local items = diff_lookup_fn(bufnr)

	if vim.tbl_isempty(items) then
		vim.notify("No ```diff blocks found in this buffer", vim.log.levels.INFO)
		return
	end

	local displayer = entry_display.create({
		separator = " │ ",
		items = {
			{ width = 35 },
			{ remaining = true },
		},
	})

	pickers
		.new({}, {
			prompt_title = "LLm Suggestions Diff Explorer",
			sorter = conf.generic_sorter({}),
			previewer = DiffPreviewer,
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					-- first non‑header line as short preview, if any
					local preview = ""
					for _, l in ipairs(entry.full) do
						if not l:match("^%-%-%-") and not l:match("^%+%+%+") then
							preview = l:sub(1, 70)
							break
						end
					end
					return {
						value = entry,
						display = function(e)
							return displayer({
								e.value.filename,
								preview == "" and "[no content]" or preview,
							})
						end,
						ordinal = entry.filename .. " " .. preview,
					}
				end,
			}),
			attach_mappings = function(_, map)
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close()
					if selection then
						-- jump to start of diff block in the markdown buffer
						vim.api.nvim_win_set_cursor(0, { selection.value.linenr, 0 })
						vim.cmd("normal! zz")
					end
				end)

				-- optional: open diff in a new split with <C‑s>
				map("i", "<C-s>", function()
					local selection = require("telescope.actions.state").get_selected_entry()
					if selection then
						vim.cmd("new")
						local new_buf = vim.api.nvim_get_current_buf()
						vim.api.nvim_buf_set_option(new_buf, "filetype", "diff")
						vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, selection.value.full)
					end
				end)

				return true
			end,
			layout_strategy = "horizontal",
			layout_config = {
				preview_width = 0.55,
				width = 0.9,
				height = 0.8,
			},
		})
		:find()
end

return M
