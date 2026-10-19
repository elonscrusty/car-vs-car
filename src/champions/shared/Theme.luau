-- Native GUI components shared by every Champions Garage screen.
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local Config = require(script.Parent.Config)
local Assets = require(script.Parent.Assets)
local T = {}
local RGB = Color3.fromRGB
T.font = Font.fromEnum(Enum.Font.Bangers)
T.C = {
	ink = RGB(2, 10, 20),
	navy = RGB(5, 23, 45),
	panel = RGB(12, 39, 67),
	blue = RGB(0, 113, 245),
	cyan = RGB(35, 216, 255),
	red = RGB(238, 28, 49),
	silver = RGB(205, 224, 242),
	white = RGB(251, 253, 255),
	muted = RGB(144, 175, 203),
	gold = RGB(255, 201, 35),
	green = RGB(136, 244, 27),
	purple = RGB(181, 57, 243),
}
local C = T.C
local reducedMotion = false
function T.configure(state)
	reducedMotion = state.settings and state.settings.reducedMotion == true
end
local function make(class, props, parent)
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	local value = object:FindFirstChildOfClass("UICorner") or make("UICorner", {}, object)
	value.CornerRadius = UDim.new(0, radius or 10)
	return value
end
local function stroke(object, color, width, transparency)
	return make("UIStroke", {
		Color = color or C.ink,
		Thickness = width or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end
local function gradient(object, top, bottom)
	object.BackgroundColor3 = C.white
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, object)
end
function T.monoTime()
	return workspace:GetServerTimeNow()
end
function T.find(id)
	return Config.ById[id]
end
function T.format(value)
	if type(value) ~= "number" then
		return "—"
	end
	return tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
function T.frame(parent, name, x, y, w, h, color, radius)
	local f = make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.panel,
		BorderSizePixel = 0,
	}, parent)
	if radius and radius > 0 then
		corner(f, radius)
	end
	return f
end
function T.panel(parent, name, x, y, w, h, accent)
	local f = T.frame(parent, name, x, y, w, h, C.panel, 12)
	gradient(f, RGB(16, 49, 81), RGB(3, 20, 40))
	stroke(f, C.ink, 4)
	local inset = T.frame(f, "MetalBezel", 2, 2, w - 4, h - 4, C.navy, 10)
	inset.BackgroundTransparency = 1
	stroke(inset, accent or C.silver, 2)
	local rim = T.frame(f, "TopEdge", 12, 4, math.max(0, w - 24), 1, C.white, 0)
	rim.BackgroundTransparency = 0.55
	return f
end
-- Smallest text the menus use (menu units; a phone shrinks the menu canvas to ~0.6).
local MIN_SIZE = 26
local MIN_BOX = 32 -- a text box is never shorter than this, so small labels can grow
function T.text(parent, name, value, x, y, w, h, size, color, align)
	size = size or 22
	color = color or C.white
	if h < MIN_BOX then
		y -= (MIN_BOX - h) / 2
		h = MIN_BOX
	end
	local label = make("TextLabel", {
		Name = name,
		Text = tostring(value),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		FontFace = T.font,
		TextSize = size,
		TextColor3 = color,
		TextStrokeColor3 = C.ink,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment[align or "Left"],
		TextYAlignment = Enum.TextYAlignment.Center,
		-- Text shrinks to fit its box instead of ending in "...".
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.None,
		RichText = false,
	}, parent)
	make(
		"UITextSizeConstraint",
		{ MaxTextSize = math.max(size, MIN_SIZE), MinTextSize = 10 },
		label
	)
	if color.R + color.G + color.B > 1.2 then
		-- Light text gets a thick dark outline so it reads over the game.
		label.TextStrokeTransparency = 1
		make("UIStroke", {
			Color = C.ink,
			Thickness = math.clamp(size * 0.07, 1.5, 3),
			Transparency = 0.15,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
		}, label)
	end
	return label
end
function T.checkers(parent, x, y, w, h, cell, color)
	local f = T.frame(parent, "Checkers", x, y, w, h, C.navy, 0)
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	for row = 0, math.ceil(h / cell) - 1 do
		for col = 0, math.ceil(w / cell) - 1 do
			if (row + col) % 2 == 0 then
				T.frame(f, "Square", col * cell, row * cell, cell, cell, color or C.white, 0)
			end
		end
	end
	return f
end
function T.icon(parent, name, kind, x, y, size, color)
	color = color or C.white
	local f = T.frame(parent, name, x, y, size, size, C.ink, 0)
	f.BackgroundTransparency = 1
	local function block(a, b, w, h, r, fill)
		return T.frame(
			f,
			"Shape",
			a * size,
			b * size,
			w * size,
			h * size,
			fill or color,
			r and r * size or 0
		)
	end
	local function bar(a, b, w, h, angle)
		local q = block(a, b, w, h, 0.025)
		q.Rotation = angle or 0
		return q
	end
	if kind == "coin" then
		local coin = block(0.03, 0.03, 0.94, 0.94, 0.48, C.gold)
		stroke(coin, RGB(145, 81, 0), 2)
		local rim = block(0.17, 0.17, 0.66, 0.66, 0.34, RGB(255, 224, 72))
		stroke(rim, RGB(255, 244, 161), 2)
		T.text(
			f,
			"Star",
			"★",
			size * 0.19,
			size * 0.16,
			size * 0.62,
			size * 0.65,
			size * 0.52,
			RGB(219, 139, 1),
			"Center"
		)
	elseif kind == "car" then
		block(0.1, 0.4, 0.8, 0.38, 0.08)
		block(0.25, 0.16, 0.5, 0.35, 0.06)
		block(0.16, 0.7, 0.18, 0.22, 0.04)
		block(0.66, 0.7, 0.18, 0.22, 0.04)
		block(0.33, 0.24, 0.34, 0.16, 0.02, C.navy)
	elseif kind == "shop" then
		bar(0.05, 0.13, 0.26, 0.08, 12)
		bar(0.25, 0.24, 0.08, 0.45, -10)
		bar(0.29, 0.28, 0.61, 0.09)
		bar(0.33, 0.6, 0.48, 0.08)
		bar(0.8, 0.3, 0.08, 0.33, 12)
		block(0.35, 0.76, 0.14, 0.14, 0.07)
		block(0.71, 0.76, 0.14, 0.14, 0.07)
	elseif kind == "gift" then
		block(0.1, 0.37, 0.8, 0.17, 0.02)
		block(0.17, 0.55, 0.66, 0.37, 0.03)
		block(0.44, 0.36, 0.12, 0.56, 0, C.navy)
		local a = block(0.22, 0.06, 0.3, 0.29, 0.13)
		a.BackgroundTransparency = 1 -- open loops, not solid blobs
		stroke(a, color, math.max(2, size * 0.07))
		local b = block(0.49, 0.06, 0.3, 0.29, 0.13)
		b.BackgroundTransparency = 1
		stroke(b, color, math.max(2, size * 0.07))
	elseif kind == "close" then
		bar(0.12, 0.44, 0.78, 0.13, 45)
		bar(0.12, 0.44, 0.78, 0.13, -45)
	elseif kind == "check" then
		bar(0.13, 0.55, 0.36, 0.13, 45)
		bar(0.36, 0.39, 0.58, 0.13, -45)
	elseif kind == "lock" then
		local ring = block(0.27, 0.06, 0.46, 0.58, 0.23)
		ring.BackgroundTransparency = 1
		stroke(ring, color, 3)
		block(0.17, 0.44, 0.66, 0.47, 0.06)
		block(0.46, 0.57, 0.08, 0.21, 0.025, C.navy)
	elseif kind == "flag" or kind == "race" then
		bar(0.14, 0.1, 0.06, 0.84, 7)
		T.checkers(f, size * 0.28, size * 0.12, size * 0.65, size * 0.46, size * 0.16, color)
	elseif kind == "trophy" then
		block(0.25, 0.08, 0.5, 0.46, 0.13)
		bar(0.45, 0.5, 0.1, 0.3)
		bar(0.27, 0.82, 0.46, 0.1)
		local cup = block(0.06, 0.13, 0.88, 0.3, 0.13)
		cup.BackgroundTransparency = 1
		stroke(cup, color, 3)
	elseif kind == "back" then
		bar(0.16, 0.3, 0.42, 0.12, -45)
		bar(0.16, 0.57, 0.42, 0.12, 45)
		bar(0.32, 0.43, 0.56, 0.13)
	elseif kind == "reset" then
		local ring = block(0.14, 0.14, 0.72, 0.72, 0.36)
		ring.BackgroundTransparency = 1
		stroke(ring, color, math.max(2, size * 0.09))
		block(0.1, 0.05, 0.38, 0.22, 0.02)
		bar(0.13, 0.22, 0.3, 0.12, -35)
	elseif kind == "claw" then
		bar(0.45, 0.04, 0.1, 0.41)
		bar(0.21, 0.44, 0.35, 0.1, -38)
		bar(0.45, 0.44, 0.35, 0.1, 38)
		bar(0.15, 0.62, 0.13, 0.27, -20)
		bar(0.72, 0.62, 0.13, 0.27, 20)
	elseif kind == "soccer" then
		local ball = block(0.04, 0.04, 0.92, 0.92, 0.48, C.white)
		stroke(ball, C.ink, 2)
		local q = block(0.33, 0.33, 0.34, 0.34, 0.06, C.navy)
		q.Rotation = 45
		for _, p in { { 0.09, 0.12 }, { 0.68, 0.12 }, { 0.07, 0.7 }, { 0.71, 0.7 } } do
			local a = block(p[1], p[2], 0.19, 0.19, 0.03, C.navy)
			a.Rotation = 20
		end
	elseif kind == "tag" then
		local tag = block(0.2, 0.12, 0.63, 0.77, 0.08, C.red)
		tag.Rotation = 32
		block(0.4, 0.2, 0.13, 0.13, 0.065, C.navy)
	elseif kind == "duel" then
		bar(0.12, 0.42, 0.77, 0.12, 45)
		bar(0.12, 0.42, 0.77, 0.12, -45)
		bar(0.1, 0.63, 0.32, 0.1, 45)
		bar(0.6, 0.63, 0.32, 0.1, -45)
	elseif kind == "Dash" or kind == "boost" then
		for i = 0, 1 do
			bar(0.13 + i * 0.35, 0.25, 0.4, 0.12, 45)
			bar(0.13 + i * 0.35, 0.55, 0.4, 0.12, -45)
		end
	elseif kind == "Shield" then
		local shield = block(0.16, 0.12, 0.68, 0.67, 0.23)
		shield.BackgroundTransparency = 1 -- outline only, so the point and cross show
		stroke(shield, color, math.max(2, size * 0.07))
		local point = block(0.33, 0.53, 0.34, 0.34, 0.04)
		point.Rotation = 45
		bar(0.45, 0.26, 0.1, 0.4)
		bar(0.3, 0.4, 0.4, 0.1)
	elseif kind == "Slam" then
		-- a down arrow hitting the ground
		bar(0.45, 0.1, 0.1, 0.5)
		bar(0.22, 0.42, 0.4, 0.11, 45)
		bar(0.38, 0.42, 0.4, 0.11, -45)
		bar(0.14, 0.83, 0.72, 0.09)
	elseif kind == "Ram" then
		local bumper = block(0.14, 0.35, 0.72, 0.37, 0.07)
		bumper.BackgroundTransparency = 1
		stroke(bumper, color, 3)
		bar(0.13, 0.1, 0.27, 0.08, 45)
		bar(0.61, 0.1, 0.27, 0.08, -45)
	elseif kind == "Magnet" then
		local u = block(0.17, 0.1, 0.66, 0.77, 0.29)
		u.BackgroundTransparency = 1
		stroke(u, color, math.max(3, size * 0.1))
		block(0.31, 0.07, 0.38, 0.4, 0, C.navy)
	elseif kind == "Jump" then
		bar(0.2, 0.26, 0.4, 0.11, -45)
		bar(0.4, 0.26, 0.4, 0.11, 45)
		bar(0.45, 0.23, 0.1, 0.49)
		bar(0.16, 0.83, 0.68, 0.09)
	else
		T.text(f, "Glyph", "•", 0, 0, size, size, size * 0.8, color, "Center")
	end
	return f
end
local buttons = setmetatable({}, { __mode = "k" })
function T.activate(button)
	local callback = buttons[button]
	if callback and button.Parent and not button:GetAttribute("Disabled") then
		callback()
	end
end
function T.labelSize(button, size)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextSize = size
		local fit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if fit then
			fit.MaxTextSize = size
		end
	end
end
function T.button(parent, name, label, x, y, w, h, callback, color, icon)
	color = color or C.blue
	local bare = label == "" and not icon
	local b = make("TextButton", {
		Name = name,
		Text = "",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BackgroundTransparency = bare and 1 or 0,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Selectable = true,
	}, parent)
	buttons[b] = callback
	b:SetAttribute("TouchMinimum", 48)
	if not bare then
		corner(b, 10)
		stroke(b, C.ink, 4)
		gradient(b, color:Lerp(C.white, 0.16), color:Lerp(C.ink, 0.22))
		local rim = T.frame(b, "ButtonBezel", 2, 2, w - 4, h - 4, C.navy, 8)
		rim.BackgroundTransparency = 1
		stroke(rim, color:Lerp(C.white, 0.45), 1.5)
		local edge = T.frame(b, "ButtonEdge", 10, 5, w - 20, 2, C.white, 0)
		edge.BackgroundTransparency = 0.55
		if w > 150 and h > 48 then
			local pattern = T.checkers(b, math.max(0, w - 70), 5, 60, h - 10, 16, C.white)
			pattern.BackgroundTransparency = 1
			for _, q in pattern:GetChildren() do
				if q:IsA("Frame") then
					q.BackgroundTransparency = 0.94
				end
			end
		end
	end
	local hasIcon = icon ~= nil
	local stacked = hasIcon and w <= h * 1.4
	if hasIcon then
		local iconSize = stacked and h * 0.47 or math.min(h - 12, 38)
		T.icon(
			b,
			"Icon",
			icon,
			stacked and (w - iconSize) / 2 or 12,
			stacked and h * 0.1 or math.max(5, (h - 34) / 2),
			iconSize,
			color == C.green and C.ink or C.white
		)
	end
	local tx = hasIcon and not stacked and math.min(h + 4, 62) or 8
	local caption = T.text(
		b,
		"Label",
		label,
		tx,
		0,
		w - tx - 8,
		h,
		math.min(32, math.max(17, h * 0.43)),
		color == C.green and C.ink or C.white,
		"Center"
	)
	caption.TextTruncate = Enum.TextTruncate.None
	caption.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = math.min(32, math.max(17, h * 0.43))
	fit.MinTextSize = 8
	fit.Parent = caption
	if stacked then
		caption.Position = UDim2.fromOffset(4, h * 0.64)
		caption.Size = UDim2.fromOffset(w - 8, h * 0.3)
		fit.MaxTextSize = math.min(26, math.max(16, h * 0.28))
	end
	if bare then
		caption.Visible = false
	end
	local highlight = T.frame(b, "Highlight", 2, 2, w - 4, h - 4, C.white, 8)
	highlight.BackgroundTransparency = 1
	local function feedback(value)
		if reducedMotion then
			highlight.BackgroundTransparency = value
		else
			TweenService:Create(highlight, TweenInfo.new(0.1), { BackgroundTransparency = value })
				:Play()
		end
	end
	b.Activated:Connect(function()
		T.activate(b)
	end)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Disabled") then
			feedback(0.92)
		end
	end)
	b.MouseLeave:Connect(function()
		feedback(1)
	end)
	b.SelectionGained:Connect(function()
		feedback(0.85)
	end)
	b.SelectionLost:Connect(function()
		feedback(1)
	end)
	-- Invisible extension preserves phone thumb targets after the menu canvas scales.
	local hit = make("TextButton", {
		Name = "TouchTarget",
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Selectable = false,
		ZIndex = 6,
	}, b)
	hit.Activated:Connect(function()
		T.activate(b)
	end)
	local function fitHit()
		local scale = math.max(0.05, b.AbsoluteSize.X / math.max(1, w))
		hit.Size = UDim2.fromOffset(math.max(w, 50 / scale), math.max(h, 50 / scale))
	end
	b:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHit)
	task.defer(fitHit)
	return b
end
function T.disable(button, disabled)
	button:SetAttribute("Disabled", disabled == true)
	button.Active = not disabled
	button.Selectable = not disabled
	local hit = button:FindFirstChild("TouchTarget")
	if hit then
		hit.Active = not disabled
	end
	local label = button:FindFirstChild("Label")
	if label then
		label.TextTransparency = disabled and 0.35 or 0
	end
end
function T.vehicle(parent, name, vehicle, x, y, w, h)
	local image = make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Image = Assets.Vehicles[vehicle.Id] or "",
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	image:SetAttribute("VehicleId", vehicle.Id)
	return image
end
function T.rarity(parent, vehicle, x, y, w, h)
	local color = Config.RarityColors[vehicle.Rarity] or C.silver
	local f = T.frame(parent, "Rarity", x, y, w, h, color, math.min(9, h * 0.3))
	stroke(f, C.ink, 2)
	local label = T.text(
		f,
		"RarityLabel",
		string.upper(vehicle.Rarity),
		4,
		0,
		w - 8,
		h,
		math.min(26, h * 0.74),
		C.ink,
		"Center"
	)
	-- The word stays inside its chip: undo the minimum box height and cap the size by the chip.
	label.Position = UDim2.fromOffset(4, 0)
	label.Size = UDim2.fromOffset(w - 8, h)
	local cap = label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = math.floor(h * 0.8)
	end
	label.TextStrokeTransparency = 1
	return f
end
function T.menu(parent, name)
	local root = T.frame(parent, name, 0, 0, 1200, 675, C.navy, 0)
	root.BackgroundTransparency = 1 -- see-through: the game shows behind the panels
	return root
end
function T.header(parent, _title, state, ctx)
	local head = T.frame(parent, "Header", 12, 9, 1176, 80, C.silver, 15)
	stroke(head, C.ink, 4)
	gradient(head, RGB(243, 249, 255), RGB(137, 165, 194))
	local brand = T.text(head, "Brand", "CAR", 16, -1, 144, 43, 43, C.white)
	brand.TextStrokeTransparency = 0.1
	T.text(head, "VS", "VS", 100, 2, 46, 34, 30, C.gold).TextStrokeTransparency = 0
	T.text(head, "BrandGold", "CAR", 39, 34, 137, 44, 43, C.gold).TextStrokeTransparency = 0.1
	T.checkers(head, 160, 21, 106, 42, 14, C.navy)
	for i, mode in if #Config.Modes > 1 then Config.Modes else {} do
		local pill = T.button(
			head,
			"Mode_" .. mode.Id,
			mode.Name,
			286 + (i - 1) * 148,
			12,
			140,
			56,
			function()
				if #Config.Modes > 1 then
					ctx.navigate("MODES")
				end
			end,
			C.navy,
			string.lower(mode.Id)
		)
		T.labelSize(pill, 20)
	end
	local chip = T.panel(head, "Coins", 886, 12, 206, 56, C.navy)
	T.icon(chip, "Coin", "coin", 8, 7, 41, C.gold)
	T.text(chip, "Balance", T.format(state.coins), 56, 0, 144, 56, 32, C.white, "Center")
	T.button(head, "Close", "", 1103, 12, 61, 56, ctx.close, C.red, "close")
	return head
end
function T.nav(parent, active, ctx)
	T.checkers(parent, 12, 611, 1176, 50, 25, C.silver)
	for i, entry in
		{ { "CARS", "car", C.red }, { "SHOP", "shop", C.blue }, { "GIFT", "gift", C.navy } }
	do
		local b = T.button(
			parent,
			"Nav_" .. entry[1],
			entry[1],
			58 + (i - 1) * 366,
			596,
			352,
			67,
			function()
				ctx.navigate(entry[1])
			end,
			entry[3],
			entry[2]
		)
		T.labelSize(b, 37)
		if active == entry[1] then
			stroke(b, C.cyan, 2)
		end
	end
end
function T.scroll(parent, name, x, y, w, h)
	return make("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.cyan,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
	}, parent)
end
function T.cooldown(parent, name, label, ability, x, y, size, callback)
	local color = name == "Boost" and C.blue or C.red
	local b = T.button(parent, name, "", x, y, size, size, callback, color, ability)
	corner(b, size / 2)
	local icon = b:FindFirstChild("Icon")
	if icon then
		icon.Position = UDim2.fromOffset(size * 0.27, size * 0.13)
		icon.Size = UDim2.fromOffset(size * 0.46, size * 0.46)
	end
	local arc = T.frame(b, "CooldownArc", 5, 5, size - 10, size - 10, C.ink, size / 2)
	arc.BackgroundTransparency = 1
	stroke(arc, color:Lerp(C.white, 0.4), 4)
	for i = 0, 11 do
		local angle = math.rad(i * 30 - 90)
		local s = T.frame(
			arc,
			"Segment" .. i,
			(size - 10) / 2 + math.cos(angle) * (size * 0.43) - 2,
			(size - 10) / 2 + math.sin(angle) * (size * 0.43) - size * 0.04,
			4,
			size * 0.08,
			C.cyan,
			1
		)
		s.Rotation = i * 30
		s:SetAttribute("Segment", i)
	end
	T.text(
		b,
		"CooldownNumber",
		"",
		size * 0.2,
		size * 0.21,
		size * 0.6,
		size * 0.38,
		size * 0.33,
		C.white,
		"Center"
	)
	b.Label.Visible = true
	b.Label.Text = label
	b.Label.Position = UDim2.fromOffset(3, size * 0.64)
	b.Label.Size = UDim2.fromOffset(size - 6, size * 0.28)
	T.labelSize(b, math.min(24, size * 0.2))
	return b
end
function T.bindHold(button, seconds, callback)
	local hold = false
	local token = 0
	local holdTween
	local hit = button:FindFirstChild("TouchTarget")
	if hit then
		hit.Visible = false
	end
	local rim = T.frame(button, "HoldProgress", 3, button.Size.Y.Offset - 7, 0, 4, C.cyan, 2)
	local function cancel()
		hold = false
		token += 1
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		rim.Size = UDim2.fromOffset(0, 4)
	end
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		if button:GetAttribute("Disabled") then
			return
		end
		hold = true
		token += 1
		local current = token
		holdTween = TweenService:Create(
			rim,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromOffset(button.Size.X.Offset - 6, 4) }
		)
		holdTween:Play()
		task.delay(seconds, function()
			if hold and token == current and button.Parent then
				cancel()
				callback()
			end
		end)
	end)
	local conn = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			cancel()
		end
	end)
	button.Destroying:Connect(function()
		cancel()
		conn:Disconnect()
	end)
end
function T.preload()
	local images = {}
	for _, id in Assets.Vehicles do
		table.insert(images, id)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(images)
		end)
	end)
end
return T
