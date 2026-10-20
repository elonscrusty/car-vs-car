--!nocheck
-- The lobby props (carter's picks L21-L40 and the "no" list L27 L32 L35 L37 L38 L55): where they
-- stand, that nothing overlaps or blocks a path, and what the builder makes.
local H = require("./harness")
local Mock = require("./robloxmock")
local Layout = require("../src/shared/LobbyLayout")
local Props = require("../src/shared/LobbyProps")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Lobby props")

local origin = Vector3.new(0, 3, 500)

local function overlapsAny(rect, others)
	for name, r in others do
		if Layout.overlaps(rect, r) then
			return name
		end
	end
	return nil
end

local function core()
	return table.clone(Layout.footprints())
end

H.test(
	"no solid prop overlaps a building, the ring, a board, a parking spot or another prop",
	function()
		local props = Props.footprints()
		local base = core()
		for name, r in props do
			local hit = overlapsAny(r, base)
			truthy(hit == nil, name .. " overlaps " .. tostring(hit))
			for other, o in props do
				if other ~= name then
					truthy(not Layout.overlaps(r, o), name .. " overlaps " .. other)
				end
			end
		end
	end
)

H.test("no solid prop stands on a walking path", function()
	for name, r in Props.footprints() do
		for i, path in Layout.paths do
			truthy(not Layout.overlaps(r, path), name .. " is on path " .. i)
		end
	end
end)

H.test("props stand on the plaza, except the side billboards just outside the tire wall", function()
	for name, r in Props.footprints() do
		if string.find(name, "billboard") == nil then
			truthy(Layout.onPlaza(r.x, r.z), name .. " is off the plaza")
		end
	end
end)

H.test("cones are rainbow: many bright colors, none of them orange", function()
	local colors = Layout.colors.rainbow
	truthy(#colors >= 6)
	for i, c in colors do
		local orange = c[1] > 220 and c[2] > 90 and c[2] < 175 and c[3] < 90
		truthy(not orange, "rainbow color " .. i .. " is orange")
	end
	local used = {}
	local n = 0
	for _, c in Props.cones() do
		truthy(c.color >= 1 and c.color <= #colors)
		if not used[c.color] then
			used[c.color] = true
			n += 1
		end
		truthy(Layout.onPlaza(c.x, c.z))
		-- not inside a building or the PLAY ring
		truthy(
			math.sqrt((c.x - Layout.ring.x) ^ 2 + (c.z - Layout.ring.z) ^ 2) > Layout.ring.radius,
			"cone on the PLAY ring"
		)
		for _, b in { Layout.workshop, Layout.customize, Layout.shop } do
			truthy(
				not Layout.overlaps({ x = c.x, z = c.z, w = 2, d = 2, yawDeg = 0 }, b),
				"cone in a garage"
			)
		end
	end
	truthy(n >= 6, "different cone colors: " .. n)
	truthy(#Props.cones() >= 16)
end)

H.test("benches and tools take their color from the garage nearest to them", function()
	for _, b in Props.benches() do
		eq(b.accent, if b.x < 0 then "orange" else "blue", "bench at " .. b.x)
	end
	eq(Props.accentAt(0, -60), "orange") -- the workshop
	eq(Props.accentAt(-57, -40), "orange") -- the customize garage
	eq(Props.accentAt(56, -40), "blue") -- the shop
	for _, t in Props.toolProps() do
		eq(t.accent, "orange")
	end
end)

H.test("six wooden benches, each facing into the lobby", function()
	local list = Props.benches()
	eq(#list, 6)
	for _, b in list do
		-- yaw 0 faces +x, yaw 180 faces -x: both look toward the middle line
		local faceX = if b.yawDeg == 0 then 1 else -1
		truthy(faceX * (0 - b.x) > 0, "bench at " .. b.x .. " faces the wall")
	end
end)

H.test("tool props stand in front of the customize garage", function()
	local list = Props.toolProps()
	truthy(#list >= 5)
	local kinds = {}
	for _, t in list do
		kinds[t.kind] = true
		local d = math.sqrt((t.x - Layout.customize.x) ^ 2 + (t.z - Layout.customize.z) ^ 2)
		truthy(d < 45, t.kind .. " is far from the garage")
	end
	truthy(kinds.toolbox and kinds.jack and kinds.rack, "toolboxes, car jacks and a wrench rack")
end)

H.test("billboards: four big bright boards with short, true tips", function()
	local list = Props.billboards()
	eq(#list, 4)
	local first = list[1]
	eq(first.line1, "HIT FROM THE SIDE")
	for _, b in list do
		truthy(#b.line1 <= 20 and #b.line2 <= 20, "tip too long: " .. b.line1)
		truthy(Props.billboardColors[b.color] ~= nil, b.color)
		truthy(b.w >= 20 and b.h >= 9, "big")
		truthy(b.bottom >= 8, "above the heads")
		truthy(b.bottom + b.h + 1.4 <= Layout.size.height, "under the 32 stud limit")
		eq(#Props.billboardPosts(b), 2)
	end
end)

H.test(
	"the chain fence goes all round, leaves the three entrances open, and keeps its distance",
	function()
		local bays = Props.fence()
		truthy(#bays > 50, "bays: " .. #bays)
		local p, g = Layout.plaza, Layout.fenceGap
		local gaps = { front = 0, left = 0, right = 0 }
		for _, b in bays do
			local len = math.sqrt((b.bx - b.ax) ^ 2 + (b.bz - b.az) ^ 2)
			truthy(len <= Props.fenceBayLength + 0.01, "bay too long")
			for _, e in { { b.ax, b.az }, { b.bx, b.bz } } do
				local x, z = e[1], e[2]
				-- every post is on the fence line: `g` studs outside the tire wall
				local onLine = math.abs(math.abs(x) - (p.halfX + g)) < 1e-6
					or math.abs(z - (p.frontZ + g)) < 1e-6
					or math.abs(z - (p.backZ - g)) < 1e-6
				truthy(onLine, "post off the line at " .. x .. ", " .. z)
			end
			local mx, mz = (b.ax + b.bx) / 2, (b.az + b.bz) / 2
			-- nothing crosses the spawn path or the side entrance paths
			truthy(
				not (math.abs(mz - (p.frontZ + g)) < 1e-6 and math.abs(mx) < 9),
				"fence across the spawn path"
			)
			truthy(
				not (math.abs(math.abs(mx) - (p.halfX + g)) < 1e-6 and mz > -29 and mz < 5),
				"fence across a side entrance"
			)
		end
		local left, right = 0, 0
		for _, b in bays do
			if b.ax < -(p.halfX + g) + 1e-6 and b.bx < -(p.halfX + g) + 1e-6 then
				left += 1
			elseif b.ax > p.halfX + g - 1e-6 and b.bx > p.halfX + g - 1e-6 then
				right += 1
			end
		end
		eq(left, right)
		eq(gaps.front, 0)
	end
)

H.test("clouds are far above the lobby", function()
	local list = Props.clouds()
	truthy(#list >= 10)
	for _, c in list do
		truthy(c.y >= 60, "cloud too low")
	end
end)

local function built()
	local world = Mock.new()
	world.quiet = true
	local Builder = world.require("server/LobbyProps")
	local folder = world.instance("Folder")
	Builder.build(folder, origin)
	return world, folder
end

local function every(inst, fn)
	for _, d in inst:GetDescendants() do
		fn(d)
	end
end

H.test("the props build with a phone friendly part count", function()
	local _, f = built()
	local n = Mock.extent(f).parts
	truthy(n > 400, "has parts: " .. n)
	truthy(n < 1500, "too many parts: " .. n)
end)

H.test("the whole lobby stays light enough for phones (L52)", function()
	local world = Mock.new()
	world.quiet = true
	local Lobby = world.require("server/Lobby")
	local handle = Lobby.build()
	local n = Mock.extent(handle.folder).parts
	truthy(n < 2300, "lobby parts: " .. n)
end)

H.test("everything visible is look-only; only the invisible blockers collide", function()
	local _, f = built()
	local solid = 0
	every(f, function(d)
		if d:IsA("BasePart") and d.CanCollide then
			solid += 1
			eq(d.Transparency, 1, d.Name .. " collides but can be seen")
			eq(d.CanQuery, false)
			truthy(string.find(d.Name, "Blocker") ~= nil, d.Name)
		end
	end)
	truthy(solid >= 20, "blockers: " .. solid)
end)

H.test(
	"benches cannot be sat on (no seats) and cones are never kickable (no blocker, no collision)",
	function()
		local _, f = built()
		every(f, function(d)
			truthy(
				d.ClassName ~= "Seat" and d.ClassName ~= "VehicleSeat",
				"a seat: " .. d:GetFullName()
			)
			truthy(d.Name ~= "ConeBlocker")
		end)
		local cones = f:FindFirstChild("Cones", true)
		eq(#cones:GetChildren(), #Props.cones())
		every(cones, function(d)
			if d:IsA("BasePart") then
				eq(d.CanCollide, false)
				eq(d.CanTouch, false)
			end
		end)
	end
)

H.test("one bench model, cone model, tire stack, junk pile and billboard per entry", function()
	local _, f = built()
	local function count(name)
		return #f:FindFirstChild(name, true):GetChildren()
	end
	eq(count("Benches"), #Props.benches())
	eq(count("Cones"), #Props.cones())
	eq(count("TireStacks"), #Props.tireStacks())
	eq(count("JunkPiles"), #Props.junkPiles())
	eq(count("Billboards"), #Props.billboards())
	eq(count("ToolProps"), #Props.toolProps())
end)

H.test("billboard tips are on both faces of the board", function()
	local _, f = built()
	local seen = {}
	every(f:FindFirstChild("Billboards", true), function(d)
		if d:IsA("TextLabel") then
			seen[d.Text] = (seen[d.Text] or 0) + 1
			eq(d.Font.Name, "FredokaOne")
		end
	end)
	for _, b in Props.billboards() do
		eq(seen[b.line1], 2, b.line1)
		eq(seen[b.line2], 2, b.line2)
	end
end)

H.test("the lobby has none of the things carter said no to", function()
	local world = Mock.new()
	world.quiet = true
	local Lobby = world.require("server/Lobby")
	local handle = Lobby.build()
	local banned =
		{ "lamp", "flower", "bush", "flag", "banner", "statue", "gasstation", "pump", "pine" }
	-- (the three garages have ceiling lights inside: those are not lobby lamps)
	local garages = { Workshop = true, Customize = true, Shop = true }
	for _, child in handle.folder:GetChildren() do
		if not garages[child.Name] then
			every(child, function(d)
				local name = string.lower(d.Name)
				for _, b in banned do
					truthy(string.find(name, b) == nil, "found " .. d:GetFullName())
				end
			end)
		end
	end
	-- L55: nothing on the arch over the spawn path says CAR VS CAR
	every(handle.folder, function(d)
		if d:IsA("TextLabel") then
			truthy(d.Text ~= "CAR VS CAR", "a CAR VS CAR sign")
		end
	end)
end)

H.test(
	"a second props build into the same folder does not break (each build makes its own groups)",
	function()
		local world, f = built()
		local Builder = world.require("server/LobbyProps")
		Builder.build(f, origin)
		near(#f:GetChildren(), 4, 0) -- Props, Clouds, Props, Clouds
	end
)

H.test("ground paint: skid marks are black, painted lines are bright", function()
	local _, f = built()
	local skids, lines = 0, 0
	every(f, function(d)
		if d.Name == "Skid" then
			skids += 1
			truthy(d.Color.R < 0.2 and d.Color.G < 0.2, "skid mark not black")
		elseif d.Name == "Line" then
			lines += 1
		end
	end)
	truthy(skids >= 10 and lines >= 20, "skids " .. skids .. " lines " .. lines)
end)
