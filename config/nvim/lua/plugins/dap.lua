local function find_colcon_root(start_dir)
	-- A colcon workspace is identified by having a `src/` sibling to `build/`.
	-- Walk up until we find a directory containing both.
	local dir = start_dir
	while dir and dir ~= "/" do
		if vim.fn.isdirectory(dir .. "/src") == 1 and vim.fn.isdirectory(dir .. "/build") == 1 then return dir end
		dir = vim.fn.fnamemodify(dir, ":h")
	end
	return nil
end

local function find_package_name(file_path, colcon_root)
	-- Given a source file under <ws>/src/<pkg>/..., return <pkg>.
	-- Assumes the conventional colcon layout.
	local src_root = colcon_root .. "/src/"
	if not vim.startswith(file_path, src_root) then return nil end
	local rel = file_path:sub(#src_root + 1)
	-- First path component is the package name (handles nested src/ layouts
	-- only for the common case; adjust if your workspace is unusual).
	return rel:match("^([^/]+)")
end

local function find_package_build_dir(file_path)
	local colcon_root = find_colcon_root(vim.fn.fnamemodify(file_path, ":h"))
	if not colcon_root then return nil end
	local pkg = find_package_name(file_path, colcon_root)
	if not pkg then return nil end
	local build_dir = colcon_root .. "/build/" .. pkg
	if vim.fn.isdirectory(build_dir) == 1 then return build_dir end
	return nil
end

return {
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = {
			{
				"williamboman/mason.nvim",
				lazy = true,
				opts = {},
			},
			"mfussenegger/nvim-dap",
		},
		event = "VeryLazy",
		opts = {
			ensure_installed = { "codelldb" },
			automatic_setup = true, -- registers with nvim-dap automatically
		},
	},
	{
		"mfussenegger/nvim-dap",
		version = "*",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			{ "theHamsta/nvim-dap-virtual-text", opts = {} },
		},
		lazy = true,
		keys = {
			{
				"<leader>dB",
				function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end,
				desc = "Breakpoint Condition",
			},
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug toggle breakpoint" },
			{ "<leader>dc", function() require("dap").continue() end, desc = "Debug run/continue" },
			-- { "<leader>da", function() require("dap").continue({ before = get_args }) end, desc = "Debug run with args" },
			{ "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Debug run to cursor" },
			-- { "<leader>dg", function() require("dap").goto_() end, desc = "Debug go to line (no execute)" },
			{ "<leader>di", function() require("dap").step_into() end, desc = "Debug step into" },
			{ "<leader>dj", function() require("dap").down() end, desc = "Debug down" },
			{ "<leader>dk", function() require("dap").up() end, desc = "Debug up" },
			{ "<leader>dl", function() require("dap").run_last() end, desc = "Debug run last" },
			{ "<leader>do", function() require("dap").step_out() end, desc = "Debug step out" },
			{ "<leader>dO", function() require("dap").step_over() end, desc = "Debug step over" },
			{ "<leader>dP", function() require("dap").pause() end, desc = "Debug pause" },
			{ "<leader>dr", function() require("dap").repl.toggle() end, desc = "Debug toggle REPL" },
			{ "<leader>ds", function() require("dap").session() end, desc = "Debug session" },
			{ "<leader>dt", function() require("dap").terminate() end, desc = "Debug terminate" },
			{ "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Debug widgets" },
		},
		config = function()
			local function pick_executable(candidates)
				local default_dir
				for _, d in ipairs(candidates) do
					local dir = vim.fn.expand(d)
					if vim.fn.isdirectory(dir) == 1 then
						default_dir = dir
						break
					end
				end
				local base = default_dir or (vim.fn.getcwd() .. "/")
				return vim.fn.input("Path to executable: ", base, "file")
			end

			local dap = require("dap")

			for _, lang in ipairs({ "c", "cpp" }) do
				dap.configurations[lang] = {
					{
						name = "CMake: Launch",
						type = "codelldb",
						request = "launch",
						program = function()
							local cwd = vim.fn.getcwd()
							local candidates = {
								cwd .. "/build/Debug/",
								cwd .. "/build/RelWithDebInfo/",
								cwd .. "/build/Release/",
								cwd .. "/build/",
								cwd .. "/cmake-build-debug/",
								cwd .. "/cmake-build-release/",
								cwd .. "/out/build/", -- VS/CMakePresets style
							}
							return pick_executable(candidates)
						end,
						cwd = "${workspaceFolder}",
						stopOnEntry = false,
						args = {},
						env = {},
					},
				}
			end

			dap.configurations.rust = {
				{
					name = "Cargo: Launch (target/debug)",
					type = "codelldb",
					request = "launch",
					program = function()
						local cwd = vim.fn.getcwd()
						local candidates = {
							cwd .. "/target/debug/",
							cwd .. "/target/x86_64-unknown-linux-gnu/debug/",
						}
						return pick_executable(candidates)
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
					env = {},
				},
			}
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		version = "*",
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
			dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open({}) end
			dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close({}) end
			dap.listeners.before.event_exited["dapui_config"] = function() dapui.close({}) end
		end,
	},
	{ "vim-test/vim-test", version = "*", lazy = true },
	{
		"nvim-neotest/neotest-vim-test",
		version = "*",
		lazy = true,
		dependencies = {
			"vim-test/vim-test",
		},
	},
	{
		"nvim-neotest/neotest",
		version = "*",
		ft = { "rust", "cpp" },
		cmd = { "Neotest", "NeotestRun", "NeotestSummary", "NeotestOutput" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			-- Rust
			"mrcjkb/rustaceanvim",
			-- Cpp
			-- "nvim-neotest/neotest-vim-test",
			"orjangj/neotest-ctest",
		},
		opts = function()
			-- vim.g["test#cpp#runner"] = "ctest"
			-- vim.g["test#cpp#runner"] = "catch2"

			return {
				adapters = {
					require("rustaceanvim.neotest"),
					-- require("neotest-vim-test")({
					-- 	allow_file_ypes = { "cpp", "c" },
					-- }),
					require("neotest-ctest").setup({
						build_dir = "/mnt/vectorv2/build/unittest/build",
						env_file = "/tmp/ros.env",
						extra_args = { "--output-on-failure" },
						frameworks = { "catch2", "gtest" },
						root = function(dir)
							vim.notify(vim.inspect(dir))
							-- `dir` is a directory neotest is considering. Try to resolve
							-- it to a colcon package build dir. If we can't, fall back to
							-- the default behavior so non-colcon projects still work.
							local probe_file = dir .. "/dummy.cpp"
							local build_dir = find_package_build_dir(probe_file)
							if build_dir then return build_dir end
							return require("neotest.lib").files.match_root_pattern(
								"CMakePresets.json",
								"compile_commands.json",
								".git"
							)(dir)
						end,
					}),
				},
				diagnostic = {
					enabled = true,
				},
				floating = {
					border = "rounded",
				},
				output = {
					enabled = true,
				},
				output_panel = {
					enabled = true,
				},
			}
		end,
		keys = {
			{
				"<leader>td",
				function() require("neotest").run.run({ strategy = "dap" }) end,
				desc = "Test debug",
			},
			{ "<leader>tt", function() require("neotest").run.run() end, desc = "Test nearest test" },
			{ "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test file tests" },
			{
				"<leader>to",
				function() require("neotest").output_panel.toggle() end,
				desc = "Test toggle output",
			},
			{ "<leader>tp", function() require("neotest").run.run({ suite = true }) end, desc = "Test project" },
			{ "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test toggle summary" },
			{ "<leader>tq", function() require("neotest").run.stop() end, desc = "Test stop test" },
		},
		config = function(_, opts)
			local neotest = require("neotest")
			neotest.setup(opts)

			local run_module = neotest.run

			local original_run_function = run_module.run

			run_module.run = function(...)
				neotest.output_panel.clear()

				local result = original_run_function(...)

				-- Do work on next tick, so that it doesn't fight the event cycle
				vim.schedule(function() neotest.output_panel.open() end)

				return result
			end
		end,
	},
}
