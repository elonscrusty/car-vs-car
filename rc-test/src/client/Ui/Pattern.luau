--!strict
-- The sliding sparkle-and-diamond pattern (spec 7): behind the words of every button, side tile,
-- slot, selected tab, offer card, glowing card, daily tile and blue popup. A 44 px tile, white at
-- 26% on colors (ink at 8% on white), sliding 44 px right and down every 3.4 s.
--
-- The tile picture, best first:
--   1. Images.PATTERN: the tile uploaded to Roblox (pattern-tile.png in project files)
--   2. drawn in the game once (EditableImage) from UiPattern
--   3. no picture allowed: little frames (a sparkle and a holed diamond per tile)
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local UiPattern = require(Shared:WaitForChild("UiPattern"))
local Base = require(script.Parent:WaitForChild("Base"))
local Anim = require(script.Parent:WaitForChild("Anim"))
local Images = require(script.Parent:WaitForChild("Images"))

local P = UiTheme.PATTERN
local TILE = P.tile

local Pattern = {}

local content: Content? = nil
local tried = false
local function tileContent(): Content?
	if tried then
		return content
	end
	tried = true
	if Images.PATTERN ~= "" then
		content = Content.fromUri(Images.PATTERN)
		return content
	end
	local ok, got = pcall(function()
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(TILE, TILE) })
		local buf = buffer.create(TILE * TILE * 4)
		UiPattern.fill(buf)
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(TILE, TILE), buf)
		return Content.fromObject(img)
	end)
	content = if ok then got else nil
	return content
end

-- the frames version of one tile (only when no picture can be made)
local function drawTile(parent: Instance, x: number, y: number)
	-- the 4-point sparkle: two thin rounded bars crossed, a small diamond in the middle (no text
	-- glyph: the game font has no ✦)
	local cx, cy, sz = x + P.sparkle.x, y + P.sparkle.y, P.sparkle.size
	local function spark(name: string, w: number, h: number, rot: number, round: UDim)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Base.WHITE
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx, cy)
		f.Size = UDim2.fromOffset(w, h)
		f.Rotation = rot
		f:SetAttribute("Spark", true)
		local c = Instance.new("UICorner")
		c.CornerRadius = round
		c.Parent = f
		f.Parent = parent
	end
	spark("SparkUp", 3, sz, 0, UDim.new(0.5, 0))
	spark("SparkSide", sz, 3, 0, UDim.new(0.5, 0))
	spark("SparkMid", sz * 0.36, sz * 0.36, 45, UDim.new(0, 1))
	local di = Instance.new("Frame")
	di.Name = "Diamond"
	di.BackgroundTransparency = 1
	di.AnchorPoint = Vector2.new(0.5, 0.5)
	di.Position = UDim2.fromOffset(x + P.diamond.x, y + P.diamond.y)
	local side = P.diamond.size / math.sqrt(2) - 2
	di.Size = UDim2.fromOffset(side, side)
	di.Rotation = 45
	di.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = Base.WHITE
	s.Thickness = 2.6
	s.Parent = di
end

-- Fill `clip` (a frame that clips) with the moving pattern, under its other children.
-- dark: ink at 8% (on white things) instead of white at 26%.
function Pattern.attach(clip: GuiObject, dark: boolean?): GuiObject
	clip.ClipsDescendants = true
	local alpha = if dark then P.onWhite else P.onColor
	local tint = if dark then Base.color("ink") else Base.WHITE
	local c = tileContent()
	local layer: GuiObject
	if c then
		local img = Instance.new("ImageLabel")
		img.Name = "Pattern"
		img.BackgroundTransparency = 1
		img.ImageContent = c
		img.ScaleType = Enum.ScaleType.Tile
		img.ImageTransparency = 1 - alpha
		img.ImageColor3 = tint
		img.ZIndex = 0
		img.Parent = clip
		layer = img
		local function size()
			local t = TILE * Base.k
			img.TileSize = UDim2.fromOffset(t, t)
			img.Size = UDim2.new(1, t, 1, t)
		end
		size()
		Base.onScale(size)
	else
		local f = Instance.new("Frame")
		f.Name = "Pattern"
		f.BackgroundTransparency = 1
		f.ZIndex = 0
		f.Parent = clip
		layer = f
		local w, h = Base.designSize(clip)
		local inner = Instance.new("Frame")
		inner.Name = "Tiles"
		inner.BackgroundTransparency = 1
		inner.Size =
			UDim2.fromOffset((math.ceil(w / TILE) + 1) * TILE, (math.ceil(h / TILE) + 1) * TILE)
		inner.Parent = f
		local sc = Instance.new("UIScale")
		sc.Scale = Base.k
		sc.Parent = inner
		Base.onScale(function()
			sc.Scale = Base.k
		end)
		for ty = 0, math.ceil(h / TILE) do
			for tx = 0, math.ceil(w / TILE) do
				drawTile(inner, tx * TILE, ty * TILE)
			end
		end
		for _, d in inner:GetDescendants() do
			if d:IsA("Frame") and d:GetAttribute("Spark") then
				d.BackgroundTransparency = 1 - alpha
				d.BackgroundColor3 = tint
			elseif d:IsA("UIStroke") then
				d.Transparency = 1 - alpha
				d.Color = tint
			end
		end
		f.Size = UDim2.new(1, TILE * Base.k, 1, TILE * Base.k)
	end
	-- slide: one shared clock, whole px only
	local last = -1
	local function place(t: number)
		local off = math.floor(UiMotion.patternOffset(t) * Base.k + 0.5)
		if off ~= last then
			last = off
			local t44 = math.floor(TILE * Base.k + 0.5)
			layer.Position = UDim2.fromOffset(off - t44, off - t44)
		end
	end
	place(0)
	if not Base.reduced() then
		Anim.tick(layer, place)
	end
	return layer
end

-- The design system's still dot pattern on white window bodies (faint blue dots, 22 px apart).
function Pattern.dots(clip: GuiObject)
	clip.ClipsDescendants = true
	local w, h = Base.designSize(clip)
	local holder = Instance.new("Frame")
	holder.Name = "Dots"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 0
	holder.Parent = clip
	-- a light grid: every 44 px (one dot per tile keeps the frame count low)
	local blue = Base.color("blue")
	for y = 22, h - 10, 44 do
		for x = 22, w - 10, 44 do
			local d = Instance.new("Frame")
			d.Name = "Dot"
			d.BackgroundColor3 = blue
			d.BackgroundTransparency = 0.88
			d.BorderSizePixel = 0
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Position = UDim2.fromScale(x / w, y / h)
			d.Size = UDim2.fromScale(4 / w, 4 / h)
			d.ZIndex = 0
			d.Parent = holder
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = d
		end
	end
end

return Pattern
