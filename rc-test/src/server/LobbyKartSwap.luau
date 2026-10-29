--!strict
-- Smash: the realistic blue sports coupe carter made with Studio's AI mesh tool
-- (Workspace.PurpleSportsCoupe, two copies, by the spawn plaza) clashes with the toy karts
-- (auditor round 12). It is kept, moved to ServerStorage (nothing deleted; LOBBY may have moved it
-- there already), and an imported kart in the coupe's blue parks on the spawn plaza near it.
-- Nothing happens without the coupe or the karts (ReplicatedStorage.CarSkins).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ToyCars = require(ReplicatedStorage.Shared.ToyCars)

local LobbyKartSwap = {}

LobbyKartSwap.COUPE = "PurpleSportsCoupe"
LobbyKartSwap.KART = "Kart_HotRod"
LobbyKartSwap.LONG = 9 -- studs nose to tail: a lobby show kart, bigger than a player's
-- on the plaza floor, clear 14x14, 27 studs from the spawn, nose to it (Studio 10-29: the coupe's own
-- spot is on the hill past the kerb, hidden in the bushes)
LobbyKartSwap.SPOT = { x = 22, y = 0, z = 892, yaw = 132 } -- (2 studs off the line to a lamp post)
local BLUE = ToyCars.PALETTE.sky
local STYLE = "muscle/white"

function LobbyKartSwap.start()
	local coupe = workspace:FindFirstChild(LobbyKartSwap.COUPE)
		or ServerStorage:FindFirstChild(LobbyKartSwap.COUPE)
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local src = skins and skins:FindFirstChild(LobbyKartSwap.KART)
	if not (coupe and coupe:IsA("Model") and src and src:IsA("Model")) then
		return
	end
	for _, d in coupe:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true -- (kept still in storage)
		end
	end
	coupe.Parent = ServerStorage -- (both copies: they are both inside it)

	local kart = src:Clone()
	kart.Name = "LobbyKart"
	for _, d in kart:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
			local col, glow = ToyCars.kartPaint(d.Name, BLUE, STYLE)
			if col then
				d.Color = Color3.fromRGB(col[1], col[2], col[3])
				d.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end
	local _, size = kart:GetBoundingBox()
	if size.Z > 0 then
		kart:ScaleTo(kart:GetScale() * LobbyKartSwap.LONG / size.Z)
	end
	local box
	box, size = kart:GetBoundingBox()
	-- (the imported kart's nose is at its pivot's -Z: Studio checked the headlights)
	local at = LobbyKartSwap.SPOT
	local lift = kart:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	kart:PivotTo(CFrame.new(at.x, at.y + lift, at.z) * CFrame.Angles(0, math.rad(at.yaw), 0))
	kart.Parent = workspace
end

return LobbyKartSwap
