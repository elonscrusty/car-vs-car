--!strict
-- The VS screen shown before a fight: both cars big, the driver names, one funny line each, and the
-- 3-2-1 in the middle. Layout and logic only: carter skins it (every piece has a clear name).
-- Left is you (blue), right is the opponent (orange). The server decides everything; this only shows
-- what the prep message carries (me / opp: id, name, line) and falls back to VsLines for the line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local VsLines = require(ReplicatedStorage.Shared.VsLines)

local VsScreen = {}

export type Handle = {
	show: (m: any, endsAt: number) -> (),
	hide: () -> (),
	visible: () -> boolean,
	tick: (now: number) -> (),
}

local FONT = Enum.Font.GothamBold
local COL_ME = Color3.fromRGB(70, 150, 255)
local COL_OPP = Color3.fromRGB(255, 140, 60)
local COL_PANEL = Color3.fromRGB(20, 24, 40)
local COL_TEXT = Color3.fromRGB(245, 247, 255)

local function text(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	maxSize: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = ""
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.fromRGB(10, 12, 22)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = 8
	c.Parent = l
	l.Parent = parent
	return l
end

-- A car in a viewport (the same models the pick screen shows). A missing model leaves the box empty.
local function fillViewport(vp: ViewportFrame, carId: string)
	local f = BattleConfig.Fighters[carId]
	local models = ReplicatedStorage:FindFirstChild("BattleModels")
	local src = if f and models then models:FindFirstChild(f.model) else nil
	if src == nil or not src:IsA("Model") then
		return
	end
	local clone = src:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	clone.Parent = world
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	local cf, size = clone:GetBoundingBox()
	local cam = Instance.new("Camera")
	local dist = size.Magnitude * 1.1
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-0.75, 0.5, -1) * dist * 0.8, cf.Position)
	cam.FieldOfView = 40
	vp.CurrentCamera = cam
	cam.Parent = vp
end

type Panel = { root: Frame, view: ViewportFrame, name: TextLabel, line: TextLabel }

local function buildPanel(parent: Instance, name: string, x: number, color: Color3): Panel
	local root = Instance.new("Frame")
	root.Name = name
	root.Size = UDim2.fromScale(0.36, 0.62)
	root.Position = UDim2.fromScale(x, 0.16)
	root.BackgroundColor3 = COL_PANEL
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = color
	stroke.Parent = root
	local view = Instance.new("ViewportFrame")
	view.Name = "CarView"
	view.Size = UDim2.fromScale(0.94, 0.5)
	view.Position = UDim2.fromScale(0.03, 0.03)
	view.BackgroundColor3 = Color3.fromRGB(34, 40, 62)
	view.BorderSizePixel = 0
	view.Parent = root
	local vc = Instance.new("UICorner")
	vc.CornerRadius = UDim.new(0, 12)
	vc.Parent = view
	local nameL = text(
		root,
		"DriverName",
		UDim2.fromScale(0.94, 0.14),
		UDim2.fromScale(0.03, 0.55),
		color,
		34
	)
	local lineL =
		text(root, "Line", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.71), COL_TEXT, 24)
	return { root = root, view = view, name = nameL, line = lineL }
end

function VsScreen.new(gui: ScreenGui): Handle
	local root = Instance.new("Frame")
	root.Name = "VsScreen"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
	root.BackgroundTransparency = 0.35
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = gui
	local me = buildPanel(root, "MePanel", 0.03, COL_ME)
	local opp = buildPanel(root, "OppPanel", 0.61, COL_OPP)
	local vs =
		text(root, "VsText", UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.4, 0.22), COL_TEXT, 90)
	vs.Text = "VS"
	local count =
		text(root, "Count", UDim2.fromScale(0.2, 0.22), UDim2.fromScale(0.4, 0.46), COL_TEXT, 110)
	local endsAt = 0

	local function fill(p: Panel, who: any)
		p.name.Text = tostring(who.name or "")
		p.line.Text = VsLines.lineFor(
			tostring(who.id or ""),
			VsLines.seedOf(tostring(who.name or "")),
			who.line
		)
		for _, c in p.view:GetChildren() do
			c:Destroy()
		end
		fillViewport(p.view, tostring(who.id or ""))
	end

	return {
		show = function(m: any, ends: number)
			fill(me, m.me)
			fill(opp, m.opp)
			endsAt = ends
			count.Text = tostring(math.max(1, math.ceil(ends - os.clock())))
			root.Visible = true
		end,
		hide = function()
			root.Visible = false
		end,
		visible = function(): boolean
			return root.Visible
		end,
		tick = function(now: number)
			if root.Visible then
				count.Text = tostring(math.max(0, math.ceil(endsAt - now)))
			end
		end,
	}
end

return VsScreen
