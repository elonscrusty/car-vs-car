--!strict
-- Keeps the drift plot's start gantry out of the way while you drive (polish tour 6): seen from
-- the top-down drift view, its tall black-and-yellow beam ran right down the middle of the
-- screen. While "Driving" is on, this screen hides the gantry (posts, beam, stripes and its
-- start light) on every drift plot; on foot it shows again. Looks only: the parts stay where
-- they are and still block the same as before.

local Players = game:GetService("Players")

local me = Players.LocalPlayer
local NAMES = { Gantry = true, GantryStripe = true }

-- every gantry piece on the drift plots, found again each time driving turns on or off (plots
-- can be rebuilt between drives)
local function pieces(): { BasePart }
	local out: { BasePart } = {}
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return out
	end
	local holders: { [Instance]: boolean } = {}
	for _, d in plots:GetDescendants() do
		if d:IsA("BasePart") and NAMES[d.Name] then
			table.insert(out, d)
			if d.Parent then
				holders[d.Parent] = true
			end
		end
	end
	-- the start light mesh on top of the beam sits beside those pieces
	for holder in holders do
		for _, m in holder:GetChildren() do
			if m.Name == "StartLight" then
				if m:IsA("BasePart") then
					table.insert(out, m)
				end
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(out, d)
					end
				end
			end
		end
	end
	return out
end

local function apply()
	local hide = if me:GetAttribute("Driving") == true then 1 else 0
	for _, p in pieces() do
		p.LocalTransparencyModifier = hide
	end
end

me:GetAttributeChangedSignal("Driving"):Connect(apply)
apply()
