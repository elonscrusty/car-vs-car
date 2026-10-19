--!strict
-- Server check on player-driven cars. The player's device owns the car physics, so a cheater can
-- teleport, fly or speed. Every fight frame this feeds the car's real position to CarSanityRules:
-- a bad step puts the car back at its last good spot (still, no speed); too many resets = forfeit.
-- State is kept per car in a weak table, so there is nothing to clean up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarSanityRules = require(ReplicatedStorage.Shared.CarSanityRules)

local CarSanity = {}

local states: { [any]: CarSanityRules.State } = setmetatable({}, { __mode = "k" }) :: any

-- Call once per fight frame for a client-driven car. Returns false = forfeit this car (caller ends
-- its fight); true = fine (the car may have been quietly put back).
function CarSanity.step(
	car: { model: Model, body: BasePart },
	originY: number,
	speedCap: number,
	dt: number
): boolean
	local st = states[car]
	if not st then
		st = CarSanityRules.newState()
		states[car] = st
	end
	local p = car.body.Position
	local res = CarSanityRules.step(st, { x = p.X, y = p.Y, z = p.Z }, originY, speedCap, dt)
	if res.verdict == "forfeit" then
		warn("[CarSanity] forfeit: car kept breaking movement limits")
		return false
	end
	local to = res.resetTo
	if res.verdict == "reset" and to then
		car.model:PivotTo(car.model:GetPivot() + (Vector3.new(to.x, to.y, to.z) - p))
		car.body.AssemblyLinearVelocity = Vector3.zero
		car.body.AssemblyAngularVelocity = Vector3.zero
	end
	return true
end

-- The server itself moved this car (respawn): forget the old spot so it is not seen as a teleport.
function CarSanity.rebase(car: { model: Model, body: BasePart })
	local st = states[car]
	if st then
		st.last = nil
		st.good = nil
		st.badTime = 0
	end
end

return CarSanity
