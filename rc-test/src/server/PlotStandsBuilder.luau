--!strict
-- Builds the car show at each plot (PlotStands has the layout): the owner's best car on the
-- turning podium, the rest on the shelf, and the board with their name and car count. The cars
-- someone has: their player attribute "CarIds" (car ids, set by CarShop). Rebuilt when the
-- plot's owner or that list changes. A plot nobody owns shows an empty shelf and a blank board.
-- The podium car carries the tag "ShowSpin"; ShowSpin.client turns it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotStands = require(ReplicatedStorage.Shared.PlotStands)
local LobbyPlots = require(script.Parent.LobbyPlots)

local PlotStandsBuilder = {}

-- Words on the road side of the board (its Back face: the plot's +z).
local function label(board: BasePart, top: string, bottom: string)
	local gui = Instance.new("SurfaceGui")
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
		l.Text = text
		l.Parent = gui
	end
	line(top, 0.05, 0.55, Color3.new(1, 1, 1))
	line(bottom, 0.6, 0.36, Color3.fromRGB(255, 200, 50))
end

function PlotStandsBuilder.start()
	local slots = LobbyLayout.slots()
	local shown: { [number]: string } = {} -- what each plot's show has now
	local watching: { [Player]: RBXScriptConnection } = {}
	local had: { [number]: string } = {} -- each owner's last list, to spot a new car

	local function rebuild(slot: number)
		local s = slots[slot]
		local plot = workspace.Plots:FindFirstChild(slot .. "_" .. s.id)
		if not plot then
			return
		end
		local owner = LobbyPlots.ownerOf(slot)
		local list = if owner then tostring(owner:GetAttribute("CarIds") or "") else ""
		local key = if owner then owner.UserId .. "|" .. list else "-"
		if shown[slot] == key then
			return
		end
		shown[slot] = key
		local old = plot:FindFirstChild("Stands")
		if old then
			old:Destroy()
		end
		local cars = if owner then PlotStands.parse(list) else {}
		local model = Instance.new("Model")
		model.Name = "Stands"
		local pivot = CFrame.new(s.plotX, 0, s.plotZ) * CFrame.Angles(0, s.angle, 0)
		local groups = Garage.makeParts(PlotStands.pieces(cars), model, pivot)
		local board = groups.Show and groups.Show:FindFirstChild("Board")
		if owner and board and board:IsA("BasePart") then
			label(board, PlotStands.words(owner.DisplayName, #cars))
		end
		-- a car just bought or won: its spot glows the next time the owner comes near
		-- (ShowSpin.client plays it)
		if owner then
			local fresh = PlotStands.fresh(had[owner.UserId], list)
			had[owner.UserId] = list
			for i, c in cars do
				if fresh[c.id] then
					local spot = if i == 1
						then groups.Show and groups.Show:FindFirstChild("Ring")
						else groups.Show and groups.Show:FindFirstChild("Plate" .. (i - 1))
					if spot then
						spot:SetAttribute("NewFor", owner.UserId)
						CollectionService:AddTag(spot, "ShowNew")
					end
				end
			end
		end
		local hero = groups.Hero
		if hero then
			local h = PlotStands.HERO
			hero.WorldPivot = pivot * CFrame.new(h.x, h.top, h.z)
			CollectionService:AddTag(hero, "ShowSpin")
		end
		model.Parent = plot
		-- follow the owner's list
		if owner and not watching[owner] then
			watching[owner] = owner:GetAttributeChangedSignal("CarIds"):Connect(function()
				local mine = LobbyPlots.slotOf(owner)
				if mine then
					rebuild(mine)
				end
			end)
			owner.AncestryChanged:Connect(function()
				if not owner.Parent and watching[owner] then
					watching[owner]:Disconnect()
					watching[owner] = nil
				end
			end)
		end
	end

	for i in slots do
		rebuild(i)
	end
	LobbyPlots.changed:Connect(rebuild)
end

return PlotStandsBuilder
