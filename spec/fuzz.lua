-- Fuzz the parser with random documents, checking the trees it builds.
--
-- usage: lua spec/fuzz.lua [-n count] [-s seed]
--
-- Run from the repository root. Without -s, the seed is random; it's printed
-- so a failure can be reproduced. When this finds a bug, add the (minimized)
-- input as a regular spec in spec/lusoup_spec.lua.
package.path = "./?.lua;./?/init.lua;" .. package.path
local fuzz = require("spec.fuzz_support")

local count, seed = 100000, os.time()
local i = 1
while i <= #arg do
    if arg[i] == "-n" then
        count = tonumber(arg[i + 1])
        i = i + 2
    elseif arg[i] == "-s" then
        seed = tonumber(arg[i + 1])
        i = i + 2
    else
        io.stderr:write("usage: lua spec/fuzz.lua [-n count] [-s seed]\n")
        os.exit(2)
    end
end

print(string.format("seed %d, %d documents", seed, count))
math.randomseed(seed)

local failures = 0
for n = 1, count do
    local well_formed = n % 4 == 0
    local html = well_formed and fuzz.well_formed(math.random) or fuzz.tag_soup(math.random)
    local err = fuzz.check(html, well_formed)
    if err then
        failures = failures + 1
        print("FAIL " .. err)
        print("     input: " .. html)
        if failures >= 10 then
            break
        end
    end
end

print(failures == 0 and "ok" or string.format("%d failures (seed %d)", failures, seed))
os.exit(failures == 0 and 0 or 1)
