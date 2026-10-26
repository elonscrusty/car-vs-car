--!strict
-- Car VS Car plots come alive (carter 10-26, rc-game/cvc/pics/plot-training-topdown-2.png;
-- PlotTraining has the layout, PlotGarageBuilder builds the room and the pads): a tiny car runs
-- on every station that has one (up the treadmill, over the ramp, round the speed track), and
-- the cars that aren't training wait on the stands in the garage room, slowly turning. Each car
-- has its tag (CarTag: name, kind, bars). On your own plot the bars are your trained numbers
-- (CvcState); on other plots, the car's starting numbers.
-- Looks only, on this screen: nothing here is solid. Far plots stop moving to save the phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
if not Features.CVC then
	return
end

local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)
local PlotTraining = require(ReplicatedStorage.Shared.PlotTraining)
local CarTag = require(script.Parent:WaitForChild("CarTag"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))

CvcState.start()

local me = Players.LocalPlayer
local glowModule = ReplicatedStorage.Shared:FindFirstChild("CarGlow")
local CarGlow: any = if glowModule and glowModule:IsA("ModuleScript")
	then require(glowModule) :: any
	else nil

local NEAR = 220 -- studs: plots farther from the camera than this stop moving
local STAND_TOP = 0.8 -- a stand's top, where its car sits
local SPIN = 20 -- degrees a second the stand cars turn

type Rider = { model: Model, kind: string, pad: number }
type Shown = {
	plot: Instance,
	training: Model,
	pivot: CFrame,
	folder: Folder,
	key: string,
	riders: { Rider },
	parked: { Model },
}

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

-- the cars to show: one per station pad (car "" = none), and the rest for the stands
type Entry = { id: string, uid: string? }
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
		for _, car in CvcState.garage do
			if not busy[car.uid] and #stands < room then
				table.insert(stands, { id = car.id, uid = car.uid })
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
			elseif #stands < room then
				table.insert(stands, { id = id })
			end
		end
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
local function tag(model: Model, e: Entry)
	local body = model:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then
		return
	end
	local car = if e.uid then CvcState.find(e.uid) else nil
	local data = car or CvcState.fresh(e.id)
	pcall(CarTag.make, body, data :: any)
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
					tag(r.model, e)
				end
			end
			for k, m in s.parked do
				local e = stands[k]
				if e then
					tag(m, e)
				end
			end
		end
		return
	end
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
				table.insert(s.riders, {
					model = model,
					kind = if pad then pad.kind else PlotTraining.kindAt(i),
					pad = i,
				})
				tag(model, e)
			end
		end
	end
	for k, e in stands do
		local model = makeCar(e.id, s.folder)
		if model then
			local st = PlotTraining.STANDS[k]
			model:PivotTo(s.pivot * CFrame.new(st.x, STAND_TOP, st.z))
			table.insert(s.parked, model)
			tag(model, e)
		end
	end
end

local function place(s: Shown, clock: number)
	for _, r in s.riders do
		local g = PlotTraining.GRID[r.pad]
		-- each pad runs a little out of step, so they don't all move as one
		local x, y, z, yaw, tilt = PlotTraining.ride(r.kind, clock + r.pad * 0.73)
		r.model:PivotTo(
			s.pivot
				* CFrame.new(g.x + x, y, g.z + z)
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.Angles(math.rad(tilt), 0, 0)
		)
	end
	for k, m in s.parked do
		local st = PlotTraining.STANDS[k]
		m:PivotTo(
			s.pivot
				* CFrame.new(st.x, STAND_TOP, st.z)
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

local moveAcc = 0
RunService.RenderStepped:Connect(function(dt: number)
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
	local clock = workspace:GetServerTimeNow()
	for _, s in shown do
		if (s.pivot.Position - eye).Magnitude < NEAR then
			place(s, clock)
		end
	end
end)
