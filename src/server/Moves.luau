--!strict
-- Server side of the fight moves (boost, jump, drift, special) for one human car.
-- Rules and numbers: shared/Moves + shared/MovesConfig. Match owns one State per car and
-- creates a fresh one each fight, so cooldowns never carry over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Moves = require(ReplicatedStorage.Shared.Moves)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local Autopilot = require(script.Parent.Autopilot)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)
local Specials = require(script.Parent.Specials)

export type State = {
	boostAt: number, -- os.clock() of the last boost press
	jumpAt: number,
	drift: Moves.DriftState,
}

local ServerMoves = {}

function ServerMoves.new(): State
	return { boostAt = -math.huge, jumpAt = -math.huge, drift = Moves.newDrift() }
end

local function onGround(car: CarBuilder.Car, rayParams: RaycastParams): boolean
	local reach = car.stats.size[2] / 2 + 2.5
	local hit = workspace:Raycast(car.body.Position, Vector3.new(0, -reach, 0), rayParams)
	return hit ~= nil and (hit.Instance.Name == "Floor" or hit.Instance.Name == "Slope")
end

-- Boost speed/push scales (while it lasts) and the drift grip, as Autopilot.stepManual wants them.
function ServerMoves.mods(
	state: State,
	car: CarBuilder.Car,
	steer: number,
	dt: number,
	now: number
): Autopilot.Mods
	local v = car.body.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local grip, turn = Moves.driftStep(state.drift, steer, speed, dt, MovesConfig.Drift)
	local sinceBoost = now - state.boostAt
	return {
		speedScale = Moves.boostSpeedMult(sinceBoost, MovesConfig.Boost),
		accelScale = Moves.boostAccelMult(sinceBoost, MovesConfig.Boost),
		gripScale = grip,
		turnScale = turn,
	}
end

-- Tries a move. Returns the cooldown in seconds to show the player when it fired, else nil.
function ServerMoves.press(
	state: State,
	name: string,
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	rayParams: RaycastParams,
	now: number
): number?
	if car.dead then
		return nil
	end
	if name == "boost" then
		local cd = MovesConfig.Boost.cooldown
		if not Moves.ready(state.boostAt, cd, now) then
			return nil
		end
		state.boostAt = now
		car.model:SetAttribute("BoostAt", workspace:GetServerTimeNow()) -- the driver's device reads this
		local look = car.body.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude > 0.1 then
			Impulse.linear(car.body, fwd.Unit * MovesConfig.Boost.kick * car.body.AssemblyMass)
		end
		return cd
	elseif name == "jump" then
		local cd = MovesConfig.Jump.cooldown
		if not Moves.ready(state.jumpAt, cd, now) or not onGround(car, rayParams) then
			return nil
		end
		state.jumpAt = now
		Impulse.linear(car.body, Vector3.yAxis * MovesConfig.Jump.speed * car.body.AssemblyMass)
		return cd
	elseif name == "special" then
		if Specials.use(car, enemy, now) then
			return Specials.cooldownLeft(car, now)
		end
	end
	return nil
end

return ServerMoves
