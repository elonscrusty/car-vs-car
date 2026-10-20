--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Bowl build (the whole map on the mock)")

local ORIGIN = Vector3.new(6000, 40, 0)

local function build()
	local world = Mock.new()
	world.quiet = true
	local Layout = world.require("shared/BowlLayout")
	local BowlMap = world.require("server/BowlMap")
	local folder = world.instance("Folder")
	folder.Name = "BattleArena_0"
	local solids = {}
	local controls = BowlMap.build(folder, ORIGIN, solids)
	folder.Parent = world.workspace
	return world, Layout, folder, solids, controls
end

local function count(folder, pred)
	local n = 0
	for _, d in folder:GetDescendants() do
		if pred(d) then
			n += 1
		end
	end
	return n
end

local function isPart(d)
	return d:IsA("BasePart")
end

H.test("the whole map builds and the part count is a big cut from Wreck City's 1472", function()
	local _, _, folder = build()
	local parts = count(folder, isPart)
	print("       bowl parts: " .. parts)
	truthy(parts > 300, "something is missing: " .. parts)
	truthy(parts <= 720, "too many parts for a phone: " .. parts)
	eq(folder:GetAttribute("PartCount"), parts)
	-- the bits a slow phone can lose
	local far = count(folder.FarScenery, isPart)
		+ count(folder.Detail, isPart)
		+ count(folder.Berm, isPart)
	print("       cuttable on a slow phone: " .. far)
	truthy(far >= 150)
end)

H.test("the sloped edge is 32 wedges that the bounce sweep can tell apart", function()
	local _, Layout, folder, solids = build()
	local list = folder.Slope:GetChildren()
	eq(#list, Layout.facetCount)
	for _, w in list do
		eq(w.ClassName, "WedgePart")
		truthy(w:HasTag("BowlSlope"), w.Name)
		truthy(not w:HasTag("Bouncy"), "a slope is not a wall")
		truthy(table.find(solids, w) ~= nil, "slope in solids")
	end
end)

H.test("a bouncy wall closes the bowl at the top of the slope", function()
	local _, Layout, folder, solids = build()
	local wallParts = folder.Wall:GetChildren()
	eq(#wallParts, Layout.wallCount)
	for _, w in wallParts do
		truthy(w:HasTag("Bouncy"), w.Name)
		truthy(table.find(solids, w) ~= nil)
		near(w.CustomPhysicalProperties[3], Layout.wallBounce)
		-- invisible: the tire stacks against it are what a player sees (Studio showed a visible
		-- wall hiding every tire)
		eq(w.Transparency, 1)
		truthy(not w.CastShadow, "an invisible wall casts no shadow")
		-- from the floor to the top of the tire stacks
		near(w.Size.Y, Layout.slopeRise + Layout.wallAboveRim, 0.01)
		-- the inner face is on the wall radius
		local rel = w.Position - ORIGIN
		local r = math.sqrt(rel.X ^ 2 + rel.Z ^ 2)
		near(r - w.Size.Z / 2, Layout.wallRadius, 0.01)
	end
end)

H.test("two tires and a hub on every stack, all round the wall", function()
	local _, Layout, folder = build()
	local n = #Layout.tires()
	eq(#folder.Tires:GetChildren(), n * 2)
	eq(#folder.Detail:GetChildren(), n)
end)

H.test(
	"a look-only dirt yard under the tire stacks and the far props, level with the slope top",
	function()
		local _, Layout, folder = build()
		local list = folder.Berm:GetChildren()
		eq(#list, Layout.wallCount)
		local base = Layout.slopeRise - 0.2 -- where the tires start
		for _, b in list do
			truthy(not b.CanCollide and not b.CanQuery and not b.CanTouch, "a berm is look only")
			local rel = b.Position - ORIGIN
			near(rel.Y + b.Size.Y / 2, base, 0.01)
			local r = math.sqrt(rel.X ^ 2 + rel.Z ^ 2)
			-- from the wall's inner face out to the yard's edge
			near(r - b.Size.Z / 2, Layout.wallRadius, 0.01)
			near(r + b.Size.Z / 2, Layout.yardRadius, 0.01)
		end
	end
)

H.test("everything near stays inside the tire wall, and low enough for the camera", function()
	local _, Layout, folder = build()
	local limit = Layout.wallRadius + Layout.tire.diameter + 1
	for _, child in folder:GetChildren() do
		if child.Name ~= "FarScenery" and child.Name ~= "Ground" and child.Name ~= "Berm" then
			local e = Mock.extent(child)
			if e.parts > 0 then
				truthy(
					e.minX >= ORIGIN.X - limit and e.maxX <= ORIGIN.X + limit,
					child.Name .. " x " .. e.minX .. " " .. e.maxX
				)
				truthy(
					e.minZ >= ORIGIN.Z - limit and e.maxZ <= ORIGIN.Z + limit,
					child.Name .. " z " .. e.minZ .. " " .. e.maxZ
				)
				truthy(e.maxY <= ORIGIN.Y + 36, child.Name .. " too tall: " .. e.maxY)
			end
		end
	end
end)

H.test("two start pads on the lane, facing each other", function()
	local _, Layout, folder = build()
	local a, b = folder:FindFirstChild("SpawnA"), folder:FindFirstChild("SpawnB")
	truthy(a and b)
	local ra, rb = a.Position - ORIGIN, b.Position - ORIGIN
	near(ra.X, -Layout.spawnX, 0.01)
	near(rb.X, Layout.spawnX, 0.01)
	near(ra.Z, Layout.laneZ, 0.01)
	near(rb.Z, Layout.laneZ, 0.01)
	truthy(a.CFrame.LookVector.X > 0.99, "A faces east")
	truthy(b.CFrame.LookVector.X < -0.99, "B faces west")
end)

H.test("the same 71 breakables as Wreck City, eight of them red barrels that explode", function()
	local _, _, folder = build()
	local list = folder.Breakables:GetChildren()
	eq(#list, 71)
	local booms = 0
	for _, m in list do
		truthy(m:GetAttribute("Breakable") == true, m.Name)
		truthy(m.PrimaryPart ~= nil, m.Name .. " has a Body")
		truthy(m.PrimaryPart.CanQuery and m.PrimaryPart.CanTouch and not m.PrimaryPart.CanCollide)
		if m:GetAttribute("Explosive") then
			booms += 1
			eq(m.Name, "BoomBarrel")
		end
	end
	eq(booms, 8)
end)

H.test("the crusher stands in the middle with a solid, bouncy base", function()
	local _, Layout, folder, solids = build()
	local c = folder.Crusher
	truthy(c:HasTag("BowlCrusher"))
	eq(c:GetAttribute("RoundStart"), -1)
	local base = c.Base
	truthy(base:HasTag("Bouncy"))
	truthy(table.find(solids, base) ~= nil)
	near(base.Position.X, ORIGIN.X, 0.01)
	near(base.Position.Z, ORIGIN.Z, 0.01)
	near(base.Size.Y, Layout.crusher.baseRadius * 2, 0.01)
	for _, name in { "Head", "HeadTrim", "LampA", "LampB", "Warn", "Wave", "Beacon", "Column" } do
		truthy(c:FindFirstChild(name) ~= nil, name)
	end
	-- only the base blocks a car; the press is a look
	for _, p in c:GetChildren() do
		if p:IsA("BasePart") and p ~= base then
			truthy(not p.CanCollide, p.Name .. " must not collide")
		end
	end
end)

H.test("GO starts the crusher's clock and the end of a round stops it", function()
	local world, _, folder, _, controls = build()
	world.workspace.GetServerTimeNow = function()
		return 123.5
	end
	controls.openDoors()
	eq(folder.Crusher:GetAttribute("RoundStart"), 123.5)
	controls.closeDoors()
	eq(folder.Crusher:GetAttribute("RoundStart"), -1)
end)

-- a fake car body: the map only reads where it is and how it moves
local function body(x, z, vx, vz, y)
	return {
		Position = Vector3.new(ORIGIN.X + x, ORIGIN.Y + (y or 3), ORIGIN.Z + z),
		AssemblyLinearVelocity = Vector3.new(vx or 0, 0, vz or 0),
	}
end

H.test("the crusher slam hurts a car near it once, and misses one far away or too early", function()
	local world, Layout, _, _, controls = build()
	local Cr = Layout.crusher
	local now = 1000
	world.workspace.GetServerTimeNow = function()
		return now
	end
	world.workspace.GetPartsInPart = function()
		return {}
	end
	controls.openDoors()
	local near20, far60 = body(20, 0), body(60, 0)
	-- before the warning: nothing
	now = 1000 + 2
	eq(#controls.tick(0.03, { a = near20, b = far60 }), 0)
	-- during the warning: still nothing (a warning is not a hit)
	now = 1000 + Cr.first - 0.5
	eq(#controls.tick(0.03, { a = near20, b = far60 }), 0)
	-- the ring is out but has not reached 20 yet
	now = 1000 + Cr.first + Cr.drop + 0.01
	eq(#controls.tick(0.03, { a = near20, b = far60 }), 0)
	-- the ring reaches the near car
	now = 1000 + Cr.first + Cr.drop + Cr.wave * 0.9
	local hits = controls.tick(0.03, { a = near20, b = far60 })
	eq(#hits, 1)
	eq(hits[1].side, "a")
	near(hits[1].damageFrac, Cr.damageFrac)
	near(hits[1].knockSpeed, Cr.knockSpeed)
	near(hits[1].stagger, Cr.stagger)
	truthy(hits[1].dir.X > 0.99, "pushed away from the middle")
	eq(hits[1].text, "Crusher slam!")
	-- the same slam never hits the same car twice
	now += 0.05
	eq(#controls.tick(0.03, { a = near20, b = far60 }), 0)
	-- the next slam does
	now = 1000 + Cr.first + Cr.period + Cr.drop + Cr.wave * 0.95
	local again = controls.tick(0.03, { a = near20, b = far60 })
	eq(#again, 1)
	-- a car high in the air over the ring is missed
	now = 1000 + Cr.first + 2 * Cr.period + Cr.drop + Cr.wave * 0.95
	eq(#controls.tick(0.03, { a = body(20, 0, 0, 0, 40), b = far60 }), 0)
	-- and a resting crusher (round over) hits nothing
	controls.closeDoors()
	now = 1000 + Cr.first + 3 * Cr.period + Cr.drop + Cr.wave * 0.95
	eq(#controls.tick(0.03, { a = near20, b = far60 }), 0)
end)

H.test(
	"a red barrel blasts the cars near it: small damage, a big push; plain barrels do not",
	function()
		local world, Layout, folder, _, controls = build()
		local boom, plain
		for _, m in folder.Breakables:GetChildren() do
			if m:GetAttribute("Explosive") and boom == nil then
				boom = m
			elseif m.Name == "Barrel" and plain == nil then
				plain = m
			end
		end
		local at = boom.PrimaryPart.Position - ORIGIN
		local driver = body(at.X + 6, at.Z, 30, 0) -- right beside the barrel
		local bystander = body(at.X - 14, at.Z, 0, 0) -- within the blast
		local far = body(at.X + 60, at.Z + 60, 0, 0) -- out of it
		local touching = boom.PrimaryPart
		world.workspace.GetPartsInPart = function(_self, who)
			if who == driver then
				return { touching }
			end
			return {}
		end
		local hits = controls.tick(0.03, { a = driver, b = bystander })
		eq(#hits, 2)
		for _, h in hits do
			near(h.damageFrac, Layout.boom.damageFrac)
			near(h.knockSpeed, Layout.boom.knockSpeed)
			eq(h.text, "Barrel boom!")
			truthy(h.damageFrac <= 0.1 and h.knockSpeed >= 40, "small damage, big push")
		end
		-- the barrel broke, and a fireball and a ring were made
		truthy(not boom.PrimaryPart.Anchored)
		truthy(folder.Booms:FindFirstChild("BoomBall") ~= nil)
		-- the blast does not reach a far car
		touching = plain.PrimaryPart
		local plainHits = controls.tick(0.03, { a = driver, b = far })
		eq(#plainHits, 0)
		-- and the props come back for the next round
		controls.resetBreakables()
		eq(#folder.Breakables:GetChildren() >= 71, true)
		eq(#folder.Booms:GetChildren(), 0)
	end
)

H.test("a stuck car is put back on the nearest rescue spot, facing along the circle", function()
	local _, _, _, _, controls = build()
	local pos, face = controls.rescuePoint(Vector3.new(ORIGIN.X + 110, ORIGIN.Y, ORIGIN.Z + 4))
	local rel = pos - ORIGIN
	near(math.sqrt(rel.X ^ 2 + rel.Z ^ 2), 68, 0.01)
	truthy(rel.X > 60, "the spot on the east side")
	near(face.X * rel.X + face.Z * rel.Z, 0, 0.01)
end)

H.test("verify() leaves a good build alone", function()
	local world, _, folder, _, controls = build()
	world.workspace.Raycast = function()
		return nil
	end
	local before = folder.Slope:GetChildren()[1].CFrame
	controls.verify()
	truthy(folder.Slope:GetChildren()[1].CFrame == before)
end)
