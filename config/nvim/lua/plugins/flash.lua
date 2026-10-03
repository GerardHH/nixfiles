-- <CR> keeps its built-in meaning outside file buffers: quickfix and the
-- command-line window use it to jump and to execute.
local function in_file_buffer(fn)
    return function()
        if vim.bo.buftype ~= "" then
            vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
            return
        end
        fn()
    end
end

return {
    "folke/flash.nvim",
    lazy = true,
    keys = {
        { "<CR>", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
        {
            "<S-CR>",
            mode = { "n", "x", "o" },
            in_file_buffer(function() require("flash").treesitter() end),
            desc = "Flash treesitter jump",
        },
        { "r", mode = "o", function() require("flash").remote() end, desc = "Flash remote" },
        {
            "R",
            mode = { "o", "x" },
            function() require("flash").treesitter_search() end,
            desc = "Flash treesitter Search",
        },
    },
    opts = {
        modes = {
            char = {
                enabled = false,
            },
        },
    },
}
