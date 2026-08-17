local lusoup = require("lusoup")

local doc = [[
<article class="post">
    <h1>Article Title</h1>
    <div class="ad-banner">Advertisement Content</div>
    <p>This is the first real paragraph.</p>
    <p>This is the second real paragraph.</p>
    <script>analytics.track();</script>
</article>
]]

-- Parse document
local soup = lusoup.parse(doc)
local article = soup:select_one("article.post")

-- Remove ads and scripts
local ad = article:select_one(".ad-banner")
if ad then ad:decompose() end

local script = article:find("script")
if script then script:decompose() end

-- Print cleaned output
print("Cleaned Outer HTML:")
print(article:outer_html())

print("\nCleaned Plain Text:")
print(article:text())
