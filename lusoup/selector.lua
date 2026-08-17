local selector = {}

local function parse_single_selector(sel)
    local pseudo = sel:match(":(first%-child)") or sel:match(":(last%-child)")
    if pseudo then
        sel = sel:gsub(":" .. pseudo, "")
    end

    local attrs = {}
    sel = sel:gsub("%[([%w_%-%:]+)%s*([%^%$%*~]?=)%s*['\"]?([^%]'\"%s]+)['\"]?%]", function(k, op, v)
        table.insert(attrs, {
            key = k:lower(),
            op = op,
            val = v
        })
        return ""
    end)

    sel = sel:gsub("%[([%w_%-%:]+)%]", function(k)
        table.insert(attrs, {
            key = k:lower(),
            op = "exists"
        })
        return ""
    end)

    local tag = sel:match("^([%w_%-%*]+)")
    if tag == "" then tag = nil end

    local id = sel:match("#([%w_%-%:]+)")

    local classes = {}
    for c in sel:gmatch("%.([%w_%-%:]+)") do
        table.insert(classes, c)
    end

    if not tag and (#attrs > 0 or id or #classes > 0) then
        tag = "*"
    end

    return {
        tag = tag,
        id = id,
        classes = classes,
        attrs = attrs,
        pseudo = pseudo
    }
end

local function node_matches(node, rule)
    if not node or node.tag == "#text" then
        return false
    end

    if rule.tag and rule.tag ~= "*" and node.tag:lower() ~= rule.tag:lower() then
        return false
    end

    if rule.id and node:attr("id") ~= rule.id then
        return false
    end

    if #rule.classes > 0 then
        local node_class = node:attr("class")
        if not node_class then return false end
        local class_str = " " .. node_class .. " "
        for _, c in ipairs(rule.classes) do
            if not class_str:find(" " .. c .. " ", 1, true) then
                return false
            end
        end
    end

    for _, a in ipairs(rule.attrs) do
        local val = node:attr(a.key)
        if not val then return false end

        if a.op == "=" and val ~= a.val then
            return false
        elseif a.op == "^=" and val:sub(1, #a.val) ~= a.val then
            return false
        elseif a.op == "$=" and val:sub(-#a.val) ~= a.val then
            return false
        elseif a.op == "*=" and not val:find(a.val, 1, true) then
            return false
        elseif a.op == "~=" and not (" " .. val .. " "):find(" " .. a.val .. " ", 1, true) then
            return false
        end
    end

    if rule.pseudo and node.parent then
        local siblings = {}
        for _, child in ipairs(node.parent.children) do
            if child.tag ~= "#text" then
                table.insert(siblings, child)
            end
        end

        if rule.pseudo == "first-child" and siblings[1] ~= node then
            return false
        elseif rule.pseudo == "last-child" and siblings[#siblings] ~= node then
            return false
        end
    end

    return true
end

local function execute_single_chain(root, query)
    local tokens = {}
    for token in query:gmatch("%S+") do
        table.insert(tokens, token)
    end

    local current_nodes = { root }

    local i = 1
    while i <= #tokens do
        local token = tokens[i]
        local is_direct_child = false

        if token == ">" then
            is_direct_child = true
            i = i + 1
            token = tokens[i]
            if not token then break end
        end

        local rule = parse_single_selector(token)
        local next_nodes = {}
        local visited = {}

        for _, parent in ipairs(current_nodes) do
            if is_direct_child then
                for _, child in ipairs(parent.children) do
                    if node_matches(child, rule) and not visited[child] then
                        visited[child] = true
                        table.insert(next_nodes, child)
                    end
                end
            else
                local descendants = parent:find_all()
                for _, desc in ipairs(descendants) do
                    if node_matches(desc, rule) and not visited[desc] then
                        visited[desc] = true
                        table.insert(next_nodes, desc)
                    end
                end
            end
        end

        current_nodes = next_nodes
        i = i + 1
    end

    return current_nodes
end

function selector.select(root, query)
    if not root or not query or query == "" then
        return {}
    end

    local sub_queries = {}
    for part in query:gmatch("([^,]+)") do
        local cleaned = part:gsub("^%s+", ""):gsub("%s+$", "")
        if cleaned ~= "" then
            table.insert(sub_queries, cleaned)
        end
    end

    local results = {}
    local seen = {}

    for _, sub_query in ipairs(sub_queries) do
        local matches = execute_single_chain(root, sub_query)
        for _, node in ipairs(matches) do
            if not seen[node] then
                seen[node] = true
                table.insert(results, node)
            end
        end
    end

    return results
end

return selector
