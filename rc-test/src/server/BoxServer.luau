--!strict
-- The "?" boxes in a smash match (shared/Boxes has the rules and odds). The server alone decides
-- a pickup: 10 times a second it looks where every live kart is and hands a touched box's weapon
-- to that kart through `give` (WeaponServer.give). No remote: a client can't ask for a box.
--
-- Use (MatchRunner, when the arena is built):
--   local boxes = BoxServer.start({
--       spots = ArenaData.boxSpots,
--       karts = function() return list of { id, position: Vector3, alive } end,
--       give = WeaponServer.give, -- (kartId, name) -> boolean; false = can't take it now
--       has = function(name) return Weapons.get(name) ~= nil end, -- weapons built so far
--   })
--   boxes.reset() -- at each match start: every box up
--   boxes.stop() -- arena gone: boxes removed
-- More than one set can run at once (the arena and the lobby's warm-up yard): give each its own
-- `name` (default "SmashBoxes"). Starting a name again stops the old set of that name first.
--
-- Each box is a Model tagged "SmashBox" in <parent>.<name> with attributes Up (bool), Home
-- (CFrame of the box's middle), TakenBy (kart id as a string), TakenWeapon and TakenCount (goes
-- up by one on every pickup: listen to this one for sounds and screens). client/BoxFx spins it,
-- plays the pop, and plays the pickup sound for the grabber: a player's kart id must be their
-- UserId (bots can use any other id).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boxes = require(ReplicatedStorage.Shared.Boxes)

local BoxServer = {}

BoxServer.TAG = "SmashBox"

local RED = Color3.fromRGB(222, 38, 52) -- cherry red
local YELLOW = Color3.fromRGB(255, 214, 46) -- sunny yellow
local NAVY = Color3.fromRGB(24, 30, 72) -- dark navy

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	give: (any, string) -> boolean?,
	has: ((string) -> boolean)?,
	parent: Instance?,
	name: string?,
	seed: number?,
	-- studs per big unit (ArenaData sizes; a kart is 5.5 big). Default Boxes.SCALE = the RC arena.
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	stop: () -> (),
	odds: () -> { [string]: number },
	folder: Folder,
}

local function mark(body: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mark"
	gui.Face = face
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Oswald
	t.Text = "?"
	t.TextSize = 90 -- fixed size on the 100 px canvas (TextScaled costs more on phones)
	t.TextColor3 = YELLOW
	t.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = NAVY
	stroke.Thickness = 4
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = body
end

-- One box: a red low-poly cube with a yellow "?" on each side and on top, and a glowing yellow
-- ring on the ground under it, so you can see where a box comes back.
local function build(i: number, spot: Vector3, parent: Instance, sc: number): Model
	local m = Instance.new("Model")
	m.Name = "Box" .. i
	local home = CFrame.new(spot + Vector3.new(0, Boxes.LIFT * sc, 0))

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.one * Boxes.SIZE * sc
	body.CFrame = home
	body.Color = RED
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = true
	for _, face in
		{
			Enum.NormalId.Front,
			Enum.NormalId.Back,
			Enum.NormalId.Left,
			Enum.NormalId.Right,
			Enum.NormalId.Top,
		}
	do
		mark(body, face)
	end
	body.Parent = m

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	local width = Boxes.RING * sc -- the look only (the reach is wider)
	ring.Size = Vector3.new(0.2 * sc, width, width)
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.12 * sc, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	ring.Color = YELLOW
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Parent = m

	m.PrimaryPart = body
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the box arrives whole if streaming is on
	m:SetAttribute("Up", true)
	m:SetAttribute("Home", home)
	m:SetAttribute("TakenBy", "")
	m:SetAttribute("TakenWeapon", "")
	m:SetAttribute("TakenCount", 0)
	CollectionService:AddTag(m, BoxServer.TAG)
	m.Parent = parent
	return m
end

local function show(m: Model, up: boolean)
	local body = m:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.Transparency = if up then 0 else 1
		for _, g in body:GetChildren() do
			if g:IsA("SurfaceGui") then
				g.Enabled = up
			end
		end
	end
	local ring = m:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Transparency = if up then 0.55 else 0.85
	end
	m:SetAttribute("Up", up)
end

local running: { [string]: Handle } = {}

function BoxServer.start(opts: Options): Handle
	local parent = opts.parent or workspace
	local name = opts.name or "SmashBoxes"
	local before = running[name]
	if before then
		before.stop()
	end
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local given = opts.scale
	local sc = if type(given) == "number" and given > 0 then given else Boxes.SCALE
	local spots = {}
	local models: { Model } = {}
	for i, v in opts.spots do
		table.insert(spots, { x = v.X, y = v.Y, z = v.Z })
		table.insert(models, build(i, v, folder, sc))
	end
	local boxes = Boxes.new(spots, sc)
	local sweepMax = Boxes.SWEEP_MAX * sc
	local prev: { [any]: Vector3 } = {} -- each kart's spot at the last check
	local rng = Random.new(opts.seed or os.clock() * 1e6)
	local last: { [any]: string } = {} -- kart id -> its last weapon from a box
	local streak: { [any]: number } = {}

	local function hasSafe(name: string): boolean
		if opts.has == nil then
			return true
		end
		local ok, yes = pcall(opts.has, name)
		return ok and yes == true
	end

	-- Called by Boxes.step for a kart touching box i: roll and try to give it.
	local function take(id: any, i: number): boolean
		local weapon = Boxes.roll(rng:NextNumber(), hasSafe, last[id], streak[id])
		if weapon == nil then
			return false -- no weapon built yet: the box stays
		end
		local ok, res = pcall(opts.give, id, weapon)
		if not ok then
			warn(`BoxServer: give failed for {tostring(id)} ({weapon}): {res}`)
			return false
		end
		if res == false then
			return false -- kart already holds a weapon: leave the box for someone else
		end
		if last[id] == weapon then
			streak[id] = (streak[id] or 0) + 1
		else
			last[id] = weapon
			streak[id] = 1
		end
		local m = models[i]
		m:SetAttribute("TakenWeapon", weapon)
		m:SetAttribute("TakenBy", tostring(id))
		local count = m:GetAttribute("TakenCount")
		m:SetAttribute("TakenCount", (if type(count) == "number" then count else 0) + 1)
		return true
	end

	local list: { Boxes.Kart } = {}
	local wait = 0
	local since = 0 -- seconds since the last check (a slow frame makes it longer)
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		wait -= dt
		since += dt
		if wait > 0 then
			return
		end
		wait = math.max(wait + 1 / Boxes.CHECK_HZ, 0)
		-- SWEEP_MAX is per normal check; a late check allows a longer drive
		local jump = sweepMax * math.max(since * Boxes.CHECK_HZ, 1)
		since = 0
		local ok, karts = pcall(opts.karts)
		if not ok or type(karts) ~= "table" then
			return
		end
		table.clear(list)
		local seen: { [any]: Vector3 } = {}
		local present: { [any]: boolean } = {}
		for _, k in karts do
			local p = k.position
			if typeof(p) == "Vector3" and k.id ~= nil then
				local alive = k.alive == true
				present[k.id] = true
				local was = prev[k.id]
				-- the path since the last check counts, unless it was a jump (respawn, teleport)
				local sweep = alive and was ~= nil and (p - was).Magnitude <= jump
				table.insert(list, {
					id = k.id,
					x = p.X,
					y = p.Y,
					z = p.Z,
					alive = alive,
					px = if sweep then (was :: Vector3).X else nil,
					pz = if sweep then (was :: Vector3).Z else nil,
				})
				if alive then
					seen[k.id] = p
				end
			end
		end
		prev = seen -- a kart missing from this check (dead, hidden after a jump) starts fresh
		for id in last do
			if not present[id] then -- left the game: forget its weapon streak
				last[id] = nil
				streak[id] = nil
			end
		end
		local taken, back = Boxes.step(boxes, list, os.clock(), take)
		for _, i in back do
			show(models[i], true)
		end
		for _, t in taken do
			show(models[t.box], false)
		end
	end)

	local handle: Handle
	handle = {
		folder = folder,
		reset = function()
			Boxes.reset(boxes)
			table.clear(prev)
			table.clear(last)
			table.clear(streak)
			for _, m in models do
				show(m, true)
			end
		end,
		stop = function()
			conn:Disconnect()
			folder:Destroy()
			if running[name] == handle then
				running[name] = nil
			end
		end,
		odds = function()
			return Boxes.odds(hasSafe)
		end,
	}
	running[name] = handle
	return handle
end

return BoxServer
