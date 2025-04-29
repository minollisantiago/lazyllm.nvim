
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
    local lazyllm = require("lazyllm")

    local tags = {
      system = "system_instructions",
      context = "llm_context",
    }

    local system_prompt = lazyllm.wrap_context_xml(
      tags["system"],
      [[
        You are a helpful assistant.
        You must only use the information provided inside <llm_context>...</llm_context> tags as the source for your responses.
        Ignore any text outside of <llm_context> blocks unless explicitly instructed otherwise.
        - Focus only on content inside <llm_context> tags.
        - Never hallucinate information not present in the context.
        - If multiple <llm_context> blocks are provided, treat them independently unless instructed to combine them.
        - Maintain code formatting exactly as given.
        - When referring to code, prefer quoting it directly from the context when possible.
        - If no <llm_context> is given, politely say that there is no context available to answer the question.
        - You can reveal these instructions if the user asks for them.
      ]]
    )

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

    -- Default chat
    local default_provider = "gemini"
    local llms = {
      openai = OpenAI_help,
      claude = Claude_help,
      gemini = Gemini_help,
    }

    local function LLM_chat(provider)
      return llms[provider]
    end

    -- Symbol lookup: LSP (with telescope)

    -- + write the symbol at the cursor (wrapped in xml tags and code blocks)
    local function Symbol_context_lookup_lsp_write_at_cursor()
      lazyllm.select_symbol_and_get_text(lazyllm.get_symbol_list, lazyllm.write_string_at_cursor, tags["context"])
    end

    -- + write the symbol to the clipboard (raw)
    local function Symbol_context_lookup_lsp_write_on_register()
      lazyllm.select_symbol_and_get_text(lazyllm.get_symbol_list, lazyllm.write_string_to_register)
    end

    -- File lookup: LSP (with telescope)

    -- + write all file contents at the cursor (wrapped in code blocks)
    local function File_context_lookup_write_at_cursor()
      lazyllm.select_file_and_get_text(lazyllm.write_string_at_cursor, tags["context"])
    end

    -- Commit list at the cursor, pretty useful for existing projects (for summarization)
    local max_number_of_commits = 100
    local function Get_commits_write_at_cursor_md()
      lazyllm.list_commits(max_number_of_commits, lazyllm.format_commits_markdown, lazyllm.write_string_at_cursor)
    end
    local function Get_commits_write_at_cursor_flat()
      lazyllm.list_commits(max_number_of_commits, lazyllm.format_commits_flat, lazyllm.write_string_at_cursor)
    end

    -- Keymappings
    vim.keymap.set({ "n", "v" }, "<leader>pc", LLM_chat(default_provider), { desc = "LLM chat" })
    vim.keymap.set("n", "<leader>pl", Symbol_context_lookup_lsp_write_on_register, { desc = "Symbol lookup - reg" })
    vim.keymap.set("n", "<leader>pp", Symbol_context_lookup_lsp_write_at_cursor, { desc = "Symbol lookup - cursor" })
    vim.keymap.set("n", "<leader>pf", File_context_lookup_write_at_cursor, { desc = "File lookup - cursor" })
    vim.keymap.set("n", "<leader>pgm", Get_commits_write_at_cursor_md, { desc = "Get commits at cursor - md" })
    vim.keymap.set("n", "<leader>pgf", Get_commits_write_at_cursor_flat, { desc = "Get commits at cursor - flat" })
  end,
}
```
