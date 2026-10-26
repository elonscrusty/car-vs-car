--!strict
-- Builds the garage yard on each plot (PlotGarage has the layout): the little loop road, the
-- coin pile pad, the LEVEL UP sign and the looks for the plot's level. Only while plots are
-- garages (Features.GARAGES on, PLOT_RACING off): then each plot's old track is put away in
-- ServerStorage (kept, so it can come back; one TrackBuild makes later goes there too) and the
-- yard goes in its place. The open drift plot keeps its track for free drift play. Rebuilt when
-- the plot's level or owner changes (TycoonServer sets PlotLevel on the owner's plot). The cars
-- and the coins are drawn by PlotGarage.client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotGarage = require(ReplicatedStorage.Shared.PlotGarage)
local Tycoon = require(ReplicatedStorage.Shared.Tycoon)

local PlotGarageBuilder = {}

-- Words on the road side of the sign (its Back face: the plot's +z).
local function label(board: BasePart, top: string, bottom: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local function line(text: string, y: number, h: number, color: Color3)
		local l = Instance.new("TextLabel")
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
	line(top, 0.06, 0.52, Color3.new(1, 1, 1))
	line(bottom, 0.6, 0.34, Color3.fromRGB(255, 220, 90))
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
	if Features.PLOT_RACING or not Features.GARAGES then
		return
	end
	local store: Instance = ServerStorage:FindFirstChild("HiddenPlotTracks")
		or Instance.new("Folder")
	store.Name = "HiddenPlotTracks"
	store.Parent = ServerStorage
	local built: { [Instance]: number } = {}

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
		model.WorldPivot = pivot
		model.Parent = plot
	end

	for _, slot in LobbyLayout.slots() do
		local plot = workspace.Plots:FindFirstChild(slot.index .. "_" .. slot.id)
		if plot and slot.id ~= "drift" then
			-- put the track away now, and again whenever one is built back in (TrackBuild
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
			build(plot, pivot)
			plot:GetAttributeChangedSignal("PlotLevel"):Connect(function()
				build(plot, pivot)
			end)
			plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
				build(plot, pivot)
			end)
		end
	end
end

return PlotGarageBuilder
