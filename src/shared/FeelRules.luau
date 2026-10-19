--!strict
-- Client "feel" rules (pure, no Roblox calls, unit tested in tests/feelrules.test.luau):
-- soccer + bowl camera framing, see-through walls, goal camera snap, ball trail and kick strength,
-- boost FOV, hit flash rate limit and calm effects, touch steering curve, team icons and the
-- low-end graphics quality switch. Numbers live in GameConfig.Feel.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local GameConfig = sibling("GameConfig")
local SoccerFieldConfig = sibling("SoccerFieldConfig")
local SoccerFieldFlow = sibling("SoccerFieldFlow")
local Steer = sibling("Steer")

local FeelRules = {}

export type Frame = {
	camX: number,
	camY: number,
	camZ: number,
	lookX: number,
	lookY: number,
	lookZ: number,
}

-- ---- Hit flash: rate limit and calm effects (#86) ------------------------------------------

export type FlashLimiter = { times: { number } }

function FeelRules.newFlashLimiter(): FlashLimiter
	return { times = {} }
end

-- True when a flash may play at `now` (seconds); records it. At most `maxPerSecond` flashes in
-- any one-second window.
function FeelRules.allowFlash(state: FlashLimiter, now: number, maxPerSecond: number): boolean
	local kept: { number } = {}
	for _, t in state.times do
		if now - t < 1 then
			table.insert(kept, t)
		end
	end
	state.times = kept
	if #kept >= maxPerSecond then
		return false
	end
	table.insert(kept, now)
	return true
end

-- Multiplier for camera shake and FOV punches.
function FeelRules.shakeScale(calm: boolean): number
	return if calm then GameConfig.Feel.calmShakeScale else 1
end

-- Background transparency of the full-screen hit flash (power 0..1); calm makes it fainter.
function FeelRules.flashTransparency(power: number, calm: boolean): number
	local strength = math.clamp(0.12 + 0.2 * power, 0, 1) -- opacity of the normal flash
	if calm then
		strength *= GameConfig.Feel.calmFlashScale
	end
	return 1 - strength
end

-- ---- Soccer camera (#15) -------------------------------------------------------------------

-- Is the point in view of a camera at `cam` looking at `look`? `fovDeg` is the vertical field of
-- view, `margin` (0..1) shrinks the usable view so things are not on the very edge.
function FeelRules.inView(
	cam: { number },
	look: { number },
	p: { number },
	fovDeg: number,
	aspect: number,
	margin: number
): boolean
	local fx, fy, fz = look[1] - cam[1], look[2] - cam[2], look[3] - cam[3]
	local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
	if fl < 1e-6 then
		return false
	end
	fx, fy, fz = fx / fl, fy / fl, fz / fl
	-- right = forward x up(0,1,0), flattened
	local rx, rz = -fz, fx
	local rl = math.sqrt(rx * rx + rz * rz)
	if rl < 1e-6 then
		return false -- looking straight down: not used here
	end
	rx, rz = rx / rl, rz / rl
	-- camera up = right x forward
	local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
	local dx, dy, dz = p[1] - cam[1], p[2] - cam[2], p[3] - cam[3]
	local z = dx * fx + dy * fy + dz * fz
	if z < 0.1 then
		return false
	end
	local x = dx * rx + dz * rz
	local y = dx * ux + dy * uy + dz * uz
	local t = math.tan(math.rad(fovDeg) / 2) * margin
	return math.abs(y) / z <= t and math.abs(x) / z <= t * aspect
end

-- The soccer camera: the base framing (SoccerFieldFlow.cameraFrame) pulled further back and
-- higher, then pushed out a little more until your car, the ball and your own goal are all in
-- view (or the grow limit is reached). `goalX` = x of the goal you defend (nil = ignore goals).
function FeelRules.soccerCamera(
	carX: number,
	carZ: number,
	ballX: number,
	ballZ: number,
	fwdX: number,
	fwdZ: number,
	goalX: number?,
	fovDeg: number?
): Frame
	local feel = GameConfig.Feel
	local c = SoccerFieldConfig
	local base = SoccerFieldFlow.cameraFrame(carX, carZ, ballX, ballZ, fwdX, fwdZ)
	local ox, oz = base.camX - carX, base.camZ - carZ
	local hx = c.length / 2 + c.goalDepth + c.camMargin
	local hz = c.width / 2 + c.camMargin
	local fov = fovDeg or feel.normalFov
	local targets: { { number } } = {
		{ carX, 1.5, carZ },
		{ ballX, c.ballDiameter / 2, ballZ },
	}
	if goalX ~= nil then
		table.insert(targets, { goalX, c.goalHeight / 3, 0 })
	end
	local look = { base.lookX, base.lookY, base.lookZ }
	local result: Frame = base
	local g = 1.0
	while g <= feel.soccerCamMaxGrow + 1e-6 do
		local cx = math.clamp(carX + ox * feel.soccerCamBackMult * g, -hx, hx)
		local cz = math.clamp(carZ + oz * feel.soccerCamBackMult * g, -hz, hz)
		local cy = base.camY * feel.soccerCamUpMult * g
		result = {
			camX = cx,
			camY = cy,
			camZ = cz,
			lookX = look[1],
			lookY = look[2],
			lookZ = look[3],
		}
		local cam = { cx, cy, cz }
		local ok = true
		for _, p in targets do
			if
				not FeelRules.inView(cam, look, p, fov, feel.soccerAspect, feel.soccerFrameMargin)
			then
				ok = false
				break
			end
		end
		if ok then
			break
		end
		g += 0.1
	end
	return result
end

-- Does the segment a -> b pass through a box of half sizes (hx, hy, hz) centred on the origin?
-- (Callers move the points into the wall's own space first.) Slab method.
function FeelRules.segmentHitsBox(
	a: { number },
	b: { number },
	hx: number,
	hy: number,
	hz: number
): boolean
	local half = { hx, hy, hz }
	local t0, t1 = 0, 1
	for i = 1, 3 do
		local d = b[i] - a[i]
		if math.abs(d) < 1e-9 then
			if math.abs(a[i]) > half[i] then
				return false
			end
		else
			local u0, u1 = (-half[i] - a[i]) / d, (half[i] - a[i]) / d
			if u0 > u1 then
				u0, u1 = u1, u0
			end
			t0, t1 = math.max(t0, u0), math.min(t1, u1)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

-- Moves `current` toward `target` at `rate` per second, without overshoot.
function FeelRules.approach(current: number, target: number, dt: number, rate: number): number
	return Steer.smooth(current, target, dt, rate)
end

-- ---- Bowl / duel camera (#99) --------------------------------------------------------------

-- Camera and look point, relative to the bowl middle. `dir` is the flat unit direction from the
-- middle to your car; `carX, carZ` is your car relative to the middle.
function FeelRules.bowlCamera(carX: number, carZ: number, dirX: number, dirZ: number): Frame
	local feel = GameConfig.Feel
	local sx, sz = carX * feel.bowlCamShift, carZ * feel.bowlCamShift
	return {
		camX = dirX * feel.bowlCamBack + sx,
		camY = feel.bowlCamUp,
		camZ = dirZ * feel.bowlCamBack + sz,
		lookX = sx,
		lookY = 0,
		lookZ = sz,
	}
end

-- ---- Goal burst (#23) ----------------------------------------------------------------------

-- 1 while the camera looks at the ball, easing to 0 after `hold` + `blend` seconds.
function FeelRules.snapWeight(elapsed: number, hold: number, blend: number): number
	if elapsed < 0 then
		return 0
	elseif elapsed <= hold then
		return 1
	elseif elapsed < hold + blend then
		return 1 - (elapsed - hold) / blend
	end
	return 0
end

-- The two goal texts the server sends: "GOAL!" (your team scored) and "THEY SCORED!".
-- Returns whether it is a goal text, and whether your team scored.
function FeelRules.parseGoal(text: string): (boolean, boolean)
	if text == "GOAL!" then
		return true, true
	elseif text == "THEY SCORED!" then
		return true, false
	end
	return false, false
end

-- Team index (1 or 2) for an rgb colour, matching `colors` ({{r,g,b},{r,g,b}}); 0 = unknown.
function FeelRules.teamOfColor(r: number, g: number, b: number, colors: { { number } }): number
	for i, c in colors do
		if math.abs(c[1] - r) < 2 and math.abs(c[2] - g) < 2 and math.abs(c[3] - b) < 2 then
			return i
		end
	end
	return 0
end

-- Which team scored: yours when the text says so, else the other one. 0 = unknown.
function FeelRules.scorerTeam(myTeam: number, mine: boolean): number
	if myTeam ~= 1 and myTeam ~= 2 then
		return 0
	end
	return if mine then myTeam else 3 - myTeam
end

-- ---- Ball feel (#91) -----------------------------------------------------------------------

-- Trail lifetime (seconds) for a ball speed (studs/s); 0 = no trail.
function FeelRules.trailLifetime(speed: number): number
	local f = GameConfig.Feel
	if speed ~= speed or speed < f.ballTrailMinSpeed then
		return 0
	end
	local t = math.clamp(
		(speed - f.ballTrailMinSpeed) / math.max(1e-3, f.ballTrailFullSpeed - f.ballTrailMinSpeed),
		0,
		1
	)
	return 0.1 + t * (f.ballTrailMaxSeconds - 0.1)
end

-- Kick strength 0..1 from how much the ball's velocity changed in one frame (studs/s); 0 = no kick.
function FeelRules.kickStrength(deltaV: number): number
	local f = GameConfig.Feel
	if deltaV ~= deltaV or deltaV < f.kickMinDelta then
		return 0
	end
	return math.max(
		0.05,
		math.clamp(
			(deltaV - f.kickMinDelta) / math.max(1e-3, f.kickFullDelta - f.kickMinDelta),
			0,
			1
		)
	)
end

-- ---- Boost feel (#92) ----------------------------------------------------------------------

-- Extra FOV (degrees) `t` seconds after a boost starts: quick rise, slow ease back, 0 after `dur`.
function FeelRules.boostFov(t: number, dur: number, amount: number): number
	if t < 0 or t >= dur or dur <= 0 then
		return 0
	end
	local peak = dur * 0.15
	if t < peak then
		return amount * (t / peak)
	end
	local k = 1 - (t - peak) / (dur - peak)
	return amount * k * k
end

-- ---- Touch steering (#52) ------------------------------------------------------------------

-- Gentler stick near the middle: sign(v) * |v|^exponent (v in -1..1).
function FeelRules.stickCurve(v: number, exponent: number): number
	local c = math.clamp(v, -1, 1)
	return math.sign(c) * math.abs(c) ^ exponent
end

-- Units per second the stick steer may move for a car with this turn rate; nil = no smoothing.
function FeelRules.touchSteerRate(turnRate: number?): number?
	if turnRate ~= nil and turnRate >= GameConfig.Feel.smallCarTurnRate then
		return GameConfig.Feel.touchSteerRate
	end
	return nil
end

-- Chase camera: eases an angle (radians) toward another by the short way round. Frame-rate safe.
function FeelRules.approachAngle(cur: number, target: number, dt: number, rate: number): number
	local diff = (target - cur + math.pi) % (2 * math.pi) - math.pi
	return cur + diff * (1 - math.exp(-rate * dt))
end

-- Chase camera: the heading the camera wants. Straight behind the car, nudged up to `maxBias`
-- radians (and `share` of the way) toward the ball so it stays on screen. nil ball = car heading.
function FeelRules.chaseYaw(
	carYaw: number,
	ballYaw: number?,
	share: number,
	maxBias: number
): number
	if ballYaw == nil then
		return carYaw
	end
	local diff = (ballYaw - carYaw + math.pi) % (2 * math.pi) - math.pi
	return carYaw + math.clamp(diff * share, -maxBias, maxBias)
end

-- Whole-arena camera: how far back (along the view line) a camera looking at the arena middle must
-- sit so every corner of the arena footprint (half sizes hx, hz; floor at y = 0) is on screen.
-- `yaw` = flat direction the camera looks (dir = sin yaw, cos yaw); pitch = degrees looking down.
function FeelRules.arenaFitDistance(
	hx: number,
	hz: number,
	yaw: number,
	pitchDeg: number,
	fovDeg: number,
	aspect: number,
	margin: number
): number
	local pitch = math.rad(pitchDeg)
	local dx, dz = math.sin(yaw), math.cos(yaw)
	local corners = { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } }
	local d = 20
	while d < 900 do
		local cam = { -dx * math.cos(pitch) * d, math.sin(pitch) * d, -dz * math.cos(pitch) * d }
		local ok = true
		for _, c in corners do
			if
				not FeelRules.inView(cam, { 0, 0, 0 }, { c[1], 0, c[2] }, fovDeg, aspect, margin)
			then
				ok = false
				break
			end
		end
		if ok then
			return d
		end
		d += 2
	end
	return 900
end

-- Mouse steering: how far the cursor is left/right of the screen middle (share of the width,
-- -0.5..0.5) -> steer -1..1. Nothing inside the dead zone, full at `full`, a gentle curve between.
function FeelRules.mouseSteer(offsetShare: number, dead: number, full: number): number
	local a = math.abs(offsetShare)
	if a <= dead then
		return 0
	end
	local t = math.clamp((a - dead) / math.max(1e-3, full - dead), 0, 1)
	return math.sign(offsetShare) * t ^ 1.2
end

-- ---- Team icons (#81) ----------------------------------------------------------------------

-- Shape (not just colour) above a car: "bomb" for IT, "chevron" for a teammate, nil for others.
function FeelRules.iconFor(isIt: boolean, isTeammate: boolean): string?
	if isIt then
		return "bomb"
	elseif isTeammate then
		return "chevron"
	end
	return nil
end

-- ---- Graphics quality (#88) ----------------------------------------------------------------

export type Quality = { avg: number, level: number, t: number, since: number } -- level 1 = full, 2 = low

function FeelRules.newQuality(): Quality
	return { avg = 1 / 60, level = 1, t = 0, since = 0 }
end

-- Feed one frame time; returns the quality level (1 full, 2 low). The average is smoothed over
-- `window` seconds, one long hitch counts at most 0.1 s, nothing changes in the warm-up, and a
-- level is held `minHold` seconds before it may switch (no flapping).
function FeelRules.qualityStep(state: Quality, dt: number): number
	local q = GameConfig.Feel.quality
	local d = math.clamp(dt, 0, 0.1)
	state.avg += (d - state.avg) * math.min(1, dt / q.window)
	state.t += dt
	state.since += dt
	if state.t < q.warmup or state.since < q.minHold then
		return state.level
	end
	if state.level == 1 and state.avg > q.lowFrameTime then
		state.level, state.since = 2, 0
	elseif state.level == 2 and state.avg < q.okFrameTime then
		state.level, state.since = 1, 0
	end
	return state.level
end

-- Particle count multiplier for a level.
function FeelRules.particleScale(level: number): number
	return if level >= 2 then GameConfig.Feel.quality.lowScale else 1
end

return FeelRules
