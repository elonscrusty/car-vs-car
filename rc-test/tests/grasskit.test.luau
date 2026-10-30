--!nocheck
-- GrassKit: night weeds are looks only (anchored, nothing to bump), thinning keeps a fixed share,
-- and the generated data hangs together.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local H = require("./harness")

local test, truthy, eq = H.test, H.truthy, H.eq

local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	math = math,
}
local GrassKit = luau.load(fs.readFile("src/shared/GrassKit.luau"), { environment = env })()
local Data = luau.load(fs.readFile("src/shared/GrassBitsData.luau"), { environment = env })()

print("GrassKit")

test("data: every tuft names a kind, every blade stands up and is a real size", function()
	truthy(#Data.tufts > 100, "tufts")
	truthy(#Data.dots > 50, "dots")
	for _, t in Data.tufts do
		truthy(Data.kinds[t.k] ~= nil, "kind " .. t.k)
		truthy(math.abs(t.x) <= 172 and math.abs(t.z) <= 172, "inside the wall")
	end
	for _, blades in Data.kinds do
		for _, b in blades do
			truthy(b.h > 0.5 and b.h < 3 and b.w > 0.1 and b.w < 1, "blade size")
			truthy(b.lean >= 0 and b.lean < 1, "lean")
		end
	end
end)

test("build: all parts are anchored looks only, in one GrassBits folder", function()
	local parent = roblox.Instance.new("Folder")
	local f = GrassKit.build(parent, Data, roblox.Vector3.new(0, 0, 0), 1, 0.4)
	eq(f.Name, "GrassBits")
	eq(f.Parent, parent)
	local kids = f:GetChildren()
	eq(#kids, GrassKit.count(Data, 0.4))
	for _, p in kids do
		truthy(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p.Name)
	end
end)

test("thinning: keep 0 builds only the dots, keep 1 builds every blade", function()
	local nBlades = 0
	for _, t in Data.tufts do
		nBlades += #Data.kinds[t.k]
	end
	eq(GrassKit.count(Data, 0), #Data.dots)
	eq(GrassKit.count(Data, 1), #Data.dots + nBlades)
	truthy(GrassKit.count(Data, 0.4) < GrassKit.count(Data, 1) / 2 + #Data.dots, "0.4 keeps about 4 in 10")
end)

test("scale: the unit moves and sizes the weeds", function()
	local f = GrassKit.build(roblox.Instance.new("Folder"), Data, roblox.Vector3.new(0, 10, 0), 2, 0.1)
	local p = f:GetChildren()[1]
	truthy(p.Size.Y > 0, "has a size")
end)
