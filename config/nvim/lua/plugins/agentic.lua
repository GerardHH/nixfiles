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
