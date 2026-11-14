return {
    "folke/trouble.nvim",
    lazy = true,
    cmd = "Trouble",
    opts = {
        focus = true,
        preview = {
            type = "main",
            -- Preview in the file's real buffer, not trouble's scratch copy
            scratch = false,
        },
    },
}
