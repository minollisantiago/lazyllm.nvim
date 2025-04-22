


### Lazy config
Add your API keys to your env, here is an example with fish:
```fish
# LLMs
set -gx XAI_API_KEY "xai_api_key_placeholder"
set -gx GEMINI_API_KEY "gemini_api_key_placeholder"
```

Add this to your lazy config:
```lua
return {
  "minollisantiago/lazyllm.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },

  config = function()
    local system_prompt = "Your are a helpful assistant."
    local lazyllm = require("lazyllm")

    -- OpenAI Chat
    local function OpenAI_help()
      lazyllm.invoke_llm_and_stream_into_editor({
        url = "https://api.openai.com/v1/chat/completions",
        model = "gpt-4o-mini",
        api_key_name = "OPENAI_API_KEY",
        system_prompt = system_prompt,
        replace = false,
      }, lazyllm.make_openai_spec_curl_args, lazyllm.handle_openai_spec_data)
    end

    -- Anthropic Claude Chat
    local function Claude_help()
      lazyllm.invoke_llm_and_stream_into_editor({
        url = "https://api.anthropic.com/v1/messages",
        model = "claude-3-5-sonnet-20241022",
        api_key_name = "ANTHROPIC_API_KEY",
        system_prompt = system_prompt,
        replace = false,
      }, lazyllm.make_anthropic_spec_curl_args, lazyllm.handle_anthropic_spec_data)
    end

    -- Gemini Native
    local function Gemini_help()
      lazyllm.invoke_llm_and_stream_into_editor({
        url = "https://generativelanguage.googleapis.com/",
        model = "gemini-2.0-flash",
        api_key_name = "GEMINI_API_KEY",
        system_prompt = system_prompt,
        replace = false,
      }, lazyllm.make_gemini_spec_curl_args, lazyllm.handle_gemini_spec_data)
    end

    -- Keymappings
    vim.keymap.set({ "n", "v" }, "<leader>oa", OpenAI_help, { desc = "LLM: OpenAI chat" })
    vim.keymap.set({ "n", "v" }, "<leader>an", Claude_help, { desc = "LLM: Anthropic (Claude) chat" })
    vim.keymap.set({ "n", "v" }, "<leader>gm", Gemini_help, { desc = "LLM: Gemini chat" })
  end,
}
```
