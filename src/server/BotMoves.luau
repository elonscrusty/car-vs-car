--!strict
-- Bot car, boost and ability: asks the pure brain (shared/Ai.wantMoves) whether now is a good
-- moment, presses through the same server Moves a human uses, and returns the move modifiers
-- for this frame (boost speed, drift grip) for Autopilot.step. Numbers: GameConfig.Ai +
-- BotLevels.moveUse. Turn it off with GameConfig.Ai.useMoves = false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local BotLevels = require(ReplicatedStorage.Shared.BotLevels)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local MovesRules = require(ReplicatedStorage.Shared.Moves)
local Autopilot = require(script.Parent.Autopilot)
local CarBuilder = require(script.Parent.CarBuilder)
local Moves = require(script.Parent.Moves)
local Specials = require(script.Parent.Specials)

local BotMoves = {}

-- Presses boost / ability when the bot's brain says so, then returns this frame's move mods.
function BotMoves.prepare(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	state: Moves.State,
	dt: number,
	rayParams: RaycastParams,
	center: Vector3,
	level: BotLevels.Level?
): Autopilot.Mods?
	if not GameConfig.Ai.useMoves or car.dead then
		return nil
	end
	local lv = level or BotLevels.get(nil)
	local now = os.clock()
	local body = car.body
	local look = body.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude > 0.1 then
		fwd = fwd.Unit
		local pos, epos = body.Position, enemy.body.Position
		local dx, dz = epos.X - pos.X, epos.Z - pos.Z
		local ability = Specials.abilityOf(car)
		local vel = body.AssemblyLinearVelocity
		local wantBoost, wantSpecial = Ai.wantMoves({
			now = now,
			seed = car.idx,
			dist = math.sqrt(dx * dx + dz * dz),
			angle = Ai.signedAngle(fwd.X, fwd.Z, dx, dz),
			me = { x = pos.X, z = pos.Z },
			fx = fwd.X,
			fz = fwd.Z,
			center = { x = center.X, z = center.Z },
			hpShare = car.hp / math.max(car.stats.hp, 1),
			speed = vel.X * fwd.X + vel.Z * fwd.Z,
			maxSpeed = car.stats.maxSpeed,
			accel = car.stats.accel,
			dashForward = if ability then ability.dashForward else 0,
			boostReady = MovesRules.ready(state.boostAt, MovesConfig.Boost.cooldown, now),
			specialReady = ability ~= nil and Specials.cooldownLeft(car, now) <= 0,
			kind = if ability then ability.kind else "",
			radius = if ability then ability.radius else 0,
			moveUse = lv.moveUse,
		}, GameConfig.Ai)
		if wantBoost then
			Moves.press(state, "boost", car, enemy, rayParams, now)
		end
		if wantSpecial then
			Moves.press(state, "special", car, enemy, rayParams, now)
		end
	end
	return Moves.mods(state, car, 0, dt, now)
end

return BotMoves
