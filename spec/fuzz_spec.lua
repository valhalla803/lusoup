-- A quick, deterministic run of the fuzzer. For longer runs with random
-- seeds, use spec/fuzz.lua.
local fuzz = require("spec.fuzz_support")

-- A small deterministic generator, so this spec gives the same documents on
-- every Lua version (math.random's sequence differs between them).
local function lcg(seed)
    local state = seed
    return function(a, b)
        state = (state * 1103515245 + 12345) % 2147483648
        if not b then
            a, b = 1, a
        end
        return a + state % (b - a + 1)
    end
end

describe("fuzz", function()
    it("builds consistent trees from tag soup", function()
        local rand = lcg(1)
        for _ = 1, 500 do
            local html = fuzz.tag_soup(rand)
            local err = fuzz.check(html, false)
            assert(err == nil, string.format("%s\nfor input: %s", tostring(err), html))
        end
    end)

    it("round-trips well-formed documents", function()
        local rand = lcg(2)
        for _ = 1, 200 do
            local html = fuzz.well_formed(rand)
            local err = fuzz.check(html, true)
            assert(err == nil, string.format("%s\nfor input: %s", tostring(err), html))
        end
    end)
end)
