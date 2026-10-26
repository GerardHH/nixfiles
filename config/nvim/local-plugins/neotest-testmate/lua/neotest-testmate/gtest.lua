-- GoogleTest, GoogleMock included: test cases from a tree-sitter query, run
-- through --gtest_filter, results from --gtest_output=xml.
local exit = require("neotest-testmate.exit")
local lib = require("neotest.lib")
local xml = require("neotest-testmate.xml")

local gtest = { name = "gtest" }

-- gmock.h includes gtest.h, so a test file may include only the former.
gtest.headers = { "^gtest/gtest%.h$", "^gmock/gmock%.h$" }

-- Own query rather than neotest-ctest's: that one skips files that include
-- only gmock.h, and names TEST_P instances by parameter value where GTest
-- numbers them. Every macro here takes (Suite, Name).
local query = [[
  ;; query
  ((namespace_definition
    name: (namespace_identifier) @namespace.name
  )) @namespace.definition
  ;; query
  ((function_definition
    declarator: (function_declarator
      declarator: (identifier) @test.kind (#any-of? @test.kind "TEST" "TEST_F" "TEST_P" "TYPED_TEST")
      parameters: (parameter_list
        . (parameter_declaration type: (type_identifier) !declarator) @test.suite
        . (parameter_declaration type: (type_identifier) !declarator) @test.name
        .
      )
    )
  )) @test.definition
]]

--- One position per macro, named Suite.Name. A TEST_P or TYPED_TEST stays a
--- single test: its instances only exist at runtime, so results are summed
--- up per macro (see read_report).
function gtest.build_position(file_path, source, captured_nodes)
    local function text(capture) return vim.treesitter.get_node_text(captured_nodes[capture], source) end
    if captured_nodes["test.name"] then
        local suite, name = text("test.suite"), text("test.name")
        return {
            type = "test",
            path = file_path,
            name = suite .. "." .. name,
            range = { captured_nodes["test.definition"]:range() },
            -- For the filter in gtest.arguments.
            kind = text("test.kind"),
            suite = suite,
            test = name,
        }
    end
    return {
        type = "namespace",
        path = file_path,
        name = text("namespace.name"),
        range = { captured_nodes["namespace.definition"]:range() },
    }
end

function gtest.parse_positions(path)
    return lib.treesitter.parse_positions(path, query, {
        -- A string, as neotest may parse in a subprocess.
        build_position = "require('neotest-testmate.gtest').build_position",
    })
end

-- --gtest_filter patterns per macro, in Suite and Name. Instances are named
-- Prefix/Suite.Name/<index> for TEST_P (no Prefix/ when it is empty) and
-- Suite/<index>.Name for TYPED_TEST.
local patterns = {
    TEST = { "%s.%s" },
    TEST_F = { "%s.%s" },
    TEST_P = { "*/%s.%s/*", "%s.%s/*" },
    TYPED_TEST = { "%s/*.%s" },
}

--- Arguments that run exactly `tests` (positions of type "test") and write an
--- XML report to `report`.
function gtest.arguments(tests, report)
    local filters = {}
    for _, test in ipairs(tests) do
        for _, pattern in ipairs(patterns[test.kind] or patterns.TEST) do
            table.insert(filters, pattern:format(test.suite, test.test))
        end
    end
    return { "--gtest_filter=" .. table.concat(filters, ":"), "--gtest_output=xml:" .. report }
end

-- Extra arguments for a debug run that stops at a failing assertion. GTest
-- traps in UnitTest::AddTestPartResult, two frames below the test's line;
-- continuing finishes the run and writes the report. It traps whether or not
-- a debugger is attached, so these never go into a normal run.
gtest.break_arguments = { "--gtest_break_on_failure" }

--- The position name a test case in the report belongs to: Suite.Name, with
--- the instance parts of TEST_P and TYPED_TEST names taken off.
local function position_name(suite, case)
    -- TYPED_TEST suites end in /<index>.
    if case.type_param then suite = suite:gsub("/[^/]*$", "") end
    -- TEST_P suites start with the instantiation's Prefix/.
    suite = suite:gsub("^.*/", "")
    -- TEST_P names end in /<index>, or in a custom name generator's suffix.
    local name = case.value_param and case.name:gsub("/[^/]*$", "") or case.name
    return suite .. "." .. name
end

local rank = { skipped = 1, passed = 2, failed = 3 }

--- Adds one test case of a run to `cases`, under its position name. Instances
--- of a TEST_P or TYPED_TEST add up: failed if any failed, passed if any
--- passed, otherwise skipped.
local function add_case(cases, name, status, failures, message)
    local entry = cases[name] or { status = status, failures = {} }
    if rank[status] > rank[entry.status] then entry.status = status end
    vim.list_extend(entry.failures, failures)
    entry.message = message or entry.message
    cases[name] = entry
end

--- Test cases in a report, by position name, as { status, failures, message }.
--- nil without a report, as after a crash: GTest writes it only at the end
--- (see read_output).
function gtest.read_report(path)
    local parsed = xml.read(path)
    local run = parsed and parsed.testsuites
    if type(run) ~= "table" then return nil end
    local cases = {}
    for _, suite in ipairs(xml.as_list(run.testsuite)) do
        for _, case in ipairs(xml.as_list(suite.testcase)) do
            local attr = type(case) == "table" and case._attr
            if attr and attr.name and suite._attr then
                local name = position_name(suite._attr.name, attr)
                local full_name = suite._attr.name .. "." .. attr.name
                -- Which instance failed, e.g. "Hours/GreetAfternoon.CoversEachHour/2 (17)".
                local instance = full_name ~= name
                        and ("[%s (%s)] "):format(full_name, attr.value_param or attr.type_param)
                    or ""

                local status = "passed"
                if attr.result == "skipped" or attr.result == "suppressed" or attr.status == "notrun" then
                    status = "skipped"
                end
                local found = {}
                for _, failure in ipairs(xml.as_list(case.failure)) do
                    status = "failed"
                    -- "<file>:<line>\n<message>", or "unknown file\n<message>"
                    -- for exceptions thrown outside an assertion.
                    local body = xml.text(failure)
                    local file, line, message = body:match("^(.-):(%d+)\n(.*)$")
                    if not file then message = body end
                    table.insert(found, { file = file, line = tonumber(line), message = instance .. message })
                end
                -- GTEST_SKIP's reason, after its "<file>:<line>" line.
                local skip_message
                for _, skipped in ipairs(xml.as_list(case.skipped)) do
                    local reason = xml.text(skipped):gsub("^[^\n]*:%d+\n", "")
                    skip_message = "skipped: " .. instance .. reason
                end
                add_case(cases, name, status, found, skip_message)
            end
        end
    end
    return cases
end

--- Why a run ended in the middle of a test, from its exit code.
local function ending(code)
    return exit.crash(code) or ("The run ended during this test, with exit code %d"):format(code)
end

-- Status lines that end a test: the result, then the test's full name, ",
-- where GetParam() = …" or ", where TypeParam = …" for an instance, and the
-- time. The summary at the end of a run repeats them without the time.
local endings = { ["       OK "] = "passed", ["  FAILED  "] = "failed", ["  SKIPPED "] = "skipped" }

--- The position name of a test by its full name in the console output, e.g.
--- "Hours/GreetAfternoon.CoversEachHour/2", and the prefix that marks an
--- instance's messages.
local function output_name(full_name)
    local suite, name = full_name:match("^([^.]+)%.(.+)$")
    if not suite then return nil end
    -- As position_name expects them: a TEST_P's index follows its name, a
    -- TYPED_TEST's its suite.
    local value_param = name:find("/", 1, true) ~= nil
    local type_param = not value_param and suite:find("/", 1, true) ~= nil
    local position = position_name(suite, { name = name, value_param = value_param, type_param = type_param })
    return position, full_name ~= position and ("[%s] "):format(full_name) or ""
end

--- Test cases in GTest's console output, as read_report gives them from a
--- report, for a run that left none: GTest writes its report only at the
--- end, so a crash leaves just the output. Tests that ended have their status
--- and failures from it. The test still running when the output stops failed,
--- with why from `code`, the run's exit code, as a failure marked `crash`.
--- nil when no test started, e.g. when the executable didn't start at all.
function gtest.read_output(output, code)
    local cases, started = {}, false
    -- The running test, as { full_name, failures, skip_lines }, and the lines
    -- of the failure or skip message coming in.
    local running, block

    local function finish(status, crash_message)
        local name, instance = output_name(running.full_name)
        if name then
            for _, failure in ipairs(running.failures) do
                failure.message = instance .. table.concat(failure.lines, "\n")
                failure.lines = nil
            end
            if crash_message then
                table.insert(running.failures, { message = instance .. crash_message, crash = true })
            end
            local skip_message = running.skip_lines
                and ("skipped: %s%s"):format(instance, table.concat(running.skip_lines, "\n"))
            add_case(cases, name, status, running.failures, skip_message)
        end
        running, block = nil, nil
    end

    for line in vim.gsplit(output, "\n", { plain = true }) do
        -- neotest runs the executable in a pty: lines end in \r, and GTest
        -- colours its status lines.
        line = line:gsub("\r$", ""):gsub("\27%[[%d;]*m", "")
        local result, rest = line:match("^%[(..........)%] (.*)$")
        if result == " RUN      " then
            started = true
            running, block = { full_name = rest, failures = {} }, nil
        elseif running and endings[result] and rest:match(" %(%d+ ms%)$") then
            finish(endings[result])
        elseif running then
            -- "<file>:<line>: Failure", or "unknown file: Failure" for an
            -- exception thrown outside an assertion, then the message up to
            -- an empty line. Other lines are the test's own output.
            local file, line_number = line:match("^(.-):(%d+): Failure$")
            if file or line == "unknown file: Failure" then
                block = { file = file, line = tonumber(line_number), lines = {} }
                table.insert(running.failures, block)
            elseif line:match(":%d+: Skipped$") then
                running.skip_lines = {}
                block = { lines = running.skip_lines }
            elseif line == "" then
                block = nil
            elseif block then
                table.insert(block.lines, line)
            end
        end
    end
    if not started then return nil end
    if running then finish("failed", ending(code)) end
    return cases
end

return gtest
