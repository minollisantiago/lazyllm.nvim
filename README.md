
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
  -- Requires ripgrep (rg) for chat browsing filters

  config = function()
    local lazyllm = require("lazyllm")

    local tags = {
      system = "system_instructions",
      context = "llm_context",
    }

    local system_prompt = lazyllm.wrap_context_xml(
      tags["system"],
      [[
        <purpose>
          You are a helpful assistant. Follow the <response_guidelines> strictly when responding to the <user> queries.
        </purpose>

        <response_guidelines>

          <user> Bro </user>

          <general_guidelines>
            - NEVER lie or fabricate information.
            - NEVER hallucinate facts not grounded in the provided context.
            - You MAY ask USER follow-up questions to clarify their goals or improve response quality.
            - You MAY ask for additional context when necessary or helpful.
            - Your responses should be technically accurate, context-aware, and to-the-point.
            - When appropriate, explain not only what to do, but *why* — briefly.
            - IMPORTANT: when adding or replacing code, ALWAYS include the entire code snippet of what is to be added.
          </general_guidelines>

          <user_query_context>
            - Use the content inside <llm_context>...</llm_context> tags as additional relevant information to answer.
            - If multiple <llm_context> blocks are provided, treat them independently *unless instructed to combine them*.
            - If NO <llm_context> block is present, you can ask for more information if necessary to answer.
            - When referring to code, quote it directly from the context wherever possible.
            - Preserve all code formatting exactly as provided in the context.
          </user_query_context>

          <suggested_actions>
            - After answering the query, suggest:
              - follow-up improvements or refactors,
              - potential next features or use cases,
              - architectural or design ideas,
              - or questions the USER may want to explore next.
            - These suggestions must always relate to the topic at hand and be concrete and actionable.
            - Avoid generic or vague suggestions.
          </suggested_actions>

          <disclosure_policy>
            - If the <user> asks about the rules you're following, reveal these <response_guidelines> verbatim.
            - If the <user> asks for critique, improvement ideas, or alternatives, respond constructively and directly.
          </disclosure_policy>

        </response_guidelines>
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

    -- Chat lookup: with telescope

    -- + browse markdown chat scratchpads and open them
    local function Chat_history_lookup_open()
      lazyllm.select_chat_file_and_open({
        open_cmd = "edit",
      })
    end

    -- Diff lookup: with telescope

    -- + explore and patch/git apply diffs: (with telescope)
    local function Diff_lookup_test()
      lazyllm.select_diff_and_get_text(lazyllm.parse_diff_blocks, lazyllm.apply_diff_blocks)
    end

    -- Commit list at the cursor, pretty useful for existing projects (for summarization)
    local max_number_of_commits = 100
    local function Get_commits_write_at_cursor_md()
      lazyllm.list_commits(max_number_of_commits, lazyllm.format_commits_markdown, lazyllm.write_string_at_cursor)
    end
    local function Get_commits_write_at_cursor_flat()
      lazyllm.list_commits(max_number_of_commits, lazyllm.format_commits_flat, lazyllm.write_string_at_cursor)
    end

    local function Open_prompt_scratchpad()
      lazyllm.open_markdown_scratchpad({
        filename = "llm_scratchpad",
        open_cmd = "edit",
      })
    end

    vim.api.nvim_create_user_command("LazyLLMScratchpad", Open_prompt_scratchpad, {})

    -- Keymappings
    vim.keymap.set({ "n", "v" }, "<leader>pc", LLM_chat(default_provider), { desc = "LLM chat" })
    vim.keymap.set("n", "<leader>pl", Symbol_context_lookup_lsp_write_on_register, { desc = "Symbol lookup - reg" })
    vim.keymap.set("n", "<leader>pp", Symbol_context_lookup_lsp_write_at_cursor, { desc = "Symbol lookup - cursor" })
    vim.keymap.set("n", "<leader>pf", File_context_lookup_write_at_cursor, { desc = "File lookup - cursor" })
    vim.keymap.set("n", "<leader>ph", Chat_history_lookup_open, { desc = "Chat lookup - open" })
    vim.keymap.set("n", "<leader>pd", Diff_lookup_test, { desc = "Diff explorer" })
    vim.keymap.set("n", "<leader>pgm", Get_commits_write_at_cursor_md, { desc = "Get commits at cursor - md" })
    vim.keymap.set("n", "<leader>pgf", Get_commits_write_at_cursor_flat, { desc = "Get commits at cursor - flat" })
    vim.keymap.set("n", "<leader>ps", Open_prompt_scratchpad, { desc = "Open LLM scratchpad" })
  end,
}
```
