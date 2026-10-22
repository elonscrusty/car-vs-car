--!strict
-- RACE plot. Starter: the old race test loop moved onto the plot. To be redone to match the
-- plot picture: a twisty lap with a hairpin, a chicane and a start / finish line.

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

local ROAD = 30
local S = 0.62 -- the old big test loop, shrunk to fit the plot
local POINTS = {
	{ x = -110, z = -110 },
	{ x = 0, z = -120 },
	{ x = 90, z = -130 },
	{ x = 170, z = -90 },
	{ x = 190, z = -20 },
	{ x = 140, z = 40 },
	{ x = 60, z = 30 },
	{ x = 30, z = 90 },
	{ x = 80, z = 150 },
	{ x = 10, z = 190 },
	{ x = -90, z = 170 },
	{ x = -150, z = 100 },
	{ x = -130, z = 20 },
	{ x = -170, z = -50 },
}

local Plot = {}
Plot.id = "race"
Plot.label = "RACE"
Plot.mode = "loop"
Plot.grip = 0.75 -- off the road is slower
Plot.ROAD = ROAD

function Plot.loop()
	local pts = {}
	for i, p in POINTS do
		pts[i] = { x = p.x * S, z = p.z * S }
	end
	return Kit.loop(pts, 6)
end

local ring = Plot.loop()
local count = #ring
Plot.spawn = Kit.spawnAt(ring[1], 14)
Plot.gates = {
	Kit.gateAt(ring[1], 0, 22, 6),
	Kit.gateAt(ring[count // 4 + 1], 0, 24, 12),
	Kit.gateAt(ring[count // 2 + 1], 0, 24, 12),
	Kit.gateAt(ring[(count * 3) // 4 + 1], 0, 24, 12),
}

function Plot.build(parent: Instance, origin: CFrame)
	Kit.ribbon(parent, origin, Plot.loop(), ROAD, { grip = 1, walls = 4 })
	local g = Plot.gates[1]
	Kit.line(parent, origin, g.x, 0, g.z, g.dx, g.dz, ROAD, C.white)
end

return Plot
