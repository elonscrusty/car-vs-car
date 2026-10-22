--!strict
-- ROCK plot. Starter: the old rock climb test course moved onto the plot. To be redone to match
-- the plot picture: a slow winding crawl to a flag, with rocks, log steps and steep climbs.

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

export type Rock = { x: number, y: number, z: number, r: number }

local HALF = 35 -- half the course width

local Plot = {}
Plot.id = "rock"
Plot.label = "ROCKS"
Plot.mode = "oneway"
Plot.grip = 1
Plot.HALF_WIDTH = HALF

-- Ground height along the course: { z, y } from the start (z high) up to the top.
Plot.profile = {
	{ z = 110, y = 0 },
	{ z = 70, y = 0 },
	{ z = 20, y = 14 },
	{ z = -10, y = 14 },
	{ z = -50, y = 38 },
	{ z = -90, y = 38 },
	{ z = -130, y = 60 },
	{ z = -180, y = 60 },
}

-- Ground height on the course at this z.
function Plot.height(z: number): number
	local p = Plot.profile
	if z >= p[1].z then
		return p[1].y
	end
	for i = 2, #p do
		if z >= p[i].z then
			local a, b = p[i - 1], p[i]
			local t = (a.z - z) / (a.z - b.z)
			return a.y + (b.y - a.y) * t
		end
	end
	return p[#p].y
end

-- Slope (rise over run, positive uphill going forward) at this z.
function Plot.slope(z: number): number
	return (Plot.height(z - 1) - Plot.height(z + 1)) / 2
end

-- Rocks, the same every time (tiny seeded random).
function Plot.rocks(): { Rock }
	local seed = 12345
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local out: { Rock } = {}
	local half = HALF - 4
	local tries = 0
	while #out < 70 and tries < 4000 do
		tries += 1
		local z = 60 - rand() * 185
		local x = (rand() * 2 - 1) * half
		local steep = math.abs(Plot.slope(z)) > 0.4
		local r = 1.2 + rand() * (if steep then 1.0 else 2.2)
		if rand() < 0.1 and not steep then
			r = 4 + rand() * 1.5
		end
		local ok = true
		for _, o in out do
			local dx, dz = o.x - x, o.z - z
			local gap = o.r + r + 4.5
			if dx * dx + dz * dz < gap * gap then
				ok = false
				break
			end
		end
		if ok then
			out[#out + 1] = { x = x, y = Plot.height(z) - r * 0.35, z = z, r = r }
		end
	end
	return out
end

Plot.spawn = { x = 0, y = 2.5, z = 100, dx = 0, dz = -1 }
Plot.gates = {
	{ x = 0, y = 0, z = 88, dx = 0, dz = -1, halfWidth = HALF, depth = 4 },
	{ x = 0, y = 60, z = -155, dx = 0, dz = -1, halfWidth = HALF, depth = 25 },
}

function Plot.build(parent: Instance, origin: CFrame)
	local prof = Plot.profile
	for i = 2, #prof do
		local a = Vector3.new(0, prof[i - 1].y, prof[i - 1].z)
		local b = Vector3.new(0, prof[i].y, prof[i].z)
		local dir = (b - a).Unit
		local right = Vector3.xAxis
		local back = -dir
		local up = back:Cross(right)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		Kit.part(
			parent,
			"Hill",
			origin,
			Vector3.new(HALF * 2, 2, len),
			CFrame.fromMatrix(mid - up, right, up, back),
			C.ground
		)
		for _, side in { -1, 1 } do
			Kit.part(
				parent,
				"Wall",
				origin,
				Vector3.new(2, 16, len),
				CFrame.fromMatrix(mid + right * (HALF + 1) * side + up * 7, right, up, back),
				C.wall
			)
		end
	end
	-- walls across the back (behind the summit) and the front (behind the start)
	Kit.part(
		parent,
		"Wall",
		origin,
		Vector3.new(HALF * 2 + 4, 20, 2),
		CFrame.new(0, 76, -182),
		C.wall
	)
	Kit.part(
		parent,
		"Wall",
		origin,
		Vector3.new(HALF * 2 + 4, 14, 2),
		CFrame.new(0, 6, 112),
		C.wall
	)
	for _, r in Plot.rocks() do
		Kit.rock(parent, origin, r.x, r.y, r.z, r.r)
	end
	-- summit flag and pad
	local top = prof[#prof].y
	Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(0, top + 7, -165),
		C.white
	).CanCollide =
		false
	Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(7, 4, 0.3),
		CFrame.new(3.8, top + 12, -165),
		C.orange
	).CanCollide =
		false
	Kit.line(parent, origin, 0, top, -148, 0, -1, HALF * 2, C.white)
	Kit.line(parent, origin, 0, 0, 88, 0, -1, HALF * 2, C.white)
end

return Plot
