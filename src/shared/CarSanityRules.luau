--!strict
-- Pure rules for "is this client-driven car behaving?" (unit tested). The server (CarSanity.luau)
-- feeds in the car's position every frame; this says ok / reset / forfeit.
--   teleport  : moved much farther in one step than the speed cap allows -> reset to last good spot
--   too high  : above the arena height limit for longer than the grace time -> reset
--   too fast  : measured speed (not the velocity the client claims) above the cap -> reset
--   forfeit   : reset too many times in one match
-- A reset is a move back to the last spot that passed every check.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("CarSanityConfig")

export type Cfg = typeof(Config)
export type Vec = { x: number, y: number, z: number }
export type State = {
	last: Vec?, -- position at the previous step
	good: Vec?, -- last position that passed every check
	badTime: number, -- seconds spent too fast / too high, cooling off
	resets: number,
}
export type Verdict = "ok" | "reset" | "forfeit"
export type Result = { verdict: Verdict, resetTo: Vec? }

local CarSanityRules = {}

function CarSanityRules.newState(): State
	return { last = nil, good = nil, badTime = 0, resets = 0 }
end

local LIMIT = 1e7

local function finite(p: Vec): boolean
	return math.abs(p.x) < LIMIT and math.abs(p.y) < LIMIT and math.abs(p.z) < LIMIT
end

local function dist(a: Vec, b: Vec): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- One step. `pos` = car position now, `originY` = arena floor height, `speedCap` = the top speed this
-- car may legitimately have (studs/s), `dt` = seconds since the last step. Mutates `state`.
function CarSanityRules.step(
	state: State,
	pos: Vec,
	originY: number,
	speedCap: number,
	dt: number,
	cfg: Cfg?
): Result
	local c: Cfg = cfg or Config
	local t = math.clamp(if dt == dt then dt else 0, 0, c.maxStepSeconds)
	local bad = false
	local teleport = false

	-- NaN fails every comparison, so "not < LIMIT" also catches NaN.
	if not finite(pos) then
		teleport = true
	end
	local last = state.last
	if not teleport and last and t > 0 then
		local moved = dist(pos, last)
		if moved > speedCap * t * c.teleportSlack + c.teleportFloor then
			teleport = true
		elseif moved / t > speedCap * c.speedSlack and moved > c.teleportFloor * 0.5 then
			bad = true
		end
	end
	if not teleport and pos.y - originY > c.maxHeightAboveArena then
		bad = true
	end

	if not teleport then
		if bad then
			state.badTime += t
		else
			state.badTime = math.max(0, state.badTime - t * c.decayRate)
		end
		if state.badTime > c.graceSeconds then
			teleport = true -- bad for too long: same handling as a teleport
		end
	end

	if teleport then
		state.resets += 1
		state.badTime = 0
		state.last = state.good
		-- Too many resets, or no good spot yet to go back to: the car forfeits.
		if state.resets >= c.maxResets or state.good == nil then
			return { verdict = "forfeit", resetTo = nil }
		end
		return { verdict = "reset", resetTo = state.good }
	end

	state.last = pos
	if not bad then
		state.good = pos
	end
	return { verdict = "ok", resetTo = nil }
end

return CarSanityRules
