-- Runs tests with a cleared output panel, so the panel only shows this run.
local function run_tests(args)
	local neotest = require("neotest")
	neotest.output_panel.clear()
	neotest.run.run(args)
	-- Do work on next tick, so that it doesn't fight the event cycle
	vim.schedule(function() neotest.output_panel.open() end)
end

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			{ "theHamsta/nvim-dap-virtual-text", opts = {} },
		},
		lazy = true,
		keys = {
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug toggle breakpoint" },
			{
				"<leader>dB",
				function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end,
				desc = "Debug conditional breakpoint",
			},
			{ "<leader>dc", function() require("dap").continue() end, desc = "Debug run/continue" },
			{ "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Debug run to cursor" },
			{ "<leader>di", function() require("dap").step_into() end, desc = "Debug step into" },
			{ "<leader>dO", function() require("dap").step_over() end, desc = "Debug step over" },
			{ "<leader>do", function() require("dap").step_out() end, desc = "Debug step out" },
			{ "<leader>dj", function() require("dap").down() end, desc = "Debug down" },
			{ "<leader>dk", function() require("dap").up() end, desc = "Debug up" },
			{ "<leader>dl", function() require("dap").run_last() end, desc = "Debug run last" },
			{ "<leader>dP", function() require("dap").pause() end, desc = "Debug pause" },
			{ "<leader>dr", function() require("dap").repl.toggle() end, desc = "Debug toggle REPL" },
			{ "<leader>dt", function() require("dap").terminate() end, desc = "Debug terminate" },
			{ "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Debug hover value" },
		},
		config = function()
			local dap = require("dap")

			-- codelldb comes from home/modules/nvim.nix. Rust launch configurations
			-- are loaded by rustaceanvim, so only C and C++ are declared here.
			dap.adapters.codelldb = {
				type = "executable",
				command = "codelldb",
			}

			local launch = {
				name = "Launch executable",
				type = "codelldb",
				request = "launch",
				program = require("dap.utils").pick_file,
				cwd = "${workspaceFolder}",
			}
			dap.configurations.c = { launch }
			dap.configurations.cpp = { launch }
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "nvim-neotest/nvim-nio" },
		lazy = true,
		keys = {
			{ "<leader>du", function() require("dapui").toggle({}) end, desc = "Debug dap UI" },
			{ "<leader>de", function() require("dapui").eval() end, desc = "Debug eval", mode = { "n", "v" } },
		},
		opts = {},
		config = function(_, opts)
			local dap = require("dap")
			local dapui = require("dapui")
			dapui.setup(opts)
			dap.listeners.before.attach.dapui_config = function() dapui.open() end
			dap.listeners.before.launch.dapui_config = function() dapui.open() end
			dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
			dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
		end,
	},
	{
		"nvim-neotest/neotest",
		ft = { "rust", "cpp" },
		cmd = "Neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"nvim-treesitter/nvim-treesitter",
			"mrcjkb/rustaceanvim",
			"orjangj/neotest-ctest",
		},
		opts = function()
			return {
				adapters = {
					require("rustaceanvim.neotest"),
					require("neotest-ctest").setup({
						dap_adapter = "codelldb",
						frameworks = { "catch2", "gtest" },
					}),
				},
				floating = {
					border = "rounded",
				},
			}
		end,
		keys = {
			{ "<leader>tt", function() run_tests() end, desc = "Test nearest test" },
			{ "<leader>tf", function() run_tests(vim.fn.expand("%")) end, desc = "Test file tests" },
			{ "<leader>tp", function() run_tests({ suite = true }) end, desc = "Test project" },
			{
				"<leader>td",
				function() require("neotest").run.run({ strategy = "dap" }) end,
				desc = "Test debug nearest test",
			},
			{ "<leader>to", function() require("neotest").output_panel.toggle() end, desc = "Test toggle output" },
			{ "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test toggle summary" },
			{ "<leader>tq", function() require("neotest").run.stop() end, desc = "Test stop test" },
		},
	},
}
