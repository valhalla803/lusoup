-- The html5lib tree-construction tests: one test per case, so a regression
-- names the file and case that broke. These are what cover the parser's
-- behaviour; spec/lusoup_spec.lua covers lusoup's own API.
--
-- The tests are fetched from web-platform-tests by spec/conformance/fetch.sh;
-- until then, this spec is pending.
local html5lib = require("spec.conformance_support")

local files = html5lib.list_files()

describe("html5lib tree construction", function()
    if #files == 0 then
        pending("the WPT parser tests haven't been fetched: run spec/conformance/fetch.sh")
        return
    end
    for _, name in ipairs(files) do
        describe(name, function()
            local skip = html5lib.skip_reason(name)
            if skip then
                pending(skip)
                return
            end
            for n, test in ipairs(html5lib.read_tests(html5lib.DIR .. name)) do
                it(string.format("#%d %q", n, test.data:sub(1, 60)), function()
                    local status, expected, actual = html5lib.run_test(test)
                    if status ~= "pass" then
                        error(string.format("input:\n%s\nexpected:\n%s\nactual:\n%s",
                            test.data, expected, actual), 0)
                    end
                end)
            end
        end)
    end
end)
