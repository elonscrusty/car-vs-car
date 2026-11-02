--!strict
-- The ONE special each car has (carter 10-29: one car = one ability). Which special a car owns,
-- and how its SPECIAL button looks (the "A Ring Meter" look: ring colour while charging, word when
-- full). Both specials share the same charge maths (FireSwarm.fill / charged, 15 s refill).
-- Plain data, so Lune tests run it.

local Specials = {}

export type Look = { word: string, on: { number }, full: { number } }

Specials.DEFAULT = "FireSwarm"

-- ring colours: charging (on) and ready (full), 0-255
Specials.LOOKS = {
	FireSwarm = { word = "FIRE SWARM", on = { 255, 130, 30 }, full = { 255, 205, 40 } },
	Shockwave = { word = "SHOCKWAVE", on = { 60, 200, 215 }, full = { 160, 245, 255 } },
} :: { [string]: Look }

-- car id (RacerCar) -> its special; any car not listed uses DEFAULT
Specials.CAR = {
	ice_viper = "Shockwave",
} :: { [string]: string }

function Specials.forCar(carId: any): string
	if type(carId) == "string" then
		local s = Specials.CAR[carId]
		if s ~= nil then
			return s
		end
	end
	return Specials.DEFAULT
end

function Specials.look(name: any): Look
	if type(name) == "string" and Specials.LOOKS[name] ~= nil then
		return Specials.LOOKS[name]
	end
	return Specials.LOOKS[Specials.DEFAULT]
end

return Specials
