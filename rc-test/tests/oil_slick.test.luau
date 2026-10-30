--!strict
-- Oil slick puddle look: the numbers in shared/OilSlick stay sane (flat, black, bubbles pop).
local H = require("./harness")
local OilSlick = require("../src/shared/OilSlick")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Oil slick")

test("oil slick: the puddle is dark, flat and not huge", function()
	local c = OilSlick.COLOR
	truthy(c[1] < 20 and c[2] < 20 and c[3] < 20, "near black")
	truthy(OilSlick.HEIGHT < 0.3, "flat")
	local far = 0
	for _, l in OilSlick.LOBES do
		far = math.max(far, math.sqrt(l.x * l.x + l.z * l.z) + math.max(l.rx, l.rz))
	end
	truthy(far < 9, "fits a puddle that is a little over a kart wide and long")
	eq(#OilSlick.RAINBOW, 5, "five shine colours")
end)

test("oil slick: it spreads from a drop to full size", function()
	truthy(OilSlick.spread(0) < 0.05, "tiny when it lands")
	truthy(math.abs(OilSlick.spread(OilSlick.SPREAD_TIME) - 1) < 1e-6, "full size on time")
	truthy(OilSlick.spread(OilSlick.SPREAD_TIME * 0.7) > 1, "pops out a little past full")
	truthy(OilSlick.spread(9) == 1, "stays full")
end)

test("oil slick: bubbles grow, then pop with a ring", function()
	local s0 = OilSlick.bubbleSize(0)
	local s1 = OilSlick.bubbleSize(0.45)
	truthy(s0 < 0.01 and s1 > 0.9, "grows")
	local gone, ring = OilSlick.bubbleSize(0.95)
	eq(gone, 0, "gone after the pop")
	truthy(ring > 0 and ring < 1, "pop ring")
	for _, b in OilSlick.BUBBLES do
		for i = 0, 40 do
			local u = OilSlick.bubbleLife(b, i * 0.25)
			truthy(u >= 0 and u < 1, "life stays in 0..1")
		end
	end
end)
