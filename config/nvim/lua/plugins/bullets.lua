return {
	"dkarter/bullets.vim",
	version = "*",
	lazy = true,
	ft = {
		"markdown",
		"text",
		"gitcommit",
	},
	config = function()
		-- Optional custom settings (change as needed)
		vim.g.bullets_enabled_file_types = {
			"markdown",
			"text",
			"gitcommit",
		}
		vim.g.bullets_outline_levels = { "num", "abc", "std-" }

		-- Disable default mappings
		vim.g.bullets_set_mappings = 0
		-- Define custom mappings
		vim.g.bullets_custom_mappings = {
			{ "imap", "<CR>", "<Plug>(bullets-newline)" },
			{ "inoremap", "<C-CR>", "<CR>" },

			{ "nmap", "o", "<Plug>(bullets-newline)" },

			{ "vmap", "gN", "<Plug>(bullets-renumber)" },
			{ "nmap", "gN", "<Plug>(bullets-renumber)" },

			{ "nmap", "<leader>x", "<Plug>(bullets-toggle-checkbox)" },

			{ "imap", "<C-t>", "<Plug>(bullets-demote)" },
			{ "nmap", ">>", "<Plug>(bullets-demote)" },
			{ "vmap", ">", "<Plug>(bullets-demote)" },

			{ "imap", "<C-d>", "<Plug>(bullets-promote)" },
			{ "nmap", "<<", "<Plug>(bullets-promote)" },
			{ "vmap", "<", "<Plug>(bullets-promote)" },
		}

		-- Demote on empty bullet, delete when can no longer demote
		vim.g.bullets_delete_last_bullet_if_empty = 2
	end,
}
