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

test(
	"arena cam: higher, further back and tilted 25-35 degrees down (carter 10-30: lower)",
	function()
		truthy(ArenaCam.PITCH >= 25 and ArenaCam.PITCH <= 35, "a low chase tilt")
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
	end
)

test("arena cam: your kart sits in the lower third", function()
	local back, up = ArenaCam.offset()
	local ahead = ArenaCam.aimAhead()
	truthy(ahead > 0, "aims ahead of the kart")
	-- where the kart lands on screen: angle below the middle, as a share of the half screen
	local lookDown = math.atan2(up, back + ahead)
	local kartDown = math.rad(ArenaCam.PITCH)
	local share = math.tan(kartDown - lookDown) / math.tan(math.rad(ArenaCam.FOV / 2))
	truthy(math.abs(share - ArenaCam.KART_LOW) < 1e-6, "kart a third of the half screen down")
	truthy(lookDown > math.rad(15), "still looking down at the arena, not at the sky")
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
		string.find(main, "then camera.arenaDistance()", 1, true) ~= nil,
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
	"arena cam: on a phone your kart is at least MIN_SHARE of the screen's width, the fight still seen",
	function()
		local Weapons = require("../src/shared/Weapons")
		truthy(math.abs(ArenaCam.KART_LONG - Weapons.KART) < 1e-9, "the kart's real length")
		for _, size in { { 667, 375 }, { 844, 390 }, { 932, 430 } } do
			local w, h = size[1], size[2]
			local f = ArenaCam.fit(w, h)
			eq(f.distance, ArenaCam.PHONE_DISTANCE, "a phone: the close camera")
			local still = ArenaCam.share(w, h, f.distance, f.fov)
			local fast = ArenaCam.share(w, h, f.distance * (1 + f.back), f.fov + f.fast)
			print(
				string.format(
					"  %dx%d: kart %.1f%% of the width (%.1f%% at top speed)",
					w,
					h,
					still * 100,
					fast * 100
				)
			)
			truthy(still >= ArenaCam.MIN_SHARE, `{w}x{h}: kart at least MIN_SHARE wide`)
			truthy(fast >= ArenaCam.MIN_SHARE_FAST, `{w}x{h}: still MIN_SHARE_FAST at top speed`)
			local ahead = ArenaCam.seeAhead(f.distance, f.pitch, f.fov)
			truthy(
				ahead >= ArenaCam.PHONE_AHEAD_MIN * ArenaCam.KART_LONG,
				`{w}x{h}: the fight ahead still seen`
			)
			truthy(f.pitch >= 25, "still looking down on the fight, a chase cam")
			-- the middle of the view still looks well down at the arena (the kart in the lower third)
			local back, up = ArenaCam.offset(f.distance, f.pitch)
			local middleDown = math.atan2(up, back + ArenaCam.aimAhead(f.distance, f.pitch, f.fov))
			truthy(middleDown > math.rad(12), `{w}x{h}: looking down at the arena, not the sky`)
			-- carter's pick (10-30 batch play): further back and lower than try A (8 studs at 45 deg)
			truthy(f.distance >= 9 and f.pitch <= 35, `{w}x{h}: back and low, so you see ahead`)
		end
		-- speed zoom (carter's pick A, 10-29): a phone slides about a fifth further back and a few
		-- degrees wider at top speed, never more than a third; the big screen keeps its camera
		local phone = ArenaCam.fit(844, 390)
		truthy(phone.back >= 0.15 and phone.back <= 0.33, "a phone pulls back a bit at speed")
		truthy(phone.fast >= 3 and phone.fast <= 8, "and goes a little wider")
		eq(ArenaCam.fit(1920, 1080).back, 0, "the big screen's camera is not pulled back")
		truthy(
			string.find(
				fs.readFile("src/client/ChaseCamera.luau"),
				"1 + arenaFit.back * CarMath.clamp(flatSpeed / Tuning.topSpeed, 0, 1)",
				1,
				true
			) ~= nil,
			"ChaseCamera pulls back with speed"
		)
		local big = ArenaCam.fit(1920, 1080)
		eq(big.distance, ArenaCam.DISTANCE, "a big screen keeps the wide camera")
		eq(big.fov, ArenaCam.FOV)
		local chase = fs.readFile("src/client/ChaseCamera.luau")
		truthy(string.find(chase, "refit(camera.ViewportSize)", 1, true) ~= nil, "fits the screen")
		truthy(string.find(chase, "ArenaCam.MIN_REACH * arenaFit.distance", 1, true) ~= nil)
		truthy(string.find(chase, "local aFov = arenaFit.fov", 1, true) ~= nil)
	end
)

test(
	"arena cam: a real phone gets the phone camera; Studio can force it with TestPhoneCam",
	function()
		-- iPhone and Android phones (points), touch, no keyboard: the close camera
		for _, size in { { 844, 390 }, { 667, 375 }, { 932, 430 }, { 915, 412 }, { 1280, 600 } } do
			truthy(
				ArenaCam.isPhone(size[1], size[2], true, false, false),
				`{size[1]}x{size[2]} phone`
			)
		end
		eq(ArenaCam.isPhone(844, 390, false, true, false), true, "phone-shaped by size alone")
		eq(ArenaCam.isPhone(1024, 768, true, false, false), false, "a tablet keeps the big camera")
		eq(ArenaCam.isPhone(1914, 604, false, true, false), false, "Studio's view: big camera")
		eq(ArenaCam.isPhone(1914, 604, false, true, true), true, "TestPhoneCam forces it")
		eq(ArenaCam.forced(true, true), true)
		eq(ArenaCam.forced(false, true), false, "never in a live game")
		eq(ArenaCam.forced(true, "yes"), false)
		eq(ArenaCam.forced(true, nil), false)
		local f = ArenaCam.fit(1914, 604, true)
		eq(f.distance, ArenaCam.PHONE_DISTANCE, "forced: the phone camera on Studio's screen")
		eq(
			ArenaCam.fit(844, 390, false).distance,
			ArenaCam.DISTANCE,
			"told not a phone: big camera"
		)
		eq(ArenaCam.fit(844, 390).distance, ArenaCam.PHONE_DISTANCE, "by size when not told")
		local chase = fs.readFile("src/client/ChaseCamera.luau")
		truthy(string.find(chase, "workspace:GetAttribute(ArenaCam.TEST_ATTR)", 1, true) ~= nil)
		truthy(string.find(chase, "ArenaCam.forced(STUDIO,", 1, true) ~= nil, "Studio only")
		truthy(string.find(chase, "UserInputService.TouchEnabled", 1, true) ~= nil, "touch counts")
	end
)

test("arena cam: on a phone the kart you see sits PHONE_LOW down, still and at speed", function()
	local f = ArenaCam.fit(844, 390, true)
	local function down(fov: number, lean: number, drop: number, fwd: number): number
		-- (at top speed the camera is f.back further out: the numbers it really aims with)
		local dist = if fov > f.fov then f.distance * (1 + f.back) else f.distance
		local ahead = ArenaCam.aimAhead(dist, f.pitch, fov, f.low, drop, fwd)
		return ArenaCam.kartDown(dist, f.pitch, fov, ahead, lean, drop, fwd)
	end
	-- the kart you see (the skin) sits somewhere under and around the followed spot: from the
	-- physics box's middle (0.375 under) down to a skin reaching the ground, a little ahead or behind
	for _, at in { { 0.375, 0 }, { 0.6, -0.2 }, { 0.8, 0 }, { 0.8, 0.3 } } do
		local drop, fwd = at[1], at[2]
		local still = down(f.fov, 0, drop, fwd)
		local fast = down(f.fov + f.fast, ArenaCam.LEAD_MAX * f.lean, drop, fwd)
		print(
			string.format(
				"  phone (skin %.2f under, %.1f ahead): %.0f%% down still, %.0f%% at speed",
				drop,
				fwd,
				still * 100,
				fast * 100
			)
		)
		local want = 0.5 + 0.5 * ArenaCam.PHONE_LOW
		truthy(math.abs(still - want) < 1e-6, "PHONE_LOW down standing still")
		truthy(math.abs(fast - want) <= 0.02, "+-2% at top speed")
		local ahead = ArenaCam.seeAhead(f.distance, f.pitch, f.fov, f.low, drop, fwd)
		-- (carter 10-30: a lower camera, so the top of the screen may reach the far side and the sky)
		truthy(ahead >= ArenaCam.PHONE_AHEAD_MIN * ArenaCam.KART_LONG, "the fight ahead seen")
	end
	-- Studio r57: aiming the physics box at 68% left the drawn kart (0.45 lower) at ~80%
	local boxAim = ArenaCam.aimAhead(f.distance, f.pitch, f.fov, f.low, 0.375, 0)
	truthy(
		ArenaCam.kartDown(f.distance, f.pitch, f.fov, boxAim, 0, 0.375 + 0.45, 0)
			> 0.5 + 0.5 * ArenaCam.PHONE_LOW + 0.01,
		"aiming at the box puts the drawn kart too low: aim at the drawn kart"
	)
	-- same distance and fov: still MIN_SHARE+ wide
	truthy(
		ArenaCam.share(844, 390, f.distance * (1 + f.back), f.fov + f.fast)
			>= ArenaCam.MIN_SHARE_FAST
	)
	-- the big screen keeps its lower third and full lean
	local big = ArenaCam.fit(1920, 1080)
	eq(big.low, ArenaCam.KART_LOW)
	eq(big.lean, 1)
	local chase = fs.readFile("src/client/ChaseCamera.luau")
	truthy(string.find(chase, "ArenaCam.lead(flatVel.Magnitude) * arenaFit.lean", 1, true) ~= nil)
	truthy(string.find(chase, 'workspace:FindFirstChild("RCSkin")', 1, true) ~= nil, "the skin")
	truthy(
		string.find(chase, "seen:Dot(-Vector3.new(arenaOff.X, 0, arenaOff.Z).Unit)", 1, true) ~= nil,
		"aims at the skin's middle"
	)
	truthy(
		string.find(chase, "body.CFrame:ToObjectSpace(d.CFrame)", 1, true) ~= nil,
		"turned parts"
	)
end)

test("kit world: the weapon icon floats over every kart but your own", function()
	local KitWorld = require("../src/shared/KitWorld")
	eq(KitWorld.iconShown("rocket", 2, false), true, "another kart with a rocket")
	eq(KitWorld.iconShown("rocket", 2, true), false, "never over your own (FIRE shows it)")
	eq(KitWorld.iconShown("rocket", 0, false), false, "out of ammo")
	eq(KitWorld.iconShown("", 3, false), false, "nothing held")
	eq(KitWorld.iconShown(nil, 3, false), false)
	eq(KitWorld.iconShown("gun", "3", false), false)
	local icon = fs.readFile("src/client/KartWeaponIcon.client.luau")
	truthy(
		string.find(icon, "KitWorld.iconShown(w, a, model.Name == MINE)", 1, true) ~= nil,
		"on every screen, not just phones"
	)
	truthy(string.find(icon, "PHONE and model.Name == MINE", 1, true) == nil)
end)

test("arena cam: the come-back whoosh spirals in and lands exactly on the match camera", function()
	local back, up = ArenaCam.offset(ArenaCam.PHONE_DISTANCE, ArenaCam.PHONE_PITCH)
	-- the start: round the kart, wide, high and zoomed out
	local turn0, out0, hgt0, wide0 = ArenaCam.comeBack(0, back, up)
	truthy(turn0 > math.pi, "starts more than half way round")
	eq(out0, ArenaCam.COMEBACK_RADIUS)
	eq(hgt0, ArenaCam.COMEBACK_HEIGHT)
	eq(wide0, ArenaCam.COMEBACK_FOV)
	-- the end (and after): exactly the chase spot, nothing left over
	for _, t in { ArenaCam.COMEBACK_SECONDS, ArenaCam.COMEBACK_SECONDS + 5 } do
		local turn, out, hgt, wide = ArenaCam.comeBack(t, back, up)
		eq(turn, 0)
		eq(out, back)
		eq(hgt, up)
		eq(wide, 0)
	end
	-- smooth and one way: the turn and the extra view only shrink, never come back
	local lastTurn, lastWide = math.huge, math.huge
	for i = 0, 25 do
		local turn, _, _, wide = ArenaCam.comeBack(i * 0.05, back, up)
		truthy(turn <= lastTurn and wide <= lastWide, "never turns back")
		lastTurn, lastWide = turn, wide
	end
	truthy(
		ArenaCam.COMEBACK_SECONDS >= 1 and ArenaCam.COMEBACK_SECONDS <= 1.5,
		"quick: about a second"
	)
	-- hooked up: a respawn in a match (the old camera was the match camera), once the car is
	-- placed, and plain with reduced motion
	local chase = fs.readFile("src/client/ChaseCamera.luau")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(string.find(chase, "ArenaCam.comeBack(whoosh, flatOff, arenaOff.Y)", 1, true) ~= nil)
	truthy(string.find(main, "local respawned = camera.isArena()", 1, true) ~= nil)
	local at = string.find(main, "camera.comeBack()", 1, true)
	local placed = string.find(main, "goTo(index)\n\t\t-- the camera's entrance", 1, true)
	truthy(
		at ~= nil and placed ~= nil and placed < at,
		"after the car is placed (goTo snaps the camera)"
	)
	truthy(string.find(main, ".reduced()", 1, true) ~= nil, "reduced motion: no whoosh")
end)

test(
	"arena cam: the match start fly-in circles down and lands exactly on the match camera",
	function()
		local back, up = ArenaCam.offset(ArenaCam.PHONE_DISTANCE, ArenaCam.PHONE_PITCH)
		local k0, turn0, out0, hgt0, wide0 = ArenaCam.flyIn(0, back, up)
		eq(k0, 0)
		truthy(turn0 > math.pi, "starts more than half way round")
		eq(out0, ArenaCam.FLYIN_RADIUS)
		eq(hgt0, ArenaCam.FLYIN_HEIGHT)
		eq(wide0, ArenaCam.FLYIN_FOV)
		for _, t in { ArenaCam.FLYIN_SECONDS, ArenaCam.FLYIN_SECONDS + 5 } do
			local k, turn, out, hgt, wide = ArenaCam.flyIn(t, back, up)
			eq(k, 1)
			eq(turn, 0)
			eq(out, back)
			eq(hgt, up)
			eq(wide, 0)
		end
		-- one way: lower, closer and straighter every step, never back up
		local lastK, lastH, lastTurn = -1, math.huge, math.huge
		for i = 0, 60 do
			local k, turn, _, hgt = ArenaCam.flyIn(i * 0.05, back, up)
			truthy(k >= lastK and hgt <= lastH and turn <= lastTurn, "never climbs or turns back")
			lastK, lastH, lastTurn = k, hgt, turn
		end
		truthy(ArenaCam.FLYIN_SECONDS >= 2 and ArenaCam.FLYIN_SECONDS <= 4, "a short swoop")
		truthy(ArenaCam.FLYIN_RUSH > 1, "a moving kart rushes it")
		-- hooked up: only at the match's start (the old camera was not the match camera), after the
		-- car is placed, never in reduced motion; the wall check holds it off the walls near the end
		local chase = fs.readFile("src/client/ChaseCamera.luau")
		local main = fs.readFile("src/client/Main.client.luau")
		truthy(string.find(chase, "ArenaCam.flyIn(flying, flatOff, arenaOff.Y)", 1, true) ~= nil)
		truthy(string.find(chase, "k >= ArenaCam.FLYIN_WALLS", 1, true) ~= nil)
		truthy(string.find(chase, "ArenaCam.FLYIN_RUSH", 1, true) ~= nil, "driving rushes it")
		truthy(string.find(main, "camera.flyIn()", 1, true) ~= nil)
		truthy(string.find(main, "if respawned then", 1, true) ~= nil, "a respawn is the whoosh")
	end
)
