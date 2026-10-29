--!strict
-- Things that move and sparkle in a match (auditor "Cheap tells" #1): shared/ArenaLife's rates,
-- plus text checks that client/ArenaLifeFx stays cheap and only runs in a match.
local fs = require("@lune/fs")
local H = require("./harness")
local ArenaLife = require("../src/shared/ArenaLife")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Arena life")

test("arena life: dust grows with speed, never past the cap, nothing far away", function()
	eq(ArenaLife.dust(0, 5), 0, "parked: no dust")
	eq(ArenaLife.dust(ArenaLife.DUST_START, 5), 0)
	local mid, top = ArenaLife.dust(10, 5), ArenaLife.dust(19, 5)
	truthy(mid > 0 and top > mid, "more dust when faster")
	eq(ArenaLife.dust(1000, 5), ArenaLife.DUST_MAX)
	truthy(ArenaLife.DUST_MAX <= ArenaLife.MAX_PER_SECOND, "cheap")
	eq(ArenaLife.dust(19, ArenaLife.FAR + 1), 0, "too far: nothing")
	eq(ArenaLife.puffs(0, 5), 0)
	truthy(ArenaLife.puffs(2, 5) > 0 and ArenaLife.puffs(19, 5) >= ArenaLife.puffs(2, 5))
	eq(ArenaLife.puffs(19, ArenaLife.FAR + 1), 0)
	eq(ArenaLife.sparkles(true, 5), ArenaLife.SPARKLE_RATE)
	eq(ArenaLife.sparkles(false, 5), 0, "a taken box doesn't sparkle")
	eq(ArenaLife.sparkles(true, ArenaLife.FAR + 1), 0)
end)

test("arena life: bits add up over frames, whole ones out", function()
	local owed, total = 0, 0
	for _ = 1, 60 do
		local n
		n, owed = ArenaLife.owe(owed, 10, 1 / 60)
		total += n
	end
	truthy(total >= 9 and total <= 10, "10 a second at 60 fps")
	local n, left = ArenaLife.owe(0, -5, 1)
	eq(n, 0)
	eq(left, 0)
end)

test("arena life: speed from the frame step; a respawn jump is not speed", function()
	eq(ArenaLife.speed(3, 4, 0.5), 10)
	eq(ArenaLife.speed(1, 0, 0), 0)
	eq(ArenaLife.speed(100, 0, 0.1), 0, "teleport")
	-- a bot's catch-up step (a few frames of a fast kart at once) is still speed, not a jump
	eq(ArenaLife.speed(3, 0, 0.1), 30)
end)

test("arena life: client is cheap and only runs in a match", function()
	local src = fs.readFile("src/client/ArenaLifeFx.luau")
	truthy(string.find(src, 'player:GetAttribute("InMatch") == true', 1, true) ~= nil, "in a match")
	truthy(string.find(src, "r.dust:Emit(n)", 1, true) ~= nil, "kart dust by hand, by speed")
	truthy(
		string.find(src, 'GetAttributeChangedSignal("Up")', 1, true) ~= nil,
		"taken box: off at once"
	)
	truthy(string.find(src, "ArenaLife.FAR", 1, true) ~= nil, "off when far away")
	truthy(string.find(src, "rbxassetid://", 1, true) == nil, "built-in textures only")
	truthy(string.find(src, "PointLight", 1, true) == nil, "no lights (phones)")
	local hits = fs.readFile("src/client/SmashHits.client.luau")
	truthy(string.find(hits, "ArenaLifeFx.spark(spot)", 1, true) ~= nil, "bump sparks")
	truthy(fs.isFile("src/client/ArenaLifeStart.client.luau"), "started")
end)
