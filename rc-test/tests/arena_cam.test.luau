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
	truthy(string.find(chase, "function cam.setArena(on: boolean, now: boolean?)", 1, true) ~= nil)
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
		string.find(chase, "elseif dir.Magnitude > 1e-3 then arenaWant(dir.Unit * len)", 1, true)
			~= nil,
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
	truthy(
		string.find(main, "then ArenaCam.fit(", 1, true) ~= nil,
		"lost-cam check fits the screen"
	)
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

test(
	"arena cam: on a phone your kart is at least 10% of the screen's width, the fight still seen",
	function()
		local Weapons = require("../src/shared/Weapons")
		truthy(math.abs(ArenaCam.KART_LONG - Weapons.KART) < 1e-9, "the kart's real length")
		for _, size in { { 667, 375 }, { 844, 390 }, { 932, 430 } } do
			local w, h = size[1], size[2]
			local f = ArenaCam.fit(w, h)
			eq(f.distance, ArenaCam.PHONE_DISTANCE, "a phone: the close camera")
			local still = ArenaCam.share(w, h, f.distance, f.fov)
			local fast = ArenaCam.share(w, h, f.distance, f.fov + f.fast)
			print(
				string.format(
					"  %dx%d: kart %.1f%% of the width (%.1f%% at top speed)",
					w,
					h,
					still * 100,
					fast * 100
				)
			)
			truthy(still >= ArenaCam.MIN_SHARE, `{w}x{h}: kart at least 10% wide`)
			truthy(fast >= ArenaCam.MIN_SHARE, `{w}x{h}: still 10% at top speed`)
			local ahead = ArenaCam.seeAhead(f.distance, f.pitch, f.fov)
			truthy(
				ahead >= ArenaCam.PHONE_AHEAD_MIN * ArenaCam.KART_LONG,
				`{w}x{h}: the fight ahead still seen`
			)
			truthy(f.pitch >= 25, "still looking down on the fight, a chase cam")
			-- the middle of the view still looks well down at the arena (the kart in the lower third)
			local back, up = ArenaCam.offset(f.distance, f.pitch)
			local middleDown = math.atan2(up, back + ArenaCam.aimAhead(f.distance, f.pitch, f.fov))
			truthy(middleDown > math.rad(20), `{w}x{h}: looking down at the arena, not the sky`)
			-- the old far camera was the "can't see my kart" one
			truthy(ArenaCam.share(w, h, ArenaCam.DISTANCE, ArenaCam.FOV) < ArenaCam.MIN_SHARE)
		end
		local big = ArenaCam.fit(1920, 1080)
		eq(big.distance, ArenaCam.DISTANCE, "a big screen keeps the wide camera")
		eq(big.fov, ArenaCam.FOV)
		local chase = fs.readFile("src/client/ChaseCamera.luau")
		truthy(string.find(chase, "refit(camera.ViewportSize)", 1, true) ~= nil, "fits the screen")
		truthy(string.find(chase, "ArenaCam.MIN_REACH * arenaFit.distance", 1, true) ~= nil)
		truthy(string.find(chase, "local aFov = arenaFit.fov", 1, true) ~= nil)
	end
)
