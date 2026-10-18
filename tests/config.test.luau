--!strict
local Harness = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("CarConfig")

test("every car has sane numbers", function()
	truthy(#CarConfig.Order >= 8)
	for _, id in CarConfig.Order do
		local s = CarConfig.Cars[id]
		truthy(s ~= nil, id .. " missing")
		truthy(s.hp > 0 and s.mass > 0 and s.maxSpeed > 0 and s.accel > 0, id .. " bad numbers")
		truthy(s.damageMult > 0 and s.turnRate > 0, id .. " bad mults")
		eq(#s.rgb, 3, id .. " rgb")
		eq(#s.size, 3, id .. " size")
	end
end)

test("get() only accepts real ids", function()
	truthy(CarConfig.get("Heavy") ~= nil)
	eq(CarConfig.get("Nope"), nil)
	eq(CarConfig.get(5), nil)
	eq(CarConfig.get(nil), nil)
	eq(CarConfig.get({}), nil)
	eq(CarConfig.get("__index"), nil)
end)

test("Spike hits hardest, Heavy has most HP, Rocket is fastest", function()
	local c = CarConfig.Cars
	for i = 1, 8 do -- the 8 hand-written cars (pack cars have their own stats)
		local id = CarConfig.FullOrder[i]
		truthy(c.Spike.damageMult >= c[id].damageMult)
		truthy(c.Heavy.hp >= c[id].hp)
		truthy(c.Rocket.maxSpeed >= c[id].maxSpeed)
	end
	truthy(c.Ramp.hitLift > 0)
end)

test("every car has a rarity and every used rarity has a car", function()
	local LobbyConfig = require("../src/shared/LobbyConfig")
	local used: { [string]: boolean } = {}
	for _, id in CarConfig.Order do
		local r = LobbyConfig.Rarity[id]
		truthy(r ~= nil, id .. " has no rarity")
		used[r] = true
		truthy(LobbyConfig.Gacha.odds[r] ~= nil, id .. " rarity has no odds")
	end
	for r in used do
		local count = 0
		for _, id in CarConfig.Order do
			if LobbyConfig.Rarity[id] == r then
				count += 1
			end
		end
		truthy(count >= 1, r .. " has no cars")
	end
	local sum = 0
	for _, pct in LobbyConfig.Gacha.odds do
		sum += pct
	end
	eq(sum, 100)
end)

test("feel and launch numbers are sane", function()
	local F, L, D = GameConfig.Feel, GameConfig.Launch, GameConfig.Drag
	truthy(F.hitStopMin <= F.hitStopMax and F.hitStopMax < 0.3, "hit stop short")
	truthy(F.hitStopFrom >= 0 and F.hitStopFrom < 1, "hitStopFrom")
	truthy(F.koFov < F.normalFov, "KO zooms in")
	truthy(L.minSpeed > 0 and L.minSpeed < L.maxSpeed, "launch speeds")
	truthy(D.minFrac > 0 and D.minFrac < D.maxFrac and D.maxFrac < 1, "drag range")
	truthy(GameConfig.Match.aimTimeout > 0 and GameConfig.Match.maxMatchSeconds > 0, "match times")
end)
