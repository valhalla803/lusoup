local Node = require("lusoup.dom")

local VOID_ELEMENTS = {
    area = true, base = true, br = true, col = true, embed = true,
    hr = true, img = true, input = true, link = true, meta = true,
    param = true, source = true, track = true, wbr = true
}

local function parse_attributes(attr_str)
    local attrs = {}
    if not attr_str or attr_str == "" then return attrs end

    local remaining = attr_str:gsub('([%w_%-%:]+)%s*=%s*["\']([^"\']*)["\']', function(k, v)
        attrs[k:lower()] = v
        return " "
    end)

    remaining = remaining:gsub('([%w_%-%:]+)%s*=%s*([^%s"\'>]+)', function(k, v)
        local lower_k = k:lower()
        if not attrs[lower_k] then
            attrs[lower_k] = v
        end
        return " "
    end)

    for key in remaining:gmatch('([%w_%-%:]+)') do
        local lower_k = key:lower()
        if not attrs[lower_k] then
            attrs[lower_k] = true
        end
    end

    return attrs
end

local function parse(html_str)
    if not html_str or html_str == "" then
        return Node.new("document")
    end

    local root = Node.new("document")
    local current = root
    local pos = 1
    local len = #html_str

    while pos <= len do
        if html_str:sub(pos, pos + 3) == "<!--" then
            local comment_end = html_str:find("-->", pos + 4, true)
            if comment_end then
                pos = comment_end + 3
            else
                break
            end
        else
            local tag_start, tag_end, is_closing, tag_name, attr_str, self_closing = 
                html_str:find("<(/?)([%w_%-%:]+)(.-)(/?)>", pos)

            if not tag_start then
                local remaining = html_str:sub(pos)
                if remaining:match("%S") then
                    local text_node = Node.new("#text")
                    text_node.text_content = remaining
                    current:append_child(text_node)
                end
                break
            end

            if tag_start > pos then
                local text = html_str:sub(pos, tag_start - 1)
                if text:match("%S") then
                    local text_node = Node.new("#text")
                    text_node.text_content = text
                    current:append_child(text_node)
                end
            end

            tag_name = tag_name:lower()

            if is_closing == "/" then
                if current.parent and current.tag == tag_name then
                    current = current.parent
                else
                    local temp = current
                    while temp.parent and temp.tag ~= tag_name do
                        temp = temp.parent
                    end
                    if temp.parent and temp.tag == tag_name then
                        current = temp.parent
                    end
                end
            else
                local attrs = parse_attributes(attr_str)
                local node = Node.new(tag_name, attrs)
                current:append_child(node)

                local is_void = VOID_ELEMENTS[tag_name] or (self_closing == "/")

                if not is_void then
                    if tag_name == "script" or tag_name == "style" then
                        local close_tag = "</" .. tag_name .. ">"
                        local s_end, e_end = html_str:find(close_tag, tag_end + 1, true)
                        if s_end then
                            local content = html_str:sub(tag_end + 1, s_end - 1)
                            if content:match("%S") then
                                local raw_node = Node.new("#text")
                                raw_node.text_content = content
                                node:append_child(raw_node)
                            end
                            tag_end = e_end
                        end
                    else
                        current = node
                    end
                end
            end

            pos = tag_end + 1
        end
    end

    return root
end

return {
    parse = parse
}
