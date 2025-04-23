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

-- Insert commits into buffer using your write_at_cursor
function M.list_commits(limit, handle_commits_fn)
	local commits = M.get_git_log(limit or 20)
	if vim.tbl_isempty(commits) then
		vim.notify("No git commits found", vim.log.levels.WARN)
		return
	end

	if handle_commits_fn then
		handle_commits_fn(commits)
	else
		print("Here is the list of selected commits:\n\n" .. commits)
	end
end

return M
