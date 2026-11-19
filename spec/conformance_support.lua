-- Reading and running the html5lib tree-construction tests, for
-- spec/html5lib_spec.lua.
local lusoup = require("lusoup")

local M = {}

M.DIR = "spec/conformance/cases/"

-- ── Reading .dat files ───────────────────────────────────────────────────────

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local SECTIONS = {
    ["#description"] = true, ["#data"] = true, ["#errors"] = true, ["#new-errors"] = true,
    ["#document-fragment"] = true, ["#script-off"] = true,
    ["#script-on"] = true, ["#document"] = true,
}

-- Split a .dat file into tests: { data = ..., document = ..., fragment = ..., script_off = bool }
function M.read_tests(path)
    local tests = {}
    local test, section, lines
    local function finish_section()
        if test and section then
            local text = table.concat(lines, "\n")
            if section == "#data" then
                test.data = text
            elseif section == "#document" then
                test.document = text
            elseif section == "#description" then
                test.description = text
            elseif section == "#document-fragment" then
                test.fragment = text
            end
        end
    end
    local content = read_file(path)
    if content:sub(-1) ~= "\n" then
        content = content .. "\n"
    end
    for line in content:gmatch("([^\n]*)\n") do
        if (line == "#data" or line == "#description") and (not test or section == "#document") then
            -- a new test; the blank line separating it from the last one
            -- ended up at the end of the last test's document
            if test then
                if lines[#lines] == "" then
                    lines[#lines] = nil
                end
                finish_section()
                tests[#tests + 1] = test
            end
            test, section, lines = {}, line, {}
        elseif SECTIONS[line] and test then
            finish_section()
            section, lines = line, {}
            if line == "#script-off" then
                test.scripting = false
            elseif line == "#script-on" then
                test.scripting = true
            end
        else
            lines[#lines + 1] = line
        end
    end
    if test then
        while lines[#lines] == "" do
            lines[#lines] = nil
        end
        finish_section()
        tests[#tests + 1] = test
    end
    return tests
end

-- ── Tree dumps ───────────────────────────────────────────────────────────────

-- Split a "| "-prefixed tree dump into items, keeping text that spans
-- several lines together.
function M.dump_items(dump)
    local items = {}
    for line in (dump .. "\n"):gmatch("([^\n]*)\n") do
        if line:sub(1, 2) == "| " then
            items[#items + 1] = line:sub(3)
        elseif #items > 0 then
            items[#items] = items[#items] .. "\n" .. line
        end
    end
    return items
end

local function attr_display_name(node, name)
    local ns = node.attr_ns and node.attr_ns[name]
    if not ns then
        return name
    end
    if name == "xmlns" then
        return "xmlns xmlns"
    end
    return ns .. " " .. name:match(":(.*)$")
end

function M.dump_tree(root)
    local items = {}
    local function add(depth, s)
        items[#items + 1] = string.rep("  ", depth) .. s
    end
    local function walk(node, depth)
        for _, child in ipairs(node.children) do
            local tag = child.tag
            if tag == "#text" then
                add(depth, '"' .. child.text_content .. '"')
            elseif tag == "#processing-instruction" then
                add(depth, "<?" .. child.target .. " " .. child.text_content .. "?>")
            elseif tag == "#comment" then
                add(depth, "<!-- " .. child.text_content .. " -->")
            elseif tag == "#doctype" then
                if child.public_id ~= "" or child.system_id ~= "" then
                    add(depth, string.format('<!DOCTYPE %s "%s" "%s">', child.name, child.public_id,
                        child.system_id))
                else
                    add(depth, "<!DOCTYPE " .. child.name .. ">")
                end
            else
                add(depth, "<" .. (child.namespace and (child.namespace .. " ") or "") .. tag .. ">")
                local names = {}
                for name in pairs(child.attrs) do
                    names[#names + 1] = { attr_display_name(child, name), name }
                end
                table.sort(names, function(a, b) return a[1] < b[1] end)
                for _, n in ipairs(names) do
                    add(depth + 1, n[1] .. '="' .. tostring(child.attrs[n[2]]) .. '"')
                end
                if child.content then
                    add(depth + 1, "content")
                    walk(child.content, depth + 2)
                end
                walk(child, depth + 1)
            end
        end
    end
    walk(root, 0)
    return table.concat(items, "\n")
end

-- ── Running ──────────────────────────────────────────────────────────────────

-- The .dat files in the test directory, optionally only those whose name contains `filter`.
function M.list_files(filter)
    local files = {}
    local p = io.popen('ls "' .. M.DIR .. '" 2>/dev/null')
    for name in p:lines() do
        if name:match("%.dat$") and (not filter or name:find(filter, 1, true)) then
            files[#files + 1] = name
        end
    end
    p:close()
    return files
end

-- Why the tests in this file can't be run, or nil if they can.
function M.skip_reason(name)
    if name:match("^scripted_") then
        -- these check the tree as scripts in it change it while parsing
        return "needs a script engine"
    end
end

-- Run one test. Returns "pass", or "fail" with the expected and actual trees.
function M.run_test(test)
    local options = { comments = true, scripting = test.scripting ~= false }
    local ok, result
    if test.fragment then
        options.context = test.fragment
        ok, result = pcall(lusoup.parse, test.data, options)
    else
        ok, result = pcall(lusoup.parse_document, test.data, options)
    end
    local expected = table.concat(M.dump_items(test.document or ""), "\n")
    if not ok then
        return "fail", expected, "error: " .. tostring(result)
    end
    local actual = M.dump_tree(result)
    if actual == expected then
        return "pass"
    end
    return "fail", expected, actual
end

return M
