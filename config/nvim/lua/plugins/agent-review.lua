-- agent-review: review an agent's unstaged changes with its notes, in
-- trouble.nvim (local plugin in `local-plugins/agent-review`, see its
-- README.md). Keys under <leader>q, with trouble's lists.
return {
    dir = vim.fn.stdpath("config") .. "/local-plugins/agent-review",
    name = "agent-review",
    -- Loaded by its keys, which must live here, not in trouble's spec:
    -- trouble only finds the `agent_review` source in plugins already loaded.
    lazy = true,
    keys = {
        {
            "<leader>qg",
            "<CMD>Trouble agent_review toggle<CR>",
            desc = "Trouble agent review (git changes)",
        },
        {
            -- Inline diff marks or the index version side by side; works
            -- during a review and sets the layout the next one starts in.
            "<leader>qs",
            function() require("agent_review").toggle_review_layout() end,
            desc = "Trouble agent review side by side (toggle)",
        },
    },
}
