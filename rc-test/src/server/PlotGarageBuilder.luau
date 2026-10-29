--!strict
-- Builds the garage yard on each plot (PlotGarage has the layout): the little loop road, the
-- coin pile pad, the LEVEL UP sign and the looks for the plot's level. Only while plots are
-- garages (Features.GARAGES on): then each plot's old track is put away in
-- ServerStorage (kept, so it can come back) and the
-- yard goes in its place. The open drift plot keeps its track for free drift play. Rebuilt when
-- the plot's level or owner changes (TycoonServer sets PlotLevel on the owner's plot). The cars
-- and the coins are drawn by PlotGarage.client.
-- Car VS Car (Features.CVC on, the Smash game): a "Showroom" model instead (PlotShowroom has the layout):
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
local PropKit = require(ReplicatedStorage.Shared.PropKit)
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
		local groups = Garage.makeParts(PlotShowroom.pieces(stands), model, pivot)
		-- the banner's words, in the game's chunky font, on its gate side
		local board = groups.Banner and groups.Banner:FindFirstChild("BannerBoard")
		if board and board:IsA("BasePart") then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Words"
			gui.Face = Enum.NormalId.Back
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.04, 0.1)
			l.Size = UDim2.fromScale(0.92, 0.8)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(255, 95, 180) -- a neon sign: pink, a white edge
			l.TextStrokeTransparency = 0
			l.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
			l.Text = PlotShowroom.BANNER_TEXT
			l.Parent = gui
			gui.Parent = board
		end
		-- the tyre stacks and barrels, from the shared PropKit (one look with the arena)
		local props = Instance.new("Model")
		props.Name = "Props"
		for _, p in PlotShowroom.PROPS do
			local at = (pivot * CFrame.new(p.x, 0.36, p.z)).Position
			if p.kind == "tyres" then
				PropKit.tyreStack(props, at, p.h)
			elseif p.kind == "barrel" then
				PropKit.barrel(props, at, p.h)
			end
		end
		props.Parent = model
		-- each bay's number on its tile, in the game font
		local bays = groups.Bays
		for i in PlotShowroom.SPOTS do
			local tile = bays and bays:FindFirstChild("BayNumber" .. i)
			if tile and tile:IsA("BasePart") then
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Top
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 40
				gui.LightInfluence = 0
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.fromScale(1, 1)
				l.Font = Enum.Font.FredokaOne
				l.TextScaled = true
				l.TextColor3 = Color3.fromRGB(255, 210, 63)
				l.Text = tostring(i)
				l.Parent = gui
				gui.Parent = tile
			end
		end
		-- each lamp bulb gets a soft light, not Neon (as LOBBY's lamps, #999)
		local lamps = groups.Lamps
		if lamps then
			for _, bulb in lamps:GetChildren() do
				if bulb:IsA("BasePart") and bulb.Name == "LampBulb" then
					local glow = Instance.new("PointLight")
					glow.Range = 10
					glow.Brightness = 1
					glow.Color = bulb.Color
					glow.Parent = bulb
				end
			end
		end
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
			if Features.CVC then
				buildShowroom(plot, pivot)
				for _, name in { "OwnerId", "Garage", "RacerCar" } do
					plot:GetAttributeChangedSignal(name):Connect(function()
						buildShowroom(plot, pivot)
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
