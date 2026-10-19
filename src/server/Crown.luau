--!strict
-- Who wears the crown: the human who won the last car fight on this server. The crown shows on
-- their car in the next fight, and knocking that car out pays a bounty. Kept in memory only.

local Crown = {}

local holder: number? = nil -- UserId

function Crown.set(userId: number?)
	holder = userId
end

function Crown.has(userId: number): boolean
	return holder ~= nil and holder == userId
end

-- A gold crown on top of the car: looks only, welded, no collision.
function Crown.attach(model: Model, body: BasePart, height: number)
	local crown = Instance.new("Part")
	crown.Name = "CrownLook"
	crown.Shape = Enum.PartType.Cylinder
	crown.Size = Vector3.new(0.9, 3, 3)
	crown.Color = Color3.fromRGB(255, 205, 40)
	crown.Material = Enum.Material.Neon
	crown.CanCollide = false
	crown.CanQuery = false
	crown.CanTouch = false
	crown.Massless = true
	crown.Anchored = body.Anchored
	crown.CFrame = body.CFrame * CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.pi / 2)
	crown.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = crown
	weld.Parent = crown
	model:SetAttribute("Crown", true)
end

return Crown
