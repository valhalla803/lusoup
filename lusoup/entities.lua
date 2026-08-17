local entities = {
    quot = '"',
    amp = '&',
    apos = "'",
    lt = '<',
    gt = '>',
    nbsp = ' ',
}

local function decode(str)
    if not str then return "" end
    str = str:gsub("&(#?x?%w+);", function(entity)
        if entity:sub(1, 2) == "#x" or entity:sub(1, 2) == "#X" then
            local hex = entity:sub(3)
            local code = tonumber(hex, 16)
            return code and string.char(code) or "&" .. entity .. ";"
        elseif entity:sub(1, 1) == "#" then
            local code = tonumber(entity:sub(2))
            return (code and code < 256) and string.char(code) or "&" .. entity .. ";"
        else
            return entities[entity] or ("&" .. entity .. ";")
        end
    end)
    return str
end

return {
    decode = decode
}
