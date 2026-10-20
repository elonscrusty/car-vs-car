--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local LobbyLayout = require("../src/shared/LobbyLayout")
local eq, truthy = H.eq, H.truthy
local Vector3 = Mock.V3

print("Lobby wall signs")

local origin = Vector3.new(0, 3, 500)

-- Which wall a sign is on and where it runs along it: axis "z" = front (runs along x), "x" = sides.
local function wallOf(s)
	local p = LobbyLayout.plaza
	if math.abs(s.z - p.frontZ) < 1e-6 then
		return "z", p.frontZ, s.x
	end
	if math.abs(math.abs(s.x) - p.halfX) < 1e-6 then
		return "x", s.x, s.z
	end
	return nil, 0, 0
end

H.test("three wall signs with the right words", function()
	eq(#LobbyLayout.wallSigns, 3)
	local seen = {}
	for _, s in LobbyLayout.wallSigns do
		seen[s.text] = true
	end
	truthy(seen["PLAY HERE"] and seen["GUMBALL"] and seen["SHOP"], "PLAY HERE, GUMBALL, SHOP")
end)

H.test("every wall sign is on the plaza edge, off the rounded corners", function()
	local p = LobbyLayout.plaza
	for _, s in LobbyLayout.wallSigns do
		local axis, _, along = wallOf(s)
		truthy(axis ~= nil, s.text .. " is not on the tire wall line")
		if axis == "z" then
			truthy(math.abs(along) + s.w / 2 <= p.halfX - p.corner, s.text .. " runs into a corner")
		else
			truthy(along + s.w / 2 <= p.frontZ - p.corner, s.text .. " runs into a front corner")
			truthy(along - s.w / 2 >= p.backZ + p.corner, s.text .. " runs into a back corner")
		end
	end
end)

H.test("no wall sign covers an entrance gap or the arch pillars", function()
	for _, s in LobbyLayout.wallSigns do
		local axis, pos, along = wallOf(s)
		for _, e in LobbyLayout.entrances do
			if e.axis == axis and e.pos == pos then
				local clear = along + s.w / 2 + 1 <= e.from or along - s.w / 2 - 1 >= e.to
				truthy(clear, s.text .. " covers an entrance")
			end
		end
		local rect = { x = s.x, z = s.z, w = s.w + 2, d = 2, yawDeg = s.yawDeg }
		local f = LobbyLayout.footprints()
		truthy(not LobbyLayout.overlaps(rect, f.archLeft), s.text .. " hits the arch")
		truthy(not LobbyLayout.overlaps(rect, f.archRight), s.text .. " hits the arch")
	end
end)

H.test("wall signs look at the ring and stand above the tires", function()
	local r = LobbyLayout.ring
	for _, s in LobbyLayout.wallSigns do
		local a = math.rad(s.yawDeg)
		local dot = math.sin(a) * (r.x - s.x) + math.cos(a) * (r.z - s.z)
		truthy(dot > 0, s.text .. " faces away from the ring")
		truthy(LobbyLayout.wallSignBottom >= 3.6, "bottom above the tires and lights")
		truthy(LobbyLayout.wallSignBottom + s.h <= LobbyLayout.size.height, s.text .. " too tall")
	end
end)

local function built()
	local world = Mock.new()
	local Signs = world.require("server/LobbyWallSigns")
	local folder = world.instance("Folder")
	Signs.build(folder, origin)
	return folder
end

H.test("the build makes 3 sign boards with their words, all look-only", function()
	local f = built()
	local boards, texts = 0, {}
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			eq(d.CanCollide, false)
			eq(d.Reflectance, 0)
			if d.Name == "WallSignBoard" then
				boards += 1
				for _, l in d:GetDescendants() do
					if l:IsA("TextLabel") then
						eq(l.Font.Name, "FredokaOne")
						texts[l.Text] = true
					end
				end
			end
		end
	end
	eq(boards, 3)
	for _, s in LobbyLayout.wallSigns do
		truthy(texts[s.text], s.text .. " text")
	end
	local e = Mock.extent(f)
	truthy(e.minX >= origin.X - 112 and e.maxX <= origin.X + 112, "x range")
	truthy(e.maxZ <= origin.Z + 90, "z range")
	truthy(e.maxY <= origin.Y + 32, "height")
	truthy(e.minY >= origin.Y - 1e-6, "not under the plaza")
end)
