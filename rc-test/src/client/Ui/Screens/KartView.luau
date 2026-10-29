--!strict
-- A car's real look in 3D for a screen (the round's winner, the crate reveal): CarSkin.copyOf gives
-- carter's own model, else the kart (with its kid driver), else the toy car, lit in a ViewportFrame
-- and turning slowly. Anything that goes wrong gives nil, so the screen keeps its drawn car.
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local SmashScreens = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SmashScreens")
)

local FOV = 30

-- The box round a model's visible parts (an invisible root or hitbox would make the kart a speck).
local function visibleBox(m: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local half = d.Size / 2
			for _, c in
				{
					Vector3.new(-1, -1, -1),
					Vector3.new(-1, -1, 1),
					Vector3.new(-1, 1, -1),
					Vector3.new(-1, 1, 1),
					Vector3.new(1, -1, -1),
					Vector3.new(1, -1, 1),
					Vector3.new(1, 1, -1),
					Vector3.new(1, 1, 1),
				}
			do
				local p = d.CFrame:PointToWorldSpace(half * c)
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
	end
	if lo.X > hi.X then
		local cf, size = m:GetBoundingBox()
		return cf.Position, size
	end
	return (lo + hi) / 2, hi - lo
end

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
	-- (moved, not turned: a kart CarSkin turned nose-first keeps that turn; PivotTo(identity)
	-- undid it and the reveal showed the kart's back, Studio 10-29)
	model:TranslateBy(-model:GetPivot().Position)
	model.Parent = world
	local mid, size = visibleBox(model)
	local base = model:GetPivot() -- (its own turn: the spin is on top of it)
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	-- back just far enough that the turning kart fills KART_FILL of the width, from a little above
	local function fit()
		local px = view.AbsoluteSize
		local aspect = if px.Y > 0 then px.X / px.Y else (if h > 0 then w / h else 1.4)
		local dist =
			SmashScreens.kartDistance(size.X, size.Y, size.Z, FOV, aspect, SmashScreens.KART_FILL)
		cam.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.3, 1).Unit * dist, mid)
	end
	fit()
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	cam.Parent = view
	view.CurrentCamera = cam
	-- turning slowly (stops when the screen closes)
	task.spawn(function()
		local a = math.rad(-20) -- (starts almost front-on: auditor round 13)
		while view.Parent do
			a += 0.02
			model:PivotTo(CFrame.new(mid) * CFrame.Angles(0, a, 0) * CFrame.new(-mid) * base)
			task.wait(1 / 30)
		end
	end)
	return view
end

-- Puts the kart over a drawn car (Icons.car's spot): the drawing hides, the 3D kart fills the spot
-- (a little past it).
-- false (and the drawing stays) when no kart can be made.
function KartView.over(spot: GuiObject, carId: string?): boolean
	local view = KartView.make(spot, 0, 0, 1, 1, carId, spot.ZIndex + 1)
	if not view then
		return false
	end
	-- (a bit bigger than the drawing's spot, on its middle: the card has room round it)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1.25, 1.25)
	for _, c in spot:GetChildren() do
		if c ~= view and c:IsA("GuiObject") then
			c.Visible = false
		end
	end
	return true
end

return KartView
