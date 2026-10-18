--!strict
-- Pure rules for the small car soccer field (no Roblox calls): wall layout, goal boxes, goal
-- detection, start spots, out-of-bounds and ball-stuck checks. Numbers: SoccerFieldConfig.
-- All positions are flat (x, z) relative to the field middle. Team 1 defends the -X goal.
-- The server (SoccerArena, GroupMatch) only builds parts and reads these answers. Unit tested.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("SoccerFieldConfig")

local SoccerField = {}

export type Spot = { x: number, z: number, yaw: number } -- yaw: the way the car faces (radians)
export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
-- A wall slab standing on the floor: centre, length along its own direction, yaw (radians).
export type Wall = { x: number, z: number, length: number, yaw: number }

function SoccerField.halfLength(): number
	return Config.length / 2
end

function SoccerField.halfWidth(): number
	return Config.width / 2
end

-- Sign of the side a team defends: team 1 = -1 (the -X end), team 2 = +1.
local function side(team: number): number
	return if team == 1 then -1 else 1
end

-- The goal the given team DEFENDS: a box from the goal line back into the net, mouth wide.
-- A ball whose middle is inside this box has crossed the line = that team conceded.
function SoccerField.goalBox(team: number): Box
	local s = side(team)
	local line = Config.length / 2
	local lo, hi = line, line + Config.goalDepth
	return {
		minX = if s < 0 then -hi else lo,
		maxX = if s < 0 then -lo else hi,
		minZ = -Config.goalWidth / 2,
		maxZ = Config.goalWidth / 2,
	}
end

function SoccerField.inBox(b: Box, x: number, z: number): boolean
	return x >= b.minX and x <= b.maxX and z >= b.minZ and z <= b.maxZ
end

-- Where the ball is: the team that CONCEDED (1 or 2), or 0 for no goal.
function SoccerField.goalConceded(x: number, z: number): number
	for team = 1, 2 do
		if SoccerField.inBox(SoccerField.goalBox(team), x, z) then
			return team
		end
	end
	return 0
end

-- Middle of the goal mouth a team ATTACKS (the other team's goal), on the goal line.
function SoccerField.attackPoint(team: number): (number, number)
	return -side(team) * Config.length / 2, 0
end

-- Start spots: each team in a row across its own half, nose toward the middle (and the ball).
function SoccerField.spawnSpots(teamSize: number): { Spot }
	local out: { Spot } = {}
	for team = 1, 2 do
		local s = side(team)
		for k = 1, teamSize do
			local z = (k - (teamSize + 1) / 2) * Config.spawnSpreadZ
			-- A car faces -Z at yaw 0; facing direction (dx, dz) needs yaw = atan2(-dx, -dz).
			table.insert(out, { x = s * Config.spawnX, z = z, yaw = math.atan2(s, 0) })
		end
	end
	return out
end

-- The ball starts in the middle.
function SoccerField.ballSpawn(): (number, number)
	return 0, 0
end

-- Where a bot should drive: a point behind the ball, on the far side from the goal it attacks.
function SoccerField.botTarget(
	ballX: number,
	ballZ: number,
	team: number,
	offset: number
): (number, number)
	local gx, gz = SoccerField.attackPoint(team)
	local dx, dz = gx - ballX, gz - ballZ
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-6 then
		return ballX, ballZ
	end
	return ballX - dx / d * offset, ballZ - dz / d * offset
end

-- Inside the playable area: the field, the two goal pockets, plus `margin` studs of slack.
function SoccerField.inBounds(x: number, z: number, margin: number): boolean
	local hx = Config.length / 2 + Config.goalDepth + margin
	local hz = Config.width / 2 + margin
	return math.abs(x) <= hx and math.abs(z) <= hz
end

-- Ball (or car) must be put back: outside the margin, under the floor or above the lid.
function SoccerField.outOfBounds(x: number, y: number, z: number): boolean
	if y < -Config.lostMargin then
		return true
	end
	if Config.ceilingHeight > 0 and y > Config.ceilingHeight then
		return true
	end
	return not SoccerField.inBounds(x, z, Config.lostMargin)
end

-- Ball-stuck timer: returns the new idle time and whether the ball must be reset.
function SoccerField.stuckStep(idle: number, speed: number, dt: number): (number, boolean)
	if speed >= Config.stuckSpeed then
		return 0, false
	end
	idle += dt
	return idle, idle >= Config.stuckSeconds
end

-- Cap a ball velocity: returns the (possibly shortened) vector parts.
function SoccerField.capVelocity(
	vx: number,
	vy: number,
	vz: number,
	maxSpeed: number
): (number, number, number)
	local m = math.sqrt(vx * vx + vy * vy + vz * vz)
	if m <= maxSpeed or m < 1e-9 then
		return vx, vy, vz
	end
	local k = maxSpeed / m
	return vx * k, vy * k, vz * k
end

-- The walls round the field as slabs. Long sides are straight, the four corners are cut at 45
-- degrees, and each short end is two pieces with the goal mouth left open between them.
-- Slab centres sit ON the field edge line (the build adds half the thickness outward).
function SoccerField.walls(): { Wall }
	local hx, hz = Config.length / 2, Config.width / 2
	local c = Config.cornerCut
	local gz = Config.goalWidth / 2
	local out: { Wall } = {}
	local function add(x: number, z: number, length: number, yaw: number)
		table.insert(out, { x = x, z = z, length = length, yaw = yaw })
	end
	-- Long sides (run along X), between the cut corners.
	add(0, -hz, Config.length - 2 * c, 0)
	add(0, hz, Config.length - 2 * c, 0)
	-- Short ends (run along Z), from the corner cut to the goal mouth.
	local endLen = hz - c - gz
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(sx * hx, sz * (gz + endLen / 2), endLen, math.pi / 2)
		end
	end
	-- Corner cuts, diagonal.
	local diag = math.sqrt(2) * c
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			-- The cut joins (sx*(hx-c), sz*hz) to (sx*hx, sz*(hz-c)).
			add(
				sx * (hx - c / 2),
				sz * (hz - c / 2),
				diag,
				if sx * sz > 0 then math.pi / 4 else -math.pi / 4
			)
		end
	end
	return out
end

-- End points of a wall slab: x1, z1, x2, z2 (a slab turned by yaw runs along (cos, -sin)).
function SoccerField.wallEnds(w: Wall): (number, number, number, number)
	local dx, dz = math.cos(w.yaw) * w.length / 2, -math.sin(w.yaw) * w.length / 2
	return w.x - dx, w.z - dz, w.x + dx, w.z + dz
end

return SoccerField
