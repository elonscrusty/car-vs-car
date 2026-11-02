--!strict
-- The health wrenches in a smash match (rules: shared/Wrenches). The server alone decides a
-- pickup: 10 times a second it looks where every live kart is and gives a touched wrench to the
-- first hurt kart on it. No remote: a client can't ask for a heal.
--
-- Use (MatchRunner, when the arena is built):
--   local w = WrenchServer.start({
--       spots = { Vector3 },  -- world floor spots (Wrenches.SPOTS through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive, hurt: boolean } end,
--       heal = MatchRunner.heal, -- (kartId, share 0..1) -> boolean; false = nothing to mend
--   })
--   w.reset() -- each round's start: every wrench up
--   w.stop()  -- arena gone: wrenches removed
-- Each wrench is a Model tagged "Wrench" in workspace.<name> (default "Wrenches") with attributes
-- Up (bool), TakenBy (kart id as a string) and TakenCount (goes up by one on every pickup: listen
-- to this one for sounds and screens). client/WrenchFx spins it and plays the heal.
-- Look: carter's pick "A Big Wrench" (preview car-vs-car/wrench-preview): one chrome wrench with
-- an orange grip, tipped over, on a green pad with a green ring and a soft light beam.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Wrenches = require(ReplicatedStorage.Shared.Wrenches)

local WrenchServer = {}

WrenchServer.TAG = "Wrench"
WrenchServer.CHECK_HZ = 10

local CHROME = Color3.fromRGB(223, 230, 245)
local DARK = Color3.fromRGB(42, 48, 66)
local GRIP = Color3.fromRGB(232, 83, 12)
local PAD = Color3.fromRGB(31, 42, 42)
local GREEN = Color3.fromRGB(60, 255, 122)
local LEN = 4.2 -- big, the wrench's length
local TIP = math.rad(35)

export type KartInfo = { id: any, position: Vector3, alive: boolean, hurt: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	heal: (kartId: any, share: number) -> boolean,
	parent: Instance?,
	name: string?,
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	stop: () -> (),
	folder: Folder,
}

local started: { [string]: Handle } = {}

-- A position as the built-in `vector` (in Roblox that IS Vector3; Lune's pretend Vector3 is another
-- type with only X Y Z), so the shared rules use one kind.
local function plain(x: any): vector?
	if type(x) == "vector" then
		return x
	elseif typeof(x) == "Vector3" then
		return vector.create(x.X, x.Y, x.Z)
	end
	return nil
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	neon: boolean?,
	see: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = see or 0
	p:SetAttribute("Look", p.Transparency) -- show() puts this back when the wrench returns
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- `p` rides along when `root` moves (client/WrenchFx moves only the Body)
local function weld(p: BasePart, root: BasePart)
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- One wrench (big units x sc): Body (the root, an invisible little cube) with the chrome handle,
-- the open head (back bar + two jaws), the ring end with a dark hole and the orange grip welded
-- to it; the pad, the ring and the beam stay on the floor.
local function build(i: number, spot: Vector3, parent: Instance, sc: number): Model
	local m = Instance.new("Model")
	m.Name = "Wrench" .. i
	local home = CFrame.new(spot + Vector3.new(0, Wrenches.LIFT * sc, 0))
	local at = home * CFrame.Angles(0, 0, TIP) -- every piece below sits in the tipped frame

	local body = part(m, "Body", Vector3.one * 0.3 * sc, home, CHROME, false, 1)
	local function piece(
		name: string,
		size: Vector3,
		off: CFrame,
		color: Color3,
		neon: boolean?
	): Part
		local p = part(m, name, size * sc, at * off, color, neon)
		weld(p, body)
		return p
	end
	local top = LEN / 2
	piece("Handle", Vector3.new(0.7, LEN - 1.6, 0.8), CFrame.new(0, 0, 0), CHROME)
	piece("Grip", Vector3.new(0.76, 1.3, 0.86), CFrame.new(0, -0.5, 0), GRIP)
	-- the open head: a back bar and two jaws with a gap between
	piece("HeadBack", Vector3.new(2.3, 0.7, 0.9), CFrame.new(0, top - 1.1, 0), CHROME)
	for _, s in { -1, 1 } do
		piece("Jaw", Vector3.new(0.75, 1.3, 0.9), CFrame.new(s * 0.78, top - 0.35, 0), CHROME)
	end
	-- the ring end: a short round plate with a dark hole through it
	local ringEnd = piece("Eye", Vector3.new(0.8, 1.9, 1.9), CFrame.new(0, -top + 0.5, 0), CHROME)
	ringEnd.Shape = Enum.PartType.Cylinder
	piece("EyeHole", Vector3.new(0.86, 0.8, 0.8), CFrame.new(0, -top + 0.5, 0), DARK).Shape =
		Enum.PartType.Cylinder

	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Brightness = 2.5
	light.Range = 12 * sc
	light.Shadows = false
	light.Parent = body

	-- the pad, the ring and the beam stay on the floor
	local pad = part(
		m,
		"Pad",
		Vector3.new(0.4 * sc, 6.2 * sc, 6.2 * sc),
		CFrame.new(spot + Vector3.new(0, 0.2 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		PAD
	)
	pad.Shape = Enum.PartType.Cylinder
	part(
		m,
		"Ring",
		Vector3.new(0.3 * sc, 5 * sc, 5 * sc),
		CFrame.new(spot + Vector3.new(0, 0.42 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		GREEN,
		true,
		0.2
	).Shape =
		Enum.PartType.Cylinder
	part(
		m,
		"Beam",
		Vector3.new(14, 3.2, 3.2) * sc,
		CFrame.new(spot + Vector3.new(0, 7 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		GREEN,
		true,
		0.9
	).Shape =
		Enum.PartType.Cylinder

	m.PrimaryPart = body
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Up", true)
	m:SetAttribute("Home", home)
	m:SetAttribute("TakenBy", "")
	m:SetAttribute("TakenCount", 0)
	m:AddTag(WrenchServer.TAG)
	m.Parent = parent
	return m
end

-- a taken wrench: everything hides but a faint pad and ring, so you can see where it comes back
local function show(m: Model, up: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local look = d:GetAttribute("Look")
			local base = if type(look) == "number" then look else 0
			if d.Name == "Ring" or d.Name == "Pad" then
				d.Transparency = if up then base else 0.8
			else
				d.Transparency = if up then base else 1
			end
		elseif d:IsA("PointLight") then
			d.Enabled = up
		end
	end
	m:SetAttribute("Up", up)
end

function WrenchServer.start(opts: Options): Handle
	local name = opts.name or "Wrenches"
	local old = started[name]
	if old then
		old.stop()
	end
	local parent = opts.parent or workspace
	local stale = parent:FindFirstChild(name)
	if stale then
		stale:Destroy()
	end
	local sc = opts.scale or Wrenches.SCALE
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local spots: { vector } = {}
	local models: { Model } = {}
	for i, spot in opts.spots do
		table.insert(spots, plain(spot) :: vector)
		table.insert(models, build(i, spot, folder, sc))
	end
	local state = Wrenches.new(spots)

	-- Called by Wrenches.step for a hurt kart on wrench i: mend it (false = nothing to mend).
	local function take(id: any, i: number): boolean
		local ok, healed = pcall(opts.heal, id, Wrenches.HEAL)
		if not ok then
			warn(`WrenchServer: heal failed for {tostring(id)}: {healed}`)
			return false
		end
		if healed ~= true then
			return false
		end
		local m = models[i]
		m:SetAttribute("TakenBy", tostring(id))
		local count = m:GetAttribute("TakenCount")
		m:SetAttribute("TakenCount", (if type(count) == "number" then count else 0) + 1)
		return true
	end

	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 1 / WrenchServer.CHECK_HZ then
			return
		end
		acc = 0
		local ok, list = pcall(opts.karts)
		if not ok or type(list) ~= "table" then
			return
		end
		local karts: { Wrenches.Kart } = {}
		for _, c in list do
			local p = plain(c.position)
			if p and c.id ~= nil then
				table.insert(
					karts,
					{ id = c.id, position = p, alive = c.alive == true, hurt = c.hurt == true }
				)
			end
		end
		local taken, back = Wrenches.step(state, karts, os.clock(), take, sc)
		for _, i in back do
			show(models[i], true)
		end
		for _, t in taken do
			show(models[t.item], false)
		end
	end)

	local handle: Handle
	handle = {
		folder = folder,
		reset = function()
			Wrenches.reset(state)
			for _, m in models do
				show(m, true)
			end
		end,
		stop = function()
			conn:Disconnect()
			folder:Destroy()
			if started[name] == handle then
				started[name] = nil
			end
		end,
	}
	started[name] = handle
	return handle
end

return WrenchServer
