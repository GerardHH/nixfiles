return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        lazy = true,
        ft = "markdown",
        opts = {},
    },
    {
        "Kicamon/markdown-table-mode.nvim",
        lazy = true,
        cmd = "Mtm",
        opts = {
            options = {
                pad_separator_line = true, -- add space in separator line
            },
        },
    },
    {
        "brianhuster/live-preview.nvim",
        dependencies = { "ibhagwan/fzf-lua" }, -- picker for `:LivePreview pick`
        cmd = "LivePreview",
        keys = {
            { "<leader>vp", "<CMD>LivePreview start<CR>", desc = "View preview in browser" },
            { "<leader>vP", "<CMD>LivePreview close<CR>", desc = "View preview close" },
        },
        config = function()
            require("livepreview.config").set({
                picker = "fzf-lua",
            })
        end,
    },
}
