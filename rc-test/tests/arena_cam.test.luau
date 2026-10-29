--!strict
-- The match camera (carter 10-29: "it's hard to tell what's going on with this camera angle"):
-- shared/ArenaCam's numbers and the InMatch-only switch, plus text checks on ChaseCamera and Main.
local fs = require("@lune/fs")
local H = require("./harness")
local ArenaCam = require("../src/shared/ArenaCam")
local Tuning = require("../src/shared/Tuning")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Arena camera")

test("arena cam: higher, further back and tilted 35-45 degrees down", function()
	truthy(ArenaCam.PITCH >= 35 and ArenaCam.PITCH <= 45, "Smash Karts tilt")
	local back, up = ArenaCam.offset()
	truthy(math.abs(back * back + up * up - ArenaCam.DISTANCE ^ 2) < 1e-6, "on the distance")
	truthy(math.abs(math.deg(math.atan2(up, back)) - ArenaCam.PITCH) < 1e-6, "at the pitch")
	-- the race chase cam at the arena's RC size, for comparison (race numbers, whatever an
	-- earlier test left)
	local T: any = Tuning
	T.setMode("race")
	T.setScale(1)
	local S = TrackData.RC_SCALE
	local oldBack, oldUp = Tuning.camDistance * S, Tuning.camHeight * S
	truthy(up > oldUp * 4, "much higher than the low race cam")
	truthy(back > oldBack * 2, "much further back")
	truthy(ArenaCam.FOV >= 50 and ArenaCam.FOV <= 70, "a normal view, not a fish-eye")
end)

test("arena cam: your kart sits in the lower third", function()
	local back, up = ArenaCam.offset()
	local ahead = ArenaCam.aimAhead()
	truthy(ahead > 0, "aims ahead of the kart")
	-- where the kart lands on screen: angle below the middle, as a share of the half screen
	local lookDown = math.atan2(up, back + ahead)
	local kartDown = math.rad(ArenaCam.PITCH)
	local share = math.tan(kartDown - lookDown) / math.tan(math.rad(ArenaCam.FOV / 2))
	truthy(math.abs(share - ArenaCam.KART_LOW) < 1e-6, "kart a third of the half screen down")
	truthy(lookDown > math.rad(20), "still looking down at the arena, not at the sky")
end)

test("arena cam: the look-ahead leans a little, never a lot", function()
	eq(ArenaCam.lead(0), 0)
	truthy(ArenaCam.lead(10) > 0 and ArenaCam.lead(10) < ArenaCam.LEAD_MAX, "a lean at speed")
	-- the arena's top speed after BOTS' ~20% cut (RC top 95 * 0.25 * 0.8 = 19 studs/s)
	local top = 95 * TrackData.RC_SCALE * 0.8
	truthy(ArenaCam.lead(top) <= ArenaCam.LEAD_MAX, "capped")
	truthy(ArenaCam.lead(top) >= ArenaCam.LEAD_MAX * 0.9, "the cap is reached near top speed")
	eq(ArenaCam.lead(1000), ArenaCam.LEAD_MAX)
	truthy(ArenaCam.LEAD_MAX < ArenaCam.aimAhead(), "a lean, not a new target")
end)

test("arena cam: eases in and out, and only in a match", function()
	eq(ArenaCam.blend(0), 0)
	eq(ArenaCam.blend(ArenaCam.BLEND), 1)
	eq(ArenaCam.blend(99), 1)
	truthy(ArenaCam.blend(ArenaCam.BLEND / 2) > 0.4 and ArenaCam.blend(ArenaCam.BLEND / 2) < 0.6)
	eq(ArenaCam.on(true, true), true)
	eq(ArenaCam.on(true, false), false, "not outside the arena")
	eq(ArenaCam.on(false, true), false, "not in the lobby or a race")
	eq(ArenaCam.on(nil, true), false)
	eq(ArenaCam.on("true", true), false)
end)

test("arena cam: slides in for a wall, never into the kart", function()
	eq(ArenaCam.reach(nil), 1)
	eq(ArenaCam.reach(100), 1)
	truthy(ArenaCam.reach(4) < 1, "a wall pulls it in")
	truthy(ArenaCam.reach(4) * ArenaCam.DISTANCE <= 4 - ArenaCam.WALL_GAP + 1e-9, "this side of it")
	eq(ArenaCam.reach(0), 0.05, "never into the kart")
	-- swung up over the kart when a wall is right behind
	local _, upHigh = ArenaCam.offset(nil, ArenaCam.STEEP)
	local _, up = ArenaCam.offset()
	truthy(ArenaCam.STEEP > ArenaCam.PITCH and upHigh > up, "steeper and higher")
end)

test("arena cam: ChaseCamera and Main use it only while InMatch, still a chase cam", function()
	local chase = fs.readFile("src/client/ChaseCamera.luau")
	truthy(string.find(chase, "function cam.setArena(on: boolean)", 1, true) ~= nil)
	truthy(
		string.find(chase, "-heading * ARENA_BACK", 1, true) ~= nil,
		"behind the kart, turns with it"
	)
	truthy(
		string.find(chase, "arenaParams.FilterType = Enum.RaycastFilterType.Include", 1, true)
			~= nil,
		"only the arena pulls it in (not other karts)"
	)
	truthy(
		string.find(chase, "arenaOff = if dir.Magnitude > 1e-3 then arenaWant(", 1, true) ~= nil,
		"in at once, never inside a wall"
	)
	truthy(string.find(chase, "ArenaCam.blend(arenaT)", 1, true) ~= nil, "eased")
	truthy(string.find(chase, "SeeKart.PROPS[inst.Name]", 1, true) ~= nil, "props fade, no jumps")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(
		string.find(
			main,
			'camera.setArena(ArenaCam.on(player:GetAttribute("InMatch"), grid ~= nil))',
			1,
			true
		) ~= nil,
		"switched by InMatch"
	)
	truthy(string.find(main, "then ArenaCam.DISTANCE", 1, true) ~= nil, "lost-cam check fits")
	truthy(
		string.find(
			main,
			'ArenaCam.on(player:GetAttribute("InMatch"), type(gridSpot) == "table")',
			1,
			true
		) ~= nil,
		"respawn: no swoop"
	)
	-- driving stays locked
	truthy(string.find(chase, "RCCar", 1, true) == nil)
end)
