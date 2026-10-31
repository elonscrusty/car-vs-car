--!strict
-- The Garage Hub look (LobbyGarage.luau): the workshop hall round the Smash lobby plaza.
local H = require("./harness")
local Garage = require("../src/shared/Garage")
local LobbyGarage = require("../src/shared/LobbyGarage")
local SpawnLobby = require("../src/shared/SpawnLobby")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby garage")

local W, D = 120, 72
local PADS = { -19, 0, 19 }
local out: { any } = {}
LobbyGarage.parts(Garage.adder(out), W, D, PADS)

local function flat(p: any): (number, number, number, number, number, number)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	if math.abs(p.rot.z) % 180 == 90 then
		sx, sy = sy, sx
	end
	if math.abs(p.rot.y) % 180 == 90 then
		sx, sz = sz, sx
	end
	return p.pos.x - sx / 2,
		p.pos.x + sx / 2,
		p.pos.y - sy / 2,
		p.pos.y + sy / 2,
		p.pos.z - sz / 2,
		p.pos.z + sz / 2
end

test("the hall is about two hundred pieces and has its walls, doors, bench and arrows", function()
	truthy(#out > 150 and #out < 260, "part count " .. #out)
	local groups: { [string]: boolean } = {}
	for _, p in out do
		groups[p.group] = true
	end
	for _, g in { "GarageHall", "GarageDoor", "GarageLamp" } do
		truthy(groups[g], g)
	end
	for _, g in { "GarageRack", "GarageTyres", "GarageDrums", "GarageCrates", "GarageGantry" } do
		truthy(groups[g], g)
	end
	local doors = 0
	for _, p in out do
		if p.group == "GarageDoor" and p.name == "Panel" then
			doors += 1
		end
	end
	eq(doors, #LobbyGarage.DOORS + 2, "four back doors and two front")
end)

test("every piece stands behind or beside the plaza: inside the box, off the walk", function()
	for _, p in out do
		local x0, x1, y0, y1, z0, z1 = flat(p)
		local name = p.group .. "/" .. p.name
		truthy(x0 >= -60.5 and x1 <= 60.5, name .. " x")
		truthy(z0 >= -41 and z1 <= 38, name .. " z")
		truthy(y0 >= -0.5 and y1 <= 21, name .. " y")
		-- nothing solid on the lane from the spawn to the street, nor on a pad
		if p.collide then
			local onLane = x1 > -6 and x0 < 6 and z1 > -8 and z0 < 37
			truthy(not onLane or y0 > 6, name .. " blocks the walk")
		end
	end
end)

test("three pink chevrons lead the way to every match pad", function()
	for i, px in PADS do
		local n = 0
		for _, p in out do
			if p.name == "Chevron" .. i then
				n += 1
				truthy(p.pos.x > px - 2.5 and p.pos.x < px + 2.5, "chevron in front of pad " .. i)
				truthy(p.pos.z < SpawnLobby.PAD_Z - SpawnLobby.PAD_R, "chevron short of the pad")
				truthy(not p.collide, "chevron is flat paint")
			end
		end
		eq(n, 2 * #LobbyGarage.ARROW_Z)
	end
end)
