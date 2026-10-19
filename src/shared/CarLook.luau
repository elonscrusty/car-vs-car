--!strict
-- Looks of a car in a fight (no UI): soft shadow blob, outline by rarity, wheel roll.
-- Pure numbers + tiny helpers; CarBuilder (server) and WheelFx (client) use them. Tests: tests/carlook.test.luau.

local CarLook = {}

CarLook.Config = {
	shadowTransparency = 0.6,
	shadowThickness = 0.05,
	shadowWidth = 1.25, -- times the hitbox width
	shadowLength = 1.1, -- times the hitbox length
	-- Outline colour by rarity (rgb). Common = plain light toy outline (shows on the dark floor); rarer = brighter.
	outline = {
		Common = { 235, 238, 250 },
		Rare = { 90, 170, 255 },
		Epic = { 190, 110, 255 },
		Legendary = { 255, 200, 40 },
	} :: { [string]: { number } },
	wheelNamePrefix = "Wheel",
	maxWheelSpin = 60, -- radians per second, so fast cars do not strobe
}

-- Outline rgb for a rarity name; unknown names get the Common look.
function CarLook.outlineRgb(rarity: string?): { number }
	local o = CarLook.Config.outline
	return (rarity and o[rarity]) or o.Common
end

-- Wheel radius from its size (the wheel axis runs along the car's X).
function CarLook.wheelRadius(sizeY: number, sizeZ: number): number
	return math.max(math.max(sizeY, sizeZ) / 2, 0.1)
end

-- How far a wheel turns this frame (radians). The car faces -Z, so rolling forward (positive
-- forward speed) turns the wheel the negative way around X. Clamped so it never strobes.
function CarLook.spinStep(forwardSpeed: number, radius: number, dt: number): number
	local cap = CarLook.Config.maxWheelSpin
	local rate = math.clamp(forwardSpeed / math.max(radius, 0.1), -cap, cap)
	return -rate * dt
end

function CarLook.isWheel(name: string): boolean
	return string.sub(name, 1, #CarLook.Config.wheelNamePrefix) == CarLook.Config.wheelNamePrefix
end

return CarLook
