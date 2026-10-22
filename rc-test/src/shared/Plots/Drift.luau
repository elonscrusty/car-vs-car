--!strict
-- DRIFT plot. Starter: the old drift test loop moved onto the plot. To be redone to match the
-- plot picture: wide sweeping corners and a big round drift pad.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Kit = sibling("Kit")
local C = Kit.COLORS

local ROAD = 44
local S = 0.62 -- the old big test loop, shrunk to fit the plot
local POINTS = {
	{ x = -120, z = -140 },
	{ x = 40, z = -170 },
	{ x = 170, z = -100 },
	{ x = 200, z = 20 },
	{ x = 120, z = 110 },
	{ x = 0, z = 60 },
	{ x = -110, z = 120 },
	{ x = -190, z = 40 },
	{ x = -200, z = -70 },
}

local Plot = {}
Plot.id = "drift"
Plot.label = "DRIFT"
Plot.mode = "free"
Plot.grip = 0.45
Plot.ROAD = ROAD

function Plot.loop()
	local pts = {}
	for i, p in POINTS do
		pts[i] = { x = p.x * S, z = p.z * S }
	end
	return Kit.loop(pts, 8)
end

Plot.spawn = Kit.spawnAt(Plot.loop()[1], 14)
Plot.gates = {}

function Plot.build(parent: Instance, origin: CFrame)
	Kit.ribbon(parent, origin, Plot.loop(), ROAD, { grip = Plot.grip })
	local donut = Kit.disc(parent, "Donut", origin, 0, 0.15, -31, 22, 0.2, C.road)
	donut:SetAttribute("Grip", Plot.grip)
	Kit.ramp(parent, "Ramp", origin, Vector3.new(0, 0, 128), Vector3.new(0, 3, 116), 16, C.road)
end

return Plot
