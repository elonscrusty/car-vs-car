--!strict
-- The damage look (shared/DamageLookData, client/DamageFx): carter's pick "Hot Cracks, better".
-- Checks the numbers behave (more damage never means less to see), the part count stays small for
-- phones, and the car skins call it.
local fs = require("@lune/fs")
local H = require("./harness")
local D = require("../src/shared/DamageLookData")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("Damage look")

test("damage look: a few crack sites, from nearly whole to nearly wrecked, in order", function()
	local n = #D.SITES
	truthy(n >= 6 and n <= 10, `{n} sites`)
	local prev = 101
	for _, s in D.SITES do
		truthy(s.thr < prev, "sites open in order (highest Health first)")
		truthy(s.thr > 0 and s.thr < 100, "a site opens between 0 and 100")
		truthy(s.face == "top" or s.face == "side", "face")
		if s.face == "side" then
			truthy(s.a == 1 or s.a == -1, "a side site is on the left or right")
			truthy(s.h ~= nil and s.h > 0 and s.h < 1, "a side site has a height")
		else
			truthy(math.abs(s.a) <= 0.5, "a top site is over the body")
		end
		truthy(math.abs(s.b) <= 0.5, "a site is along the body")
		prev = s.thr
	end
end)

test("damage look: a whole car shows nothing, a wrecked one shows everything", function()
	eq(D.open(100), 0)
	eq(D.open(92), 0, "a site opens only when Health is BELOW its number")
	eq(D.open(91), 1)
	eq(D.open(0), #D.SITES)
	eq(D.smokeRate(100), 0)
	eq(D.smokeRate(76), 0)
	truthy(D.smokeRate(75) > 0)
	eq(D.fire(100), 0)
	eq(D.fire(42), 0)
	eq(D.fire(26), 1)
	eq(D.fire(0), 1)
	eq(D.sparkGap(80, 0.5), nil)
	truthy(D.sparkGap(50, 0.5) ~= nil)
	eq(D.glow(100, 0), 0)
end)

test("damage look: more damage never means less smoke, fire, soot or glow", function()
	local ps, pf, pt, po, pg = -1.0, -1.0, -1.0, -1, -1.0
	for hp = 100, 0, -1 do
		truthy(D.smokeRate(hp) >= ps, "smoke at " .. hp)
		truthy(D.fire(hp) >= pf, "fire at " .. hp)
		truthy(D.soot(hp) >= pt, "soot at " .. hp)
		truthy(D.open(hp) >= po, "cracks at " .. hp)
		truthy(D.glow(hp, 0.3) >= pg - 1e-9, "glow at " .. hp)
		ps, pf, pt, po, pg = D.smokeRate(hp), D.fire(hp), D.soot(hp), D.open(hp), D.glow(hp, 0.3)
	end
end)

test(
	"damage look: phones - smoke stays under the 100 a second cap, sparks come gap by gap",
	function()
		truthy(D.smokeRate(0) <= 40, "smoke at wreck")
		for _, r in { 0, 0.5, 1 } do
			local gap = D.sparkGap(10, r)
			truthy(gap ~= nil and gap >= 0.19 and gap <= 1, "gap " .. r)
		end
		-- (branches add about half again)
		local parts = D.ARMS * math.floor(D.ARM_LEN[2] / D.STEP) * #D.SITES
		truthy(parts <= 200, `{parts} crack parts before branches`)
	end
)

test("damage look: throb and colours", function()
	for i = 1, 8 do
		for t = 0, 5, 0.37 do
			local p = D.pulse(t, i)
			truthy(p >= 0 and p <= 1, "pulse")
		end
	end
	local m = D.mix(D.HOT, D.WHITE_HOT, 0)
	eq(m[1], D.HOT[1])
	near(D.mix(D.HOT, D.WHITE_HOT, 1)[2], D.WHITE_HOT[2])
	eq(D.soot(60), 0)
	eq(D.soot(15), 1)
end)

test("damage look: every car skin calls it, and it needs no made-up asset ids", function()
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(skin:find("DamageFx.new()", 1, true), "CarSkin makes it")
	truthy(skin:find("damage.step(", 1, true), "CarSkin steps it")
	local fx = fs.readFile("src/client/DamageFx.luau")
	truthy(not fx:find("rbxassetid", 1, true), "no asset ids (only built-in textures)")
	truthy(not fx:find("wait(", 1, true) or fx:find("task.delay", 1, true) ~= nil, "no wait()")
end)
