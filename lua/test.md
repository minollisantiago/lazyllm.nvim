<llm_context name="M.get_lines_until_cursor" filetype="lua" kind="Function">
```lua
function M.get_lines_until_cursor()
	local current_buffer = vim.api.nvim_get_current_buf()
	local current_window = vim.api.nvim_get_current_win()
	local cursor_position = vim.api.nvim_win_get_cursor(current_window)
	local row = cursor_position[1]

	local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

	return table.concat(lines, "\n")
end
```
</llm_context>

Explain this function please

<llm_context kind="Variable" filetype="lua" name="prompts">
```lua
local prompts = require("promp_utils")
```
</llm_context>

<llm_context kind="Function" filetype="lua" name="M.handle_gemini_spec_data">
```lua
function M.handle_gemini_spec_data(data_stream)
	if data_stream:match('"candidates":') then
		local ok, json = pcall(vim.json.decode, data_stream)
		if ok and json.candidates and json.candidates[1] then
			local parts = json.candidates[1].content and json.candidates[1].content.parts
			if parts then
				for _, part in ipairs(parts) do
					if part.text then
						M.write_string_at_cursor(part.text)
					end
				end
			end
		end
	end
end
```
</llm_context>

<llm_context kind="Function" filetype="lua" name="M.make_openai_spec_curl_args">
```lua
function M.make_openai_spec_curl_args(opts, prompt, system_prompt)
	local url = opts.url
	local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
	if not api_key then
		error("API key not found for: " .. opts.api_key_name)
	end
	local data = {
		messages = { { role = "system", content = system_prompt }, { role = "user", content = prompt } },
		model = opts.model,
		temperature = 0.7,
		stream = true,
	}
	local args = { "-N", "-X", "POST", "-H", "Content-Type: application/json", "-d", vim.json.encode(data) }
	if api_key then
		table.insert(args, "-H")
		table.insert(args, "Authorization: Bearer " .. api_key)
	end
	table.insert(args, url)
	return args
end
```
</llm_context>

`M.get_lines_until_cursor` is a Lua function designed to retrieve all lines from the current buffer in a Neovim instance, up to the line where the cursor is currently located. It then concatenates these lines into a single string, separated by newline characters, and returns the resulting string.

Here's a breakdown:

1.  **`local current_buffer = vim.api.nvim_get_current_buf()`**: This line retrieves the handle (or identifier) of the current buffer in Neovim.  The `vim.api.nvim_get_current_buf()` function is a built-in Neovim API function that returns the current buffer.

2.  **`local current_window = vim.api.nvim_get_current_win()`**: This line retrieves the handle of the current window in Neovim using `vim.api.nvim_get_current_win()`.

3.  **`local cursor_position = vim.api.nvim_win_get_cursor(current_window)`**:  This line gets the cursor position within the current window. `vim.api.nvim_win_get_cursor()` returns a table containing the row and column of the cursor. The `current_window` handle obtained in the previous step is passed as an argument.

4.  **`local row = cursor_position[1]`**: This line extracts the row number from the `cursor_position` table.  In Neovim's API, row and column numbers are 1-indexed.

5.  **`local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)`**:  This is the core part of the function. It uses `vim.api.nvim_buf_get_lines()` to retrieve a list of lines from the buffer.
    *   `current_buffer`:  The buffer from which to retrieve the lines.
    *   `0`: The starting line index (0-indexed), meaning the first line of the buffer.
    *   `row`: The ending line index (0-indexed). Because `row` obtained earlier is 1-indexed, this retrieves lines up to and including the line *before* the cursor.
    *   `true`:  `true` indicates that the lines should be returned as a Lua table of strings.

6.  **`return table.concat(lines, "\n")`**: This line concatenates the lines retrieved in the previous step into a single string. `table.concat()` joins the elements of a table together. In this case, it joins the lines with a newline character (`\n`) as the separator, creating a single string containing all the lines up to the cursor position, separated by newlines. The resulting string is then returned by the function.


<!-- File: git_utils.lua -->
```lua
local M = {}

-- Get commit history using `git log`
function M.get_git_log(limit)
	local cmd = string.format("git log -n %d --pretty=format:'%%h|%%ad|%%an|%%s' --date=short", limit or 20)
	local handle = io.popen(cmd)
	if not handle then
		return {}
	end

	local result = handle:read("*a")
	handle:close()

	local commits = {}
	for line in result:gmatch("[^\r\n]+") do
		local hash, date, author, message = line:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
		if hash and date and author and message then
			table.insert(commits, {
				hash = hash,
				date = date,
				author = author,
				message = message,
			})
		end
	end

	return commits
end

-- Format commits markdown
function M.format_commits_markdown(commits)
	local lines = {}
	table.insert(lines, "| Date | Commit | Author | Message |")
	table.insert(lines, "|------|--------|--------|---------|")
	for _, c in ipairs(commits) do
		local row = string.format("| %s | `%s` | %s | %s |", c.date, c.hash, c.author, c.message)
		table.insert(lines, row)
	end
	return table.concat(lines, "\n")
end

-- Format commits flat stype
function M.format_commits_flat(commits)
	local lines = {}
	for _, c in ipairs(commits) do
		table.insert(lines, string.format("[%s] %s — %s", c.date, c.hash, c.message))
	end
	return table.concat(lines, "\n")
end

-- List commits, format them and handle the result
function M.list_commits(limit, format_commits_fn, handle_commits_fn)
	local commits = M.get_git_log(limit or 20)
	if vim.tbl_isempty(commits) then
		vim.notify("No git commits found", vim.log.levels.WARN)
		return
	end
	local commits_ = format_commits_fn(commits)
	if handle_commits_fn then
		handle_commits_fn(commits_)
	else
		print("Here is the list of selected commits:\n\n" .. commits)
	end
end

return M
```


