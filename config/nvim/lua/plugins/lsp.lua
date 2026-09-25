-- All language server, with overrides. Merged on top of the defaults nvim-lspconfig ships.
local function servers()
	local nix_flake = vim.env.HOME .. "/nixfiles"
	local nix_hm_config = vim.env.USER == "ubuntu" and "container" or "personal"

	return {
		bashls = {},
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
		cmake = {},
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
		marksman = {},
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
		pyright = {},
		ruff = {},
	}
end

return {
	-- LSP
	{
		"neovim/nvim-lspconfig",
		version = "*",
		dependencies = {
			"saghen/blink.cmp",
			"SmiteshP/nvim-navic",
		},
		lazy = true,
		ft = {
			"bash",
			"c",
			"cmake",
			"cpp",
			"lua",
			"markdown",
			"python",
			"sh",
			"nix",
		},
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
			local group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true })

			vim.api.nvim_create_autocmd("LspAttach", {
				group = group,
				callback = function(args)
					local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
					if client:supports_method("textDocument/documentSymbol") then
						require("nvim-navic").attach(client, args.buf)
					end
				end,
			})
		end,
		config = function()
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			})

			local enabled, missing = {}, {}

			for name, override in pairs(servers()) do
				vim.lsp.config(name, override)

				local cmd = (vim.lsp.config[name] or {}).cmd
				local bin = type(cmd) == "table" and cmd[1] or nil

				if bin and vim.fn.executable(bin) == 0 then
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
		version = "*",
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
		version = "*",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		lazy = true,
		event = "LspAttach",
		config = function()
			local lsp_formatting = function(bufnr)
				vim.lsp.buf.format({
					bufnr = bufnr,
					filter = function(client)
						-- apply whatever logic you want (in this example, we'll only use null-ls)
						return client.name == "null-ls"
					end,
					timeout_ms = 2000,
				})
			end

			local null_ls = require("null-ls")

			local sources = {}
			local missing = {}

			for _, candidate in ipairs({
				{ null_ls.builtins.diagnostics.mypy, "mypy" }, -- python
				{ null_ls.builtins.formatting.black, "black" }, -- python
				{ null_ls.builtins.formatting.clang_format, "clang-format" }, -- c/c++
				{ null_ls.builtins.formatting.shfmt, "shfmt" }, -- shell
				{ null_ls.builtins.formatting.stylua, "stylua" }, -- lua
				{ null_ls.builtins.formatting.nixfmt, "nixfmt" }, -- nix
			}) do
				if vim.fn.executable(candidate[2]) == 1 then
					table.insert(sources, candidate[1])
				else
					table.insert(missing, candidate[2])
				end
			end

			local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

			null_ls.setup({
				sources = sources,
				on_attach = function(client, bufnr)
					if client:supports_method("textDocument/formatting") then
						vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
						vim.api.nvim_create_autocmd("BufWritePre", {
							group = augroup,
							buffer = bufnr,
							callback = function() lsp_formatting(bufnr) end,
						})
					end
				end,
			})
		end,
	},
	-- Others
	{
		"utilyre/barbecue.nvim",
		version = "*",
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
		version = "*",
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
		version = "*",
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
		version = "*",
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
