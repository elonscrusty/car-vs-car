--!strict
-- A car's real look in 3D for a screen (the round's winner, the crate reveal): CarSkin.copyOf gives
-- carter's own model, else the kart (with its kid driver), else the toy car, lit in a ViewportFrame
-- and turning slowly. Anything that goes wrong gives nil, so the screen keeps its drawn car.
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))

local KartView = {}

-- A car's real kart turning in a 3D window at x, y, w, h (design px); nil when it can't be made
-- (then the caller's drawn car shows).
function KartView.make(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	carId: string?,
	z: number?
): ViewportFrame?
	if not carId then
		return nil
	end
	local client = script.Parent.Parent.Parent
	local mod = client:FindFirstChild("CarSkin")
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	-- (any trouble making it: the drawn car instead, never a screen that fails to build)
	local ok, made = pcall(function()
		return (require(mod) :: any).copyOf(carId)
	end)
	if not ok then
		return nil
	end
	if not (made and typeof(made) == "Instance" and made:IsA("Model")) then
		return nil
	end
	local model = made :: Model
	local view = Instance.new("ViewportFrame")
	view.Name = "Kart"
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(190, 190, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-0.4, -1, -0.6)
	view.ZIndex = z or 4
	view.Parent = parent
	Base.at(view, x, y, w, h)
	local world = Instance.new("WorldModel")
	world.Parent = view
	model:PivotTo(CFrame.identity)
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local mid = cf.Position
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- far enough back that the kart's longest side fits, from a little above and in front
	local dist = math.max(size.X, size.Y, size.Z) / math.tan(math.rad(15)) * 0.62
	cam.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.35, 1).Unit * dist, mid)
	cam.Parent = view
	view.CurrentCamera = cam
	-- turning slowly (stops when the screen closes)
	task.spawn(function()
		local a = math.rad(-30)
		while view.Parent do
			a += 0.02
			model:PivotTo(CFrame.new(mid) * CFrame.Angles(0, a, 0) * CFrame.new(-mid))
			task.wait(1 / 30)
		end
	end)
	return view
end

-- Puts the kart over a drawn car (Icons.car's spot): the drawing hides, the 3D kart fills the spot.
-- false (and the drawing stays) when no kart can be made.
function KartView.over(spot: GuiObject, carId: string?): boolean
	local view = KartView.make(spot, 0, 0, 1, 1, carId, spot.ZIndex + 1)
	if not view then
		return false
	end
	view.Position = UDim2.fromScale(0, 0)
	view.Size = UDim2.fromScale(1, 1)
	for _, c in spot:GetChildren() do
		if c ~= view and c:IsA("GuiObject") then
			c.Visible = false
		end
	end
	return true
end

return KartView
