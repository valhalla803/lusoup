local lusoup = require("lusoup")

local raw_html = [[
<div class="product-card" id="p-101">
    <h2 class="title">Wireless Gaming Mouse</h2>
    <span class="price" data-currency="USD">$49.99</span>
    <span class="badge in-stock">In Stock</span>
    <ul class="specs">
        <li>16000 DPI</li>
        <li>RGB Lighting</li>
        <li>Rechargeable Battery</li>
    </ul>
    <a href="/buy/101" class="btn buy-now" target="_blank">Order Now</a>
</div>
]]

-- Parse HTML string
local soup = lusoup.parse(raw_html)

-- Direct property access & selectors
print("Product : " .. soup.div.h2:text())
print("Price   : " .. soup:select_one(".price"):text())
print("Status  : " .. soup:select_one(".badge"):text())
print("Link    : " .. soup:select_one("a[href^=/buy]"):attr("href"))

-- Extract list items
print("\nSpecifications:")
local specs = soup:select(".specs > li")
for i, spec in ipairs(specs) do
    print(string.format("  - %s", spec:text()))
end
