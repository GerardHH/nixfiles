-- Reading test reports with neotest's XML parser, shared by the frameworks.
-- An element comes out as a table with its attributes in `_attr` and its text
-- at [1]; one that holds only text, and has no attributes, as a plain string.
local lib = require("neotest.lib")

local xml = {}

--- An element that occurs once is a table; one that repeats, a list of them.
function xml.as_list(value)
    if value == nil then return {} end
    return vim.islist(value) and value or { value }
end

--- The text of an element, CDATA included and trimmed.
function xml.text(value)
    if type(value) == "table" then
        -- Text can come in parts, e.g. GTest splits CDATA around "]]>".
        local parts = {}
        for _, part in ipairs(value) do
            if type(part) == "string" then table.insert(parts, part) end
        end
        value = table.concat(parts)
    end
    return vim.trim(value or "")
end

--- The report at `path`, parsed, or nil when it is missing or incomplete, as
--- after a crash. `prepare` can fix up the text before parsing.
function xml.read(path, prepare)
    local ok, parsed = pcall(function()
        local content = lib.files.read(path)
        return lib.xml.parse(prepare and prepare(content) or content)
    end)
    if ok and type(parsed) == "table" then return parsed end
    return nil
end

return xml
