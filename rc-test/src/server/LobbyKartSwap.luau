--!strict
-- Smash: the realistic blue sports coupe carter made with Studio's AI mesh tool
-- (Workspace.PurpleSportsCoupe, two copies, by the spawn plaza) clashes with the toy karts
-- (auditor round 12). It is kept, moved to ServerStorage (nothing deleted), and an imported kart
-- in the coupe's blue parks where its first copy stood. Nothing happens without the coupe or the
-- karts (ReplicatedStorage.CarSkins).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ToyCars = require(ReplicatedStorage.Shared.ToyCars)

local LobbyKartSwap = {}

LobbyKartSwap.COUPE = "PurpleSportsCoupe"
LobbyKartSwap.KART = "Kart_HotRod"
LobbyKartSwap.LONG = 9 -- studs nose to tail: a lobby show kart, bigger than a player's
local BLUE = ToyCars.PALETTE.sky
local STYLE = "muscle/white"

function LobbyKartSwap.start()
	local coupe = workspace:FindFirstChild(LobbyKartSwap.COUPE)
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local src = skins and skins:FindFirstChild(LobbyKartSwap.KART)
	if not (coupe and coupe:IsA("Model") and src and src:IsA("Model")) then
		return
	end
	-- where its first copy stands: the top-level body (the second copy is nested deeper)
	local body = coupe:FindFirstChild("body") or coupe:FindFirstChildWhichIsA("BasePart", true)
	local at = if body and body:IsA("BasePart") then body.CFrame else coupe:GetPivot()
	local _, coupeSize = coupe:GetBoundingBox()
	local floorY = coupe:GetPivot().Position.Y - coupeSize.Y / 2
	if body and body:IsA("BasePart") then
		floorY = body.Position.Y - body.Size.Y / 2
	end
	for _, d in coupe:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true -- (kept still in storage)
		end
	end
	coupe.Parent = ServerStorage

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
	-- (stand it on the coupe's floor, turned the coupe's way, flat)
	local look = at.LookVector * Vector3.new(1, 0, 1)
	local yaw = if look.Magnitude > 0.01 then math.atan2(-look.X, -look.Z) else 0
	local lift = kart:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	kart:PivotTo(CFrame.new(at.Position.X, floorY + lift, at.Position.Z) * CFrame.Angles(0, yaw, 0))
	kart.Parent = workspace
end

return LobbyKartSwap
