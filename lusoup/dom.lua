local entities = require("lusoup.entities")

local Node = {}

function Node.new(tag, attrs, parent)
    local self = {
        tag = tag or "document",
        attrs = attrs or {},
        children = {},
        parent = parent or nil,
        text_content = nil
    }
    return setmetatable(self, Node)
end

-- A node's own fields, as opposed to names of child nodes that can be
-- accessed with the same syntax (e.g. node.children vs node.ul.li).
local DECLARED_FIELDS = { tag = true, attrs = true, children = true, parent = true, text_content = true }

function Node.__index(table, key)
    if Node[key] ~= nil then
        return Node[key]
    end
    if DECLARED_FIELDS[key] then
        -- We end up here if someone asks for an undefined node attribute,
        -- e.g. someone asks for node.parent but node is the root.
        -- In that case, avoid incorrectly (and expensively) searching the tree.
        return nil
    end
    if type(key) == "string" and not key:match("^_") then
        local child = table:find(key)
        if child then return child end
    end
    return rawget(table, key)
end

function Node:append_child(child)
    child.parent = self
    table.insert(self.children, child)
end

function Node:attr(key)
    if not key then return nil end
    return self.attrs[key:lower()]
end

function Node:text()
    if self.tag == "#text" then
        return entities.decode(self.text_content or "")
    end

    local texts = {}
    for _, child in ipairs(self.children) do
        local t = child:text()
        if t and t ~= "" then
            table.insert(texts, t)
        end
    end

    return table.concat(texts, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function Node:parent_node()
    return self.parent
end

function Node:children_nodes()
    local res = {}
    for _, child in ipairs(self.children) do
        if child.tag ~= "#text" then
            table.insert(res, child)
        end
    end
    return res
end

function Node:next_sibling()
    if not self.parent then return nil end
    local siblings = self.parent.children
    for i, child in ipairs(siblings) do
        if child == self then
            for j = i + 1, #siblings do
                if siblings[j].tag ~= "#text" then
                    return siblings[j]
                end
            end
            break
        end
    end
    return nil
end

function Node:prev_sibling()
    if not self.parent then return nil end
    local siblings = self.parent.children
    for i, child in ipairs(siblings) do
        if child == self then
            for j = i - 1, 1, -1 do
                if siblings[j].tag ~= "#text" then
                    return siblings[j]
                end
            end
            break
        end
    end
    return nil
end

function Node:closest(tag_or_rule)
    local current = self.parent
    while current and current.tag ~= "document" do
        if type(tag_or_rule) == "string" and current.tag:lower() == tag_or_rule:lower() then
            return current
        elseif type(tag_or_rule) == "function" and tag_or_rule(current) then
            return current
        end
        current = current.parent
    end
    return nil
end

local function collect_all_nodes(node, list)
    for _, child in ipairs(node.children) do
        if child.tag ~= "#text" then
            table.insert(list, child)
            collect_all_nodes(child, list)
        end
    end
end

function Node:next_element()
    local root = self
    while root.parent do
        root = root.parent
    end
    local flat_list = {}
    collect_all_nodes(root, flat_list)
    for i, node in ipairs(flat_list) do
        if node == self then
            return flat_list[i + 1]
        end
    end
    return nil
end

function Node:prev_element()
    local root = self
    while root.parent do
        root = root.parent
    end
    local flat_list = {}
    collect_all_nodes(root, flat_list)
    for i, node in ipairs(flat_list) do
        if node == self then
            return flat_list[i - 1]
        end
    end
    return nil
end

function Node:decompose()
    if not self.parent then return end
    for i, child in ipairs(self.parent.children) do
        if child == self then
            table.remove(self.parent.children, i)
            self.parent = nil
            break
        end
    end
end

function Node:inner_html()
    if self.tag == "#text" then
        return self.text_content or ""
    end
    local parts = {}
    for _, child in ipairs(self.children) do
        table.insert(parts, child:outer_html())
    end
    return table.concat(parts, "")
end

function Node:outer_html()
    if self.tag == "#text" then
        return self.text_content or ""
    end
    if self.tag == "document" then
        return self:inner_html()
    end

    local attr_parts = {}
    for k, v in pairs(self.attrs) do
        if v == true or v == k then
            table.insert(attr_parts, k)
        else
            table.insert(attr_parts, string.format('%s="%s"', k, tostring(v)))
        end
    end

    local attr_str = ""
    if #attr_parts > 0 then
        table.sort(attr_parts)
        attr_str = " " .. table.concat(attr_parts, " ")
    end

    local VOID_ELEMENTS = {
        area = true, base = true, br = true, col = true, embed = true,
        hr = true, img = true, input = true, link = true, meta = true,
        param = true, source = true, track = true, wbr = true
    }

    if VOID_ELEMENTS[self.tag:lower()] then
        return string.format("<%s%s />", self.tag, attr_str)
    end

    return string.format("<%s%s>%s</%s>", self.tag, attr_str, self:inner_html(), self.tag)
end

function Node:find(tag, attrs)
    local results = self:find_all(tag, attrs)
    return results[1]
end

function Node:find_all(tag, attrs)
    local results = {}

    local function match_node(node)
        if tag and tag ~= "*" and node.tag:lower() ~= tag:lower() then
            return false
        end

        if attrs then
            for k, v in pairs(attrs) do
                local attr_val = node:attr(k)
                if not attr_val then return false end
                if type(v) == "string" and attr_val ~= v then
                    return false
                end
            end
        end

        return true
    end

    local function traverse(node)
        for _, child in ipairs(node.children) do
            if child.tag ~= "#text" then
                if match_node(child) then
                    table.insert(results, child)
                end
                traverse(child)
            end
        end
    end

    traverse(self)
    return results
end

return Node
