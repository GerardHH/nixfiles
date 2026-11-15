return {
    dir = vim.fn.stdpath("config") .. "/local-plugins/agent-review",
    name = "agent-review",
    lazy = true,
    keys = {
        {
            "<leader>ar",
            "<CMD>Trouble agent_review toggle<CR>",
            desc = "Agent review (git changes)",
        },
        {
            "<leader>as",
            function() require("agent_review").toggle_review_layout() end,
            desc = "Agent review side by side (toggle)",
        },
    },
}
