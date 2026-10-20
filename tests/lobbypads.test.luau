--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3, CFrame = Mock.V3, Mock.CF

print("Lobby pads")

local ORIGIN = Vector3.new(0, 3, 500)

local function setup()
	local world = Mock.new()
	local Layout = world.require("shared/LobbyLayout")
	local Pads = world.require("server/LobbyPads")
	local folder = world.instance("Folder")
	local pads = Pads.build(folder, ORIGIN)
	local synced: { { [any]: number } } = {}
	local counts = { 0, 0, 0, 0 }
	local battle = {
		padSync = function(observed)
			table.insert(synced, observed)
			return counts
		end,
		padCounts = function()
			return counts
		end,
		cancel = function() end,
		isBusy = function()
			return false
		end,
	}
	local fired = {}
	local remotes = {
		BattleUpdate = {
			FireClient = function(_s, _p, msg)
				table.insert(fired, msg)
			end,
		},
	}
	local handle = Pads.start({ pads = pads, origin = ORIGIN, battle = battle, remotes = remotes })
	local function player(name: string, id: number, at: any)
		local p = world.newPlayer(name, id)
		local char = world.instance("Model")
		local hum = world.instance("Humanoid")
		hum.Health = 100
		hum.Parent = char
		local root = world.instance("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.new(at)
		root.Parent = char
		p.Character = char
		world.players = world.players or {}
		table.insert(world.players, p)
		return p, root
	end
	return world, Layout, pads, handle, battle, synced, fired, player, folder, counts
end

H.test("builds 4 pads under the height limit with a counter each", function()
	local world, _, _, _, _, _, _, _, folder = setup()
	local g = folder:FindFirstChild("Pads")
	eq(#g:GetChildren(), 4)
	for i = 1, 4 do
		local pad = g:FindFirstChild("Pad" .. i)
		eq(pad:GetAttribute("PadIndex"), i)
		eq(pad:FindFirstChild("Count", true).Text, "0/2")
	end
	truthy(Mock.extent(g).maxY < ORIGIN.Y + 12)
end)

H.test("the watcher reports who stands on which pad", function()
	local world, Layout, _, _, _, synced, _, player = setup()
	local p = Layout.pads()[3]
	local a = player("A", 1, Vector3.new(p.x, ORIGIN.Y + 3, 500 + p.z))
	local b = player("B", 2, Vector3.new(0, ORIGIN.Y + 3, 500 + 60))
	world.step(0.3)
	local seen = synced[#synced]
	eq(seen[a], 3)
	eq(seen[b], nil)
end)

H.test("pad counts and glow follow what BattleService says", function()
	local world, _, _, _, _, _, _, _, folder, counts = setup()
	counts[2] = 1
	world.step(0.3)
	eq(folder:FindFirstChild("Pad2", true):FindFirstChild("Count", true).Text, "1/2")
end)

H.test("the rings are tagged so each player's screen spins them", function()
	local world, _, _, _, _, _, _, _, folder = setup()
	local ring = folder:FindFirstChild("Ring", true)
	eq(ring:GetAttribute("SpinMode"), "world")
	truthy((ring:GetAttribute("SpinSpeed") :: number) > 0)
	world.step(1)
end)

H.test("PLAY walks you onto a free pad", function()
	local world, Layout, _, handle, _, _, _, player = setup()
	local a, root = player("A", 1, Vector3.new(0, ORIGIN.Y + 3, 500 + 60))
	handle.play(a)
	local rel = root.Position - ORIGIN
	eq(Layout.padAt(rel.X, rel.Z), 1)
end)

H.test("PLAY with every pad full says so and does not move you", function()
	local world, _, _, handle, _, _, fired, player, _, counts = setup()
	for i = 1, 4 do
		counts[i] = 2
	end
	local a, root = player("A", 1, Vector3.new(0, ORIGIN.Y + 3, 500 + 60))
	handle.play(a)
	eq(root.Position.Z, 560)
	eq(fired[1].kind, "error")
end)

H.test("park hides a fighter under the lobby and return puts them next to the pads", function()
	local world, Layout, _, handle, _, _, _, player = setup()
	local a, root = player("A", 1, Vector3.new(0, ORIGIN.Y + 3, 500 + 60))
	handle.park(a)
	truthy(root.Anchored)
	truthy(root.Position.Y < ORIGIN.Y - 20)
	handle.returnToLobby(a)
	truthy(not root.Anchored)
	local rel = root.Position - ORIGIN
	eq(Layout.padAt(rel.X, rel.Z, 1), nil)
	truthy(Layout.onPlaza(rel.X, rel.Z))
	truthy(
		math.sqrt((rel.X - Layout.ring.x) ^ 2 + (rel.Z - Layout.ring.z) ^ 2) < Layout.ring.radius
	)
end)

H.test("cancel moves you off the pad and the watcher skips you for a while", function()
	local world, Layout, _, handle, _, synced, _, player = setup()
	local p = Layout.pads()[1]
	local a, root = player("A", 1, Vector3.new(p.x, ORIGIN.Y + 3, 500 + p.z))
	handle.cancel(a)
	local rel = root.Position - ORIGIN
	eq(Layout.padAt(rel.X, rel.Z, 1), nil)
	world.step(0.3)
	eq(synced[#synced][a], nil)
end)
