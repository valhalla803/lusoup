local tokenizer = require("lusoup.tokenizer")
local selector = require("lusoup.selector")
local Node = require("lusoup.dom")

function Node:select(query)
    return selector.select(self, query)
end

function Node:select_one(query)
    local res = selector.select(self, query)
    return res[1]
end

local lusoup = {}

function lusoup.parse(html)
    return tokenizer.parse(html)
end

return lusoup
