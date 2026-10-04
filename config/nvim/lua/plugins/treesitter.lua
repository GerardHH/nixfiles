local languages = require("languages")

local function textobject(capture)
    return function() require("nvim-treesitter-textobjects.select").select_textobject(capture, "textobjects") end
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        -- The main branch doesn't support lazy-loading.
        lazy = false,
        config = function(plugin)
            -- Parsers come from nix, via home/modules/nvim.nix. Installing them with
            -- :TSInstall is what would link these queries into the runtimepath, so add
            -- them by hand. Appended, so that Neovim's bundled queries stay first for
            -- the parsers it bundles.
            vim.opt.runtimepath:append(plugin.dir .. "/runtime")

            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter", { clear = true }),
                callback = function(args)
                    local language = vim.treesitter.language.get_lang(args.match)

                    if not language or not vim.treesitter.language.add(language) then return end

                    -- vim.treesitter.start turns regex syntax off, so a parser without a
                    -- highlights query leaves the buffer uncolored. Let nbim's own syntax
                    -- file do the work instead.
                    if #vim.api.nvim_get_runtime_file("queries/" .. language .. "/highlights.scm", true) == 0 then
                        return
                    end

                    vim.treesitter.start(args.buf, language)

                    if vim.treesitter.query.get(language, "indents") then
                        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                    end
                end,
            })

            local missing = {}

            for _, grammar in ipairs(languages.grammars) do
                if #vim.api.nvim_get_runtime_file("parser/" .. grammar .. ".so", false) == 0 then
                    table.insert(missing, grammar)
                end
            end

            if #missing > 0 then
                table.sort(missing)
                vim.schedule(
                    function()
                        vim.notify(
                            "Parsers missing from the nix runtime:\n" .. table.concat(missing, "\n"),
                            vim.log.levels.WARN,
                            { title = "Treesitter" }
                        )
                    end
                )
            end
        end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
        },
        lazy = true,
        event = "VeryLazy",
        opts = {
            indent = {
                char = "",
                highlight = {
                    "RainbowRed",
                    "RainbowYellow",
                    "RainbowBlue",
                    "RainbowOrange",
                    "RainbowGreen",
                    "RainbowViolet",
                    "RainbowCyan",
                },
            },
        },
    },
    {
        "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        main = "nvim-treesitter-textobjects",
        lazy = true,
        keys = {
            { "af", textobject("@function.outer"), mode = { "x", "o" }, desc = "Around function" },
            { "if", textobject("@function.inner"), mode = { "x", "o" }, desc = "Inside function" },
            { "ac", textobject("@class.outer"), mode = { "x", "o" }, desc = "Around class" },
            { "ic", textobject("@class.inner"), mode = { "x", "o" }, desc = "Inside class" },
            { "ai", textobject("@conditional.outer"), mode = { "x", "o" }, desc = "Around conditional (if)" },
            { "ii", textobject("@conditional.inner"), mode = { "x", "o" }, desc = "Inside conditional (if)" },
            { "al", textobject("@loop.outer"), mode = { "x", "o" }, desc = "Around loop" },
            { "il", textobject("@loop.inner"), mode = { "x", "o" }, desc = "Inside loop" },
            { "at", textobject("@comment.outer"), mode = { "x", "o" }, desc = "Select comment (text)" },
            { "ap", textobject("@parameter.outer"), mode = { "x", "o" }, desc = "Around parameter" },
            { "ip", textobject("@parameter.inner"), mode = { "x", "o" }, desc = "Inside parameter" },
            { "ar", textobject("@return.outer"), mode = { "x", "o" }, desc = "Around return" },
            { "ir", textobject("@return.inner"), mode = { "x", "o" }, desc = "Inside return" },
        },
        opts = {
            select = {
                lookahead = true, -- Jump forward to textobj
            },
        },
    },
}
