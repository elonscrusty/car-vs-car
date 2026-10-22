--!strict
-- The copy cars in the lobby: while someone drives a plot, a little car on that plot's small
-- copy follows their real car (same spot and heading, shrunk), so people walking by see it.
-- Looks only: anchored, no collisions. The server moves them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local MiniCars = {}

export type MiniCars = {
	-- car's world CFrame on the small plot (nil = hide it)
	place: (player: Player, cf: CFrame?) -> (),
	remove: (player: Player) -> (),
}

local SIZE = Vector3.new(Tuning.bodyX, Tuning.bodyY, Tuning.bodyZ)
	* (LobbyLayout.MINI * LobbyLayout.MINI_CAR)

local function part(model: Model, name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

local function build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local body = part(model, "Body", SIZE, Color3.fromRGB(220, 50, 47))
	local cabin = part(
		model,
		"Cabin",
		Vector3.new(SIZE.X * 0.7, SIZE.Y * 0.8, SIZE.Z * 0.4),
		Color3.fromRGB(35, 35, 40)
	)
	cabin.CFrame = body.CFrame * CFrame.new(0, SIZE.Y * 0.9, SIZE.Z * 0.05)
	model.PrimaryPart = body
	return model
end

function MiniCars.new(parent: Instance): MiniCars
	local cars: { [Player]: Model } = {}
	local self = {} :: MiniCars

	function self.place(player: Player, cf: CFrame?)
		local car = cars[player]
		if cf == nil then
			if car then
				car.Parent = nil
			end
			return
		end
		if car == nil then
			car = build("MiniCar_" .. player.UserId)
			cars[player] = car
		end
		-- the bigger-than-true-scale body would sink into the floor: lift it by the extra height
		car:PivotTo(cf * CFrame.new(0, SIZE.Y * (1 - 1 / LobbyLayout.MINI_CAR) / 2, 0))
		car.Parent = parent
	end

	function self.remove(player: Player)
		local car = cars[player]
		if car then
			car:Destroy()
			cars[player] = nil
		end
	end

	return self
end

return MiniCars
