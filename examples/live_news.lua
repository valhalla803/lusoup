local lureq = require("lureq")
local lusoup = require("lusoup")

print("Fetching top stories from News...\n")

-- Fetch webpage
local res, err = lureq.get("https://news.ycombinator.com/", {
    headers = {
        ["User-Agent"] = "Mozilla/5.0 (Linux; x86_64)"
    },
    timeout = 10
})

if not res or not res.ok then
    print("Failed to fetch page: " .. tostring(err or res.status_code))
    return
end

-- Parse DOM tree
local soup = lusoup.parse(res.text)

-- Extract links with CSS selector
local title_links = soup:select("span.titleline > a")

for i = 1, math.min(#title_links, 10) do
    local link = title_links[i]
    local title = link:text()
    local url = link:attr("href") or "N/A"
    print(string.format("[%02d] %s\n     Link: %s\n", i, title, url))
end
