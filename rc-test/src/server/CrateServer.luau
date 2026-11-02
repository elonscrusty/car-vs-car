--!strict
-- The breakable crates in the Smash arena (rules: shared/BreakCrates). The server alone decides:
-- 10 times a second it looks where every live kart is and breaks a crate that is touched; weapon fx
-- (bullets, rockets, mines) break the ones they hit. A broken crate is taken out of the world and
-- every client is told to play the burst (client/CrateFx); it comes back RESPAWN seconds later.
-- Crates are never solid and never hurt anyone. No remote lets a client break anything.
--
-- Use (MatchRunner, when the arena is built):
--   local crates = CrateServer.start({
--       spots = { Vector3 },  -- world floor spots (BreakCrates.SPOTS through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive } end,
--   })
--   crates.reset()                 -- each round's start: every crate up
--   crates.weaponFx(kind, data)    -- WeaponServer's fx (GunShot, RocketBoom, MineBoom)
--   crates.hitAt(pos, reach)       -- anything else that goes off at pos
--   crates.stop()                  -- arena gone: crates removed
-- Each crate is a Model in workspace.<name> (default "BreakCrates") with the attribute Up.
-- Remote CrateFx: server -> all "Burst" { position, seed }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BreakCrates = require(ReplicatedStorage.Shared.BreakCrates)
local GemKit = require(ReplicatedStorage.Shared.GemKit)

local CrateServer = {}

CrateServer.TAG = "BreakCrate"
CrateServer.REMOTE = "CrateFx"
CrateServer.TICK = 0.1

local WOOD = Color3.fromRGB(176, 120, 70)

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	parent: Instance?,
	name: string?,
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	hitAt: (position: Vector3, reach: number) -> number,
	weaponFx: (kind: string, data: any) -> number,
	stop: () -> (),
	folder: Folder,
}

local started: { [string]: Handle } = {}

local function remote(): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(CrateServer.REMOTE)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local made = Instance.new("RemoteEvent")
	made.Name = CrateServer.REMOTE
	made.Parent = ReplicatedStorage
	return made
end

-- A position as the built-in `vector` (in Roblox that IS Vector3; Lune's pretend Vector3 is another
-- type with only X Y Z), so the shared rules use one kind. Anything else: nil.
local function plain(x: any): vector?
	if type(x) == "vector" then
		return x
	elseif typeof(x) == "Vector3" then
		return vector.create(x.X, x.Y, x.Z)
	end
	return nil
end

-- The studs per data unit that make a crate BreakCrates.SIZE big units tall at this scale.
function CrateServer.factor(sc: number): number
	return BreakCrates.SIZE * sc / GemKit.height("crateWhole")
end

-- One crate with its foot at `spot`: the faceted mesh crate, or (if this server can't make a mesh)
-- a plain wooden box so the arena never has a hole.
local function build(i: number, spot: Vector3, parent: Instance, sc: number): Model
	local yaw = (i * 1.7) % (math.pi / 2) - math.pi / 4 -- a little different each, not a grid
	local m = GemKit.build(
		parent,
		"crateWhole",
		spot,
		GemKit.height("crateWhole") * CrateServer.factor(sc),
		yaw,
		false
	)
	if m == nil then
		m = Instance.new("Model")
		local box = Instance.new("Part")
		box.Name = "Box"
		box.Size = Vector3.one * BreakCrates.SIZE * sc
		box.CFrame = CFrame.new(spot + Vector3.new(0, BreakCrates.SIZE * sc / 2, 0))
			* CFrame.Angles(0, yaw, 0)
		box.Color = WOOD
		box.Material = Enum.Material.Wood
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch = true, false, false, false
		box.Parent = m
		m.PrimaryPart = box
		m.Parent = parent
	end
	local model = m :: Model
	model.Name = "Crate" .. i
	model:SetAttribute("Up", true)
	model:AddTag(CrateServer.TAG)
	return model
end

function CrateServer.start(opts: Options): Handle
	local name = opts.name or "BreakCrates"
	local old = started[name]
	if old then
		old.stop()
	end
	local sc = opts.scale or BreakCrates.SCALE
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = opts.parent or workspace
	local fx = remote()

	local crates: { BreakCrates.Crate } = {}
	local models: { Model } = {}
	for i, spot in opts.spots do
		table.insert(crates, BreakCrates.newCrate(plain(spot) :: vector))
		table.insert(models, build(i, spot, folder, sc))
	end

	-- show or hide each model to match its rules state; `broke` indices also play the burst
	local function sync(broke: { number }?)
		for _, i in broke or {} do
			local p = opts.spots[i]
			fx:FireAllClients("Burst", { position = p, seed = i * 7 + math.floor(os.clock()) % 97 })
		end
		for i, c in crates do
			local m = models[i]
			if m:GetAttribute("Up") ~= c.up then
				m:SetAttribute("Up", c.up)
				m.Parent = if c.up then folder else nil
			end
		end
	end

	local clock = 0
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		acc += dt
		if acc < CrateServer.TICK then
			return
		end
		acc = 0
		local karts = {}
		for _, c in opts.karts() do
			local p = plain(c.position)
			if p then
				table.insert(karts, { id = c.id, position = p, alive = c.alive })
			end
		end
		sync(BreakCrates.step(crates, karts, clock, sc))
	end)

	local handle: Handle
	handle = {
		reset = function()
			for _, c in crates do
				BreakCrates.reset(c)
			end
			sync(nil)
		end,
		hitAt = function(position: Vector3, reach: number): number
			local at = plain(position)
			local broke = if at then BreakCrates.hitAt(crates, at, reach, clock, sc) else {}
			if #broke > 0 then
				sync(broke)
			end
			return #broke
		end,
		weaponFx = function(kind: string, data: any): number
			if type(data) ~= "table" then
				return 0
			end
			local d = {
				from = plain(data.from),
				to = plain(data.to),
				pos = plain(data.pos),
				position = plain(data.position),
				quiet = data.quiet,
			}
			local broke = BreakCrates.fromFx(crates, kind, d, clock, sc)
			if #broke > 0 then
				sync(broke)
			end
			return #broke
		end,
		stop = function()
			conn:Disconnect()
			folder:Destroy()
			if started[name] == handle then
				started[name] = nil
			end
		end,
		folder = folder,
	}
	started[name] = handle
	return handle
end

return CrateServer
