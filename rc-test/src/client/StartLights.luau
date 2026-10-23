--!strict
-- The three start lamps on a race plot's start arch (built by Plots/Race as StartLamp1..3).
-- Colours change on this screen only. Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceStart = require(ReplicatedStorage.Shared.RaceStart)

local OFF = Color3.fromRGB(40, 40, 44)
local RED = Color3.fromRGB(255, 40, 30)
local GREEN = Color3.fromRGB(40, 255, 80)

local StartLights = {}

-- The lamps of the lobby plot with this slot number (none if it isn't loaded or isn't a race).
function StartLights.find(slot: number): { BasePart }
	local lamps: { BasePart } = {}
	local plots = workspace:FindFirstChild("Plots")
	if plots == nil then
		return lamps
	end
	for _, m in plots:GetChildren() do
		if m:GetAttribute("Slot") == slot then
			for i = 1, 3 do
				local p = m:FindFirstChild("StartLamp" .. i, true)
				if p and p:IsA("BasePart") then
					table.insert(lamps, p)
				end
			end
		end
	end
	return lamps
end

-- 0 = all off, 1..3 = that many red, RaceStart.GO = all green.
function StartLights.show(lamps: { BasePart }, step: number)
	for i, p in lamps do
		local lit = step >= RaceStart.GO or i <= step
		p.Color = if step >= RaceStart.GO then GREEN elseif lit then RED else OFF
		p.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

return StartLights
