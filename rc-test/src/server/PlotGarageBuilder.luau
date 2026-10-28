--!strict
-- Builds the garage yard on each plot (PlotGarage has the layout): the little loop road, the
-- coin pile pad, the LEVEL UP sign and the looks for the plot's level. Only while plots are
-- garages (Features.GARAGES on): then each plot's old track is put away in
-- ServerStorage (kept, so it can come back) and the
-- yard goes in its place. The open drift plot keeps its track for free drift play. Rebuilt when
-- the plot's level or owner changes (TycoonServer sets PlotLevel on the owner's plot). The cars
-- and the coins are drawn by PlotGarage.client.
-- Car VS Car (Features.CVC on): a "Training" model instead (PlotTraining has the layout): the
-- garage room, the trophy shelf, the car stands and the station pads, from the plot's Stations,
-- PlotLevel, GarageLevel and Trophies (TrainingServer sets them). CvcPlot.client puts the cars on.
-- Car VS Car SMASH (Features.SMASH on): a "Showroom" model instead (PlotShowroom has the layout):
-- the floor, the turntable, one stand for each kart and the crate, from the plot's Garage and
-- RacerCar (GarageServer sets them). PlotShowroom.client puts the karts on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)
local PlotShowroom = require(ReplicatedStorage.Shared.PlotShowroom)
local PlotTraining = require(ReplicatedStorage.Shared.PlotTraining)
local Tycoon = require(ReplicatedStorage.Shared.Tycoon)

local PlotGarageBuilder = {}

-- Words on the road side of the sign (its Back face: the plot's +z).
local function label(board: BasePart, top: string, bottom: string, one: boolean?, glow: { number }?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local function line(name: string, text: string, y: number, h: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.03, y)
		l.Size = UDim2.fromScale(0.94, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.4
		l.Text = text
		l.Parent = gui
	end
	if one then
		-- one line: big, the whole board
		line("Top", top, 0.08, 0.84, Color3.new(1, 1, 1))
		line("Bottom", "", 0.92, 0.04, Color3.fromRGB(255, 220, 90))
		return
	end
	-- a station's name glows in its colour (its sign's Neon rim), the car's line stays gold
	local name = if glow then Color3.fromRGB(glow[1], glow[2], glow[3]) else Color3.new(1, 1, 1)
	line("Top", top, 0.06, 0.52, name)
	line("Bottom", bottom, 0.6, 0.34, Color3.fromRGB(255, 220, 90))
	if glow then
		local t = gui:FindFirstChild("Top") :: TextLabel
		t.TextStrokeTransparency = 0.55
		t.TextStrokeColor3 = Color3.new(1, 1, 1)
	end
end

-- Words painted big across a locked pad's top, turned to read upright from the road
-- (PlotTraining.PAINT has the layout and why).
local function paint(base: BasePart, top: string, bottom: string)
	local ppu = 20
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu
	gui.LightInfluence = 0
	gui.Parent = base
	-- quiet dark green on the grass-green locked pad: there, not shouting (carter 10-28: the
	-- old big LOCKED words were most of what you saw from the stand)
	local colors = { Color3.fromRGB(60, 100, 50), Color3.fromRGB(60, 100, 50) }
	for k, text in { top, bottom } do
		local line = PlotTraining.PAINT[k]
		local l = Instance.new("TextLabel")
		l.Name = if k == 1 then "Top" else "Bottom"
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(line.at, 0.5)
		l.Size = UDim2.fromOffset(line.w * ppu, line.h * ppu)
		l.Rotation = 90
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = colors[k]
		l.TextTransparency = 0.25
		l.TextStrokeTransparency = 1
		l.Text = text
		l.Parent = gui
	end
end

-- The sign's words: what the next level gives and costs (MAX at the top).
local function words(level: number): (string, string)
	return PlotGarage.levelWords(level, Tycoon.levelCost(level))
end

local function levelOf(plot: Instance): number
	local owner = tonumber(plot:GetAttribute("OwnerId")) or 0
	if owner == 0 then
		return 0
	end
	local n = tonumber(plot:GetAttribute("PlotLevel")) or 0
	return math.clamp(math.floor(n), 0, PlotGarage.MAX_LEVEL)
end

function PlotGarageBuilder.start()
	if not Features.GARAGES then
		return
	end
	local store: Instance = ServerStorage:FindFirstChild("HiddenPlotTracks")
		or Instance.new("Folder")
	store.Name = "HiddenPlotTracks"
	store.Parent = ServerStorage
	local built: { [Instance]: number } = {}
	local boards: { [Instance]: BasePart } = {} -- each plot's income board face
	local following: { [Instance]: RBXScriptConnection } = {}

	-- the income board shows the owner's coins a minute (TycoonServer sets Income, BoostUntil)
	local function showIncome(plot: Instance)
		local face = boards[plot]
		if not face then
			return
		end
		local owner = Players:GetPlayerByUserId(tonumber(plot:GetAttribute("OwnerId")) or 0)
		local top, bottom = "", ""
		if owner then
			local parked = tostring(plot:GetAttribute("Parked") or "")
			local cars = if parked == "" then 0 else #string.split(parked, ",")
			local boost = tonumber(owner:GetAttribute("BoostUntil")) or 0
			top, bottom = PlotGarage.incomeWords(
				tonumber(owner:GetAttribute("Income")) or 0,
				cars,
				boost > os.time()
			)
		end
		local gui = face:FindFirstChild("Words")
		if gui then
			local a = gui:FindFirstChild("Top")
			local b = gui:FindFirstChild("Bottom")
			if a and a:IsA("TextLabel") then
				a.Text = top
			end
			if b and b:IsA("TextLabel") then
				b.Text = bottom
			end
		end
	end

	local function follow(plot: Instance)
		local old = following[plot]
		if old then
			old:Disconnect()
			following[plot] = nil
		end
		local owner = Players:GetPlayerByUserId(tonumber(plot:GetAttribute("OwnerId")) or 0)
		if owner then
			following[plot] = owner.AttributeChanged:Connect(function(name: string)
				if name == "Income" or name == "BoostUntil" then
					showIncome(plot)
				end
			end)
		end
		showIncome(plot)
	end

	local function build(plot: Instance, pivot: CFrame)
		local level = levelOf(plot)
		if built[plot] == level then
			return
		end
		built[plot] = level
		local old = plot:FindFirstChild("Garage")
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "Garage"
		model:SetAttribute("Level", level)
		local groups = Garage.makeParts(PlotGarage.pieces(level), model, pivot)
		Garage.useMeshes(groups, pivot, PlotGarage.meshes(level))
		local board = groups.Sign and groups.Sign:FindFirstChild("SignBoard")
		if board and board:IsA("BasePart") then
			label(board, words(level))
		end
		-- the income board in the front left corner
		local boardGroups = Garage.makeParts(PlotGarage.boardPieces(), model, pivot)
		local face = boardGroups.Board and boardGroups.Board:FindFirstChild("IncomeBoard")
		if face and face:IsA("BasePart") then
			label(face, "", "")
			boards[plot] = face
		end
		model.WorldPivot = pivot
		model.Parent = plot
		showIncome(plot)
	end

	-- Car VS Car: the training garage, rebuilt when its looks change (not when a car moves pads)
	local trainedKey: { [Instance]: string } = {}
	local function buildTraining(plot: Instance, pivot: CFrame)
		local ownerId = tonumber(plot:GetAttribute("OwnerId")) or 0
		local owned = ownerId ~= 0
		local function num(name: string): number
			return if owned
				then math.max(0, math.floor(tonumber(plot:GetAttribute(name)) or 0))
				else 0
		end
		local plotLevel, garageLevel, trophies =
			num("PlotLevel"), num("GarageLevel"), num("Trophies")
		local nextOpen = owned and plot:GetAttribute("NextOpen") == true
		local pads =
			PlotTraining.parse(if owned then tostring(plot:GetAttribute("Stations") or "") else "")
		local kinds = {}
		for _, p in pads do
			table.insert(kinds, p.kind .. p.level)
		end
		local key = table.concat({
			ownerId,
			plotLevel,
			garageLevel,
			trophies,
			table.concat(kinds, ","),
			tostring(nextOpen),
		}, "|")
		if trainedKey[plot] == key then
			return
		end
		trainedKey[plot] = key
		local old = plot:FindFirstChild("Training")
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "Training"
		local groups = Garage.makeParts(
			PlotTraining.pieces(plotLevel, garageLevel, trophies, nextOpen),
			model,
			pivot
		)
		Garage.useMeshes(groups, pivot, PlotTraining.meshes())
		for i = 1, #PlotTraining.GRID do
			local g = groups["Pad" .. i]
			local base = g and g:FindFirstChild("PadBase")
			if i > PlotTraining.open(plotLevel) and base and base:IsA("BasePart") then
				paint(base, PlotTraining.padWords(nil, i))
			end
			local sign = g and g:FindFirstChild("PadSign")
			if sign and sign:IsA("BasePart") then
				-- an open pad the server hasn't listed yet still says its station
				local pad = pads[i]
				if pad == nil and i <= PlotTraining.open(plotLevel) then
					pad = { kind = PlotTraining.kindAt(i), level = 1, car = "" }
				end
				local top, bottom = PlotTraining.padWords(pad, i)
				label(sign, top, bottom, false, pad and PlotTraining.signColor(pad.kind))
			end
		end
		local owner = Players:GetPlayerByUserId(ownerId)
		local room = groups.Room and groups.Room:FindFirstChild("RoomSign")
		if room and room:IsA("BasePart") then
			label(room, PlotGarage.signText(if owner then owner.DisplayName else nil), "", true)
		end
		local shelf = groups.Shelf and groups.Shelf:FindFirstChild("ShelfSign")
		if shelf and shelf:IsA("BasePart") then
			label(shelf, "TROPHIES " .. trophies, "", true)
		end
		model.WorldPivot = pivot
		model.Parent = plot
	end

	-- Car VS Car SMASH: the showroom, rebuilt when the number of stands changes
	local roomKey: { [Instance]: string } = {}
	local function buildShowroom(plot: Instance, pivot: CFrame)
		local owned = (tonumber(plot:GetAttribute("OwnerId")) or 0) ~= 0
		local ids = if owned then tostring(plot:GetAttribute("Garage") or "") else ""
		local karts = if ids == "" then 0 else #string.split(ids, ",")
		local racer = owned and type(plot:GetAttribute("RacerCar")) == "string"
		local stands = PlotShowroom.standCount(karts, racer)
		local key = tostring(stands)
		if roomKey[plot] == key then
			return
		end
		roomKey[plot] = key
		local old = plot:FindFirstChild("Showroom")
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "Showroom"
		model:SetAttribute("Stands", stands)
		Garage.makeParts(PlotShowroom.pieces(stands), model, pivot)
		model.WorldPivot = pivot
		model.Parent = plot
	end

	for _, slot in LobbyLayout.slots() do
		local plot = workspace.Plots:FindFirstChild(slot.index .. "_" .. slot.id)
		-- (Car VS Car: every plot is a training garage, the drift ones too)
		if plot and (slot.id ~= "drift" or Features.CVC) then
			-- put the track away now, and again whenever one is built back in (TrackBuilder
			-- still makes the starter track on owner changes): only the newest is kept
			local function stash(track: Instance)
				if track.Name ~= "Track" or track.Parent ~= plot then
					return
				end
				local older = store:FindFirstChild(plot.Name)
				if older then
					older:Destroy()
				end
				track.Name = plot.Name
				track.Parent = store
			end
			local track = plot:FindFirstChild("Track")
			if track then
				stash(track)
			end
			plot.ChildAdded:Connect(function(child)
				if child.Name == "Track" then
					task.defer(stash, child)
				end
			end)
			local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
			if Features.CVC and Features.SMASH then
				buildShowroom(plot, pivot)
				for _, name in { "OwnerId", "Garage", "RacerCar" } do
					plot:GetAttributeChangedSignal(name):Connect(function()
						buildShowroom(plot, pivot)
					end)
				end
				continue
			end
			if Features.CVC then
				buildTraining(plot, pivot)
				for _, name in
					{ "OwnerId", "PlotLevel", "GarageLevel", "Trophies", "Stations", "NextOpen" }
				do
					plot:GetAttributeChangedSignal(name):Connect(function()
						buildTraining(plot, pivot)
					end)
				end
				continue
			end
			build(plot, pivot)
			plot:GetAttributeChangedSignal("PlotLevel"):Connect(function()
				build(plot, pivot)
			end)
			plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
				build(plot, pivot)
				follow(plot)
			end)
			plot:GetAttributeChangedSignal("Parked"):Connect(function()
				showIncome(plot)
			end)
			follow(plot)
		end
	end
end

return PlotGarageBuilder
