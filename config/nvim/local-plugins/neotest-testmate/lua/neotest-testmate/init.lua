-- neotest adapter that runs C++ test executables directly, the way VSCode's
-- C++ TestMate does, instead of through CTest. Test cases are found in the
-- sources with neotest-ctest's tree-sitter queries. The executable for a source
-- file is the one under the build directories that contains the file's path,
-- which the test macros embed through __FILE__. Only Catch2 is supported so far.
local lib = require("neotest.lib")
local nio = require("nio")
local frameworks = require("neotest-ctest.framework")
local catch2 = require("neotest-ctest.framework.catch2")

local adapter = { name = "neotest-testmate" }

local options = {
    -- Directories in a project root that hold build trees, and the names of
    -- test executables in them: TestMate's default
    -- `{build,Build,BUILD,out,Out,OUT}/**/*{test,Test,TEST}*`.
    build_dirs = { "build", "Build", "BUILD", "out", "Out", "OUT" },
    executable_glob = "*test*",
    -- nvim-dap adapter for the dap strategy.
    dap_adapter = "codelldb",
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

function adapter.discover_positions(path)
    if frameworks.detect(path) ~= catch2 then return nil end
    return catch2.parse_positions(path)
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

-- Catch2 test specs treat these characters specially; a backslash makes them literal.
local function catch2_filter(name) return (name:gsub('[\\,%[%]%*~"]', "\\%0")) end

function adapter.build_spec(args)
    local tree = args.tree
    local position = tree:data()
    if position.type == "dir" then return nil end

    local filters = {}
    for _, node in tree:iter_nodes() do
        if node:data().type == "test" then table.insert(filters, catch2_filter(node:data().name)) end
    end
    -- Without filters the executable would run every test it has.
    if #filters == 0 then return nil end

    local root = adapter.root(vim.fs.dirname(position.path))
    local executable = root and find_executable(root, position.path)
    if not executable then
        error(
            ("No test executable in the build directories of %s contains %s; is it built?"):format(root, position.path)
        )
    end

    local report = nio.fn.tempname()
    -- One argument: Catch2 v2 joins separate ones with spaces into a single name.
    local arguments = { table.concat(filters, ","), "--reporter", "xml", "--out", report }
    local cwd = vim.fs.dirname(executable)
    local spec = {
        command = vim.list_extend({ executable }, arguments),
        cwd = cwd,
        context = { report = report, debug = args.strategy == "dap" },
    }
    if spec.context.debug then
        spec.strategy = {
            type = options.dap_adapter,
            request = "launch",
            name = "Debug " .. position.name,
            program = executable,
            args = arguments,
            cwd = cwd,
        }
    end
    return spec
end

local function as_list(value)
    if value == nil then return {} end
    return vim.islist(value) and value or { value }
end

local function text(value)
    if type(value) == "table" then value = value[1] end
    return vim.trim(value or "")
end

-- Failed assertions, exceptions and fatal signals anywhere in a test case,
-- sections included, as { file, line, message }.
local function failures(element, found)
    found = found or {}
    for _, expression in ipairs(as_list(element.Expression)) do
        if expression._attr.success == "false" then
            local message = ("%s( %s )"):format(expression._attr.type, text(expression.Original))
            local expanded = text(expression.Expanded)
            if expanded ~= text(expression.Original) then message = message .. "\nwith expansion: " .. expanded end
            table.insert(
                found,
                { file = expression._attr.filename, line = tonumber(expression._attr.line), message = message }
            )
        end
    end
    for _, kind in ipairs({ "Exception", "FatalErrorCondition", "Failure" }) do
        for _, failure in ipairs(as_list(element[kind])) do
            local attr = failure._attr or {}
            table.insert(
                found,
                { file = attr.filename, line = tonumber(attr.line), message = kind .. ": " .. text(failure) }
            )
        end
    end
    for _, section in ipairs(as_list(element.Section)) do
        failures(section, found)
    end
    return found
end

-- Test cases in a Catch2 v2 (<Catch><Group>) or v3 (<Catch2TestRun>) report.
local function read_report(path)
    local ok, parsed = pcall(function() return lib.xml.parse(lib.files.read(path)) end)
    if not ok or type(parsed) ~= "table" then return nil end
    local run = parsed.Catch and parsed.Catch.Group or parsed.Catch2TestRun
    if not run then return nil end
    local cases = {}
    for _, case in ipairs(as_list(run.TestCase)) do
        cases[case._attr.name] = {
            passed = case.OverallResult and case.OverallResult._attr.success == "true",
            failures = failures(case),
        }
    end
    return cases
end

function adapter.results(spec, result, tree)
    local cases = read_report(spec.context.report)
    -- An interrupted debug session leaves no report; keep the previous results.
    if not cases and spec.context.debug then return {} end

    local results, summary = {}, {}
    local summary_path = nio.fn.tempname()
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if position.type == "test" then
            local case = cases and cases[position.name]
            local status, short, errors = "skipped", "not run", {}
            if not cases then
                status = "failed"
                short = ("Exited with code %d without writing a complete report"):format(result.code)
            elseif case then
                status = case.passed and "passed" or "failed"
                local lines = {}
                for _, failure in ipairs(case.failures) do
                    table.insert(lines, ("%s:%d: %s"):format(failure.file, failure.line or 0, failure.message))
                    if failure.line and failure.file == position.path then
                        table.insert(errors, { line = failure.line - 1, message = failure.message })
                    end
                end
                short = #lines > 0 and table.concat(lines, "\n") or status
            end
            table.insert(
                summary,
                ("%s %s"):format(status == "passed" and "✔" or status == "failed" and "✘" or "-", position.name)
            )
            if status == "failed" then table.insert(summary, (short:gsub("\n", "\n    "):gsub("^", "    "))) end
            results[position.id] = { status = status, short = short, errors = errors, output = summary_path }
        end
    end

    -- Anything the executable printed itself, such as a crash message.
    local printed = vim.trim(lib.files.read(result.output) or "")
    if printed ~= "" then vim.list_extend(summary, { "", printed }) end
    lib.files.write(summary_path, table.concat(summary, "\n") .. "\n")

    -- Files and namespaces fail when any of their tests fail.
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
            results[position.id] = { status = status, output = summary_path }
        end
    end
    return results
end

return adapter
