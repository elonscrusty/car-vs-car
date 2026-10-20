--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, truthy = H.eq, H.truthy
local Vector3 = Mock.V3

print("Lobby ground")

local origin = Vector3.new(0, 3, 500)

local function built()
	local world = Mock.new()
	local Ground = world.require("server/LobbyGround")
	local folder = world.instance("Folder")
	Ground.build(folder, origin)
	return folder
end

local function every(inst, fn)
	for _, d in inst:GetDescendants() do
		fn(d)
	end
end

H.test("ground builds with a sane part count", function()
	local f = built()
	local e = Mock.extent(f)
	truthy(e.parts > 100, "has parts")
	truthy(e.parts < 1800, "part count " .. e.parts)
end)

H.test("ground stays inside the lobby box and under 32 studs", function()
	local f = built()
	local e = Mock.extent(f)
	local visible = f:Clone()
	visible:FindFirstChild("Blockers"):Destroy() -- the invisible walls are 40 tall on purpose
	local ev = Mock.extent(visible)
	truthy(ev.maxY <= origin.Y + 32 + 1e-6, "height " .. ev.maxY)
	truthy(e.minX >= origin.X - 120 and e.maxX <= origin.X + 120, "x range")
	truthy(e.minZ >= origin.Z - 100 and e.maxZ <= origin.Z + 100, "z range")
end)

H.test("blockers are invisible, solid and not queryable", function()
	local f = built()
	local b = f:FindFirstChild("Blockers")
	truthy(b, "Blockers folder")
	local n = 0
	for _, p in b:GetChildren() do
		n += 1
		eq(p.Transparency, 1)
		eq(p.CanCollide, true)
		eq(p.CanQuery, false)
		eq(p.CanTouch, false)
	end
	truthy(n >= 7 + 6 + 3 + 2, "edge, garage, bench, cart and pillar blockers: " .. n)
end)

H.test("the plaza slab is the only big collidable floor", function()
	local f = built()
	local big = 0
	every(f, function(d)
		if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 then
			if d.Size.X >= 60 and d.Size.Z >= 60 then
				big += 1
				eq(d.Name, "PlazaSlab")
				eq(d.Position.Y + d.Size.Y / 2, origin.Y)
			end
		end
	end)
	eq(big, 1)
end)

H.test("everything else visible is look-only", function()
	local f = built()
	local solidVisible = 0
	every(f, function(d)
		if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 then
			solidVisible += 1
			truthy(d.Name:find("^Plaza"), "solid visible part " .. d.Name)
		end
	end)
	truthy(solidVisible >= 1)
end)

H.test("music spot is silent", function()
	local f = built()
	local spot = f:FindFirstChild("MusicSpot")
	truthy(spot, "MusicSpot")
	local s = spot:FindFirstChild("LobbyMusic")
	truthy(s, "LobbyMusic")
	eq(s.SoundId, "")
	eq(s.Looped, true)
	eq(s.Volume, 0.5)
	eq(s.RollOffMaxDistance, 260)
end)

H.test("signs have text", function()
	local f = built()
	local seen = {}
	every(f, function(d)
		if d:IsA("TextLabel") then
			seen[d.Text] = true
		end
	end)
	truthy(seen["PLAY"], "PLAY text")
	-- carter's L55: no big CAR VS CAR sign where the players land
	truthy(seen["CAR VS CAR"] == nil, "no sign over the spawn path")
end)
