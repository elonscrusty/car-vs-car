--!strict
-- Drives YOUR car on this device during the fight. The server hands you the physics of your own
-- car (network ownership), so it answers your stick right away instead of waiting for a round
-- trip. The server still decides hits, HP and the winner, and slows the car if it ever goes
-- faster than the game allows. Falls back to nothing if the server still drives the car (then
-- the Steer messages from SteerInput move it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local CarDrive = require(ReplicatedStorage.Shared.CarDrive)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Moves = require(ReplicatedStorage.Shared.Moves)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local Steer = require(ReplicatedStorage.Shared.Steer)

export type DriveCar = {
	start: () -> (),
	stop: () -> (),
}

local DriveCar = {}

local FIND_EVERY = 0.2 -- seconds between searches for the own car

-- `read` gives the current (steer, gas) from the stick or keys.
-- `onBoost` (optional) runs when YOUR car starts a boost (the camera widens, speed lines show).
function DriveCar.new(read: () -> (number, number), onBoost: (() -> ())?): DriveCar
	local conn: RBXScriptConnection? = nil

	local function start()
		if conn then
			return
		end
		local me = Players.LocalPlayer :: Player
		local model: Model? = nil
		local body: BasePart? = nil
		local stats: CarConfig.CarStats? = nil
		local sinceSearch = FIND_EVERY
		local steer, gas = 0, 0
		local flipTimer = 0
		local seenBoostAt: any = nil
		local drift = Moves.newDrift()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		conn = RunService.Heartbeat:Connect(function(dt: number)
			if model == nil or model.Parent == nil then
				model, body, stats = nil, nil, nil
				sinceSearch += dt
				if sinceSearch < FIND_EVERY then
					return
				end
				sinceSearch = 0
				-- Cars sit directly inside the "Arena" folders, so no need to scan the whole world.
				local candidates: { Instance } = {}
				for _, arena in workspace:GetChildren() do
					if arena.Name == "Arena" then
						for _, m in arena:GetChildren() do
							table.insert(candidates, m)
						end
					end
				end
				for _, m in candidates do
					if m:IsA("Model") and m:GetAttribute("DriverUserId") == me.UserId then
						local b = m:FindFirstChild("Body")
						local s = CarConfig.get(m:GetAttribute("CarId"))
						if b and b:IsA("BasePart") and s then
							model, body, stats = m, b, s
							rayParams.FilterDescendantsInstances = { m }
							flipTimer = 0
							ground = CarDrive.newGroundMemory()
							seenBoostAt = m:GetAttribute("BoostAt") -- an old boost does not count
							steer, gas = 0, 0
							drift = Moves.newDrift()
							break
						end
					end
				end
				return
			end
			local m, b, s = model, body :: BasePart, stats :: CarConfig.CarStats
			local boostMark = m:GetAttribute("BoostAt")
			if boostMark ~= seenBoostAt then
				seenBoostAt = boostMark
				if onBoost ~= nil and type(boostMark) == "number" then
					onBoost()
				end
			end
			if b.Anchored then
				return -- frozen for a hit stop
			end
			local rawSteer, rawGas = read()
			-- The stick points where the car should go ON SCREEN (the camera stays steady).
			local cam = workspace.CurrentCamera
			if cam ~= nil then
				local cl, kl = cam.CFrame.LookVector, b.CFrame.LookVector
				rawSteer, rawGas = Steer.toward(
					rawSteer,
					rawGas,
					cl.X,
					cl.Z,
					kl.X,
					kl.Z,
					GameConfig.Steer.aimLock,
					steer
				)
			end
			steer = Steer.smooth(steer, rawSteer, dt, GameConfig.Steer.smoothRate)
			gas = Steer.smooth(gas, rawGas, dt, GameConfig.Steer.smoothRate)

			local v = b.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local gripScale, turnScale = Moves.driftStep(drift, steer, speed, dt, MovesConfig.Drift)
			local boostAt = m:GetAttribute("BoostAt")
			local sinceBoost = if type(boostAt) == "number"
				then workspace:GetServerTimeNow() - boostAt
				else math.huge
			local mods: CarDrive.Mods = {
				speedScale = Moves.boostSpeedMult(sinceBoost, MovesConfig.Boost),
				accelScale = Moves.boostAccelMult(sinceBoost, MovesConfig.Boost),
				gripScale = gripScale * (if type(m:GetAttribute("GripMult")) == "number"
					then m:GetAttribute("GripMult") :: number
					else 1),
				turnScale = turnScale,
			}
			local speedMult = m:GetAttribute("SpeedMult")
			flipTimer = CarDrive.manual(
				m,
				b,
				s,
				flipTimer,
				steer,
				gas,
				dt,
				rayParams,
				mods,
				if type(speedMult) == "number" then speedMult else 1
			)
		end)
	end

	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	return { start = start, stop = stop }
end

return DriveCar
