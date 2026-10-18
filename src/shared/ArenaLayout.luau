--!strict
-- Where the scenery around the bowl goes (pure numbers, no Roblox types). Positions are studs
-- from the arena centre: x right, z toward the camera side. Same config = same layout.
-- yawDeg is the turn for CFrame.Angles(0, rad(yawDeg), 0); a spot at angle a is (r sin a, -r cos a)
-- and yaw -a makes the part's local Z point along the radius (local X is then along the road).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local ArenaLookConfig = sibling("ArenaLookConfig")

export type Spot = {
	x: number,
	z: number,
	yawDeg: number,
	scale: number, -- size factor (radius for hills, 1 for most props)
	n: number, -- count or variant (tires in the stack, tree blocks)
	y: number, -- extra height above the ground (clouds only)
}
type Circle = { x: number, z: number, r: number }

local ArenaLayout = {}

ArenaLayout.look = ArenaLookConfig

-- Tiny seeded random numbers (no math.random: it is not repeatable).
type Rng = { state: number }

local function newRng(seed: number): Rng
	return { state = (seed * 7919 + 12345) % 2147483646 + 1 }
end

local function nextFloat(rng: Rng): number
	rng.state = (rng.state * 16807) % 2147483647
	return rng.state / 2147483647
end

local function between(rng: Rng, a: number, b: number): number
	return a + (b - a) * nextFloat(rng)
end

local function polar(angleDeg: number, r: number): (number, number)
	local a = math.rad(angleDeg)
	return r * math.sin(a), -r * math.cos(a)
end

local function spot(x: number, z: number, yawDeg: number, scale: number, n: number): Spot
	return { x = x, z = z, yawDeg = yawDeg, scale = scale, n = n, y = 0 }
end

local function clear(x: number, z: number, r: number, gap: number, avoid: { Circle }): boolean
	for _, c in avoid do
		local dx, dz = x - c.x, z - c.z
		local need = c.r + r + gap
		if dx * dx + dz * dz < need * need then
			return false
		end
	end
	return true
end

-- Random spots in a ring band, skipping any that touch `avoid`. Gives up on a spot after 80
-- tries, so the list can be shorter than `count` if the band is too crowded.
local function scatter(
	rng: Rng,
	count: number,
	minR: number,
	maxR: number,
	r: number,
	gap: number,
	avoid: { Circle }
): { Spot }
	local out: { Spot } = {}
	for _ = 1, count do
		for _ = 1, 80 do
			local rad = math.sqrt(between(rng, minR * minR, maxR * maxR))
			local ang = between(rng, 0, 360)
			local x, z = polar(ang, rad)
			if clear(x, z, r, gap, avoid) then
				local s = spot(x, z, between(rng, 0, 360), 1, 1)
				table.insert(out, s)
				table.insert(avoid, { x = x, z = z, r = r })
				break
			end
		end
	end
	return out
end

local function ring(count: number, startDeg: number, r: number): { Spot }
	local out: { Spot } = {}
	for i = 0, count - 1 do
		local ang = startDeg + i * 360 / count
		local x, z = polar(ang, r)
		table.insert(out, spot(x, z, -ang, 1, 1))
	end
	return out
end

local function circles(spots: { Spot }, r: number): { Circle }
	local out: { Circle } = {}
	for _, s in spots do
		table.insert(out, { x = s.x, z = s.z, r = r })
	end
	return out
end

local function append(into: { Circle }, from: { Circle })
	for _, c in from do
		table.insert(into, c)
	end
end

function ArenaLayout.hazardPadRadius(): number
	local p = ArenaLookConfig.hazardPads
	return math.sqrt(p.sizeX ^ 2 + p.sizeZ ^ 2) / 2
end

ArenaLayout.towerRadius = 3
ArenaLayout.barrierRadius = 4.5
ArenaLayout.coneRadius = 1

-- Evenly spaced on the ring road, long side along the radius.
function ArenaLayout.hazardPadSpots(): { Spot }
	local p = ArenaLookConfig.hazardPads
	return ring(p.count, p.startDeg, p.radius)
end

-- Floodlight towers; yaw turns the lamp face toward the bowl (local +Z).
function ArenaLayout.towerSpots(): { Spot }
	local t = ArenaLookConfig.towers
	return ring(t.count, t.startDeg, t.radius)
end

-- Red/white barriers on the outer edge of the road, long side along the road.
function ArenaLayout.barrierSpots(): { Spot }
	local b = ArenaLookConfig.barriers
	return ring(b.count, b.startDeg, b.radius)
end

function ArenaLayout.tireStacks(): { Spot }
	local t = ArenaLookConfig.tires
	local rng = newRng(ArenaLookConfig.seed + 11)
	local avoid = circles(ArenaLayout.hazardPadSpots(), ArenaLayout.hazardPadRadius())
	append(avoid, circles(ArenaLayout.barrierSpots(), ArenaLayout.barrierRadius))
	local out = scatter(rng, t.count, t.minR, t.maxR, t.radius, t.gap, avoid)
	for _, s in out do
		s.n = 2 + math.floor(nextFloat(rng) * 2) -- 2 or 3 tires high
	end
	return out
end

function ArenaLayout.coneSpots(): { Spot }
	local c = ArenaLookConfig.cones
	local rng = newRng(ArenaLookConfig.seed + 23)
	local avoid = circles(ArenaLayout.hazardPadSpots(), ArenaLayout.hazardPadRadius())
	append(avoid, circles(ArenaLayout.barrierSpots(), ArenaLayout.barrierRadius))
	append(avoid, circles(ArenaLayout.tireStacks(), ArenaLookConfig.tires.radius))
	return scatter(rng, c.count, c.minR, c.maxR, ArenaLayout.coneRadius, c.gap, avoid)
end

-- Big flat green balls near the horizon; scale = their radius.
function ArenaLayout.hillSpots(): { Spot }
	local h = ArenaLookConfig.hills
	local rng = newRng(ArenaLookConfig.seed + 37)
	local out: { Spot } = {}
	local avoid: { Circle } = {}
	for _ = 1, h.count do
		for _ = 1, 80 do
			local scale = between(rng, h.minScale, h.maxScale)
			local rad = between(rng, h.minR, math.min(h.maxR, ArenaLookConfig.maxRadius - scale))
			local x, z = polar(between(rng, 0, 360), rad)
			if clear(x, z, scale, -scale * 0.3, avoid) then -- a little overlap is fine
				table.insert(out, spot(x, z, between(rng, 0, 360), scale, 1))
				table.insert(avoid, { x = x, z = z, r = scale })
				break
			end
		end
	end
	return out
end

local function towerAndHillCircles(): { Circle }
	local avoid = circles(ArenaLayout.towerSpots(), ArenaLayout.towerRadius)
	for _, h in ArenaLayout.hillSpots() do
		table.insert(avoid, { x = h.x, z = h.z, r = h.scale })
	end
	return avoid
end

-- Low-poly trees: n = 1 or 2 stacked green blocks, scale 0.8 to 1.3. Not on hills or towers.
function ArenaLayout.treeSpots(): { Spot }
	local t = ArenaLookConfig.trees
	local rng = newRng(ArenaLookConfig.seed + 41)
	local out = scatter(rng, t.count, t.minR, t.maxR, 3, t.gap - 3, towerAndHillCircles())
	for _, s in out do
		s.n = 1 + math.floor(nextFloat(rng) * 2)
		s.scale = between(rng, 0.8, 1.3)
	end
	return out
end

-- Grey rocks; scale = size in studs. Not on towers or trees.
function ArenaLayout.rockSpots(): { Spot }
	local k = ArenaLookConfig.rocks
	local rng = newRng(ArenaLookConfig.seed + 53)
	local avoid = circles(ArenaLayout.towerSpots(), ArenaLayout.towerRadius)
	append(avoid, circles(ArenaLayout.treeSpots(), 3))
	local out = scatter(rng, k.count, k.minR, k.maxR, k.maxScale, 1, avoid)
	for _, s in out do
		s.scale = between(rng, k.minScale, k.maxScale)
	end
	return out
end

-- White cloud puffs high up and far out; y is the height above the ground.
function ArenaLayout.cloudSpots(): { Spot }
	local c = ArenaLookConfig.clouds
	local rng = newRng(ArenaLookConfig.seed + 67)
	local out = scatter(rng, c.count, c.minR, c.maxR, 20, 10, {})
	for _, s in out do
		s.y = between(rng, c.minY, c.maxY)
		s.scale = between(rng, 0.8, 1.4)
	end
	return out
end

return ArenaLayout
