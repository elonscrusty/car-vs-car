--!strict
-- Every player's car parked in a spot of the lobby with their name over it (LobbyLayout.parking, 24
-- spots). Look only. A spot is taken when the player's car is shown and freed when they leave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(script.Parent.Appearance)
local Build = require(ReplicatedStorage.Shared.Build)
local LobbyCarModels = require(script.Parent.LobbyCarModels)
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

local CAR_LENGTH = 11

type Spot = { cf: CFrame, player: Player?, model: Model?, sign: TextLabel, anchor: Part }

function LobbyParking.new(folder: Folder, origin: Vector3): Handle
	local group = MapParts.group(folder, "Parking")
	local spots: { Spot } = {}
	for i, s in LobbyLayout.parking() do
		local pos = origin + Vector3.new(s.x, 0.05, s.z)
		-- the nose points at the front path (left side faces +x, right side -x)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(if s.side == -1 then 1 else -1, 0, 0))
		local anchor = MapParts.part(
			group,
			"Spot" .. i,
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(pos + Vector3.new(0, 6.5, 0)),
			Color3.new(1, 1, 1),
			false
		)
		anchor.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(190, 34)
		gui.MaxDistance = 110
		gui.LightInfluence = 0
		gui.Enabled = false
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 22
		label.TextColor3 = Color3.fromRGB(237, 240, 234)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(20, 26, 40)
		label.Parent = gui
		table.insert(spots, { cf = cf, player = nil, model = nil, sign = label, anchor = anchor })
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
		if s.model then
			s.model:Destroy()
			s.model = nil
		end
		s.player = nil
		s.sign.Text = ""
		local gui = s.anchor:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = false
		end
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
		if spot.model then
			spot.model:Destroy()
			spot.model = nil
		end
		spot.player = player
		local model = LobbyCarModels.make(group, carId, CAR_LENGTH)
		if look and look.paintColor then
			LobbyCarModels.paint(model, look.paintColor)
		end
		LobbyCarModels.place(model, spot.cf)
		spot.model = model
		spot.sign.Text = sign
		local gui = spot.anchor:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = true
		end
	end
	handle.clear = function(player)
		local s = spotOf(player)
		if s then
			empty(s)
		end
	end
	handle.destroy = function()
		for _, s in spots do
			empty(s)
		end
		group:Destroy()
	end
	return handle
end

return LobbyParking
