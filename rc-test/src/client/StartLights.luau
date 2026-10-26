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
	-- a lobby plot, or a big race map (its model carries the race's Slot)
	local list = {}
	for _, name in { "Plots", "RaceMaps" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			for _, m in folder:GetChildren() do
				table.insert(list, m)
			end
		end
	end
	for _, m in list do
		if m:GetAttribute("Slot") == slot then
			for i = 1, 3 do
				local p = m:FindFirstChild("StartLamp" .. i, true)
				if p and p:IsA("BasePart") then
					table.insert(lamps, p)
				end
			end
			if #lamps == 0 then
				-- a built track: its start tile's gantry has three lamps all called "StartLamp"
				for _, d in m:GetDescendants() do
					if d.Name == "StartLamp" and d:IsA("BasePart") then
						table.insert(lamps, d)
					end
				end
			end
		end
	end
	-- left to right along the beam (the way the lamps are spread out most)
	if #lamps > 1 then
		local lo, hi = lamps[1].Position, lamps[1].Position
		for _, p in lamps do
			lo, hi = lo:Min(p.Position), hi:Max(p.Position)
		end
		local spread = hi - lo
		local alongX = spread.X >= spread.Z
		table.sort(lamps, function(a: BasePart, b: BasePart): boolean
			return if alongX then a.Position.X < b.Position.X else a.Position.Z < b.Position.Z
		end)
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
