--!nocheck
-- The two things the tutorial puts in the lobby, on the fake Roblox: the green glowing line (L1, L18,
-- L53) and the blue portal (L6, L59). Both are built on the new player's screen only.
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local V3 = Mock.V3

print("Tutorial lobby pieces (green line, blue portal)")

local function setup(at: any?)
	local world = Mock.new("./src")
	world.quiet = true
	local player = world.newLocalPlayer("Dana", 7, at)
	local config = world.require("shared/LobbyConfig")
	local tutorial = world.require("shared/TutorialConfig")
	local env: any =
		{ world = world, player = player, origin = config.Lobby.origin, config = tutorial }
	function env.position()
		return player.Character.HumanoidRootPart.Position
	end
	function env.moveTo(x: number, z: number)
		-- studs from the lobby origin; a standing character is 3 studs above the asphalt
		player.Character.HumanoidRootPart.Position =
			V3.new(env.origin.X + x, env.origin.Y + 3, env.origin.Z + z)
	end
	function env.frames(n: number)
		for _ = 1, n do
			world.step(0.05)
		end
	end
	return env
end

local function count(folder: any, name: string): number
	local n = 0
	for _, c in folder:GetChildren() do
		if c.Name == name then
			n += 1
		end
	end
	return n
end

-- ---------- the green line ----------

H.test(
	"the line to the gumball machine starts under the player and ends where the machine is",
	function()
		local e = setup()
		local GuideTrail = e.world.requireClient("GuideTrail")
		e.moveTo(0, 42) -- the spawn
		local trail = GuideTrail.new(e.origin, e.position)
		eq(trail.shown(), nil)
		trail.show("gumball")
		eq(trail.shown(), "gumball")
		e.frames(3)
		local folder = e.world.workspace:FindFirstChild("GuideTrail")
		truthy(folder, "the line is in the world")
		truthy(count(folder, "Strip") >= 1, "a glowing strip")
		truthy(count(folder, "Arrow") >= 2, "arrows flowing along it")
		local beacon = folder:FindFirstChild("Beacon")
		truthy(beacon, "a tall green light where it ends")
		-- the light stands at the green path's end: in front of the gumball machine, in the workshop
		local stop = e.config.gumballStop
		near(beacon.Position.X, e.origin.X + stop.x, 3, "beacon x")
		near(beacon.Position.Z, e.origin.Z + stop.z, 3, "beacon z")
		-- the first strip begins under the character
		local first = folder:FindFirstChild("Cap")
		truthy(first)
		-- everything lies flat on the asphalt
		for _, p in folder:GetChildren() do
			if p.Name == "Strip" or p.Name == "Cap" then
				near(p.Position.Y, e.origin.Y + 0.12, 0.5, p.Name .. " height")
			end
		end
		truthy(
			#folder:GetChildren() < 250,
			"a small number of parts for a phone: " .. #folder:GetChildren()
		)
	end
)

H.test("the line to a PLAY pad ends at the pad nearest to the player", function()
	local e = setup()
	local GuideTrail = e.world.requireClient("GuideTrail")
	local trail = GuideTrail.new(e.origin, e.position)
	e.moveTo(-12, 40)
	trail.show("pad")
	e.frames(3)
	local beacon = e.world.workspace:FindFirstChild("GuideTrail"):FindFirstChild("Beacon")
	truthy(beacon)
	-- the four pads stand at x = +-10.25, z = -4.25 and 16.25; from the left side the left pads are nearest
	truthy(beacon.Position.X < 0, "the left side: " .. beacon.Position.X)
	near(beacon.Position.Z, e.origin.Z + 16.25, 8, "the near row of pads")
	-- the player walks to the other side: the line finds the other way when they have moved
	e.moveTo(14, 40)
	e.frames(40)
	local after = e.world.workspace:FindFirstChild("GuideTrail"):FindFirstChild("Beacon")
	truthy(after.Position.X > 0, "now the right side: " .. after.Position.X)
end)

H.test("hiding takes the line out of the world, and showing again brings it back", function()
	local e = setup()
	local GuideTrail = e.world.requireClient("GuideTrail")
	local trail = GuideTrail.new(e.origin, e.position)
	e.moveTo(0, 42)
	trail.show("gumball")
	e.frames(2)
	truthy(e.world.workspace:FindFirstChild("GuideTrail"))
	trail.hide()
	eq(trail.shown(), nil)
	eq(e.world.workspace:FindFirstChild("GuideTrail"), nil)
	e.frames(3) -- nothing is drawn any more
	eq(e.world.workspace:FindFirstChild("GuideTrail"), nil)
	trail.show("pad")
	e.frames(2)
	truthy(e.world.workspace:FindFirstChild("GuideTrail"):FindFirstChild("Beacon"))
	trail.destroy()
	eq(e.world.workspace:FindFirstChild("GuideTrail"), nil)
end)

H.test("showing the same line twice does not start it over", function()
	local e = setup()
	local GuideTrail = e.world.requireClient("GuideTrail")
	local trail = GuideTrail.new(e.origin, e.position)
	e.moveTo(0, 42)
	trail.show("gumball")
	e.frames(2)
	local folder = e.world.workspace:FindFirstChild("GuideTrail")
	local strips = count(folder, "Strip")
	trail.show("gumball")
	e.frames(1)
	eq(count(folder, "Strip"), strips)
	trail.destroy()
end)

H.test("no character: nothing is drawn and nothing breaks", function()
	local e = setup()
	local GuideTrail = e.world.requireClient("GuideTrail")
	local trail = GuideTrail.new(e.origin, function()
		return nil
	end)
	trail.show("gumball")
	e.frames(3)
	eq(count(e.world.workspace:FindFirstChild("GuideTrail"), "Strip"), 0)
	trail.destroy()
end)

-- ---------- the blue portal ----------

H.test("the portal stands on the front path between the spawn and the pads", function()
	local e = setup()
	local TutorialPortal = e.world.requireClient("TutorialPortal")
	e.moveTo(0, 42)
	local entered = 0
	local portal = TutorialPortal.new(e.origin, e.position, function()
		entered += 1
	end)
	eq(e.world.workspace:FindFirstChild("TutorialPortal"), nil, "not built until it is shown")
	portal.show()
	local folder = e.world.workspace:FindFirstChild("TutorialPortal")
	truthy(folder, "the portal")
	eq(count(folder, "RingBlock"), 20, "a ring of blocks")
	truthy(folder:FindFirstChild("Face"), "the glowing face")
	eq(count(folder, "Swirl"), 4, "the swirl")
	local x = Mock.extent(folder)
	local cfg = e.config.portal
	near((x.minX + x.maxX) / 2, e.origin.X + cfg.x, 0.5, "centred on the path")
	near((x.minZ + x.maxZ) / 2, e.origin.Z + cfg.z, 3.5, "in front of the spawn")
	truthy(x.minZ > e.origin.Z + 20 and x.maxZ < e.origin.Z + 42, "between the pads and the spawn")
	truthy(x.maxY < e.origin.Y + 16, "not taller than 16 studs")
	truthy(x.minY < e.origin.Y + 1, "the pool lies on the asphalt")
	truthy(x.parts < 40)
	eq(entered, 0, "the spawn is outside")
	e.frames(10)
	eq(entered, 0)
end)

H.test("walking into the portal calls onEnter once", function()
	local e = setup()
	local TutorialPortal = e.world.requireClient("TutorialPortal")
	e.moveTo(0, 42)
	local entered = 0
	local portal = TutorialPortal.new(e.origin, e.position, function()
		entered += 1
	end)
	portal.show()
	local cfg = e.config.portal
	-- just outside the doorway
	e.moveTo(cfg.x, cfg.z + cfg.enterRadius + 1)
	e.frames(3)
	eq(entered, 0)
	-- inside it
	e.moveTo(cfg.x, cfg.z)
	e.frames(3)
	eq(entered, 1)
	e.frames(10)
	eq(entered, 1, "only once")
	-- hidden and shown again (a replay): it works again
	portal.hide()
	eq(e.world.workspace:FindFirstChild("TutorialPortal"), nil)
	portal.show()
	e.frames(3)
	eq(entered, 2)
	portal.destroy()
end)

H.test("far above or below the doorway does not count", function()
	local e = setup()
	local TutorialPortal = e.world.requireClient("TutorialPortal")
	local entered = 0
	local portal = TutorialPortal.new(e.origin, e.position, function()
		entered += 1
	end)
	portal.show()
	local cfg = e.config.portal
	e.player.Character.HumanoidRootPart.Position =
		V3.new(e.origin.X + cfg.x, e.origin.Y + 60, e.origin.Z + cfg.z)
	e.frames(3)
	eq(entered, 0)
	portal.destroy()
end)

H.test("showing the portal twice builds it once", function()
	local e = setup()
	local TutorialPortal = e.world.requireClient("TutorialPortal")
	local portal = TutorialPortal.new(e.origin, e.position, function() end)
	portal.show()
	portal.show()
	local n = 0
	for _, c in e.world.workspace:GetChildren() do
		if c.Name == "TutorialPortal" then
			n += 1
		end
	end
	eq(n, 1)
	portal.destroy()
end)

H.test("the portal's doorway is on open ground, in line with the spawn", function()
	-- a bench, a stand or a PLAY pad in the doorway would block the walk in
	local e = setup()
	local GuidePath = e.world.require("shared/GuidePath")
	local cfg = e.config.portal
	truthy(GuidePath.free(cfg.x, cfg.z), "the middle of the doorway is free")
	truthy(GuidePath.free(cfg.x - cfg.enterRadius + 0.5, cfg.z), "left of the middle")
	truthy(GuidePath.free(cfg.x + cfg.enterRadius - 0.5, cfg.z), "right of the middle")
	-- the walk from the spawn is short and straight
	local spawnZ = 42
	local route, found = GuidePath.route(0, spawnZ, cfg.x, cfg.z)
	truthy(found, "a way exists")
	truthy(#route >= 2)
	truthy(
		GuidePath.length(route) < (spawnZ - cfg.z) * 1.25 + 1,
		"no detour: " .. GuidePath.length(route)
	)
end)

-- ---------- the gumball machine the lesson points at ----------

H.test(
	"the machine in the built lobby stands where the lesson says (and its prompt reaches the green line's end)",
	function()
		local e = setup()
		local Lobby = e.world.require("server/Lobby")
		local handle = Lobby.build()
		local body
		for _, d in handle.folder:GetDescendants() do
			if d.Name == "GachaBody" then
				body = d
			end
		end
		truthy(body, "the gumball machine's body")
		local prompt = body:FindFirstChild("GachaPrompt")
		truthy(prompt, "the prompt")
		local at = e.config.gumballMachine
		near(body.Position.X, e.origin.X + at.x, 1.5, "machine x")
		near(body.Position.Z, e.origin.Z + at.z, 1.5, "machine z")
		-- the green line ends in front of the machine, inside the prompt's reach (40 studs)
		local stop = e.config.gumballStop
		local dx, dz =
			body.Position.X - (e.origin.X + stop.x), body.Position.Z - (e.origin.Z + stop.z)
		truthy(
			math.sqrt(dx * dx + dz * dz) < prompt.MaxActivationDistance - 5,
			"the line's end is within the prompt's reach"
		)
		-- and "near" (when the lesson says: tap it) is closer than the prompt's reach
		truthy(e.config.gumballNearStuds < prompt.MaxActivationDistance, "near is inside the reach")
	end
)
