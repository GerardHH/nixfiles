-- Crashing tests through the adapter's own functions. The test that crashes
-- fails with the signal in its message and a diagnostic, and the tests after
-- it say why they didn't run. Catch2 v2 and v3 still finish their report
-- after a fatal signal; GTest leaves none, so its results come from the
-- console output. The fixtures' crash tests crash on purpose, see their
-- sources.
local nio = require("nio")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

--- Runs the tests in `file` and returns the results per test name. With
--- `executable`, a build made in the container, runs that directly with
--- `framework`'s arguments: the adapter can't find it on the host, as it
--- embeds /workspaces paths.
local function run(file, executable, framework)
    local tree = adapter.discover_positions(file)
    assert.is_not_nil(tree, "no positions: framework not detected?")
    local spec
    if executable then
        local tests = {}
        for _, node in tree:iter_nodes() do
            if node:data().type == "test" then table.insert(tests, node:data()) end
        end
        local report = nio.fn.tempname()
        spec = {
            command = vim.list_extend(
                { executable },
                require("neotest-testmate." .. framework).arguments(tests, report)
            ),
            context = { framework = framework, report = report, debug = false },
        }
    else
        spec = adapter.build_spec({ tree = tree })
    end
    return helpers.test_results(tree, adapter.results(spec, helpers.run_spec(spec), tree))
end

--- Asserts that `text` holds `part`, showing both when it doesn't.
local function contains(part, text)
    assert.is_true(text:find(part, 1, true) ~= nil, ("%q not in:\n%s"):format(part, text))
end

-- The same test cases for v2 and v3, with the same results.
local function describe_catch2(version, file, executable)
    describe("Catch2 " .. version .. " with a crashing test", function()
        local results
        local function get()
            results = results or run(helpers.fixture(file), executable and helpers.fixture(executable), "catch2")
            return results
        end

        it(
            "passes the test before the crash",
            function() assert.equals("passed", get()["passes before the crash"].status) end
        )

        it("fails on an exception inside an assertion, with the exception", function()
            local result = get()["throws inside an assertion"]
            assert.equals("failed", result.status)
            contains("CHECK( throws() == 1 )", result.short)
            contains("Exception: thrown inside an assertion", result.short)
        end)

        it("fails on an exception outside an assertion", function()
            local result = get()["throws outside an assertion"]
            assert.equals("failed", result.status)
            contains("Exception: thrown outside an assertion", result.short)
        end)

        it("fails on an exception after an assertion, at that assertion", function()
            local result = get()["throws after an assertion"]
            assert.equals("failed", result.status)
            contains("Exception: thrown after an assertion, thrown somewhere after this line", result.short)
            assert.is_nil(result.short:find("nil(", 1, true))
            assert.same(
                { helpers.line_of(helpers.fixture(file), "// last assertion before the exception") },
                vim.tbl_map(function(error) return error.line end, result.errors)
            )
        end)

        it("fails the crashing test with the signal, at its last assertion", function()
            local result = get()["segfaults"]
            assert.equals("failed", result.status)
            contains("Crashed: SIGSEGV - Segmentation violation signal", result.short)
            assert.equals(1, #result.errors)
            assert.equals(
                helpers.line_of(helpers.fixture(file), "// last assertion before the crash"),
                result.errors[1].line
            )
        end)

        it("says the test after the crash didn't run, and why", function()
            local result = get()["not run after the crash"]
            assert.equals("skipped", result.status)
            assert.equals("not run: the run crashed before it, in segfaults", result.short)
        end)
    end)
end

describe_catch2("v3", "cmake-catch2/test/crash_test.cpp")
describe_catch2("v2", "colcon/src/toolbox/text/test/text_crash_test.cpp", "colcon/build/text/text_crash_test")

describe("GTest with a crashing test", function()
    local file = "colcon/src/toolbox/greeter/test/greeter_crash_test.cpp"
    local results
    local function get()
        results = results
            or run(helpers.fixture(file), helpers.fixture("colcon/build/greeter/greeter_crash_test"), "gtest")
        return results
    end

    it("passes the test before the crash", function() assert.equals("passed", get()["Crash.PassesBefore"].status) end)

    it("fails a test before the crash with its failure, not its printing", function()
        local result = get()["Crash.FailsBefore"]
        assert.equals("failed", result.status)
        contains("a message", result.short)
        assert.is_nil(result.short:find("printed by the test", 1, true))
        assert.same(
            { helpers.line_of(helpers.fixture(file), '<< "a message"') },
            vim.tbl_map(function(error) return error.line end, result.errors)
        )
    end)

    it("fails on an exception outside an assertion", function()
        local result = get()["Crash.ThrowsOutsideAnAssertion"]
        assert.equals("failed", result.status)
        contains('C++ exception with description "thrown outside an assertion"', result.short)
    end)

    it("fails the crashing test with its failures and the signal", function()
        local result = get()["Crash.Segfaults"]
        assert.equals("failed", result.status)
        contains("failed before the crash", result.short)
        contains("Crashed: SIGSEGV (exit code 139)", result.short)
        -- The failure at its line, the crash at the test's first line.
        local path = helpers.fixture(file)
        assert.same(
            { helpers.line_of(path, '<< "failed before the crash"'), helpers.line_of(path, "TEST(Crash, Segfaults)") },
            vim.tbl_map(function(error) return error.line end, result.errors)
        )
    end)

    it("says the test after the crash didn't run, and why", function()
        local result = get()["Crash.NotRunAfter"]
        assert.equals("skipped", result.status)
        assert.equals("not run: the run crashed before it, in Crash.Segfaults", result.short)
    end)
end)

-- The console output as neotest captures it, through a pty: lines end in
-- \r\n, and GTest colours its status lines.
describe("GTest's console output", function()
    local function green(status) return "\27[0;32m[" .. status .. "] \27[m" end
    local function red(status) return "\27[0;31m[" .. status .. "] \27[m" end
    local output = table.concat({
        "Running main() from gmock_main.cc",
        green("==========") .. "Running 4 tests from 3 test suites.",
        green(" RUN      ") .. "Hours/GreetAfternoon.CoversEachHour/0",
        green("       OK ") .. "Hours/GreetAfternoon.CoversEachHour/0 (0 ms)",
        green(" RUN      ") .. "Hours/GreetAfternoon.CoversEachHour/1",
        "/src/greeter_test.cpp:45: Failure",
        "Expected equality of these values:",
        '  greeter::greet(clock, "Cy")',
        "",
        red("  FAILED  ") .. "Hours/GreetAfternoon.CoversEachHour/1, where GetParam() = 15 (0 ms)",
        green(" RUN      ") .. "GreetTyped/0.AcceptsHourType",
        green("       OK ") .. "GreetTyped/0.AcceptsHourType (0 ms)",
        green(" RUN      ") .. "Greet.SkipsItself",
        "/src/greeter_test.cpp:63: Skipped",
        "nothing to check yet",
        "",
        green("  SKIPPED ") .. "Greet.SkipsItself (0 ms)",
        green("  PASSED  ") .. "2 tests.",
        -- The summary repeats failures without a time.
        red("  FAILED  ") .. "Hours/GreetAfternoon.CoversEachHour/1, where GetParam() = 15",
        "",
    }, "\r\n")

    it(
        "gives each test's status and messages, instances added up per test",
        function()
            assert.same({
                ["GreetAfternoon.CoversEachHour"] = {
                    status = "failed",
                    failures = {
                        {
                            file = "/src/greeter_test.cpp",
                            line = 45,
                            message = '[Hours/GreetAfternoon.CoversEachHour/1] Expected equality of these values:\n  greeter::greet(clock, "Cy")',
                        },
                    },
                },
                ["GreetTyped.AcceptsHourType"] = { status = "passed", failures = {} },
                ["Greet.SkipsItself"] = { status = "skipped", failures = {}, message = "skipped: nothing to check yet" },
            }, require("neotest-testmate.gtest").read_output(output, 1))
        end
    )

    it("gives nothing when no test started", function()
        local loader_error =
            "greeter_test: error while loading shared libraries: libgreeter.so: cannot open shared object file"
        assert.is_nil(require("neotest-testmate.gtest").read_output(loader_error, 127))
    end)
end)
