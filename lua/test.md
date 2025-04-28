<llm_context filetype="lua" name="M.wrap_context_xml" kind="Function">
function M.wrap_context_xml(tag, content, metadata)
	local attributes = ""
	for k, v in pairs(metadata or {}) do
		attributes = attributes .. string.format(' %s="%s"', k, v)
	end
	return string.format("&lt;%s%s&gt;\n%s\n&lt;/%s&gt;", tag, attributes, escape_xml(content), tag)
end
</llm_context>

<user_question>
Explain this function
</user_question>


