--!strict
local H = require("./harness")
local FeelRules = require("../src/shared/FeelRules")
local GameConfig = require("../src/shared/GameConfig")
local ModesConfig = require("../src/shared/ModesConfig")
local SoccerFieldConfig = require("../src/shared/SoccerFieldConfig")
local SoccerFieldFlow = require("../src/shared/SoccerFieldFlow")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy
local F = GameConfig.Feel

print("FeelRules")

test("flash limiter: at most 3 per second, then free again", function()
	local s = FeelRules.newFlashLimiter()
	truthy(FeelRules.allowFlash(s, 0, 3))
	truthy(FeelRules.allowFlash(s, 0.1, 3))
	truthy(FeelRules.allowFlash(s, 0.2, 3))
	truthy(not FeelRules.allowFlash(s, 0.3, 3))
	truthy(not FeelRules.allowFlash(s, 0.99, 3))
	truthy(FeelRules.allowFlash(s, 1.05, 3)) -- the first one left the window
	truthy(not FeelRules.allowFlash(s, 1.06, 3))
	eq(F.maxFlashesPerSecond, 3)
end)

test("flash limiter never lets more than max through in any second", function()
	local s = FeelRules.newFlashLimiter()
	local allowed: { number } = {}
	for i = 0, 600 do
		local now = i * 0.01 -- a hit every 10 ms for 6 s
		if FeelRules.allowFlash(s, now, F.maxFlashesPerSecond) then
			table.insert(allowed, now)
		end
	end
	for i = 1, #allowed do
		local count = 0
		for j = i, #allowed do
			if allowed[j] - allowed[i] < 1 then
				count += 1
			end
		end
		truthy(count <= F.maxFlashesPerSecond, "window at " .. allowed[i])
	end
	truthy(#allowed >= 15)
end)

test("calm lowers flash and shake", function()
	truthy(FeelRules.shakeScale(true) < FeelRules.shakeScale(false))
	eq(FeelRules.shakeScale(false), 1)
	for _, power in { 0, 0.5, 1 } do
		local normal = FeelRules.flashTransparency(power, false)
		local calm = FeelRules.flashTransparency(power, true)
		truthy(calm > normal, "calm flash is fainter")
		truthy(calm <= 1 and normal >= 0)
	end
	truthy(FeelRules.flashTransparency(1, false) < FeelRules.flashTransparency(0, false))
end)

local function norm(x: number, z: number): (number, number)
	local l = math.sqrt(x * x + z * z)
	return x / l, z / l
end

test("soccer camera: higher and further back than the old framing", function()
	local cases = {
		{ -40, 0, 0, 0, 1, 0 },
		{ -50, -25, 20, 10, 1, 0 },
		{ 10, 10, 30, -10, 1, 0 },
	}
	for i, c in cases do
		local old = SoccerFieldFlow.cameraFrame(c[1], c[2], c[3], c[4], c[5], c[6])
		local new = FeelRules.soccerCamera(c[1], c[2], c[3], c[4], c[5], c[6], nil)
		truthy(new.camY > old.camY, "higher, case " .. i)
		local oldBack = math.sqrt((old.camX - c[1]) ^ 2 + (old.camZ - c[2]) ^ 2)
		local newBack = math.sqrt((new.camX - c[1]) ^ 2 + (new.camZ - c[2]) ^ 2)
		truthy(newBack >= oldBack - 1e-6, "further back, case " .. i)
	end
end)

test("soccer camera: car, ball and own goal stay in frame", function()
	local hits = 0
	-- {carX, carZ, ballX, ballZ, fwdX, fwdZ, ownGoalX}
	local cases = {
		{ -40, 0, 0, 0, 1, 0, -70 },
		{ -50, -25, 30, 25, 1, 0, -70 },
		{ 50, 25, -30, -25, -1, 0, 70 },
		{ -20, 10, -45, -5, -1, 0, -70 }, -- defending: ball between car and goal
		{ 0, 30, 0, -30, 0, -1, -70 },
		{ -55, 0, 40, 0, 1, 0, -70 },
		{ 45, -20, 55, 0, 1, 0, 70 },
	}
	local fov = F.normalFov
	for i, c in cases do
		local f = FeelRules.soccerCamera(c[1], c[2], c[3], c[4], c[5], c[6], c[7])
		local cam = { f.camX, f.camY, f.camZ }
		local look = { f.lookX, f.lookY, f.lookZ }
		-- Check with a slightly looser margin than the fit used, to leave float room.
		for name, p in
			{
				car = { c[1], 1.5, c[2] },
				ball = { c[3], SoccerFieldConfig.ballDiameter / 2, c[4] },
				goal = { c[7], SoccerFieldConfig.goalHeight / 3, 0 },
			}
		do
			truthy(
				FeelRules.inView(cam, look, p, fov, F.soccerAspect, 1),
				"case " .. i .. " " .. name .. " out of frame"
			)
		end
		hits += 1
	end
	eq(hits, #cases)
end)

test("soccer camera: inside the field margin, no NaN, height sane", function()
	local hx = SoccerFieldConfig.length / 2
		+ SoccerFieldConfig.goalDepth
		+ SoccerFieldConfig.camMargin
	local hz = SoccerFieldConfig.width / 2 + SoccerFieldConfig.camMargin
	for _, c in
		{ { 0, 0, 0, 0, 0, 0, -70 }, { -60, 35, 60, -35, 1, 0, -70 }, { 5, 5, 5, 5, 0, 0, nil } }
	do
		local f = FeelRules.soccerCamera(c[1], c[2], c[3], c[4], c[5], c[6], c[7])
		truthy(f.camX == f.camX and f.camY == f.camY and f.camZ == f.camZ)
		truthy(math.abs(f.camX) <= hx + 1e-6 and math.abs(f.camZ) <= hz + 1e-6)
		truthy(
			f.camY > 0
				and f.camY
					<= SoccerFieldConfig.camMaxUp * F.soccerCamUpMult * F.soccerCamMaxGrow + 1e-6
		)
	end
end)

test("inView: ahead yes, behind no, far to the side no", function()
	local cam, look = { 0, 50, 0 }, { 0, 0, -50 }
	truthy(FeelRules.inView(cam, look, { 0, 0, -50 }, 65, 1.8, 1))
	truthy(not FeelRules.inView(cam, look, { 0, 0, 50 }, 65, 1.8, 1))
	truthy(not FeelRules.inView(cam, look, { 500, 0, -50 }, 65, 1.8, 1))
	truthy(not FeelRules.inView(cam, cam, { 0, 0, -50 }, 65, 1.8, 1))
end)

test("segmentHitsBox: wall between camera and car", function()
	-- wall box centred at origin: 20 long (x), 30 high, 3 thick (z)
	local hx, hy, hz = 10, 15, 1.5
	truthy(FeelRules.segmentHitsBox({ 0, 20, -30 }, { 0, 0, 30 }, hx, hy, hz)) -- passes through
	truthy(not FeelRules.segmentHitsBox({ 0, 40, 5 }, { 0, 0, 30 }, hx, hy, hz)) -- both on one side
	truthy(not FeelRules.segmentHitsBox({ 40, 5, -30 }, { 40, 5, 30 }, hx, hy, hz)) -- beside the wall
	truthy(FeelRules.segmentHitsBox({ 0, 5, -3 }, { 0, 5, 3 }, hx, hy, hz)) -- short poke through
	truthy(not FeelRules.segmentHitsBox({ 0, 50, -30 }, { 0, 50, 30 }, hx, hy, hz)) -- over the top
	truthy(FeelRules.segmentHitsBox({ -20, 5, 0 }, { 20, 5, 0 }, hx, hy, hz)) -- parallel to a face, along x
end)

test("approach moves at the rate and never overshoots", function()
	near(FeelRules.approach(0, 1, 0.1, 5), 0.5)
	near(FeelRules.approach(0, 1, 1, 5), 1)
	near(FeelRules.approach(1, 0, 0.1, 5), 0.5)
end)

test("bowl camera: closer than the old 40 back / 48 up and follows the car", function()
	local f = FeelRules.bowlCamera(0, 0, 0, 1)
	truthy(f.camZ < 40 and f.camY < 48)
	near(f.lookX, 0)
	local g = FeelRules.bowlCamera(40, 0, norm(1, 1))
	near(g.lookX, 40 * F.bowlCamShift)
	truthy(g.camX > f.camX)
	-- the middle of the bowl is still in front of the camera
	local dx, dz = 0 - g.camX, 0 - g.camZ
	local fx, fz = g.lookX - g.camX, g.lookZ - g.camZ
	truthy(dx * fx + dz * fz > 0)
end)

test("goal snap: holds 1 s, eases out, done inside the goal pause", function()
	eq(FeelRules.snapWeight(-1, 1, 0.35), 0)
	eq(FeelRules.snapWeight(0, 1, 0.35), 1)
	eq(FeelRules.snapWeight(1, 1, 0.35), 1)
	near(FeelRules.snapWeight(1.175, 1, 0.35), 0.5, 1e-9)
	eq(FeelRules.snapWeight(1.35, 1, 0.35), 0)
	truthy(F.goalSnapSeconds + F.goalSnapBlendOut < ModesConfig.Soccer.goalPause)
	truthy(F.goalBurstSeconds < 2.5)
	truthy(F.goalBurstSeconds <= ModesConfig.Soccer.goalPause)
end)

test("goal text parsing and scorer team", function()
	local a, aMine = FeelRules.parseGoal("GOAL!")
	truthy(a and aMine)
	local b, bMine = FeelRules.parseGoal("THEY SCORED!")
	truthy(b and not bMine)
	local c = FeelRules.parseGoal("GOAL! TEAM WINS!")
	truthy(not c)
	local colors = ModesConfig.Soccer.colors
	eq(FeelRules.teamOfColor(colors[1][1], colors[1][2], colors[1][3], colors), 1)
	eq(FeelRules.teamOfColor(colors[2][1], colors[2][2], colors[2][3], colors), 2)
	eq(FeelRules.teamOfColor(1, 2, 3, colors), 0)
	eq(FeelRules.scorerTeam(1, true), 1)
	eq(FeelRules.scorerTeam(1, false), 2)
	eq(FeelRules.scorerTeam(2, false), 1)
	eq(FeelRules.scorerTeam(0, true), 0)
end)

test("ball trail: none when slow, longer the faster, capped", function()
	eq(FeelRules.trailLifetime(0), 0)
	eq(FeelRules.trailLifetime(F.ballTrailMinSpeed - 0.1), 0)
	local slow = FeelRules.trailLifetime(F.ballTrailMinSpeed + 1)
	local mid = FeelRules.trailLifetime(60)
	local fast = FeelRules.trailLifetime(F.ballTrailFullSpeed)
	truthy(slow > 0 and slow < mid and mid < fast)
	near(fast, F.ballTrailMaxSeconds)
	near(FeelRules.trailLifetime(1000), F.ballTrailMaxSeconds)
	eq(FeelRules.trailLifetime(0 / 0), 0)
	truthy(SoccerFieldConfig.ballMaxSpeed >= F.ballTrailFullSpeed - 1)
end)

test("kick strength: small touches are not kicks, strong ones reach 1", function()
	eq(FeelRules.kickStrength(0), 0)
	eq(FeelRules.kickStrength(F.kickMinDelta - 1), 0)
	truthy(FeelRules.kickStrength(F.kickMinDelta) > 0)
	near(FeelRules.kickStrength(F.kickFullDelta), 1)
	near(FeelRules.kickStrength(500), 1)
	truthy(FeelRules.kickStrength(40) < FeelRules.kickStrength(60))
	eq(FeelRules.kickStrength(0 / 0), 0)
	-- a spark needs a clearly strong kick
	truthy(FeelRules.kickStrength(F.kickMinDelta + 1) < F.kickSparkFrom)
end)

test("boost fov: zero outside 0.8 s, peak early, eases back", function()
	local dur, amount = F.boostFxSeconds, F.boostFovAdd
	eq(F.boostFxSeconds, 0.8)
	eq(FeelRules.boostFov(-0.1, dur, amount), 0)
	eq(FeelRules.boostFov(0, dur, amount), 0)
	eq(FeelRules.boostFov(dur, dur, amount), 0)
	eq(FeelRules.boostFov(5, dur, amount), 0)
	near(FeelRules.boostFov(dur * 0.15, dur, amount), amount)
	truthy(FeelRules.boostFov(0.4, dur, amount) < amount)
	truthy(FeelRules.boostFov(0.6, dur, amount) < FeelRules.boostFov(0.4, dur, amount))
	eq(FeelRules.boostFov(0.2, 0, amount), 0)
end)

test("stick curve: gentle in the middle, full at the edge, keeps sign", function()
	near(FeelRules.stickCurve(1, F.touchSteerCurve), 1)
	near(FeelRules.stickCurve(-1, F.touchSteerCurve), -1)
	eq(FeelRules.stickCurve(0, F.touchSteerCurve), 0)
	truthy(FeelRules.stickCurve(0.5, F.touchSteerCurve) < 0.5)
	truthy(FeelRules.stickCurve(-0.5, F.touchSteerCurve) > -0.5)
	near(FeelRules.stickCurve(3, F.touchSteerCurve), 1)
end)

test("touch smoothing applies to small (fast turning) cars only", function()
	eq(FeelRules.touchSteerRate(4.4), F.touchSteerRate)
	eq(FeelRules.touchSteerRate(F.smallCarTurnRate), F.touchSteerRate)
	eq(FeelRules.touchSteerRate(2.2), nil)
	eq(FeelRules.touchSteerRate(nil), nil)
end)

test("team icons: bomb for IT, chevron for teammates", function()
	eq(FeelRules.iconFor(true, false), "bomb")
	eq(FeelRules.iconFor(true, true), "bomb")
	eq(FeelRules.iconFor(false, true), "chevron")
	eq(FeelRules.iconFor(false, false), nil)
end)

local function runFrames(state: FeelRules.Quality, seconds: number, dt: number): number
	local level = state.level
	for _ = 1, math.floor(seconds / dt) do
		level = FeelRules.qualityStep(state, dt)
	end
	return level
end

test("quality: 60 fps stays full, slow frames drop to low, fast again recovers", function()
	local s = FeelRules.newQuality()
	eq(runFrames(s, 30, 1 / 60), 1)
	eq(runFrames(s, 12, 1 / 15), 2)
	eq(runFrames(s, 20, 1 / 60), 1)
	truthy(FeelRules.particleScale(2) < 1)
	eq(FeelRules.particleScale(1), 1)
end)

test("quality: warm-up is ignored and one hitch does not switch", function()
	local s = FeelRules.newQuality()
	for _ = 1, 15 do
		FeelRules.qualityStep(s, 0.2) -- slow load frames inside the warm-up
	end
	eq(s.level, 1)
	local t = FeelRules.newQuality()
	runFrames(t, 20, 1 / 60)
	FeelRules.qualityStep(t, 1.5) -- one long hitch
	eq(runFrames(t, 6, 1 / 60), 1)
end)

test("quality: holds a level for minHold seconds (no flapping)", function()
	local s = FeelRules.newQuality()
	runFrames(s, 10, 1 / 12)
	eq(s.level, 2)
	-- immediately fast again: still low until minHold passes
	FeelRules.qualityStep(s, 1 / 60)
	s.avg = 1 / 60
	eq(FeelRules.qualityStep(s, 1 / 60), 2)
	s.since = GameConfig.Feel.quality.minHold
	eq(FeelRules.qualityStep(s, 1 / 60), 1)
end)

test("chase camera: angle easing goes the short way and never overshoots", function()
	local a = FeelRules.approachAngle(3.0, -3.0, 1 / 60, 5) -- 3 -> -3 is a small step across +-pi
	truthy(a > 3.0)
	local b = FeelRules.approachAngle(0, 1, 10, 5)
	truthy(b > 0.99 and b <= 1)
end)

test("chase camera: leans toward the ball, capped, nil ball = straight behind", function()
	eq(FeelRules.chaseYaw(1, nil, 0.35, 0.6), 1)
	near(FeelRules.chaseYaw(0, 1, 0.35, 0.6), 0.35)
	near(FeelRules.chaseYaw(0, 3, 0.35, 0.6), 0.6)
	near(FeelRules.chaseYaw(3, -3, 0.5, 0.6), 3 + 0.5 * (-6 + 2 * math.pi))
end)

test("whole-arena camera: every corner fits, and a bigger arena needs a farther camera", function()
	local f = GameConfig.Feel
	local function dist(hx: number, hz: number)
		return FeelRules.arenaFitDistance(hx, hz, 0, 66, f.normalFov, 1.9, 0.94)
	end
	local small, big = dist(40, 30), dist(80, 40)
	truthy(big > small)
	truthy(small < 900 and big < 900)
	-- at that distance the far corners are really inside the view
	local pitch = math.rad(66)
	local cam = { 0, math.sin(pitch) * big, -math.cos(pitch) * big }
	for _, c in { { -80, -40 }, { 80, -40 }, { -80, 40 }, { 80, 40 } } do
		truthy(FeelRules.inView(cam, { 0, 0, 0 }, { c[1], 0, c[2] }, f.normalFov, 1.9, 0.94))
	end
	-- a narrower (portrait-ish) screen needs more distance for a wide arena
	truthy(FeelRules.arenaFitDistance(80, 40, 0, 66, f.normalFov, 1.2, 0.94) > big)
end)

test("mouse steering: dead zone, full at the edge, sign follows the side", function()
	eq(FeelRules.mouseSteer(0.02, 0.05, 0.3), 0)
	eq(FeelRules.mouseSteer(-0.04, 0.05, 0.3), 0)
	near(FeelRules.mouseSteer(0.3, 0.05, 0.3), 1)
	near(FeelRules.mouseSteer(-0.5, 0.05, 0.3), -1)
	truthy(FeelRules.mouseSteer(0.15, 0.05, 0.3) > 0)
	truthy(FeelRules.mouseSteer(0.15, 0.05, 0.3) < 1)
	truthy(FeelRules.mouseSteer(0.1, 0.05, 0.3) < FeelRules.mouseSteer(0.2, 0.05, 0.3))
end)
