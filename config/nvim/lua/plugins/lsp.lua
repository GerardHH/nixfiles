local languages = require("languages")

local format_on_save = {}
for _, name in ipairs(languages.formatters or {}) do
    format_on_save[name] = true
end

local function server_overrides()
    local nix_flake = vim.env.HOME .. "/nixfiles"
    local nix_hm_config = vim.env.USER == "ubuntu" and "container" or "personal"

    return {
        clangd = {
            capabilities = {
                offsetEncoding = { "utf-16" },
            },
            cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--header-insertion=iwyu",
                "--completion-style=detailed",
                "--function-arg-placeholders",
                "--fallback-style=llvm",
            },
        },
        jsonls = {
            settings = {
                json = {
                    schemas = require("schemastore").json.schemas(),
                    validate = { enable = true },
                },
            },
        },
        lua_ls = {
            settings = {
                Lua = {
                    runtime = {
                        version = "LuaJIT",
                        path = vim.split(package.path, ";"),
                    },
                    completion = {
                        callSnippet = "Replace",
                    },
                    workspace = {
                        checkThirdParty = false,
                        library = {
                            vim.env.VIMRUNTIME,
                            "${3rd}/luv/library",
                            "${3rd}/busted/library",
                        },
                    },
                },
            },
        },
        nixd = {
            cmd = { "nixd", "--log=error" },
            settings = {
                nixd = {
                    nixpkgs = {
                        expr = ('import (builtins.getFlake "%s").inputs.nixpkgs { }'):format(nix_flake),
                    },
                    options = {
                        ["home-manager"] = {
                            expr = ('(builtins.getFlake "%s").homeConfigurations.%s.options'):format(
                                nix_flake,
                                nix_hm_config
                            ),
                        },
                    },
                },
            },
        },
        yamlls = {
            settings = {
                yaml = {
                    -- Take the catalog from SchemaStore.nvim,instead of
                    -- the server downloading schemastore.org's at startup.
                    schemaStore = { enable = false, url = "" },
                    schemas = require("schemastore").yaml.schemas(),
                },
            },
        },
    }
end

return {
    -- LSP
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "saghen/blink.cmp",
            "SmiteshP/nvim-navic",
            "b0o/SchemaStore.nvim",
        },
        lazy = true,
        ft = languages.filetypes,
        keys = {
            -- lsp
            { "<leader>lG", vim.lsp.buf.type_definition, desc = "LSP Go to type definition" },
            { "<leader>lg", vim.lsp.buf.definition, desc = "LSP Go to definition" },
            { "<leader>lh", vim.lsp.buf.hover, desc = "LSP hover documentation" },
            { "<leader>ls", "<CMD>LspClangdSwitchSourceHeader<CR>", desc = "LSP Switch header/source" },
            -- View
            { "<leader>vL", "<CMD>checkhealth vim.lsp<CR>", desc = "View connected LS's" },
        },
        init = function()
            -- `format_on_save = false` in an .editorconfig section skips formatting on
            -- save for those files, e.g. lazy-lock.json, which lazy.nvim writes itself.
            -- Registered in init so it exists before the first buffer is read.
            require("editorconfig").properties.format_on_save = function(bufnr, val)
                vim.b[bufnr].format_on_save = val ~= "false"
            end

            local group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = group,
                callback = function(args)
                    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
                    if client:supports_method("textDocument/documentSymbol") then
                        require("nvim-navic").attach(client, args.buf)

                        if client:supports_method("textDocument/documentHighlight") then
                            local highlight =
                                vim.api.nvim_create_augroup("UserLspHighlight" .. args.buf, { clear = true })
                            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                                group = highlight,
                                buffer = args.buf,
                                callback = function() vim.lsp.buf.document_highlight() end,
                            })
                            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                                group = highlight,
                                buffer = args.buf,
                                callback = function() vim.lsp.buf.clear_references() end,
                            })
                        end
                    end

                    -- Format on save for all language servers and formatters (if they support it)
                    if format_on_save[client.name] then
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            group = vim.api.nvim_create_augroup("UserLspFormat" .. args.buf, { clear = true }),
                            buffer = args.buf,
                            callback = function()
                                -- Off per file through .editorconfig (see above), or for the
                                -- whole session with `:let g:format_on_save = v:false`, e.g.
                                -- in a repo whose JSON/YAML/Markdown nobody formats.
                                if vim.b[args.buf].format_on_save == false or vim.g.format_on_save == false then
                                    return
                                end
                                -- Skip quitly when no listed client formats this buffer.
                                -- Some are tricky like that such as lemminx and docker_language_server.
                                local can_format = vim.tbl_filter(
                                    function(c) return format_on_save[c.name] == true end,
                                    vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })
                                )
                                if #can_format == 0 then return end
                                vim.lsp.buf.format({
                                    bufnr = args.buf,
                                    filter = function(c) return format_on_save[c.name] == true end,
                                    timeout_ms = 2000,
                                })
                            end,
                        })
                    end
                end,
            })
        end,
        config = function()
            vim.lsp.config("*", {
                capabilities = require("blink.cmp").get_lsp_capabilities(),
            })

            local overrides = server_overrides()
            local enabled, missing = {}, {}

            for _, name in ipairs(languages.servers) do
                local override = overrides[name]
                if override then vim.lsp.config(name, override) end

                local resolved = vim.lsp.config[name]
                local cmd = resolved and resolved.cmd
                local bin = type(cmd) == "table" and cmd[1] or nil

                if not resolved then
                    table.insert(missing, ("%s (no config found)"):format(name))
                elseif bin and vim.fn.executable(bin) == 0 then
                    table.insert(missing, ("%s (%s)"):format(name, bin))
                else
                    table.insert(enabled, name)
                end
            end

            if #missing > 0 then
                table.sort(missing)
                vim.schedule(
                    function()
                        vim.notify(
                            "Not installed, server disabled:\n" .. table.concat(missing, "\n"),
                            vim.log.levels.WARN,
                            { title = "LSP" }
                        )
                    end
                )
            end

            vim.lsp.enable(enabled)
            vim.lsp.inlay_hint.enable()
        end,
    },
    {
        "mrcjkb/rustaceanvim",
        lazy = true,
        ft = "rust",
        config = function()
            vim.lsp.inlay_hint.enable()
            vim.api.nvim_create_autocmd("BufWritePre", {
                pattern = "*.rs",
                callback = function(args)
                    vim.lsp.buf.format({
                        bufnr = args.buf,
                        async = false,
                    })
                end,
            })
        end,
        cond = function()
            if vim.fn.executable("rust-analyzer") == 1 then return true end
            vim.schedule(
                function()
                    vim.notify(
                        "Not installed, rustaceanvim disabled:\nrust-analyzer",
                        vim.log.levels.WARN,
                        { title = "LSP" }
                    )
                end
            )
        end,
    },
    -- Linting & Formatting
    {
        "nvimtools/none-ls.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        lazy = true,
        event = "LspAttach",
        config = function()
            local null_ls = require("null-ls")

            local sources = {}
            local missing = {}

            for _, candidate in ipairs({
                { null_ls.builtins.diagnostics.mypy, "mypy" }, -- python
                { null_ls.builtins.formatting.black, "black" }, -- python
                { null_ls.builtins.formatting.clang_format, "clang-format" }, -- c/c++
                { null_ls.builtins.formatting.shfmt, "shfmt" }, -- shell
                { null_ls.builtins.formatting.stylua, "stylua" }, -- lua
                {
                    null_ls.builtins.formatting.nixfmt.with({
                        extra_args = function(params)
                            local editorconfig = vim.b[params.bufnr].editorconfig
                            local indent = editorconfig and editorconfig.indent_size
                            return indent and { "--indent=" .. indent } or {}
                        end,
                    }),
                    "nixfmt",
                }, -- nix
            }) do
                if vim.fn.executable(candidate[2]) == 1 then
                    table.insert(sources, candidate[1])
                else
                    table.insert(missing, candidate[2])
                end
            end

            -- Format on save is set up in nvim-lspconfig's LspAttach autocmd, for
            -- null-ls and the language servers alike.
            null_ls.setup({ sources = sources })
        end,
    },
    -- Others
    {
        "utilyre/barbecue.nvim",
        dependencies = {
            "SmiteshP/nvim-navic",
            "nvim-tree/nvim-web-devicons",
        },
        lazy = true,
        event = "LspAttach",
        opts = {
            attach_navic = false,
        },
    },
    {
        "rmagatti/goto-preview",
        lazy = true,
        keys = {
            {
                "<leader>lp",
                function() require("goto-preview").goto_preview_definition({}) end,
                desc = "LSP preview definition",
            },
            {
                "<leader>lP",
                function() require("goto-preview").goto_preview_type_definition({}) end,
                desc = "LSP preview type definition",
            },
        },
        opts = {},
    },
    {
        "smjonas/inc-rename.nvim",
        lazy = true,
        keys = {
            {
                "<leader>lr",
                function() return ":IncRename " .. vim.fn.expand("<cword>") end,
                expr = true,
                desc = "LSP rename",
            },
        },
        opts = {},
    },
    {
        "kosayoda/nvim-lightbulb",
        version = false,
        lazy = true,
        event = "LspAttach",
        opts = {
            autocmd = {
                enabled = true,
            },
            sign = {
                enabled = true,
                text = "",
            },
            virtual_text = {
                enabled = true,
                text = "",
            },
        },
    },
}
