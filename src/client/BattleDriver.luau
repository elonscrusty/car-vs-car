--!strict
-- Drives YOUR car on this device during a fight. The server hands your device the physics of
-- your own car (network ownership, model attribute "ClientDriven"), so the car answers the
-- stick or keys right away instead of after a round trip. The server still decides weapons,
-- hits, HP and the winner, and tells this driver about knocks and weapon states through model
-- attributes: KnockUntil (server time), BState / BDrive / BTurn (a ram charge, recoil or skid).
-- When the server drives the car instead, this does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleDrive = require(ReplicatedStorage.Shared.BattleDrive)

export type Driver = {
	start: () -> (),
	stop: () -> (),
}

local BattleDriver = {}

-- `read` gives the current (steer, gas) from the stick or keys (steer +1 = right, gas -1 = reverse).
-- `findBody` gives my car's Body part, or nil while it is not in the world.
function BattleDriver.new(read: () -> (number, number), findBody: () -> BasePart?): Driver
	local conn: RBXScriptConnection? = nil
	local mover: BattleDrive.Mover? = nil
	local seenKnock: any = nil
	local flippedFor = 0

	local function mine(body: BasePart): BattleDrive.Mover?
		local model = body.Parent
		if model == nil or not model:IsA("Model") then
			return nil
		end
		if mover ~= nil and mover.model == model then
			return mover
		end
		local fighter = BattleConfig.fighter(model:GetAttribute("FighterId"))
		local L = model:GetAttribute("CarL")
		if fighter == nil or type(L) ~= "number" then
			return nil
		end
		seenKnock = model:GetAttribute("KnockUntil")
		mover = {
			body = body,
			model = model,
			L = L,
			fighter = fighter,
			stagger = 0,
			slide = Vector3.zero,
			lastForward = Vector3.new(0, 0, -1),
			momentum = false,
		}
		return mover
	end

	local function step(dt: number)
		local body = findBody()
		if body == nil or body.Parent == nil then
			mover = nil
			return
		end
		local model = body.Parent
		if model == nil or model:GetAttribute("ClientDriven") ~= true then
			return
		end
		local car = mine(body)
		if car == nil then
			return
		end
		-- the server knocked this car: slide on the shove for as long as it says
		local knock = model:GetAttribute("KnockUntil")
		if knock ~= seenKnock then
			seenKnock = knock
			if type(knock) == "number" then
				car.stagger = math.max(car.stagger, knock - workspace:GetServerTimeNow())
				car.slide = Vector3.zero
			end
		end
		-- the server cannot turn a car this device owns, so a flipped car rights itself here
		if body.CFrame.UpVector.Y < BattleConfig.Move.flipUpDot then
			flippedFor += dt
			if flippedFor >= BattleConfig.Move.flipSeconds then
				flippedFor = 0
				local look = body.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.1 then
					flat = car.lastForward
				end
				local pos = body.Position + Vector3.new(0, 0.25 * car.L, 0)
				local rel = body.CFrame:ToObjectSpace(model:GetPivot())
				model:PivotTo(CFrame.lookAt(pos, pos + flat) * rel)
				body.AssemblyLinearVelocity = Vector3.zero
				body.AssemblyAngularVelocity = Vector3.zero
			end
		else
			flippedFor = 0
		end
		local out: BattleDrive.Out
		local state = model:GetAttribute("BState")
		if state == "charge" or state == "recoil" or state == "skid" then
			local d, t = model:GetAttribute("BDrive"), model:GetAttribute("BTurn")
			out = {
				state = state,
				drive = if type(d) == "number" then d else 0,
				turn = if type(t) == "number" then t else 0,
			}
		else
			local steer, gas = read()
			out = { state = "drive", drive = gas, turn = -steer }
		end
		BattleDrive.drive(car, out, dt)
	end

	local function start()
		if conn then
			return
		end
		mover, seenKnock, flippedFor = nil, nil, 0
		conn = RunService.PreSimulation:Connect(step)
	end

	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		mover = nil
	end

	return { start = start, stop = stop }
end

return BattleDriver
