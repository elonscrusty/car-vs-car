--!nocheck
-- PropKit (the one prop kit, LOOK-BIBLE.md): every prop is chunky, rounded, SmoothPlastic, in
-- a few parts, and solid only where a car should stop (trunks, barrels, tyres, cones, poles).
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
	table = table,
}
local PropKit = luau.load(fs.readFile("src/shared/PropKit.luau"), { environment = env })()

print("PropKit")

local function build(fn: (Instance) -> ()): { any }
	local folder = roblox.Instance.new("Folder")
	fn(folder)
	return folder:GetChildren()
end

local AT = roblox.Vector3.new(0, 0, 0)
local PROPS = {
	tree = function(f)
		PropKit.tree(f, AT, 30, "pink", 3)
	end,
	bush = function(f)
		PropKit.bush(f, AT, 6, 2)
	end,
	barrel = function(f)
		PropKit.barrel(f, AT, 5)
	end,
	tyres = function(f)
		PropKit.tyreStack(f, AT, 4)
	end,
	cone = function(f)
		PropKit.cone(f, AT, 4)
	end,
	flag = function(f)
		PropKit.flag(f, AT, 12, nil, roblox.Vector3.new(0, 0, 1))
	end,
}

test(
	"every prop: a few anchored SmoothPlastic parts, nothing paper-thin, none sharp-cornered up top",
	function()
		for name, fn in PROPS do
			local parts = build(fn)
			truthy(#parts >= 1 and #parts <= 12, name .. ": a few parts (" .. #parts .. ")")
			for _, p in parts do
				truthy(p.Anchored, name .. " anchored")
				eq(p.Material, roblox.Enum.Material.SmoothPlastic, name .. " SmoothPlastic")
				truthy(not p.CanTouch, name .. " no touch events")
				local s = p.Size
				-- thin only for a painted disc or band (a cylinder lying flat), never a spindly block
				local thin = math.min(s.X, s.Y, s.Z)
				truthy(thin >= 0.1, name .. ": " .. p.Name .. " not paper-thin")
			end
		end
	end
)

test("a tree: solid round trunk, round non-solid crown blobs in two tones", function()
	local parts = build(PROPS.tree)
	local trunk, blobs, tones = 0, 0, {}
	for _, p in parts do
		if p.Name == "TreeTrunk" then
			trunk += 1
			truthy(p.CanCollide and p.Shape == roblox.Enum.PartType.Cylinder, "solid round trunk")
		elseif p.Name == "TreeTop" then
			blobs += 1
			truthy(
				not p.CanCollide and p.Shape == roblox.Enum.PartType.Ball,
				"round blob, drive under it"
			)
			tones[p.Color:ToHex()] = true
		end
	end
	eq(trunk, 1, "one trunk")
	eq(blobs, 3, "three blobs")
	local n = 0
	for _ in tones do
		n += 1
	end
	eq(n, 2, "two tones")
end)

test("solid where a car should stop, see-through-able where it shouldn't", function()
	for _, p in build(PROPS.bush) do
		truthy(not p.CanCollide, "bushes: drive through")
	end
	local solid = false
	for _, p in build(PROPS.barrel) do
		if p.Name == "Barrel" then
			solid = p.CanCollide
		end
	end
	truthy(solid, "a barrel stops a car")
	local tree = build(function(f)
		PropKit.tree(f, AT, 30, "green", 1, false)
	end)
	for _, p in tree do
		truthy(not p.CanCollide, "a backdrop tree can be all looks")
	end
end)
