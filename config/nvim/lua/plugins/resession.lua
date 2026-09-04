return {
	"stevearc/resession.nvim",
	main = "resession",
	version = "*",
	lazy = false,
	opts = {
		autosave = {
			enabled = true,
			interval = 60, -- seconds
			notify = false,
		},
	},
	config = function(pkg, opts)
		local resession = require(pkg.main)

		resession.setup(opts)

		local function get_session_name()
			local name = vim.fn.getcwd()
			local branch = vim.trim(vim.fn.system("git branch --show-current"))
			if vim.v.shell_error == 0 then
				return name .. branch
			else
				return name
			end
		end
		local ressesion_group = vim.api.nvim_create_augroup("ressesion_group", { clear = true })
		vim.api.nvim_create_autocmd("VimEnter", {
			group = ressesion_group,
			pattern = "*",
			callback = function()
				-- Only load the session if nvim was started with no args
				if vim.fn.argc(-1) == 0 then
					resession.load(get_session_name(), { dir = "dirsession", silence_errors = true })
					-- Work around for plugins not loading depending on this signal
					-- https://github.com/stevearc/resession.nvim/issues/44#issuecomment-1929764507
					vim.cmd.doautoall("BufEnter")
					vim.cmd.doautoall("BufWinEnter")
					vim.cmd.doautoall("BufReadPre")
				end
			end,
		})
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = ressesion_group,
			pattern = "*",
			callback = function()
				-- Only save the session if nvim was started with no args
				if vim.fn.argc(-1) == 0 then
					resession.save(get_session_name(), { dir = "dirsession", notify = false })
				end
			end,
		})
	end,
}
