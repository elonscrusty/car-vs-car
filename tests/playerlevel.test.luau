--!strict
local H = require("./harness")
local PlayerLevel = require("../src/shared/PlayerLevel")
local PaintConfig = require("../src/shared/PaintConfig")

print("PlayerLevel")

local function profile(): any
	return { coins = 0, paint = { owned = {} }, daily = { freePulls = 0 } }
end

H.test("levels rise with XP, start at 1 and stop at the max", function()
	H.eq(PlayerLevel.levelForXp(0), 1)
	H.eq(PlayerLevel.levelForXp(34), 1)
	H.eq(PlayerLevel.levelForXp(35), 2)
	H.eq(PlayerLevel.levelForXp(1e9), PlayerLevel.MaxLevel)
	local v = PlayerLevel.view(50)
	H.eq(v.level, 2)
	H.truthy(v.into >= 0 and v.into < v.needed)
	H.eq(PlayerLevel.view(1e9).maxed, true)
end)

H.test("total XP adds every car", function()
	H.eq(PlayerLevel.totalXp({ carXp = { Sedan = 30, Muscle = 12 } }), 42)
end)

H.test("every reward paint is a real paint color", function()
	for level = 2, PlayerLevel.MaxLevel do
		local r = PlayerLevel.reward(level)
		if r.paint then
			H.truthy(PaintConfig.color(r.paint) ~= nil)
		end
	end
	H.eq(PlayerLevel.reward(1).coins, 0)
end)

H.test("pay: coins, a spin try every 3rd level, a paint once; none paid twice", function()
	local p = profile()
	local paid = PlayerLevel.pay(p, 0, 1e9) -- all levels at once
	H.truthy(paid.coins > 0)
	H.eq(#paid.paints, 7)
	H.truthy(p.paint.owned.blue and p.paint.owned.gold)
	H.truthy(p.daily.freePulls >= 1) -- capped by the daily stack limit
	local again = PlayerLevel.pay(p, 1e9, 1e9)
	H.eq(again.coins, 0)
	H.eq(#again.paints, 0)
end)

H.test("pay: a paint you already own pays coins instead", function()
	local p = profile()
	p.paint.owned.blue = true
	local paid = PlayerLevel.pay(p, PlayerLevel.totalXp({ carXp = {} }), 106) -- levels 2 and 3
	H.eq(#paid.paints, 0)
	H.truthy(paid.coins >= 60)
end)
