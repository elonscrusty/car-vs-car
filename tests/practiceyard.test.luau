--!nocheck
-- The practice yard builder (carter's L13, L56, L57): flat, small, a junkyard, three kinds of solid
-- things only, boxes that never collide, and a part budget a phone can carry.
local H = require("./harness")
local Mock = require("./robloxmock")
local Layout = require("../src/shared/PracticeLayout")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Practice yard builder")

local world = Mock.new("./src")
world.quiet = true
local Yard = world.require("shared/PracticeYard")
local origin = Vector3.new(Layout.origin.x, Layout.origin.y, Layout.origin.z)
local yard = Yard.build(world.workspace, origin)

local function partsOf(inst)
	local list = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

H.test("the yard fits a phone: well under 500 parts", function()
	local n = #partsOf(yard.root)
	truthy(n > 150, "the junkyard has some detail: " .. n)
	truthy(n <= 480, "too many parts for a phone: " .. n)
end)

H.test("the floor is flat and its top is the origin height", function()
	local floor = yard.root.Ground.Floor
	near(floor.Position.Y + floor.Size.Y / 2, origin.Y, 1e-6)
	eq(floor.CanCollide, true)
	near(floor.Size.X, Layout.half.x * 2 + Layout.wall.thickness * 2)
	near(floor.Size.Z, Layout.half.z * 2 + Layout.wall.thickness * 2)
	-- the slab below it is a hair lower so the two never flicker, and reaches far past the walls
	local slab = yard.root.Ground.Slab
	truthy(slab.Position.Y + slab.Size.Y / 2 < origin.Y)
	truthy(slab.Position.Y + slab.Size.Y / 2 > origin.Y - 0.5)
	truthy(slab.Size.X >= Layout.half.x * 2 * 5)
end)

H.test("there are no ramps: no wedge, nothing turned on its side", function()
	for _, p in partsOf(yard.root) do
		truthy(p.ClassName ~= "WedgePart", p.Name .. " is a wedge")
		if p.CanCollide then
			-- the up direction of every solid part is up
			near(p.CFrame.UpVector.Y, 1, 1e-6, p.Name .. " is tilted")
		end
	end
end)

H.test("only the floor, the slab, four walls and three blocks collide", function()
	local solid = {}
	for _, p in partsOf(yard.root) do
		if p.CanCollide then
			solid[p.Name] = (solid[p.Name] or 0) + 1
		end
	end
	eq(solid.Slab, 1)
	eq(solid.Floor, 1)
	eq((solid.WallZ or 0) + (solid.WallX or 0), 4)
	eq(solid.Barrier, #Layout.barriers)
	local total = 0
	for _, n in solid do
		total += n
	end
	eq(total, 2 + 4 + #Layout.barriers, "something else collides")
end)

H.test("walls and blocks are Bouncy, and nothing else is", function()
	local bouncy = 0
	for _, p in partsOf(yard.root) do
		if p:HasTag("Bouncy") then
			bouncy += 1
			truthy(p.Name == "WallZ" or p.Name == "WallX" or p.Name == "Barrier", p.Name)
			truthy(p.CanCollide)
			truthy(p.CanQuery)
		end
	end
	eq(bouncy, 4 + #Layout.barriers)
end)

H.test("the walls stand on the edge of the play floor and are low", function()
	local lo, hi = math.huge, -math.huge
	for _, w in yard.root.Walls:GetChildren() do
		if w.Name == "WallZ" or w.Name == "WallX" then
			near(w.Size.Y, Layout.wall.height)
			near(w.Position.Y - w.Size.Y / 2, origin.Y, 1e-6)
			if w.Name == "WallX" then
				near(
					math.abs(w.Position.X - origin.X),
					Layout.half.x + Layout.wall.thickness / 2,
					1e-6
				)
			else
				near(
					math.abs(w.Position.Z - origin.Z),
					Layout.half.z + Layout.wall.thickness / 2,
					1e-6
				)
			end
			lo, hi = math.min(lo, w.Position.Y), math.max(hi, w.Position.Y)
		end
	end
	near(lo, hi)
end)

H.test("the boxes stand where the layout says and never collide", function()
	eq(#yard.crates, #Layout.crates)
	for i, c in yard.crates do
		eq(c.index, i)
		near(c.x, Layout.crates[i].x)
		near(c.z, Layout.crates[i].z)
		truthy(c.model.PrimaryPart ~= nil)
		eq(c.model.PrimaryPart.Name, "Body")
		local pos = c.model.PrimaryPart.Position
		near(pos.X, origin.X + c.x, 1e-6)
		near(pos.Z, origin.Z + c.z, 1e-6)
		near(pos.Y, origin.Y + Layout.crateSize / 2, 1e-6)
		for _, p in partsOf(c.model) do
			eq(p.CanCollide, false)
			eq(p.CanQuery, false)
			eq(p.Anchored, true)
		end
	end
end)

H.test("a smashed box flies apart without colliding", function()
	local c = yard.crates[1]
	Yard.burst(c, Vector3.new(0, 0, -40))
	for _, p in partsOf(c.model) do
		eq(p.Anchored, false)
		eq(p.CanCollide, false)
		eq(p.CanTouch, false)
		truthy(p.AssemblyLinearVelocity.Y > 10, "the pieces fly up")
	end
end)

H.test("the car starts on the floor at the layout's spot, nose toward the boxes", function()
	local cf = yard.spawn()
	near(cf.Position.X, origin.X + Layout.spawn.x, 1e-6)
	near(cf.Position.Y, origin.Y, 1e-6)
	near(cf.Position.Z, origin.Z + Layout.spawn.z, 1e-6)
	near(cf.LookVector.Z, -1, 1e-6)
	near(cf.LookVector.X, 0, 1e-6)
	local p = yard.toWorld(5, -7)
	near(p.X, origin.X + 5)
	near(p.Z, origin.Z - 7)
	near(p.Y, origin.Y)
end)

H.test("everything stands on the ground slab", function()
	local e = Mock.extent(yard.root.Scrapyard)
	local slabHalf = Layout.ground.half
	truthy(e.minX > origin.X - slabHalf and e.maxX < origin.X + slabHalf)
	truthy(e.minZ > origin.Z - slabHalf and e.maxZ < origin.Z + slabHalf)
	truthy(e.minY >= origin.Y - 0.2, "nothing sinks into the ground")
	truthy(e.maxY < origin.Y + 14, "nothing towers over the camera's view")
end)

H.test("the yard is named, tagged for the client, and goes away when destroyed", function()
	eq(yard.root.Name, "PracticeYard")
	eq(yard.root:GetAttribute("PracticeYard"), true)
	eq(yard.root.Parent, world.workspace)
	yard.destroy()
	eq(yard.root.Parent, nil)
end)
