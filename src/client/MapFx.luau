--!strict
-- Moves the decoration models the server tags on this player's own screen, so the movement costs no
-- network traffic and the server never moves them:
--   "MapSpin": the big wheel behind the toy battle arena, turning about its axle.
--   "MapWave": the garage flags in the duel arena. Their strips (Strip1..Strip5) sway sideways, more
--   toward the free end.
--   "BowlCrusher": the Junkyard Bowl's crusher. The press, its lamps, the red warning on the floor
--   and the shock ring follow the server clock (BowlView.crusher, from the model's RoundStart
--   attribute: the server time of GO, -1 while resting), so every screen sees the same slam and the
--   server sends nothing while it happens.
-- Also on a slow phone: the bowl's far scenery, small details and berm are removed from this screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BowlLayout = require(ReplicatedStorage.Shared.BowlLayout)
local BowlView = require(ReplicatedStorage.Shared.BowlView)
local Quality = require(script.Parent.Quality)

local MapFx = {}

local spinning: { [Model]: { base: CFrame, center: Vector3, speed: number } } = {}

local waving: { [Model]: { { part: BasePart, base: CFrame, k: number } } } = {}

type PressPart = { part: BasePart, base: CFrame }
type Crusher = {
	press: { PressPart }, -- the press head, its trim and its lamps: they ride up and down together
	lamps: { { part: BasePart, on: Color3, off: Color3 } },
	warn: BasePart?, -- the red disc on the floor
	wave: BasePart?, -- the shock ring
	slamSound: Sound?,
	lastSlam: number, -- the number of the slam whose sound already played
	resting: boolean, -- the press is hanging at rest and shows nothing: no need to update it
}
local crushers: { [Model]: Crusher } = {}

local function addCrusher(inst: Instance)
	if not inst:IsA("Model") or crushers[inst] ~= nil then
		return
	end
	-- the model streams in whole (atomic), but wait a moment for the pieces anyway
	local head = inst:WaitForChild("Head", 10)
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local press: { PressPart } = {}
	local lamps: { { part: BasePart, on: Color3, off: Color3 } } = {}
	for _, name in { "Head", "HeadTrim", "LampA", "LampB" } do
		local p = inst:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(press, { part = p, base = p.CFrame })
		end
	end
	for _, name in { "LampA", "LampB", "Beacon" } do
		local p = inst:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(
				lamps,
				{ part = p, on = p.Color, off = p.Color:Lerp(Color3.new(0.12, 0.1, 0.1), 0.85) }
			)
		end
	end
	local warn = inst:FindFirstChild("Warn")
	local wave = inst:FindFirstChild("Wave")
	local sounds = inst.Parent and inst.Parent:FindFirstChild("Sounds")
	local slam = if sounds then sounds:FindFirstChild("Slam", true) else nil
	crushers[inst] = {
		press = press,
		lamps = lamps,
		warn = if warn and warn:IsA("BasePart") then warn else nil,
		wave = if wave and wave:IsA("BasePart") then wave else nil,
		slamSound = if slam and slam:IsA("Sound") then slam else nil,
		lastSlam = -1,
		resting = false,
	}
end

-- Seconds since GO by the server clock, or nil while the crusher rests.
local function sinceGo(model: Model, now: number): number?
	local start = model:GetAttribute("RoundStart")
	if type(start) == "number" and start >= 0 then
		return now - start
	end
	return nil
end

local function updateCrusher(model: Model, c: Crusher, now: number)
	local since = sinceGo(model, now)
	if since == nil and c.resting then
		return
	end
	local look = BowlView.crusher(since)
	c.resting = since == nil
	local rise = look.lift - BowlLayout.crusher.restLift
	for _, pp in c.press do
		pp.part.CFrame = pp.base + Vector3.new(0, rise, 0)
	end
	for _, l in c.lamps do
		l.part.Color = if look.lamps then l.on else l.off
	end
	if c.warn then
		-- a faint red disc on the floor that grows redder before the slam
		c.warn.Transparency = 1 - 0.55 * look.warn
	end
	if c.wave then
		if look.ring > 0 then
			c.wave.Size = Vector3.new(0.08, look.ring, look.ring)
			c.wave.Transparency = look.ringFade
		else
			c.wave.Transparency = 1
		end
	end
	if look.slam >= 0 and look.slam ~= c.lastSlam then
		c.lastSlam = look.slam
		local s = c.slamSound
		if s and s.SoundId ~= "" then
			s:Play()
		end
	elseif look.slam < 0 and since == nil then
		c.lastSlam = -1
	end
end

-- Camera shake from the crusher's slam for a car at `pos`: strongest beside it, still a little
-- from across the bowl. 0 when no crusher is slamming.
function MapFx.crusherShake(pos: Vector3): number
	local best = 0
	local now = workspace:GetServerTimeNow()
	for model, c in crushers do
		if model.Parent and not c.resting then
			local look = BowlView.crusher(sinceGo(model, now))
			if look.shake > 0 then
				local d = (pos - model:GetPivot().Position).Magnitude
				best = math.max(best, look.shake * math.clamp(1.2 - d / 110, 0.25, 1))
			end
		end
	end
	return best
end

local function collectStrips(inst: Instance): { { part: BasePart, base: CFrame, k: number } }
	local strips = {}
	for _, c in inst:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Strip(%d+)$"))
		if n ~= nil and c:IsA("BasePart") then
			table.insert(strips, { part = c, base = c.CFrame, k = n })
		end
	end
	return strips
end

local function addWave(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	waving[inst] = collectStrips(inst)
end

local function add(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local pivot = inst:GetPivot()
	local speed = inst:GetAttribute("SpinSpeed")
	spinning[inst] = {
		base = pivot,
		center = pivot.Position,
		speed = if type(speed) == "number" then speed else 0.2,
	}
end

-- A slow phone loses the bowl's far scenery, small details and the berm under the tires
-- (look-only; the fight is the same).
local function cutForSlowPhones()
	if Quality.level() < 2 then
		return
	end
	for _, folder in workspace:GetChildren() do
		if folder:IsA("Folder") and string.sub(folder.Name, 1, 12) == "BattleArena_" then
			for _, name in { "FarScenery", "Detail", "Berm" } do
				local g = folder:FindFirstChild(name)
				if g then
					g:Destroy()
				end
			end
		end
	end
end

function MapFx.start()
	for _, inst in CollectionService:GetTagged("MapSpin") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("MapSpin"):Connect(add)
	for _, inst in CollectionService:GetTagged("MapWave") do
		addWave(inst)
	end
	CollectionService:GetInstanceAddedSignal("MapWave"):Connect(addWave)
	for _, inst in CollectionService:GetTagged("BowlCrusher") do
		task.spawn(addCrusher, inst)
	end
	CollectionService:GetInstanceAddedSignal("BowlCrusher"):Connect(function(inst)
		task.spawn(addCrusher, inst)
	end)
	CollectionService:GetInstanceRemovedSignal("BowlCrusher"):Connect(function(inst)
		crushers[inst :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("MapWave"):Connect(function(inst)
		waving[inst :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("MapSpin"):Connect(function(inst)
		spinning[inst :: Model] = nil
	end)
	local lastCut = 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t - lastCut > 1.5 then
			lastCut = t
			cutForSlowPhones()
		end
		for model, strips in waving do
			if model.Parent then
				if #strips < 5 then
					-- the strips may still be streaming in: look again until all five are here
					strips = collectStrips(model)
					waving[model] = strips
				end
				for _, st in strips do
					st.part.CFrame = st.base
						* CFrame.new(math.sin(t * 4 - st.k * 0.9) * 0.16 * st.k, 0, 0)
				end
			else
				waving[model] = nil
			end
		end
		local now = workspace:GetServerTimeNow()
		for model, c in crushers do
			if model.Parent then
				updateCrusher(model, c, now)
			else
				crushers[model] = nil
			end
		end
		for model, s in spinning do
			if model.Parent then
				-- turns about the wheel's own axle (the x axis, through the hub)
				model:PivotTo(
					CFrame.new(s.center)
						* CFrame.Angles(t * s.speed, 0, 0)
						* CFrame.new(-s.center)
						* s.base
				)
			else
				spinning[model] = nil
			end
		end
	end)
end

return MapFx
