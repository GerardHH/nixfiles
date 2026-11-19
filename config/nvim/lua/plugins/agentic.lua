local function agentic(function_name)
    return function() require("agentic")[function_name]() end
end

return {
    "carlos-algms/agentic.nvim",
    cond = vim.fn.executable("claude-agent-acp") == 1,
    lazy = true,
    opts = {
        provider = "claude-agent-acp",
        provider_switcher = {
            hide_unhealthy_providers = true,
        },
        keymaps = {
            widget = {
                switch_provider = "<leader>aP",
                switch_model = "<leader>am",
                -- Effort, the name Claude Code uses for the thought level.
                change_thought_level = "<leader>ae",
                open_options = "<leader>ao",
                select_session = "<leader>al",
                next_session = "<leader>a]",
                prev_session = "<leader>a[",
                -- K for kill: no confirmation, so not next to `<leader>ax`.
                destroy_session = "<leader>aK",
            },
            prompt = {
                paste_image = {
                    { "<leader>ap", mode = { "n" } },
                    -- agentic's default, as in Claude Code.
                    { "<C-v>", mode = { "i" } },
                },
            },
        },
        acp_providers = {
            ["claude-agent-acp"] = {
                -- Each session starts at medium effort; the adapter ignores
                -- `modelSettings` in Claude's settings and would start at
                -- xhigh. `<leader>ae` changes it per session.
                default_thought_level = "medium",
            },
        },
    },
    keys = {
        {
            "<leader>aa",
            agentic("toggle"),
            mode = { "n", "v" },
            desc = "Agent chat (toggle)",
        },
        {
            "<leader>ac",
            agentic("add_selection_or_file_to_context"),
            mode = { "n", "v" },
            desc = "Agent context: add selection or file",
        },
        {
            "<leader>ad",
            agentic("add_current_line_diagnostics"),
            desc = "Agent context: add line diagnostics",
        },
        {
            "<leader>aD",
            agentic("add_buffer_diagnostics"),
            desc = "Agent context: add buffer diagnostics",
        },
        {
            "<leader>an",
            agentic("new_session"),
            desc = "Agent new session",
        },
        {
            -- Picks one of the agent's earlier sessions, also those started
            -- from the terminal CLI.
            "<leader>aR",
            agentic("restore_session"),
            desc = "Agent restore session",
        },
        {
            "<leader>ax",
            agentic("stop_generation"),
            desc = "Agent stop",
        },
    },
}
