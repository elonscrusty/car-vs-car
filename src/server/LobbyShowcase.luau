--!strict
-- The show cars of the lobby: the rarest gumball car and the weekly #1's gold car turning on the
-- workshop stages, the three battle cars in the shop and the car on the customize turntable (it
-- shows the car of whoever last opened the garage). Spinning is one slow Heartbeat loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyCars = require(ReplicatedStorage.Shared.LobbyCars)
local LobbyCarModels = require(script.Parent.LobbyCarModels)

local LobbyShowcase = {}

export type Spots = {
	stageRare: CFrame,
	stageGold: CFrame,
	goldSign: TextLabel,
	shopSpots: { CFrame },
	turntable: Part,
	turntableCF: CFrame,
}

export type Handle = {
	setChampion: (name: string?) -> (), -- the weekly #1's name on the gold stage (nil = nobody yet)
	setTurntable: (carId: string) -> (), -- the car on the customize turntable
	stop: () -> (),
}

local STAGE_LENGTH = 15
local SHOP_LENGTH = 11
local TURN_LENGTH = 12
local SPIN_SPEED = 0.7 -- radians per second
local STEP = 0.05

type Spinner = { model: Model, base: CFrame, center: Vector3 }

function LobbyShowcase.start(folder: Folder, spots: Spots): Handle
	local group = Instance.new("Folder")
	group.Name = "ShowCars"
	group.Parent = folder
	local spinners: { Spinner } = {}
	local function addSpinner(model: Model, cf: CFrame): Spinner
		local base = LobbyCarModels.place(model, cf)
		local s = { model = model, base = base, center = cf.Position }
		table.insert(spinners, s)
		return s
	end

	local rare = LobbyCars.rarestGumball() or "SawBuggy"
	addSpinner(LobbyCarModels.make(group, rare, STAGE_LENGTH), spots.stageRare)
	local goldModel = LobbyCarModels.make(group, "RamTruck", STAGE_LENGTH)
	LobbyCarModels.gold(goldModel)
	addSpinner(goldModel, spots.stageGold)
	spots.goldSign.Text = "TOP DRIVER"

	for i, id in LobbyCars.shopDisplay() do
		local cf = spots.shopSpots[i]
		if cf then
			LobbyCarModels.place(LobbyCarModels.make(group, id, SHOP_LENGTH), cf)
		end
	end

	local turnCar: Spinner? = nil
	local function setTurntable(carId: string)
		if turnCar then
			local i = table.find(spinners, turnCar)
			if i then
				table.remove(spinners, i)
			end
			turnCar.model:Destroy()
		end
		turnCar = addSpinner(LobbyCarModels.make(group, carId, TURN_LENGTH), spots.turntableCF)
	end
	setTurntable("RamTruck")

	local angle = 0
	local acc = 0
	local base = spots.turntable.CFrame
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		angle += acc * SPIN_SPEED
		acc = 0
		for _, s in spinners do
			LobbyCarModels.spin(s.model, s.base, s.center, angle)
		end
		-- the turntable disc turns with its car (a cylinder: its length axis is x)
		spots.turntable.CFrame = base * CFrame.Angles(angle, 0, 0)
	end)

	return {
		setChampion = function(name: string?)
			spots.goldSign.Text = if name and name ~= "" then `TOP DRIVER: {name}` else "TOP DRIVER"
		end,
		setTurntable = setTurntable,
		stop = function()
			conn:Disconnect()
		end,
	}
end

return LobbyShowcase
