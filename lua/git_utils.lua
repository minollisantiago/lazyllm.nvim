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
