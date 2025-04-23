
## LazyLLM
My own (dirty and lazy) take on [Yacine's dingllm scripts](https://github.com/yacineMTB/dingllm.nvim)

https://github.com/user-attachments/assets/2b83319f-704d-479c-b496-3c8836ee72c4

> [!NOTE]
> Ive extended the scripts to include Gemini and symbol lookup with telescope. The idea is to be able to quickly find and paste symbols to the chat for more context.

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
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },

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

    -- Symbol lookup: LSP
    local function Symbol_context_lookup_lsp()
      lazyllm.select_symbol_and_get_text(lazyllm.get_symbol_list)
    end
    --
    -- Symbol lookup: LSP, write the result at the cursor
    local function Symbol_context_lookup_lsp_write_at_cursor()
      lazyllm.select_symbol_and_get_text(lazyllm.get_symbol_list, lazyllm.write_string_at_cursor)
    end

    -- Keymappings
    vim.keymap.set({ "n", "v" }, "<leader>po", OpenAI_help, { desc = "LLM: OpenAI chat" })
    vim.keymap.set({ "n", "v" }, "<leader>pc", Claude_help, { desc = "LLM: Anthropic (Claude) chat" })
    vim.keymap.set({ "n", "v" }, "<leader>pg", Gemini_help, { desc = "LLM: Gemini chat" })
    vim.keymap.set("n", "<leader>pl", Symbol_context_lookup_lsp, { desc = "LLM on symbol" })
    vim.keymap.set("n", "<leader>pt", Symbol_context_lookup_lsp_write_at_cursor, { desc = "LLM on symbol - cursor" })
  end,
}
```
