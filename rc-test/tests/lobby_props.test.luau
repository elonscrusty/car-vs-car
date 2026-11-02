--!strict
-- Lobby models (LobbyProps.luau): two floodlight towers and the scrap claw. Light for phones,
-- inside the lobby's box, on the floor, nothing solid on the walks, and the lamp banks face the
-- spawn.
local H = require("./harness")
local Garage = require("../src/shared/Garage")
local LobbyProps = require("../src/shared/LobbyProps")
local SpawnLobby = require("../src/shared/SpawnLobby")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby models")

local function pieces(): { Garage.Piece }
	local out: { Garage.Piece } = {}
	LobbyProps.parts(Garage.adder(out))
	return out
end
local all = pieces()

-- the piece's box, turned like CFrame.Angles(rx, ry, rz) (= Rx * Ry * Rz): the half sizes along
-- X, Y and Z of the box round the turned piece
local function half(p: Garage.Piece): (number, number, number)
	local rx, ry, rz = math.rad(p.rot.x), math.rad(p.rot.y), math.rad(p.rot.z)
	local cx, sx, cy, sy, cz, sz =
		math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	-- Rx * Ry * Rz, row by row
	local m = {
		{ cy * cz, -cy * sz, sy },
		{ sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy },
		{ -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy },
	}
	local s = { p.size.x / 2, p.size.y / 2, p.size.z / 2 }
	local out = { 0, 0, 0 }
	for r = 1, 3 do
		for c = 1, 3 do
			out[r] += math.abs(m[r][c]) * s[c]
		end
	end
	return out[1], out[2], out[3]
end

test("both models are there: two towers and one claw, each in its own group", function()
	local groups: { [string]: number } = {}
	for _, p in all do
		groups[p.group] = (groups[p.group] or 0) + 1
	end
	eq(#LobbyProps.TOWERS, 2)
	truthy(groups.FloodTower1 ~= nil and groups.FloodTower2 ~= nil and groups.ScrapClaw ~= nil)
	eq(groups.FloodTower1, groups.FloodTower2, "the towers match")
end)

test("light for phones: under 200 parts in all, 2 lights at most", function()
	truthy(#all <= 200, `{#all} parts`)
	local lights = 0
	for _, p in all do
		if p.light then
			lights += 1
		end
	end
	truthy(lights >= 1 and lights <= 2, `{lights} lights`)
end)

test("every piece is inside the lobby's box, on or over the floor", function()
	local B = SpawnLobby.BOX
	for _, p in all do
		local hx, hy, hz = half(p)
		local where = `{p.group}/{p.name}`
		truthy(p.pos.y - hy >= -0.05, `{where} sinks into the floor`)
		truthy(p.pos.y + hy <= B.maxY, `{where} tops {p.pos.y + hy}, box {B.maxY}`)
		truthy(p.pos.x - hx >= B.minX and p.pos.x + hx <= B.maxX, `{where} out of the box in X`)
		truthy(p.pos.z - hz >= B.minZ and p.pos.z + hz <= B.maxZ, `{where} out of the box in Z`)
	end
end)

test("nothing solid on the spawn, the portal or the walk out of any door", function()
	local spawn = SpawnLobby.SPAWN
	local function nearPath(
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		hx: number,
		hz: number,
		p: Garage.Piece
	): boolean
		-- the walk's line, 2 studs each side, against the piece's flat box
		local minX, maxX = math.min(x0, x1) - 2 - hx, math.max(x0, x1) + 2 + hx
		local minZ, maxZ = math.min(z0, z1) - 2 - hz, math.max(z0, z1) + 2 + hz
		return p.pos.x > minX and p.pos.x < maxX and p.pos.z > minZ and p.pos.z < maxZ
	end
	for _, p in all do
		if p.collide then
			local hx, _, hz = half(p)
			local where = `{p.group}/{p.name}`
			truthy(
				math.abs(p.pos.x - spawn.x) > 4 + hx or math.abs(p.pos.z - spawn.z) > 4 + hz,
				`{where} stands on the spawn`
			)
			truthy(
				math.sqrt(p.pos.x ^ 2 + (p.pos.z - SpawnLobby.PAD_Z) ^ 2) > 12 + math.max(hx, hz),
				`{where} stands on the portal`
			)
			for door = 1, #SpawnLobby.DOORS do
				local path = SpawnLobby.exitPath(door)
				for i = 1, #path - 1 do
					truthy(
						not nearPath(
							path[i][1],
							path[i][2],
							path[i + 1][1],
							path[i + 1][2],
							hx,
							hz,
							p
						),
						`{where} blocks the walk from door {door}`
					)
				end
			end
		end
	end
end)

test(
	"the lamp banks face the spawn: the lenses sit nearer the spawn than the bank's back",
	function()
		for i = 1, #LobbyProps.TOWERS do
			local lens, back
			for _, p in all do
				if p.group == "FloodTower" .. i then
					if p.name == "Lens" then
						lens = p
					elseif p.name == "Back" then
						back = p
					end
				end
			end
			truthy(lens ~= nil and back ~= nil, "a bank has a back and lenses")
			-- the spawn is toward -Z of the towers (they stand at z = 19, the spawn at z = -6)
			truthy(
				(lens :: Garage.Piece).pos.z < (back :: Garage.Piece).pos.z,
				`bank {i} faces away from the spawn`
			)
			-- and it leans down: its rot.x sign gives the tilt toward the front
			truthy((lens :: Garage.Piece).pos.y > 12, "the bank is up high")
		end
	end
)

test("the lobby builds them in, in Smash", function()
	local n = 0
	for _, p in SpawnLobby.allParts() do
		if p.group == "ScrapClaw" or string.sub(p.group, 1, 10) == "FloodTower" then
			n += 1
		end
	end
	truthy(n >= #all, `{n} of {#all} model parts in the lobby`)
end)
