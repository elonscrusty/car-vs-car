--!strict
-- The 16 parking spots of the lobby (LobbyLayout.parking), each a slowly spinning car-show stand
-- (carter's L24). A player's car takes a spot with their name over it; every other spot shows a
-- real car you can win from the gumball machine (L23), so the lot is never empty. Look only.
-- A spot is taken when the player's car is shown and goes back to a show car when they leave.
-- The stand is tagged "LobbySpin": each player's device turns it (LobbyClient), the server never
-- moves it, so it costs nothing to keep spinning.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(script.Parent.Appearance)
local Build = require(ReplicatedStorage.Shared.Build)
local LobbyCarModels = require(script.Parent.LobbyCarModels)
local LobbyCars = require(ReplicatedStorage.Shared.LobbyCars)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyParking = {}

export type Handle = {
	-- Show (or change) this player's car. `sign` is the text over it ("NAME  LV 3").
	set: (
		player: Player,
		carId: string,
		look: Appearance.Appearance?,
		build: Build.BuildData?,
		sign: string
	) -> (),
	clear: (player: Player) -> (),
	destroy: () -> (),
}

-- A car turns on its stand, so it must fit a spot (10.4 studs deep) all the way round.
local CAR_LENGTH = 7.6 -- room to spare inside the glowing rim
local STAND_D = 9.6
local STAND_H = 0.8
local SPIN_SPEED = 0.45 -- radians a second: one turn in about 14 seconds

local rgb = MapParts.rgb

type Spot = {
	faceX: number, -- the way the car's nose points when it is put on the stand: toward the path
	player: Player?,
	stand: Model,
	glow: Part,
	car: Model?,
	sign: TextLabel,
	gui: BillboardGui,
	decor: string?, -- the show car this spot falls back to
}

local WHITE = Color3.fromRGB(237, 240, 234)

local function buildStand(group: Folder, index: number, pos: Vector3): (Model, Part)
	local stand = Instance.new("Model")
	stand.Name = "CarStand" .. index
	-- a glowing rim under a dark disc: the rim color tells the rarity of the car on it
	local glow = MapParts.can(
		stand,
		"StandGlow",
		STAND_D + 1.2,
		0.25,
		pos,
		rgb(LobbyLayout.colors.blue),
		false,
		nil,
		Enum.Material.Neon
	)
	MapParts.can(
		stand,
		"StandDisc",
		STAND_D,
		STAND_H,
		pos + Vector3.new(0, 0.1, 0),
		rgb(LobbyLayout.colors.asphaltDark),
		false,
		nil,
		Enum.Material.Metal
	)
	-- an invisible hub in the middle is the pivot, so the whole stand turns round its middle
	local hub = MapParts.part(
		stand,
		"Hub",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(pos + Vector3.new(0, STAND_H + 0.1, 0)),
		WHITE,
		false
	)
	hub.Transparency = 1
	stand.PrimaryPart = hub
	stand:SetAttribute("SpinSpeed", SPIN_SPEED)
	CollectionService:AddTag(stand, "LobbySpin")
	stand.Parent = group
	return stand, glow
end

function LobbyParking.new(folder: Folder, origin: Vector3): Handle
	local group = MapParts.group(folder, "CarStands")
	local spots: { Spot } = {}
	local decorList = LobbyCars.decorCars()
	for i, s in LobbyLayout.parking() do
		local pos = origin + Vector3.new(s.x, 0.05, s.z)
		local stand, glow = buildStand(group, i, pos)
		local anchor = MapParts.part(
			stand,
			"SignAnchor",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(pos + Vector3.new(0, 7, 0)),
			WHITE,
			false
		)
		anchor.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(150, 26)
		gui.MaxDistance = 45
		gui.LightInfluence = 0
		gui.Enabled = false
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 17
		label.TextColor3 = WHITE
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(20, 26, 40)
		label.Parent = gui
		table.insert(spots, {
			faceX = if s.side == -1 then 1 else -1,
			player = nil,
			stand = stand,
			glow = glow,
			car = nil,
			sign = label,
			gui = gui,
			-- neighbours show different cars, so a column is never one car over and over
			decor = if #decorList > 0 then decorList[(i - 1) % #decorList + 1] else nil,
		})
	end

	-- The car on a spot's stand: a look-only copy standing on the stand's top, nose toward the path.
	local function showCar(spot: Spot, carId: string, look: Appearance.Appearance?)
		if spot.car then
			spot.car:Destroy()
			spot.car = nil
		end
		local model = LobbyCarModels.make(spot.stand, carId, CAR_LENGTH)
		if look and look.paintColor then
			LobbyCarModels.paint(model, look.paintColor)
		end
		local top = spot.stand.PrimaryPart :: BasePart
		LobbyCarModels.place(
			model,
			CFrame.lookAt(top.Position, top.Position + Vector3.new(spot.faceX, 0, 0))
		)
		spot.car = model
		spot.glow.Color = rgb(LobbyCars.rarityColor(carId))
	end

	local function showDecor(spot: Spot)
		local id = spot.decor
		if id == nil then
			spot.gui.Enabled = false
			return
		end
		showCar(spot, id, nil)
		spot.sign.Text = string.upper(LobbyCars.nameOf(id))
		spot.sign.TextColor3 = rgb(LobbyCars.rarityColor(id))
		spot.gui.Enabled = true
	end

	for _, spot in spots do
		showDecor(spot)
	end

	local function spotOf(player: Player): Spot?
		for _, s in spots do
			if s.player == player then
				return s
			end
		end
		return nil
	end

	local function empty(s: Spot)
		s.player = nil
		showDecor(s)
	end

	local handle = {} :: Handle
	handle.set = function(player, carId, look, _build, sign)
		local spot = spotOf(player)
		if spot == nil then
			for _, s in spots do
				if s.player == nil then
					spot = s
					break
				end
			end
		end
		if spot == nil then
			return -- every spot is taken: this player simply has none
		end
		spot.player = player
		showCar(spot, carId, look)
		spot.sign.Text = sign
		spot.sign.TextColor3 = WHITE
		spot.gui.Enabled = true
	end
	handle.clear = function(player)
		local s = spotOf(player)
		if s then
			empty(s)
		end
	end
	handle.destroy = function()
		for _, s in spots do
			s.player = nil
			s.car = nil
		end
		group:Destroy()
	end
	return handle
end

return LobbyParking
