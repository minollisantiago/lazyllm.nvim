local M = {}

local parsers = require("nvim-treesitter.parsers")

-- default LSP SymbolKinds
local default_allowed_kinds = {
	[5] = "Class",
	[6] = "Method",
	[12] = "Function",
	[13] = "Variable", -- const, let, etc.
	[11] = "Interface", -- interface Foo {}
	[25] = "TypeParameter", -- type Foo = ...
}

-- LSP-based symbol lookup
function M.get_symbol_list(allowed_kinds)
	local out = {}
	local allowed_kinds_ = {}

	if not allowed_kinds then
		allowed_kinds_ = default_allowed_kinds
	else
		allowed_kinds_ = allowed_kinds
	end

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			if #clients > 0 then
				local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
				local resp = vim.lsp.buf_request_sync(bufnr, "textDocument/documentSymbol", params, 500)
				if resp then
					for _, res in pairs(resp) do
						if res.result then
							local function flatten(symbols)
								for _, s in ipairs(symbols) do
									if allowed_kinds_[s.kind] then
										table.insert(out, {
											name = s.name,
											range = s.range,
											kind = vim.lsp.protocol.SymbolKind[s.kind],
											bufnr = bufnr,
										})
									end
									if s.children then
										flatten(s.children)
									end
								end
							end
							flatten(res.result)
						else
							vim.notify("No result from LSP response.", vim.log.levels.WARN)
						end
					end
				end
			end
		end
	end
	return out
end

-- Tree-sitter based symbol lookup (supports TS types/interfaces, arrow funcs, etc.)
function M.get_symbol_list_treesitter()
	local out = {}

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
			local lang = parsers.get_buf_lang(bufnr)
			local parser = vim.treesitter.get_parser(bufnr, lang)
			if not parser then
				goto continue
			end

			local tree = parser:parse()[1]
			local root = tree:root()

			local function walk(node)
				if not node then
					return
				end

				local type = node:type()

				-- React components or other function-as-variable
				if type == "lexical_declaration" or type == "variable_declaration" then
					for i = 0, node:named_child_count() - 1 do
						local child = node:named_child(i)
						if not child then
							goto skip
						end

						local name_node = child:field("name")[1]
						local value_node = child:field("value")[1]

						if name_node and value_node then
							local value_type = value_node:type()
							if value_type == "arrow_function" or value_type == "function" then
								local name = vim.treesitter.get_node_text(name_node, bufnr)
								local start_row = value_node:range()

								table.insert(out, {
									name = name,
									range = { start = { line = start_row } },
									kind = "Function (var)",
									bufnr = bufnr,
								})
							end
						end

						::skip::
					end
				end

				-- Regular function declaration
				if type == "function_declaration" then
					local name_node = node:field("name")[1]
					if name_node then
						local name = vim.treesitter.get_node_text(name_node, bufnr)
						local start_row = node:range()
						table.insert(out, {
							name = name,
							range = { start = { line = start_row } },
							kind = "Function",
							bufnr = bufnr,
						})
					end
				end

				-- Class, interface, type
				if
					type == "class_declaration"
					or type == "interface_declaration"
					or type == "type_alias_declaration"
				then
					local name_node = node:field("name")[1]
					if name_node then
						local name = vim.treesitter.get_node_text(name_node, bufnr)
						local start_row = node:range()
						table.insert(out, {
							name = name,
							range = { start = { line = start_row } },
							kind = type,
							bufnr = bufnr,
						})
					end
				end

				-- Recursively walk children
				for i = 0, node:named_child_count() - 1 do
					walk(node:named_child(i))
				end
			end

			walk(root)

			::continue::
		end
	end

	return out
end

-- Telescope picker
function M.select_symbol_and_get_text(symbol_lookup_fn, handle_symbol_fn)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local entry_display = require("telescope.pickers.entry_display")
	local devicons = require("nvim-web-devicons")

	local symbols = symbol_lookup_fn()
	if vim.tbl_isempty(symbols) then
		vim.notify("No symbols available", vim.log.levels.WARN)
		return
	end

	local make_entry = function(entry)
		local filename = vim.api.nvim_buf_get_name(entry.bufnr)
		local shortname = vim.fn.fnamemodify(filename, ":t")
		local ext = vim.fn.fnamemodify(filename, ":e")
		local icon, iconhl = devicons.get_icon(shortname, ext, { default = true })

		local displayer = entry_display.create({
			separator = " ",
			items = {
				{ width = 2 },
				{ width = 25 },
				{ width = 12 },
				{ remaining = true },
			},
		})

		local display = function()
			return displayer({
				{ icon, iconhl },
				entry.name,
				"[" .. entry.kind .. "]",
				shortname,
			})
		end

		return {
			value = entry,
			display = display,
			ordinal = entry.name .. " " .. shortname,
			filename = shortname,
			bufnr = entry.bufnr,
			start_row = entry.range.start.line,
			end_row = entry.range["end"].line,
		}
	end

	pickers
		.new({}, {
			prompt_title = "Select a symbol to add to context",
			finder = finders.new_table({
				results = symbols,
				entry_maker = make_entry,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local lines = vim.api.nvim_buf_get_lines(entry.bufnr, entry.start_row, entry.end_row + 1, false)
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
					vim.bo[self.state.bufnr].filetype = vim.bo[entry.bufnr].filetype
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry().value
					local bufnr = selection.bufnr
					local start_row = selection.range.start.line
					local end_row = selection.range["end"].line
					local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
					local symbolText = table.concat(lines, "\n")
					if handle_symbol_fn then
						handle_symbol_fn(symbolText)
					else
						print("Here is the selected function:\n\n" .. symbolText)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
