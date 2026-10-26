-- neotest adapter that runs C++ test executables directly, the way VSCode's
-- C++ TestMate does, instead of through CTest. The executable for a source
-- file is the one under the build directories that contains the file's path,
-- which the test macros embed through __FILE__. Supports Catch2 v2 and v3 and
-- GoogleTest; each framework's module finds the test cases, builds the
-- command-line filter and reads the XML report.
local exit = require("neotest-testmate.exit")
local lib = require("neotest.lib")
local nio = require("nio")

local adapter = { name = "neotest-testmate" }

local frameworks = {
    require("neotest-testmate.catch2"),
    require("neotest-testmate.gtest"),
}

local options = {
    -- Directories in a project root that hold build trees, and the names of
    -- test executables in them: TestMate's default
    -- `{build,Build,BUILD,out,Out,OUT}/**/*{test,Test,TEST}*`.
    build_dirs = { "build", "Build", "BUILD", "out", "Out", "OUT" },
    executable_glob = "*test*",
    -- nvim-dap adapter for the dap strategy.
    dap_adapter = "codelldb",
    -- Under the dap strategy, stop in the debugger at a failing assertion, as
    -- TestMate's testMate.cpp.debug.breakOnFailure does (also on by default).
    break_on_failure = true,
}

function adapter.setup(opts)
    options = vim.tbl_extend("force", options, opts or {})
    return adapter
end

local function is_dir(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == "directory"
end

local function build_dirs(root)
    local dirs = {}
    for _, name in ipairs(options.build_dirs) do
        local dir = vim.fs.joinpath(root, name)
        if is_dir(dir) then table.insert(dirs, dir) end
    end
    return dirs
end

--- The nearest directory, `dir` itself included, that has a build directory.
function adapter.root(dir)
    while true do
        if #build_dirs(dir) > 0 then return dir end
        local parent = vim.fs.dirname(dir)
        if parent == dir then return nil end
        dir = parent
    end
end

function adapter.filter_dir(name)
    return not vim.startswith(name, ".") and not vim.tbl_contains(options.build_dirs, name)
end

local extensions = { cpp = true, cc = true, cxx = true }

--- C++ sources with "test" in their name or in the name of their directory.
function adapter.is_test_file(path)
    local name = vim.fs.basename(path)
    if not extensions[name:match("%.(%w+)$")] then return false end
    local parent = vim.fs.basename(vim.fs.dirname(path))
    return (name .. "/" .. parent):lower():find("test", 1, true) ~= nil
end

--- The framework of a test source: the first in `frameworks` that one of its
--- #includes belongs to, whatever the order of the #includes. Catch2 comes
--- first, so a Catch2 test that includes gmock.h for its mocks, even before
--- Catch2's header, stays Catch2; taken for GTest, it would have no tests.
local function detect(path)
    local ok, content = pcall(lib.files.read, path)
    if not ok then return nil end
    -- Collect all includes first, so the loop below can go by framework
    -- order instead of include order.
    local headers = {}
    for header in content:gmatch('#%s*include%s*[<"]([^>"]+)[>"]') do
        table.insert(headers, header)
    end
    for _, framework in ipairs(frameworks) do
        for _, header in ipairs(headers) do
            for _, pattern in ipairs(framework.headers) do
                if header:find(pattern) then return framework end
            end
        end
    end
    return nil
end

function adapter.discover_positions(path)
    local framework = detect(path)
    return framework and framework.parse_positions(path)
end

--- The most recently built executable in the project's build directories that
--- contains the path of `file`.
local function find_executable(root, file)
    local command = { "rg", "--files-with-matches", "--text", "--fixed-strings", "--no-ignore", "--hidden" }
    vim.list_extend(command, { "--iglob", options.executable_glob, "--regexp", file })
    local real = vim.uv.fs_realpath(file)
    if real and real ~= file then vim.list_extend(command, { "--regexp", real }) end
    table.insert(command, "--")
    vim.list_extend(command, build_dirs(root))

    local _, output = lib.process.run(command, { stdout = true })
    local newest, newest_mtime = nil, -1
    for candidate in vim.gsplit(output.stdout or "", "\n", { trimempty = true }) do
        local stat = vim.uv.fs_stat(candidate)
        local executable = stat and stat.type == "file" and bit.band(stat.mode, tonumber("111", 8)) ~= 0
        if executable and stat.mtime.sec > newest_mtime then
            newest, newest_mtime = candidate, stat.mtime.sec
        end
    end
    return newest
end

--- A spec for a position without test cases, such as a test main.cpp with
--- only CATCH_CONFIG_MAIN, or a namespace of helpers: it only prints why, and
--- `results` marks the position skipped. Returning nil instead makes neotest
--- look for tests to run one by one, find none, and leave the position
--- running forever; an error would abort a whole suite run, as neotest runs
--- its files together.
local function no_tests_spec(position, strategy)
    local message = ("No test cases in %s %s"):format(position.type, position.name)
    -- neotest's dap strategy needs a debug configuration, and without one
    -- reports that the adapter doesn't support it. A debug run is never part
    -- of a suite run, so an error, shown as a warning, can say why instead.
    if strategy == "dap" then error(message, 0) end
    return { command = { "echo", message }, context = { no_tests = message } }
end

function adapter.build_spec(args)
    local tree = args.tree
    local position = tree:data()
    if position.type == "dir" then return nil end

    local tests = {}
    for _, node in tree:iter_nodes() do
        if node:data().type == "test" then table.insert(tests, node:data()) end
    end
    -- Without filters the executable would run every test it has.
    if #tests == 0 then return no_tests_spec(position, args.strategy) end

    local framework = detect(position.path)
    if not framework then error(("No supported test framework included in %s"):format(position.path)) end

    local root = adapter.root(vim.fs.dirname(position.path))
    local executable = root and find_executable(root, position.path)
    if not executable then
        error(
            ("No test executable in the build directories of %s contains %s; is it built?"):format(root, position.path)
        )
    end

    local report = nio.fn.tempname()
    local arguments = framework.arguments(tests, report)
    local cwd = vim.fs.dirname(executable)
    local spec = {
        command = vim.list_extend({ executable }, arguments),
        cwd = cwd,
        context = { framework = framework.name, report = report, debug = args.strategy == "dap" },
    }
    if spec.context.debug then
        -- Only the debugger gets the break arguments; spec.command stays as
        -- a normal run. Stopping the session at the trap leaves no complete
        -- report, so `results` keeps the previous results.
        local debug_arguments = arguments
        if options.break_on_failure then
            debug_arguments = vim.list_extend(vim.list_slice(arguments), framework.break_arguments)
        end
        spec.strategy = {
            type = options.dap_adapter,
            request = "launch",
            name = "Debug " .. position.name,
            program = executable,
            args = debug_arguments,
            cwd = cwd,
        }
    end
    return spec
end

-- Known causes of a run that never got to its tests, by exit code, for the
-- message of a run without a report. By exit code, as a debug run has
-- nothing else: codelldb passes on no output from a process that exits
-- while it loads.
local exit_hints = {
    -- The dynamic loader's code when it can't find a shared library, as in
    -- a colcon/ROS workspace not sourced in the shell that started nvim.
    [127] = "a shared library could not be loaded; source the workspace (e.g. `source install/setup.bash`) before starting nvim",
}

-- How many of the last lines of a run's output go into its message.
local tail_lines = 5

--- The message for each test of a run that left no complete report: the
--- exit code, or the signal that killed it, a hint for a known cause, and
--- the end of what the run printed, which would otherwise only be in the
--- output panel.
local function no_report_message(code, printed)
    -- A signal, e.g. from a crash before the first test, as in a static
    -- initializer: nothing prints it, as no shell runs the executable.
    local ended = exit.crash(code) or ("Exited with code %d"):format(code)
    local lines = { ended .. " without writing a complete report" }
    if exit_hints[code] then table.insert(lines, "Hint: " .. exit_hints[code]) end
    -- neotest runs the executable in a pty: lines end in \r, and may be
    -- coloured.
    local output = vim.split((printed:gsub("\r", ""):gsub("\27%[[%d;]*m", "")), "\n", { trimempty = true })
    if #output > 0 then
        table.insert(lines, "Output ends with:")
        vim.list_extend(lines, vim.list_slice(output, math.max(1, #output - tail_lines + 1)))
    end
    return table.concat(lines, "\n")
end

-- Each test's last result, by position id, for a debug session that ends
-- without a report (see adapter.results). neotest drops a test's result as a
-- run of it starts, before the adapter sees that run, so the adapter keeps
-- its own. In memory, like neotest's, and the same tables: an entry per test.
-- Not on disk: a result's output is a temporary file, gone with nvim.
local last_results = {}

--- Adds the results of files and namespaces: failed when any of their tests
--- failed, passed when one passed, skipped otherwise.
local function add_parent_results(tree, results, output)
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if position.type ~= "test" then
            local status = "skipped"
            for _, child in node:iter_nodes() do
                local child_result = results[child:data().id]
                if child_result and child_result.status == "failed" then
                    status = "failed"
                    break
                elseif child_result and child_result.status == "passed" then
                    status = "passed"
                end
            end
            results[position.id] = { status = status, output = output }
        end
    end
end

--- Results for a debug session that ended without a report: each test's
--- last result, or skipped for a test without one. Returning none instead
--- makes neotest mark every test failed, without a message.
local function previous_results(tree, output)
    local results = {}
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if position.type == "test" then
            results[position.id] = last_results[position.id]
                or {
                    status = "skipped",
                    short = "not run yet: the debug session ended before its report",
                    output = output,
                }
        end
    end
    add_parent_results(tree, results, output)
    return results
end

function adapter.results(spec, result, tree)
    -- See no_tests_spec: skipped, with the reason as message and output.
    if spec.context.no_tests then
        local results = {}
        for _, node in tree:iter_nodes() do
            results[node:data().id] = { status = "skipped", short = spec.context.no_tests, output = result.output }
        end
        return results
    end

    local framework = vim.iter(frameworks):find(function(f) return f.name == spec.context.framework end)
    local cases = framework.read_report(spec.context.report)
    -- A debug session stopped before the end, e.g. at the break-on-failure
    -- trap, leaves no report: keep each test's last result. Its exit code
    -- can't tell it apart, as neotest gives 0 for a session that ends before
    -- the debuggee's exit. Not when the executable never started (see
    -- exit_hints): that fails as a normal run does, with the reason.
    if not cases and spec.context.debug and not exit_hints[result.code] then
        return previous_results(tree, result.output)
    end

    -- Anything the executable printed itself, such as a crash message.
    local printed = vim.trim(lib.files.read(result.output) or "")
    -- Without a report, as GTest's after a crash, what the output shows.
    if not cases and framework.read_output then cases = framework.read_output(printed, result.code) end

    -- The test the run crashed in, so the tests without a result can say why.
    local crashed
    for name, case in pairs(cases or {}) do
        if vim.iter(case.failures):any(function(failure) return failure.crash end) then crashed = name end
    end

    -- Without any results, every test fails with the same message.
    local no_report = not cases and no_report_message(result.code, printed)

    local results, summary = {}, {}
    local summary_path = nio.fn.tempname()
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if position.type == "test" then
            local case = cases and cases[position.name]
            local status, short, errors = "skipped", "not run", {}
            if no_report then
                status = "failed"
                short = no_report
            elseif case then
                status = case.status
                local lines = {}
                for _, failure in ipairs(case.failures) do
                    -- Exceptions outside an assertion can come without a file.
                    local location = failure.file and ("%s:%d: "):format(failure.file, failure.line or 0) or ""
                    table.insert(lines, location .. failure.message)
                    if failure.line and failure.file == position.path then
                        table.insert(errors, { line = failure.line - 1, message = failure.message })
                    elseif failure.crash then
                        -- A crash without a location, as GTest's: on the
                        -- test's first line, so the editor still shows it.
                        table.insert(errors, { line = position.range[1], message = failure.message })
                    end
                end
                short = #lines > 0 and table.concat(lines, "\n") or case.message or status
            elseif crashed then
                short = ("not run: the run crashed before it, in %s"):format(crashed)
            end
            table.insert(
                summary,
                ("%s %s"):format(status == "passed" and "✔" or status == "failed" and "✘" or "-", position.name)
            )
            -- The shared message of a run without a report goes in once,
            -- below the tests.
            if status ~= "passed" and not no_report then
                table.insert(summary, (short:gsub("\n", "\n    "):gsub("^", "    ")))
            end
            results[position.id] = { status = status, short = short, errors = errors, output = summary_path }
        end
    end

    if no_report then vim.list_extend(summary, { "", no_report }) end
    if printed ~= "" then vim.list_extend(summary, { "", printed }) end
    lib.files.write(summary_path, table.concat(summary, "\n") .. "\n")

    -- The tests' results, for a later debug session without a report.
    for id, test_result in pairs(results) do
        last_results[id] = test_result
    end
    add_parent_results(tree, results, summary_path)
    return results
end

return adapter
