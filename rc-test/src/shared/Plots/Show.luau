--!strict
-- SHOW CAR plot. Starter: a plain cruise loop round the edge and a flat stage. To be redone to
-- match the plot picture: a spinning stage, parked car spots and a little cruise loop.

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
local POINTS = {
	{ x = -100, z = 120 },
	{ x = 100, z = 120 },
	{ x = 130, z = 90 },
	{ x = 130, z = -160 },
	{ x = 100, z = -190 },
	{ x = -100, z = -190 },
	{ x = -130, z = -160 },
	{ x = -130, z = 90 },
}

local Plot = {}
Plot.id = "show"
Plot.label = "SHOW"
Plot.mode = "free"
Plot.grip = 1
Plot.ROAD = ROAD

function Plot.loop()
	return Kit.loop(POINTS, 8)
end

Plot.spawn = Kit.spawnAt(Plot.loop()[1], -20)
Plot.gates = {}

function Plot.build(parent: Instance, origin: CFrame)
	Kit.ribbon(parent, origin, Plot.loop(), ROAD)
	Kit.disc(parent, "Stage", origin, 0, 0.5, -40, 50, 1, C.pad)
end

return Plot
