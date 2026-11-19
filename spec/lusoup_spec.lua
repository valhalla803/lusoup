local lusoup = require("lusoup")
local entities = require("lusoup.entities")

-- Serialize a node's subtree compactly, to compare tree shapes:
-- elements as tag(child,child), text nodes as their raw text in quotes.
local function shape(node)
    if node.tag == "#text" then
        return string.format("%q", node.text_content)
    end
    local parts = {}
    for _, child in ipairs(node.children) do
        parts[#parts + 1] = shape(child)
    end
    return node.tag .. "(" .. table.concat(parts, ",") .. ")"
end

describe("lusoup", function()
    -- ── Existing behaviour ────────────────────────────────────────────────────────

    it("parses nested elements and text", function()
        local soup = lusoup.parse("<div><p>Hello <b>world</b></p></div>")
        assert.are.equal('document(div(p("Hello ",b("world"))))', shape(soup))
    end)

    it("reads attributes", function()
        local soup = lusoup.parse('<a href="https://example.com" class=btn hidden>x</a>')
        local a = soup:select_one("a")
        assert.are.equal("https://example.com", a:attr("href"))
        assert.are.equal("btn", a:attr("class"))
        assert.is_true(a:attr("hidden"))
    end)

    it("void elements have no children", function()
        local soup = lusoup.parse("<p>a<br>b<img src=x.png>c</p>")
        assert.are.equal('document(p("a",br(),"b",img(),"c"))', shape(soup))
    end)

    it("skips comments that follow a tag", function()
        local soup = lusoup.parse("<p><!-- <b>not</b> -->b</p>")
        assert.are.equal('document(p("b"))', shape(soup))
    end)

    it("keeps script and style contents as raw text", function()
        local soup = lusoup.parse("<script>if (a < b) {}</script><style>p > b {}</style>")
        assert.are.equal('document(script("if (a < b) {}"),style("p > b {}"))', shape(soup))
    end)

    it("decodes basic entities", function()
        assert.are.equal('<a> & "b" AB', entities.decode("&lt;a&gt; &amp; &quot;b&quot; &#65;&#x42;"))
    end)

    it("text() joins and collapses whitespace", function()
        local soup = lusoup.parse("<h2>Scraping with <span>Lusoup</span></h2>")
        assert.are.equal("Scraping with Lusoup", soup:select_one("h2"):text())
    end)
end)
