--!strict
-- The build screen for the 5-min break (carter: "tiles that swap in with different road shapes
-- and some have hazards or powerups").
-- SWAP: drag a tile from the bar onto any square and it swaps in; the server turns it to fit the
--   road around it.
-- TURN: tap a tile on the grid to turn it a quarter (it spins; PC: R turns the last one). The tile
--   you just dropped or turned wears a yellow ring and a turn badge, and until you turn one the
--   hint says TAP TO TURN (carter: "add a way to rotate tiles").
-- ERASE: turn ERASE on, then tap squares.
-- First time: a big hand shows one drag from the bar to the grid, until you do it yourself.
-- This screen only draws and reports; the server checks everything and sends back the state.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BuildLayout = require(ReplicatedStorage.Shared.BuildLayout)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)

export type Piece = {
	id: string,
	name: string,
	ends: BuildLayout.Ends, -- at rotation 0
	icon: string?, -- a short mark drawn on the road
	color: Color3?, -- road colour (default asphalt)
	kind: string?, -- "road" | "hazard" | "power": the card's rim colour
}
-- c = column (1 = left), r = row (1 = front, next to the stand; drawn at the bottom)
export type Cell = { c: number, r: number, piece: string, rot: number }
export type State = {
	cols: number,
	rows: number,
	cells: { Cell },
	pieces: { Piece }, -- every tile, to draw the grid
	specials: { string }, -- ids in the drag bar, in order
	ready: boolean,
	why: string?, -- when not ready: "Road has a gap"
	secondsLeft: number,
}
export type Options = {
	onDrop: (c: number, r: number, piece: string) -> (), -- swap in, turned to fit
	onPlace: (c: number, r: number, piece: string, rot: number) -> (), -- as it is, turned rot
	onRemove: (c: number, r: number) -> (),
	onDone: () -> (),
}
export type BuildScreen = {
	setState: (state: State) -> (),
	setSeconds: (seconds: number) -> (),
	show: (on: boolean) -> (),
	destroy: () -> (),
}

local BuildScreen = {}

local DARK = Color3.fromRGB(30, 32, 44)
local ROAD = Color3.fromRGB(64, 66, 76)
local GRASS = Color3.fromRGB(110, 190, 90)
local GRASS_2 = Color3.fromRGB(98, 176, 80)
local YELLOW = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(60, 190, 90)
local RED = Color3.fromRGB(225, 70, 70)
local WHITE = Color3.new(1, 1, 1)
-- card rims: hazards red, powerups green (they hit every racer the same)
local KIND_RIM: { [string]: Color3 } = {
	road = DARK,
	hazard = Color3.fromRGB(225, 80, 50),
	power = Color3.fromRGB(40, 170, 80),
}

local function cellKey(c: number, r: number): string
	return `{c},{r}`
end

local function round(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function rim(parent: Instance, color: Color3, thick: number): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thick
	s.Parent = parent
	return s
end

local function label(parent: Instance, text: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function pad(parent: Instance, y: number, x: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(y, 0)
	p.PaddingBottom = UDim.new(y, 0)
	p.PaddingLeft = UDim.new(x, 0)
	p.PaddingRight = UDim.new(x, 0)
	p.Parent = parent
end

local function place(obj: GuiObject, r: BuildLayout.Rect)
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

-- a road tile drawn from its ends: a middle square plus an arm to each open side
local function drawRoad(parent: GuiObject, piece: Piece, rot: number)
	local e = BuildLayout.turn(piece.ends, rot)
	local w = 0.46
	local colr = piece.color or ROAD
	local function bar(x: number, y: number, sx: number, sy: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = colr
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(sx, sy)
		f.Parent = parent
	end
	local m = (1 - w) / 2
	bar(m, m, w, w)
	if e.N then
		bar(m, 0, w, m)
	end
	if e.S then
		bar(m, m + w, w, m)
	end
	if e.W then
		bar(0, m, m, w)
	end
	if e.E then
		bar(m + w, m, m, w)
	end
	if piece.icon then
		local l = label(parent, piece.icon, YELLOW)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(w, w)
		l.Rotation = rot * 90
		l.ZIndex = 3
	end
end

-- screen pixels of a finger / mouse (InputObject.Position starts under the top bar)
local function pointer(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

function BuildScreen.new(opts: Options): BuildScreen
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = HudLayout.POPUP
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local state: State = {
		cols = 8,
		rows = 8,
		cells = {},
		pieces = {},
		specials = {},
		ready = false,
		secondsLeft = 0,
	}
	local byKey: { [string]: Cell } = {}
	local layout = BuildLayout.fit(844, 390, state.cols, state.rows)
	local erasing = false
	local selected: string? = nil -- the tile just dropped or turned: ringed, R turns it
	local turnTaught = Players.LocalPlayer:GetAttribute("TurnTaught") == true

	-- ===== grid =====
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundColor3 = GRASS
	grid.Active = true -- the camera doesn't turn while you build
	grid.Parent = gui
	local tiles = Instance.new("Folder")
	tiles.Parent = grid
	round(grid, 10)
	rim(grid, DARK, 3)

	-- ===== top: countdown, RACE READY, help / why =====
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.BackgroundColor3 = YELLOW
	timer.Parent = gui
	round(timer, 22)
	rim(timer, Color3.fromRGB(176, 112, 10), 2)
	local timerText = label(timer, "RACE IN 5:00", Color3.fromRGB(70, 35, 0))
	pad(timerText, 0.14, 0.06)

	local status = Instance.new("Frame")
	status.Name = "Status"
	status.Parent = gui
	round(status, 22)
	rim(status, DARK, 2)
	local statusText = label(status, "", WHITE)
	pad(statusText, 0.14, 0.06)

	local whyText = label(gui, BuildLayout.hint(false, false, false), WHITE)
	whyText.Name = "Why"
	local whyStroke = rim(whyText, DARK, 2)
	whyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- ===== tile bar: every road shape, hazard and powerup =====
	local tray = Instance.new("Frame")
	tray.Name = "Tiles"
	tray.BackgroundColor3 = DARK
	tray.BackgroundTransparency = 0.1
	tray.Parent = gui
	round(tray, 14)
	local cards = Instance.new("ScrollingFrame")
	cards.BackgroundTransparency = 1
	cards.BorderSizePixel = 0
	cards.Position = UDim2.fromOffset(8, 8)
	cards.Size = UDim2.new(1, -16, 1, -16)
	cards.ScrollBarThickness = 6
	cards.ScrollingDirection = Enum.ScrollingDirection.Y
	cards.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cards.CanvasSize = UDim2.new()
	cards.Parent = tray
	local cardGrid = Instance.new("UIGridLayout")
	cardGrid.CellSize = UDim2.fromOffset(BuildLayout.CARD, BuildLayout.CARD + 16)
	cardGrid.CellPadding = UDim2.fromOffset(8, 8)
	cardGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cardGrid.Parent = cards

	-- ===== buttons =====
	local function bigButton(name: string, text: string, color: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.BackgroundColor3 = color
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = WHITE
		b.Text = text
		b.Parent = gui
		round(b, 14)
		rim(b, DARK, 2)
		pad(b, 0.22, 0.08)
		return b
	end
	local eraseBtn = bigButton("Erase", "ERASE", Color3.fromRGB(80, 86, 106))
	local doneBtn = bigButton("Done", "DONE", GREEN)

	-- the tile under the finger while dragging a special tile
	local ghost = Instance.new("Frame")
	ghost.Name = "Ghost"
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.BackgroundColor3 = GRASS
	ghost.BackgroundTransparency = 0.2
	ghost.Visible = false
	ghost.ZIndex = 10
	ghost.Parent = gui
	round(ghost, 6)

	-- the teaching hand (first build only)
	local hand = Instance.new("TextLabel")
	hand.Name = "Hand"
	hand.BackgroundTransparency = 1
	hand.AnchorPoint = Vector2.new(0.3, 0)
	hand.Size = UDim2.fromOffset(64, 64)
	hand.TextScaled = true
	hand.Text = "👆"
	hand.ZIndex = 20
	hand.Visible = false
	hand.Parent = gui
	local taught = Players.LocalPlayer:GetAttribute("BuildTaught") == true

	local function pieceById(id: string): Piece?
		for _, p in state.pieces do
			if p.id == id then
				return p
			end
		end
		return nil
	end

	local function square(parent: Instance, c: number, r: number): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		local px, py = BuildLayout.cellPos(layout, c, r, state.rows)
		f.Position = UDim2.fromOffset(px, py)
		f.Size = UDim2.fromOffset(layout.cell, layout.cell)
		f.Parent = parent
		return f
	end

	local function drawGrid()
		tiles:ClearAllChildren()
		for r = 1, state.rows do
			for c = 1, state.cols do
				local f = square(tiles, c, r)
				f.BackgroundColor3 = if (c + r) % 2 == 0 then GRASS else GRASS_2
				local here = byKey[cellKey(c, r)]
				local piece = if here then pieceById(here.piece) else nil
				if here and piece then
					f.Name = cellKey(c, r)
					drawRoad(f, piece, here.rot)
					if selected == cellKey(c, r) and not erasing then
						-- a ring and a turn badge: "tap me to turn"
						rim(f, YELLOW, 3)
						f.ZIndex = 2
						local badge = Instance.new("TextLabel")
						badge.Name = "Turn"
						badge.AnchorPoint = Vector2.new(1, 0)
						badge.Position = UDim2.new(1, 2, 0, -2)
						badge.Size = UDim2.fromScale(0.42, 0.42)
						badge.BackgroundColor3 = YELLOW
						badge.Font = Enum.Font.GothamBlack
						badge.TextScaled = true
						badge.TextColor3 = DARK
						badge.Text = "↻"
						badge.ZIndex = 5
						badge.Parent = f
						round(badge, 100)
					end
				end
			end
		end
	end

	local function drawTop()
		timerText.Text = "RACE IN " .. BuildLayout.clock(state.secondsLeft)
		status.BackgroundColor3 = if state.ready then GREEN else RED
		statusText.Text = BuildLayout.statusText(state.ready)
		local gap = not state.ready and state.why ~= nil and #state.cells > 1
		local turnTip = selected ~= nil and not turnTaught
		whyText.Text = BuildLayout.hint(state.ready, gap, erasing, turnTip)
		whyText.TextColor3 = if gap and not erasing then Color3.fromRGB(255, 140, 130) else WHITE
	end

	-- ===== drag a special tile =====
	local dropping: string? = nil
	local dropInput: InputObject? = nil
	local dropFrom = Vector2.zero -- where the press on the card began
	local dragged = false -- moved far enough to count as a drag
	local function moveGhost(at: Vector2)
		ghost.Position = UDim2.fromOffset(at.X, at.Y)
	end

	local function drawTray()
		for _, ch in cards:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i, id in state.specials do
			local p = pieceById(id)
			if not p then
				continue
			end
			local piece = p :: Piece
			local card = Instance.new("Frame")
			card.Name = id
			card.LayoutOrder = i
			card.Active = true
			card.BackgroundColor3 = Color3.fromRGB(245, 245, 240)
			card.Parent = cards
			round(card, 10)
			rim(card, KIND_RIM[piece.kind or "road"] or DARK, 4)
			local tile = Instance.new("Frame")
			tile.BackgroundColor3 = GRASS
			tile.BorderSizePixel = 0
			tile.Position = UDim2.fromOffset(6, 4)
			tile.Size = UDim2.new(1, -12, 1, -24)
			tile.Parent = card
			round(tile, 6)
			drawRoad(tile, piece, 0)
			local name = label(card, piece.name, DARK)
			name.Position = UDim2.new(0, 3, 1, -19)
			name.Size = UDim2.new(1, -6, 0, 16)
			card.InputBegan:Connect(function(input: InputObject)
				if not isPress(input) or dropping then
					return
				end
				dropping, dropInput = id, input
				dropFrom, dragged = pointer(input), false
				ghost:ClearAllChildren()
				round(ghost, 6)
				ghost.Size = UDim2.fromOffset(layout.cell * 1.3, layout.cell * 1.3)
				drawRoad(ghost, piece, 0)
				moveGhost(pointer(input))
			end)
		end
	end

	-- ===== tap the grid: turn a tile, or erase it =====
	local function cellUnder(at: Vector2): (number?, number?)
		return BuildLayout.cellAt(layout, at.X, at.Y, state.cols, state.rows)
	end

	-- a quarter turn: spin the square at once, the server's state redraws it turned
	local function turnTile(c: number, r: number)
		local here = byKey[cellKey(c, r)]
		if not here then
			return
		end
		selected = cellKey(c, r)
		if not turnTaught then
			turnTaught = true
			Players.LocalPlayer:SetAttribute("TurnTaught", true)
		end
		local f = tiles:FindFirstChild(cellKey(c, r))
		if f and f:IsA("GuiObject") then
			TweenService:Create(f, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Rotation = 90 })
				:Play()
		end
		opts.onPlace(c, r, here.piece, (here.rot + 1) % 4)
		drawTop()
	end

	grid.InputBegan:Connect(function(input: InputObject)
		if not isPress(input) or dropping then
			return
		end
		local c, r = cellUnder(pointer(input))
		if not (c and r) then
			return
		end
		local here = byKey[cellKey(c, r)]
		if not here then
			return
		end
		if erasing then
			opts.onRemove(c, r)
		else
			turnTile(c, r)
		end
	end)

	-- PC: R turns the ringed tile
	UserInputService.InputBegan:Connect(function(input: InputObject, typing: boolean)
		if typing or not gui.Enabled or erasing or input.KeyCode ~= Enum.KeyCode.R then
			return
		end
		local at = if selected then byKey[selected] else nil
		if at then
			turnTile(at.c, at.r)
		end
	end)

	local function sameFinger(input: InputObject, started: InputObject?): boolean
		if input.UserInputType == Enum.UserInputType.Touch then
			return input == started
		end
		return started ~= nil and started.UserInputType ~= Enum.UserInputType.Touch
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		local moving = input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseMovement
		if not (moving and dropping and sameFinger(input, dropInput)) then
			return
		end
		local at = pointer(input)
		if not dragged and (at - dropFrom).Magnitude >= BuildLayout.DRAG then
			dragged = true
			ghost.Visible = true
		end
		moveGhost(at)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not (isPress(input) and dropping and sameFinger(input, dropInput)) then
			return
		end
		local id = dropping :: string
		local wasDrag = dragged
		dropping, dropInput, dragged = nil, nil, false
		ghost.Visible = false
		-- a tap on a card (no drag) drops nothing
		local c, r = cellUnder(pointer(input))
		if wasDrag and c and r then
			selected = cellKey(c, r)
			opts.onDrop(c, r, id)
			if not taught then
				taught = true
				Players.LocalPlayer:SetAttribute("BuildTaught", true)
				hand.Visible = false
			end
		end
	end)

	-- the teaching hand: from the first card to the middle of the grid, again and again
	RunService.Heartbeat:Connect(function()
		local first = cards:FindFirstChildWhichIsA("Frame")
		local want = gui.Enabled and not taught and dropping == nil and first ~= nil
		hand.Visible = want
		if not (want and first) then
			return
		end
		local t = (os.clock() % 2.2) / 1.6 -- 0..1 moving, then a short rest
		local u = math.clamp(t, 0, 1)
		u = u * u * (3 - 2 * u)
		local from = first.AbsolutePosition + first.AbsoluteSize / 2
		local to = Vector2.new(layout.grid.x + layout.grid.w / 2, layout.grid.y + layout.grid.h / 2)
		local at = from:Lerp(to, u)
		hand.Position = UDim2.fromOffset(at.X, at.Y)
		hand.TextTransparency = if t > 1 then 0.5 else 0
	end)

	local function relayout()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		-- keep clear of Roblox's own top-left buttons (taller than 58 px on some screens)
		local top = math.max(BuildLayout.TOP, GuiService.TopbarInset.Max.Y + 6)
		layout = BuildLayout.fit(size.X, size.Y, state.cols, state.rows, top)
		place(grid, layout.grid)
		place(timer, layout.timer)
		place(status, layout.status)
		place(whyText, layout.why)
		place(tray, layout.tray)
		place(eraseBtn, layout.erase)
		place(doneBtn, layout.done)
		drawGrid()
	end

	eraseBtn.Activated:Connect(function()
		erasing = not erasing
		eraseBtn.Text = if erasing then "ERASE: ON" else "ERASE"
		eraseBtn.BackgroundColor3 = if erasing then RED else Color3.fromRGB(80, 86, 106)
		drawGrid()
		drawTop()
	end)
	doneBtn.Activated:Connect(function()
		opts.onDone()
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	local screen = {} :: BuildScreen
	function screen.setState(s: State)
		local resized = s.cols ~= state.cols or s.rows ~= state.rows
		local newTray = #s.specials ~= #state.specials or #s.pieces ~= #state.pieces
		state = s
		byKey = {}
		for _, cell in s.cells do
			byKey[cellKey(cell.c, cell.r)] = cell
		end
		if resized then
			relayout()
		else
			drawGrid()
		end
		if newTray then
			drawTray()
		end
		drawTop()
	end
	function screen.setSeconds(seconds: number)
		state.secondsLeft = seconds
		timerText.Text = "RACE IN " .. BuildLayout.clock(seconds)
	end
	function screen.show(on: boolean)
		gui.Enabled = on
		Players.LocalPlayer:SetAttribute("Building", on) -- lobby buttons hide under the screen
		if on then
			relayout()
		else
			dropping, dropInput, dragged = nil, nil, false
			ghost.Visible = false
		end
	end
	function screen.destroy()
		gui:Destroy()
	end
	relayout()
	drawTray()
	drawTop()
	return screen
end

return BuildScreen
