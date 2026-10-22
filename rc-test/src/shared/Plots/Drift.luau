--!strict
-- DRIFT plot: one wide loop with long sweeping corners (Tokyo-drift style held slides), an
-- S-shaped "big sweeper" on the right, and a big round drift pad in the middle with a cone to
-- circle around. Everything is flat and level so a slide never gets broken by a bump.
-- Matches /mnt/project-files/car-vs-car/rc-plot/plot-drift.png.

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

local ROAD = 52 -- wide, so a car can hold a long slide without running off
local TOP = 0.1 -- road and pad top: both level, so crossing from one to the other is smooth

-- The centre line is drawn like a turtle: drive straight, or turn through an angle on a set
-- radius. Driven order: front straight to the right, the right-hand sweeper, the "big sweeper"
-- S-bend on the right, across the back, then the long slide down the left. Plot-local big
-- units, +Z is the front. Every corner has a big radius so a slide can be held all the way.
-- The loop keeps about 25 of open floor to the outer walls on every side: room to run wide in
-- a slide, and the chase camera sits over open floor instead of up against a wall.
local START = { x = -32, z = 100 }
local R_RIGHT = 56 -- right-hand corners
local R_LEFT = 76 -- left-hand corners: the long slide
local R_S = 56 -- the S-bend
local S_ANGLE = math.acos(0.8) -- S-bend goes in 22 and back out (2 * R_S * (1 - 0.8))
local SIDE = 156 - 4 * R_S * math.sin(S_ANGLE) -- straight left over on the right side

type Step = { straight: number?, turn: number?, radius: number? }
local STEPS: { Step } = {
	{ straight = 84 },
	{ turn = -90, radius = R_RIGHT },
	{ straight = SIDE / 2 },
	{ turn = -math.deg(S_ANGLE), radius = R_S },
	{ turn = 2 * math.deg(S_ANGLE), radius = R_S },
	{ turn = -math.deg(S_ANGLE), radius = R_S },
	{ straight = SIDE / 2 },
	{ turn = -90, radius = R_RIGHT },
	{ straight = 84 },
	{ turn = -90, radius = R_LEFT },
	{ straight = 116 },
	{ turn = -90, radius = R_LEFT },
}
local SPACING = 12

-- Points along the steps, about SPACING apart (the last one, back at the start, is left off).
local function turtle(): { Kit.Pt }
	local pts: { Kit.Pt } = {}
	local x, z, h = START.x, START.z, 0
	for _, step in STEPS do
		local straight, turnDeg, radius = step.straight, step.turn, step.radius
		if straight then
			local n = math.max(1, math.round(straight / SPACING))
			local d = straight / n
			for _ = 1, n do
				pts[#pts + 1] = { x = x, z = z }
				x += math.cos(h) * d
				z += math.sin(h) * d
			end
		elseif turnDeg and radius then
			local turn = math.rad(turnDeg)
			local n = math.max(1, math.round(math.abs(turn) * radius / SPACING))
			local side = if turn < 0 then -1 else 1
			-- centre of the turn sits to that side of the heading
			local cx = x - math.sin(h) * radius * side
			local cz = z + math.cos(h) * radius * side
			for _ = 1, n do
				pts[#pts + 1] = { x = x, z = z }
				h += turn / n
				x = cx + math.sin(h) * radius * side
				z = cz - math.cos(h) * radius * side
			end
		end
	end
	return pts
end
local POINTS = turtle()

local Plot = {}
Plot.id = "drift"
Plot.label = "DRIFT"
Plot.mode = "free"
Plot.grip = 0.45
Plot.ROAD = ROAD
Plot.POINTS = POINTS
-- The round drift pad in the middle, and the cone you circle around.
Plot.PAD = { x = -12, z = -34, r = 46 }
Plot.CONE = { r = 3, h = 8 }

function Plot.loop()
	return Kit.loop(POINTS, 2)
end

local start = Plot.loop()[1]
Plot.start = start
Plot.spawn = Kit.spawnAt(start, 14)
Plot.gates = {}

function Plot.build(parent: Instance, origin: CFrame)
	Kit.ribbon(parent, origin, Plot.loop(), ROAD, { grip = Plot.grip })

	-- Start line across the road (painted, no bump).
	Kit.line(parent, origin, start.x, TOP, start.z, start.tx, start.tz, ROAD, C.white)

	-- Drift pad: flush with the road, same grip, a painted white ring, and the cone.
	local pad = Plot.PAD
	local disc = Kit.disc(parent, "DriftPad", origin, pad.x, TOP / 2, pad.z, pad.r, TOP, C.road)
	disc:SetAttribute("Grip", Plot.grip)
	local bits = 40
	local seg = 2 * math.pi * pad.r / bits + 1
	for i = 1, bits do
		local a = (i - 0.5) / bits * 2 * math.pi
		local x, z = pad.x + math.cos(a) * pad.r, pad.z + math.sin(a) * pad.r
		-- Kit.line runs its length across (dx, dz), so face it outward to lay it along the ring.
		Kit.line(parent, origin, x, TOP, z, math.cos(a), math.sin(a), seg, C.white)
	end
	local cone = Plot.CONE
	Kit.disc(parent, "Cone", origin, pad.x, cone.h / 2, pad.z, cone.r, cone.h, C.orange)
end

return Plot
