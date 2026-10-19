--!strict
-- Pure car soccer flow rules (no Roblox calls): kickoff countdown text, match clock text, ball-stuck
-- warning, goalkeeper / chaser bot aims and the camera framing. Positions are flat (x, z) relative
-- to the field middle. Numbers: SoccerFieldConfig and ModesConfig.Soccer. Unit tested.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("SoccerFieldConfig")
local SoccerField = sibling("SoccerField")

local Flow = {}

export type Frame = {
	camX: number,
	camY: number,
	camZ: number,
	lookX: number,
	lookY: number,
	lookZ: number,
}

-- "3", "2", "1" while time remains, then "GO!".
function Flow.countdownText(remaining: number): string
	if remaining <= 0 then
		return "GO!"
	end
	return tostring(math.ceil(remaining))
end

-- Match clock "2:05". In golden goal (overtime) it says so instead.
function Flow.clockText(secondsLeft: number, overtime: boolean): string
	if overtime then
		return "GOLDEN GOAL"
	end
	local s = math.max(0, math.ceil(secondsLeft))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The ball has been idle long enough that the reset is coming: show the warning.
function Flow.stuckWarning(idle: number): boolean
	return idle >= Config.stuckSeconds - Config.stuckWarnSeconds and idle < Config.stuckSeconds
end

-- Which slot (1..n) in a team is the goalkeeper: the first bot, only when the team has 2+ cars.
-- `bots[k]` = true when slot k is driven by a bot. 0 = nobody keeps goal.
function Flow.keeperSlot(bots: { boolean }): number
	if #bots < 2 then
		return 0
	end
	for k, isBot in bots do
		if isBot then
			return k
		end
	end
	return 0
end

-- Where a keeper waits: in front of its own goal line, following the ball sideways (clamped).
function Flow.keeperTarget(team: number, ballZ: number): (number, number)
	local sign = if team == 1 then -1 else 1
	local x = sign * (Config.length / 2 - Config.keeperDepth)
	return x, math.clamp(ballZ, -Config.keeperRange, Config.keeperRange)
end

-- Where a bot drives. Chasers go behind the ball on the line to the goal they attack and push
-- through it. A keeper holds its spot until the ball gets close to its own goal, then clears it.
function Flow.botAim(
	isKeeper: boolean,
	team: number,
	ballX: number,
	ballZ: number,
	carX: number,
	carZ: number
): (number, number)
	if isKeeper then
		local gx = (if team == 1 then -1 else 1) * Config.length / 2
		local dx, dz = ballX - gx, ballZ
		if dx * dx + dz * dz > Config.keeperClearRadius ^ 2 then
			return Flow.keeperTarget(team, ballZ)
		end
	end
	local tx, tz = SoccerField.botTarget(ballX, ballZ, team, Config.botOffset)
	local ex, ez = tx - carX, tz - carZ
	if ex * ex + ez * ez < Config.botNear ^ 2 then
		return ballX, ballZ
	end
	return tx, tz
end

-- Camera: high behind your car, on the line ball -> car, so both stay in view. `fwdX, fwdZ` is the
-- way the car faces (used when the ball is too close to give a stable line). Height grows with the
-- car-ball distance. The camera is kept inside the field plus a margin.
function Flow.cameraFrame(
	carX: number,
	carZ: number,
	ballX: number,
	ballZ: number,
	fwdX: number,
	fwdZ: number
): Frame
	local bx, bz = carX - ballX, carZ - ballZ
	local dist = math.sqrt(bx * bx + bz * bz)
	local fl = math.sqrt(fwdX * fwdX + fwdZ * fwdZ)
	local backX, backZ = 0, 1
	if fl > 1e-6 then
		backX, backZ = -fwdX / fl, -fwdZ / fl
	end
	local dirX, dirZ = backX, backZ
	if dist > 1e-6 then
		local w = math.clamp(dist / Config.camDirBlend, 0, 1)
		local mx = (bx / dist) * w + backX * (1 - w)
		local mz = (bz / dist) * w + backZ * (1 - w)
		local m = math.sqrt(mx * mx + mz * mz)
		if m > 1e-6 then
			dirX, dirZ = mx / m, mz / m
		end
	end
	local up = math.min(Config.camMaxUp, Config.camUp + dist * Config.camUpPerBallDist)
	local hx = Config.length / 2 + Config.goalDepth + Config.camMargin
	local hz = Config.width / 2 + Config.camMargin
	local k = Config.camLookBall
	return {
		camX = math.clamp(carX + dirX * Config.camBack, -hx, hx),
		camY = up,
		camZ = math.clamp(carZ + dirZ * Config.camBack, -hz, hz),
		lookX = carX + (ballX - carX) * k,
		lookY = 0,
		lookZ = carZ + (ballZ - carZ) * k,
	}
end

return Flow
