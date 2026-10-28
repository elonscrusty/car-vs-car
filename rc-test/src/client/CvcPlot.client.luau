--!strict
-- Car VS Car plots come alive (carter 10-28, rc-game/plot-layouts/plot-layout-edges.png;
-- PlotTraining has the layout, PlotGarageBuilder builds the room and the pads): a tiny car runs
-- on every station that has one (up the treadmill, over the ramp, round the speed track), and
-- the cars that aren't training wait on the stands in the middle, slowly turning (the best one
-- on the podium), and the scoreboard on the back wall lists every car's bars. A stand
-- car has its tag (CarTag: name, kind, bars); a station car's name and the number it trains go on
-- its pad's sign. On your own plot those are your trained numbers (CvcState); on other plots,
-- the car's starting numbers. The treadmill belts scroll under
-- their cars, and while the owner's COACH is on (CoachAt) the whole plot runs faster and the
-- treadmill screens glow orange.
-- Looks only, on this screen: nothing here is solid. Far plots stop moving to save the phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
if not Features.CVC then
	return
end

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local CarStats = require(ReplicatedStorage.Shared.CarStats)
local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)
local PlotTraining = require(ReplicatedStorage.Shared.PlotTraining)
local Training = require(ReplicatedStorage.Shared.Training)
local CarTag = require(script.Parent:WaitForChild("CarTag"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))

CvcState.start()

local me = Players.LocalPlayer
local glowModule = ReplicatedStorage.Shared:FindFirstChild("CarGlow")
local CarGlow: any = if glowModule and glowModule:IsA("ModuleScript")
	then require(glowModule) :: any
	else nil

local STAND_TOP = 0.8 -- a stand's top, where its car sits
local SPIN = 20 -- degrees a second the stand cars turn

type Rider = { model: Model, kind: string, pad: number, slats: { BasePart } }
type Shown = {
	plot: Instance,
	training: Model,
	pivot: CFrame,
	folder: Folder,
	key: string,
	riders: { Rider },
	parked: { Model },
	phase: number, -- the plot's own clock: runs faster while coached
	coached: boolean,
}

local SCREEN = Color3.fromRGB(60, 160, 230) -- PlotTraining's treadmill screen
local SCREEN_COACH = Color3.fromRGB(255, 150, 40)
local SLAT = Color3.fromRGB(90, 90, 100)

local shown: { [Instance]: Shown } = {}

local function mine(plot: Instance): boolean
	return tonumber(plot:GetAttribute("OwnerId")) == me.UserId
end

-- one toy car, nose to -z around its bottom middle
local function makeCar(id: string, parent: Instance): Model?
	local info = CarCatalog.get(id) :: any
	if not info then
		return nil
	end
	local pieces = {}
	Garage.toyCar(
		Garage.adder(pieces),
		"Car",
		{ x = 0, y = 0, z = 0 },
		0,
		info.color,
		PlotTraining.CAR,
		info.style
	)
	local holder = Instance.new("Model")
	local groups = Garage.makeParts(pieces, holder, CFrame.identity)
	local model = groups.Car
	model.Name = id
	model.WorldPivot = CFrame.identity
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	if CarGlow and type(CarGlow.apply) == "function" then
		pcall(CarGlow.apply, model, info.rarity)
	end
	model.Parent = parent
	holder:Destroy()
	return model
end

type Entry = { id: string, uid: string? }

-- a car's bars, yours trained and anyone else's as it comes
local function barsOf(e: Entry): PlotTraining.BoardCar
	local car = if e.uid then CvcState.find(e.uid) else nil
	local data: any = car or CvcState.fresh(e.id)
	local info = CarCatalog.get(e.id) :: any
	local out: PlotTraining.BoardCar = {
		name = string.upper(if info then info.name else e.id),
		speed = 0,
		turn = 0,
		boost = 0,
	}
	for _, b in CarStats.view(data) do
		(out :: any)[b.bar] = b.value
	end
	return out
end

local function total(e: Entry): number
	local b = barsOf(e)
	return b.speed + b.turn + b.boost
end

-- the cars to show: one per station pad (car "" = none), and the rest for the stands
local function cars(plot: Instance): ({ [number]: Entry }, { Entry })
	local onPads: { [number]: Entry } = {}
	local stands: { Entry } = {}
	if (tonumber(plot:GetAttribute("OwnerId")) or 0) == 0 then
		return onPads, stands
	end
	local room = PlotTraining.stands(tonumber(plot:GetAttribute("GarageLevel")) or 0)
	if mine(plot) and CvcState.loaded then
		local busy: { [string]: boolean } = {}
		for i, st in CvcState.stations do
			local car = if st.uid ~= "" then CvcState.find(st.uid) else nil
			if car and i <= #PlotTraining.GRID then
				onPads[i] = { id = car.id, uid = car.uid }
				busy[car.uid] = true
			end
		end
		local waiting: { Entry } = {}
		for _, car in CvcState.garage do
			if not busy[car.uid] then
				table.insert(waiting, { id = car.id, uid = car.uid })
			end
		end
		-- your best waiting car goes on the podium (stand 1)
		table.sort(waiting, function(a: Entry, b: Entry): boolean
			return total(a) > total(b)
		end)
		for _, e in waiting do
			if #stands < room then
				table.insert(stands, e)
			end
		end
		return onPads, stands
	end
	-- someone else's plot: from the attributes (ids only)
	local left: { [string]: number } = {}
	for i, pad in PlotTraining.parse(tostring(plot:GetAttribute("Stations") or "")) do
		if pad.car ~= "" and i <= #PlotTraining.GRID then
			onPads[i] = { id = pad.car }
			left[pad.car] = (left[pad.car] or 0) + 1
		end
	end
	for _, id in string.split(tostring(plot:GetAttribute("Garage") or ""), ",") do
		if id ~= "" then
			if (left[id] or 0) > 0 then
				left[id] -= 1
			else
				table.insert(stands, { id = id })
			end
		end
	end
	table.sort(stands, function(a: Entry, b: Entry): boolean
		return total(a) > total(b)
	end)
	while #stands > room do
		table.remove(stands)
	end
	return onPads, stands
end

local function keyOf(onPads: { [number]: Entry }, stands: { Entry }): string
	local bits = {}
	for i = 1, #PlotTraining.GRID do
		local e = onPads[i]
		table.insert(bits, if e then (e.uid or e.id) else "")
	end
	table.insert(bits, "|")
	for _, e in stands do
		table.insert(bits, e.uid or e.id)
	end
	return table.concat(bits, ",")
end

-- the bars over a car: yours trained, anyone else's as it comes
-- The bars over a car: yours trained, anyone else's as it comes. Sized in studs
-- (PlotTraining.TAG / STAND_TAG), so tags on next-door pads and stands never pile up.
local function tag(at: BasePart, e: Entry, w: number, h: number, up: number)
	local car = if e.uid then CvcState.find(e.uid) else nil
	local data = car or CvcState.fresh(e.id)
	local ok, gui = pcall(CarTag.make, at, data :: any)
	if ok and gui then
		gui.Size = UDim2.fromScale(w, h)
		gui.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	end
end

-- A station car's numbers go on its pad's sign, in the sign's own big letters (no tag over the
-- car: too small to read from the plot camera). Yours trained, anyone else's as it comes.
local function riderSign(s: Shown, i: number, e: Entry)
	local group = s.training:FindFirstChild("Pad" .. i)
	local sign = group and group:FindFirstChild("PadSign")
	local words = sign and sign:FindFirstChild("Words")
	local top = words and words:FindFirstChild("Top")
	local bottom = words and words:FindFirstChild("Bottom")
	if not (top and top:IsA("TextLabel") and bottom and bottom:IsA("TextLabel")) then
		return
	end
	local pads = PlotTraining.parse(tostring(s.plot:GetAttribute("Stations") or ""))
	local pad = pads[i] or { kind = PlotTraining.kindAt(i), level = 1, car = e.id }
	local car = if e.uid then CvcState.find(e.uid) else nil
	local data: any = car or CvcState.fresh(e.id)
	local main = Training.MAIN[pad.kind]
	local value = 0
	for _, b in CarStats.view(data) do
		if b.bar == main then
			value = b.value
		end
	end
	local info = CarCatalog.get(e.id) :: any
	top.Text, bottom.Text = PlotTraining.carWords(pad, if info then info.name else e.id, value)
	-- two even lines: the car's number as big as the station's name
	top.Position, top.Size = UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.44)
	bottom.Position, bottom.Size = UDim2.fromScale(0.03, 0.52), UDim2.fromScale(0.94, 0.43)
end

-- The scoreboard on the back wall: each car's name and its 3 bars, best on top.
local function scoreBoard(s: Shown, onPads: { [number]: Entry }, stands: { Entry })
	local group = s.training:FindFirstChild("Board")
	local board = group and group:FindFirstChild("ScoreBoard")
	if not (board and board:IsA("BasePart")) then
		return
	end
	local list: { PlotTraining.BoardCar } = {}
	for i = 1, #PlotTraining.GRID do
		local e = onPads[i]
		if e then
			table.insert(list, barsOf(e))
		end
	end
	for _, e in stands do
		table.insert(list, barsOf(e))
	end
	local old = board:FindFirstChild("Rows")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Rows"
	gui.Face = Enum.NormalId.Back -- the road side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local rows = PlotTraining.BOARD_ROWS
	local function text(parent: Instance, words: string, x: number, y: number, w: number, h: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(x, y)
		l.Size = UDim2.fromScale(w, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = words
		l.Parent = parent
		return l
	end
	local title = text(gui, "WHO IS AHEAD?", 0.03, 0.02, 0.94, 0.16)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	local rowH = 0.8 / rows
	for k, car in PlotTraining.board(list) do
		local y = 0.19 + (k - 1) * rowH
		text(gui, k .. "  " .. car.name, 0.03, y + rowH * 0.1, 0.42, rowH * 0.8)
		for j, bar in Training.BARS do
			local c = PlotTraining.BAR_COLORS[bar]
			local x = 0.47 + (j - 1) * 0.17
			local back = Instance.new("Frame")
			back.BorderSizePixel = 0
			back.BackgroundColor3 = Color3.fromRGB(70, 74, 90)
			back.Position = UDim2.fromScale(x, y + rowH * 0.25)
			back.Size = UDim2.fromScale(0.155, rowH * 0.5)
			back.Parent = gui
			local fill = Instance.new("Frame")
			fill.BorderSizePixel = 0
			fill.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
			fill.Size = UDim2.fromScale(math.clamp((car :: any)[bar] / Training.MAX_BAR, 0, 1), 1)
			fill.Parent = back
		end
	end
	gui.Parent = board
end

local function standTag(model: Model, e: Entry)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		local T = PlotTraining.STAND_TAG
		tag(body, e, T.w, T.h, T.up)
	end
end

local function refresh(s: Shown)
	local onPads, stands = cars(s.plot)
	local key = keyOf(onPads, stands)
	if key == s.key then
		-- same cars: only the numbers may have moved
		if mine(s.plot) then
			for _, r in s.riders do
				local e = onPads[r.pad]
				if e then
					riderSign(s, r.pad, e)
				end
			end
			for k, m in s.parked do
				local e = stands[k]
				if e then
					standTag(m, e)
				end
			end
			scoreBoard(s, onPads, stands)
		end
		return
	end
	scoreBoard(s, onPads, stands)
	s.key = key
	s.folder:ClearAllChildren()
	s.riders, s.parked = {}, {}
	local pads = PlotTraining.parse(tostring(s.plot:GetAttribute("Stations") or ""))
	for i = 1, #PlotTraining.GRID do
		local e = onPads[i]
		if e then
			local model = makeCar(e.id, s.folder)
			if model then
				local pad = pads[i]
				local kind = if pad then pad.kind else PlotTraining.kindAt(i)
				local slats: { BasePart } = {}
				if kind == "treadmill" then
					for _ = 1, PlotTraining.BELT.slats do
						local p = Instance.new("Part")
						p.Name = "Slat"
						p.Anchored = true
						p.CanCollide = false
						p.CanQuery = false
						p.CanTouch = false
						p.CastShadow = false
						p.Size = Vector3.new(4.2 * PlotTraining.K, 0.04, 0.3 * PlotTraining.K)
						p.Color = SLAT
						p.Material = Enum.Material.SmoothPlastic
						p.Parent = s.folder
						table.insert(slats, p)
					end
				end
				local r: Rider = { model = model, kind = kind, pad = i, slats = slats }
				table.insert(s.riders, r)
				riderSign(s, i, e)
			end
		end
	end
	for k, e in stands do
		local model = makeCar(e.id, s.folder)
		if model then
			local st = PlotTraining.STANDS[k]
			model:PivotTo(s.pivot * CFrame.new(st.x, STAND_TOP + (st.lift or 0), st.z))
			table.insert(s.parked, model)
			standTag(model, e)
		end
	end
end

local function place(s: Shown, clock: number)
	for _, r in s.riders do
		local g = PlotTraining.GRID[r.pad]
		-- each pad runs a little out of step, so they don't all move as one
		local t = clock + r.pad * 0.73
		local x, y, z, yaw, tilt = PlotTraining.ride(r.kind, t)
		r.model:PivotTo(
			s.pivot
				* CFrame.new(g.x + x, y, g.z + z)
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.Angles(math.rad(tilt), 0, 0)
		)
		for k, zz in PlotTraining.slats(t) do
			local p = r.slats[k]
			if p then
				p.CFrame = s.pivot * CFrame.new(g.x, 0.3 + 0.9 * PlotTraining.K, g.z + zz)
			end
		end
	end
	for k, m in s.parked do
		local st = PlotTraining.STANDS[k]
		m:PivotTo(
			s.pivot
				* CFrame.new(st.x, STAND_TOP + (st.lift or 0), st.z)
				* CFrame.Angles(0, math.rad(clock * SPIN + k * 40), 0)
		)
	end
end

local function setUp(plot: Instance, training: Model)
	local old = shown[plot]
	if old then
		old.folder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CvcPlotCars"
	folder.Parent = workspace
	local s: Shown = {
		plot = plot,
		training = training,
		pivot = training.WorldPivot,
		folder = folder,
		key = "",
		riders = {},
		parked = {},
		phase = workspace:GetServerTimeNow(),
		coached = false,
	}
	shown[plot] = s
	refresh(s)
end

local function watch(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	local function found(child: Instance)
		if child.Name == "Training" and child:IsA("Model") then
			setUp(plot, child)
		end
	end
	plot.ChildAdded:Connect(found)
	local t = plot:FindFirstChild("Training")
	if t then
		found(t)
	end
	plot.ChildRemoved:Connect(function(child)
		local s = shown[plot]
		if s and child == s.training then
			s.folder:Destroy()
			shown[plot] = nil
		end
	end)
	for _, name in { "Stations", "Garage", "GarageLevel", "OwnerId" } do
		plot:GetAttributeChangedSignal(name):Connect(function()
			local s = shown[plot]
			if s then
				refresh(s)
			end
		end)
	end
end

CvcState.changed:Connect(function()
	for plot, s in shown do
		if mine(plot) then
			refresh(s)
		end
	end
end)

local plots = workspace:WaitForChild("Plots")
plots.ChildAdded:Connect(watch)
for _, p in plots:GetChildren() do
	watch(p)
end

-- the owner's COACH: faster stations, orange treadmill screens
local function coach(s: Shown, now: number): number
	local owner = Players:GetPlayerByUserId(tonumber(s.plot:GetAttribute("OwnerId")) or 0)
	local on = owner ~= nil and PlotTraining.coaching(owner:GetAttribute("CoachAt") :: any, now)
	if on ~= s.coached then
		s.coached = on
		for i = 1, #PlotTraining.GRID do
			local pad = s.training:FindFirstChild("Pad" .. i)
			local screen = pad and pad:FindFirstChild("TreadScreen")
			if screen and screen:IsA("BasePart") then
				screen.Color = if on then SCREEN_COACH else SCREEN
			end
		end
	end
	return if on then PlotTraining.COACH_SPEED else 1
end

local moveAcc = 0
RunService.RenderStepped:Connect(function(dt: number)
	local now = workspace:GetServerTimeNow()
	for _, s in shown do
		s.phase += dt * coach(s, now)
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local due: boolean
	moveAcc, due = PlotGarage.stepDue(moveAcc, dt, Features.PLOT_CAR_HZ)
	if not due then
		return
	end
	local eye = cam.CFrame.Position
	for _, s in shown do
		if PlotTraining.awake((s.pivot.Position - eye).Magnitude) then
			place(s, s.phase)
		end
	end
end)
