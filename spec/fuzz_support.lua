-- Shared by the fuzz spec (spec/fuzz_spec.lua) and the standalone fuzzer
-- (spec/fuzz.lua): random document generators and tree invariant checks.
local lusoup = require("lusoup")

local M = {}

-- Tags chosen to exercise the tree builder's repairs: implied end tags,
-- scopes, formatting reconstruction, the adoption agency algorithm and
-- table fixups.
local SOUP_TAGS = {
    "a", "b", "i", "em", "font", "nobr", "p", "div", "span", "li", "ul", "ol",
    "dd", "dt", "dl", "table", "tbody", "tr", "td", "th", "caption", "col",
    "h1", "h2", "pre", "button", "form", "select", "option", "optgroup",
    "br", "hr", "img", "title", "script", "plaintext",
}

-- Random tag soup: start tags, end tags and text in any order.
function M.tag_soup(rand)
    local parts = {}
    for _ = 1, rand(1, 40) do
        local tag = SOUP_TAGS[rand(#SOUP_TAGS)]
        local r = rand(100)
        if r <= 45 then
            parts[#parts + 1] = "<" .. tag .. (rand(4) == 1 and ' class="c"' or "") .. ">"
        elseif r <= 90 then
            parts[#parts + 1] = "</" .. tag .. ">"
        elseif r <= 95 then
            parts[#parts + 1] = "x"
        else
            parts[#parts + 1] = " "
        end
    end
    return table.concat(parts)
end

-- Elements that nest freely without HTML repairing anything, so a document
-- made of them must serialize back to exactly the same HTML.
local NESTABLE = { "div", "span", "em", "strong", "section", "blockquote" }

function M.well_formed(rand, depth)
    depth = depth or 0
    local parts = {}
    for _ = 1, rand(1, 4) do
        if depth < 5 and rand(3) > 1 then
            local tag = NESTABLE[rand(#NESTABLE)]
            parts[#parts + 1] = "<" .. tag .. ">" .. M.well_formed(rand, depth + 1) .. "</" .. tag .. ">"
        else
            parts[#parts + 1] = ({ "x", "y z", " " })[rand(3)]
        end
    end
    return table.concat(parts)
end

-- Check that the tree under `root` is consistent: every child's parent is
-- the node that lists it, no node appears twice (no cycles or sharing), and
-- text nodes have no children. Returns nil, or a description of the problem.
function M.check_tree(root)
    local seen = {}
    local function check(node, path)
        if seen[node] then
            return "node appears twice: " .. path
        end
        seen[node] = true
        if node.tag == "#text" then
            if #node.children > 0 then
                return "text node has children: " .. path
            end
            return nil
        end
        for i, child in ipairs(node.children) do
            local child_path = path .. " > " .. child.tag .. "[" .. i .. "]"
            if rawget(child, "parent") ~= node then
                return "child's parent is wrong: " .. child_path
            end
            local err = check(child, child_path)
            if err then
                return err
            end
        end
        return nil
    end
    return check(root, root.tag)
end

-- Parse `html` and check everything we can about the result.
-- Returns nil, or a description of the failure.
function M.check(html, must_round_trip)
    local ok, result = pcall(function()
        local root = lusoup.parse(html)
        local err = M.check_tree(root)
        if err then
            return err
        end
        local out = root:outer_html()
        if must_round_trip and out ~= html then
            return "didn't round-trip: got " .. out
        end
        return nil
    end)
    if not ok then
        return "error: " .. tostring(result)
    end
    return result
end

return M
