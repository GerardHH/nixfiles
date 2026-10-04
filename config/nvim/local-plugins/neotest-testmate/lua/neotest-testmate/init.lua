-- neotest adapter that runs C++ test executables directly, the way VSCode's
-- C++ TestMate does, instead of through CTest. The executable for a source
-- file is the one under the build directories that contains the file's path,
-- which the test macros embed through __FILE__. Supports Catch2 v2 and v3 and
-- GoogleTest; each framework's module finds the test cases, builds the
-- command-line filter and reads the XML report.
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

--- The framework of a test source, by the first of its #includes that one of
--- them claims.
local function detect(path)
    local ok, content = pcall(lib.files.read, path)
    if not ok then return nil end
    for header in content:gmatch('#%s*include%s*[<"]([^>"]+)[>"]') do
        for _, framework in ipairs(frameworks) do
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

function adapter.build_spec(args)
    local tree = args.tree
    local position = tree:data()
    if position.type == "dir" then return nil end

    local tests = {}
    for _, node in tree:iter_nodes() do
        if node:data().type == "test" then table.insert(tests, node:data()) end
    end
    -- Without filters the executable would run every test it has.
    if #tests == 0 then return nil end

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

function adapter.results(spec, result, tree)
    local framework = vim.iter(frameworks):find(function(f) return f.name == spec.context.framework end)
    local cases = framework.read_report(spec.context.report)
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
                status = case.status
                local lines = {}
                for _, failure in ipairs(case.failures) do
                    -- Exceptions outside an assertion can come without a file.
                    local location = failure.file and ("%s:%d: "):format(failure.file, failure.line or 0) or ""
                    table.insert(lines, location .. failure.message)
                    if failure.line and failure.file == position.path then
                        table.insert(errors, { line = failure.line - 1, message = failure.message })
                    end
                end
                short = #lines > 0 and table.concat(lines, "\n") or case.message or status
            end
            table.insert(
                summary,
                ("%s %s"):format(status == "passed" and "✔" or status == "failed" and "✘" or "-", position.name)
            )
            if status ~= "passed" then table.insert(summary, (short:gsub("\n", "\n    "):gsub("^", "    "))) end
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
