return {
	"stevearc/overseer.nvim",
	version = "*",
	lazy = true,
	keys = {
		{ "<leader>rt", "<CMD>OverseerRun<CR>", desc = "Run task" },
		{ "<leader>rT", "<CMD>OverseerToggle<CR>", desc = "Run toggle results" },
		{
			"<leader>rr",
			function()
				local overseer = require("overseer")
				local tasks = overseer.list_tasks({ recent_first = true })
				if vim.tbl_isempty(tasks) then
					vim.notify("No tasks found", vim.log.levels.WARN)
				else
					overseer.run_action(tasks[1], "restart")
				end
			end,
			desc = "Run re-run task",
		},
	},
	opts = {
		task_list = {
			bindings = {
				["<F1>"] = "ShowHelp",
			},
		},
		task_launcher = {
			bindings = {
				i = {
					["<F1>"] = "ShowHelp",
				},
				n = {
					["<F1>"] = "ShowHelp",
				},
			},
		},
		task_editor = {
			bindings = {
				i = {
					["<F1>"] = "ShowHelp",
				},
				n = {
					["<F1>"] = "ShowHelp",
				},
			},
		},
	},
}
