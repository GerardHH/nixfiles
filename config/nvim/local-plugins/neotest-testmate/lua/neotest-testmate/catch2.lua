-- Catch2 v2 and v3: test cases from neotest-ctest's tree-sitter query, run by
-- name, results from the XML reporter.
local xml = require("neotest-testmate.xml")

local catch2 = { name = "catch2" }

-- v2's single header is catch2/catch.hpp, v3 has headers under catch2/.
catch2.headers = { "^catch2/", "^catch_amalgamated%.hpp$" }

function catch2.parse_positions(path) return require("neotest-ctest.framework.catch2").parse_positions(path) end

-- Catch2 test specs treat these characters specially; a backslash makes them literal.
local function filter(name) return (name:gsub('[\\,%[%]%*~"]', "\\%0")) end

--- Arguments that run exactly `tests` (positions of type "test") and write an
--- XML report to `report`.
function catch2.arguments(tests, report)
    local filters = vim.tbl_map(function(test) return filter(test.name) end, tests)
    -- One argument: Catch2 v2 joins separate ones with spaces into a single name.
    return { table.concat(filters, ","), "--reporter", "xml", "--out", report }
end

-- Failed assertions, exceptions and fatal signals anywhere in a test case,
-- sections included, as { file, line, message }.
local function failures(element, found)
    found = found or {}
    for _, expression in ipairs(xml.as_list(element.Expression)) do
        if expression._attr.success == "false" then
            local message = ("%s( %s )"):format(expression._attr.type, xml.text(expression.Original))
            local expanded = xml.text(expression.Expanded)
            if expanded ~= xml.text(expression.Original) then message = message .. "\nwith expansion: " .. expanded end
            table.insert(
                found,
                { file = expression._attr.filename, line = tonumber(expression._attr.line), message = message }
            )
        end
    end
    for _, kind in ipairs({ "Exception", "FatalErrorCondition", "Failure" }) do
        for _, failure in ipairs(xml.as_list(element[kind])) do
            local attr = failure._attr or {}
            table.insert(
                found,
                { file = attr.filename, line = tonumber(attr.line), message = kind .. ": " .. xml.text(failure) }
            )
        end
    end
    for _, section in ipairs(xml.as_list(element.Section)) do
        failures(section, found)
    end
    return found
end

-- Catch2 writes `>` unescaped in attribute values, e.g. a test case named
-- "a -> b", and neotest's XML parser ends a tag at the first `>`: the test
-- case loses its attributes and turns into a string. Escape `>` inside quoted
-- attribute values; the parser turns `&gt;` back into `>`. Text never holds a
-- raw `<`, Catch2 escapes it, so each `<` starts a tag.
local function escape_gt_in_attributes(report)
    local parts, pos = {}, 1
    local in_tag, in_quote = false, false
    while true do
        local at = report:find('[<>"]', pos)
        if not at then break end
        local char = report:sub(at, at)
        if char == "<" then
            in_tag = true
        elseif char == '"' then
            -- Quotes in text, such as in <Original>, start no attribute value.
            in_quote = in_tag and not in_quote
        elseif in_quote then
            char = "&gt;"
        else
            in_tag = false
        end
        table.insert(parts, report:sub(pos, at - 1))
        table.insert(parts, char)
        pos = at + 1
    end
    table.insert(parts, report:sub(pos))
    return table.concat(parts)
end

--- Test cases in a v2 (<Catch><Group>) or v3 (<Catch2TestRun>) report, by
--- test case name, as { status, failures }; nil without a complete report.
function catch2.read_report(path)
    local parsed = xml.read(path, escape_gt_in_attributes)
    local run = parsed and (parsed.Catch and parsed.Catch.Group or parsed.Catch2TestRun)
    if not run then return nil end
    local cases = {}
    for _, case in ipairs(xml.as_list(run.TestCase)) do
        -- Skip a test case the parser still mangled instead of failing the
        -- whole run; its test shows up as "not run".
        if type(case) == "table" and case._attr then
            local result = case.OverallResult
            local passed = type(result) == "table" and result._attr ~= nil and result._attr.success == "true"
            cases[case._attr.name] = { status = passed and "passed" or "failed", failures = failures(case) }
        end
    end
    return cases
end

return catch2
