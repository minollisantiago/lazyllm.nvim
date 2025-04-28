local M = {}

local function get_api_key(name)
	return os.getenv(name)
end

function M.make_anthropic_spec_curl_args(opts, prompt, system_prompt)
	local url = opts.url
	local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
	if not api_key then
		error("API key not found for: " .. opts.api_key_name)
	end
	local data = {
		system = system_prompt,
		messages = { { role = "user", content = prompt } },
		model = opts.model,
		stream = true,
		max_tokens = 4096,
	}
	local args = { "-N", "-X", "POST", "-H", "Content-Type: application/json", "-d", vim.json.encode(data) }
	if api_key then
		table.insert(args, "-H")
		table.insert(args, "x-api-key: " .. api_key)
		table.insert(args, "-H")
		table.insert(args, "anthropic-version: 2023-06-01")
	end
	table.insert(args, url)
	return args
end

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

function M.make_gemini_spec_curl_args(opts, prompt, system_prompt)
	-- Validate necessary options
	if not opts.model then
		error("opts.model (e.g., 'gemini-2.0-flash') is required for the Gemini API URL")
		return nil
	end
	if not opts.api_key_name then
		error("opts.api_key_name is required for Gemini API authentication")
		return nil
	end

	local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
	if not api_key then
		error("Could not retrieve Gemini API key using name: " .. opts.api_key_name)
		return nil
	end

	-- Construct the gemini API URL
	local url = string.format("%sv1beta/models/%s:streamGenerateContent?alt=sse", opts.url, opts.model)

	-- Prompts
	local data = {
		contents = {
			{ role = "user", parts = { { text = prompt } } },
		},
		generationConfig = {
			temperature = opts.temperature or 0.7,
			maxOutputTokens = opts.maxTokens or 4096,
		},
	}

	local args = {
		"-N",
		"-X",
		"POST",
		"-H",
		"Content-Type: application/json",
		"-H",
		"x-goog-api-key: " .. api_key,
		"-d",
		vim.json.encode(data),
	}

	table.insert(args, url)
	return args
end

return M
