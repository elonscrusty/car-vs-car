--!strict
-- The build screen for the 5-min break (carter: "make it a drag and drop").
-- DRAW: press a square and drag your finger across the grid; the road follows it. Let go and
--   the path goes to the server, which picks straights and turns and turns them itself.
--   Dragging back onto START closes the loop.
-- DROP: drag a special tile (boost, oil, ...) from the bar onto a road square.
-- ERASE: hold a square, or turn ERASE on and drag over squares.
-- This screen only draws and reports; the server checks everything and sends back the state.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BuildLayout = require(ReplicatedStorage.Shared.BuildLayout)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)

export type Piece = {
	id: string,
	name: string,
	ends: BuildLayout.Ends, -- at rotation 0
	icon: string?, -- a short mark drawn on the road
	color: Color3?, -- road colour (default asphalt)
}
-- c = column (1 = left), r = row (1 = front, next to the stand; drawn at the bottom)
export type Cell = { c: number, r: number, piece: string, rot: number }
export type State = {
	cols: number,
	rows: number,
	cells: { Cell },
	pieces: { Piece }, -- every tile, to draw the grid
	specials: { string }, -- ids in the drag bar
	ready: boolean,
	why: string?, -- when not ready: "Road has a gap"
	secondsLeft: number,
}
export type Options = {
	onPath: (path: { BuildLayout.Spot }) -> (),
	onDrop: (c: number, r: number, piece: string) -> (),
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

	-- ===== grid =====
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundColor3 = GRASS
	grid.Active = true -- the camera doesn't turn while you draw
	grid.Parent = gui
	local tiles = Instance.new("Folder")
	tiles.Parent = grid
	local trail = Instance.new("Folder") -- yellow squares under your finger while drawing
	trail.Parent = grid
	round(grid, 10)
	rim(grid, DARK, 3)

	-- ===== top: countdown, RACE READY, help / why =====
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.BackgroundColor3 = YELLOW
	timer.Parent = gui
	round(timer, 22)
	rim(timer, Color3.fromRGB(176, 112, 10), 2)
	local timerText = label(timer, "5:00", Color3.fromRGB(70, 35, 0))
	pad(timerText, 0.14, 0.06)

	local status = Instance.new("Frame")
	status.Name = "Status"
	status.Parent = gui
	round(status, 22)
	rim(status, DARK, 2)
	local statusText = label(status, "", WHITE)
	pad(statusText, 0.14, 0.06)

	local whyText = label(gui, BuildLayout.HELP, WHITE)
	whyText.Name = "Why"
	local whyStroke = rim(whyText, DARK, 2)
	whyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- ===== special tiles bar =====
	local tray = Instance.new("Frame")
	tray.Name = "Specials"
	tray.BackgroundColor3 = DARK
	tray.BackgroundTransparency = 0.15
	tray.Parent = gui
	round(tray, 12)
	local trayTitle = label(tray, "DRAG ONTO THE ROAD", Color3.fromRGB(200, 200, 210))
	trayTitle.Position = UDim2.fromOffset(10, 6)
	trayTitle.Size = UDim2.new(1, -20, 0, 18)
	trayTitle.TextXAlignment = Enum.TextXAlignment.Left
	local cards = Instance.new("Frame")
	cards.BackgroundTransparency = 1
	cards.Position = UDim2.fromOffset(8, 28)
	cards.Size = UDim2.new(1, -16, 1, -34)
	cards.Parent = tray
	local cardGrid = Instance.new("UIGridLayout")
	cardGrid.CellSize = UDim2.fromOffset(BuildLayout.CARD, BuildLayout.CARD)
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
	local eraseBtn = bigButton("Erase", "ERASE", RED)
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
					drawRoad(f, piece, here.rot)
				end
			end
		end
	end

	local function drawTrail(path: { BuildLayout.Spot })
		trail:ClearAllChildren()
		for _, p in path do
			local f = square(trail, p.c, p.r)
			f.BackgroundColor3 = if erasing then RED else YELLOW
			f.BackgroundTransparency = 0.45
			f.ZIndex = 5
		end
	end

	local function drawTop()
		timerText.Text = BuildLayout.clock(state.secondsLeft)
		status.BackgroundColor3 = if state.ready then GREEN else RED
		statusText.Text = BuildLayout.statusText(state.ready)
		if state.ready then
			whyText.Text = "Tap DONE, or keep building"
			whyText.TextColor3 = WHITE
		elseif state.why and #state.cells > 1 then
			whyText.Text = state.why
			whyText.TextColor3 = Color3.fromRGB(255, 140, 130)
		else
			whyText.Text = BuildLayout.HELP
			whyText.TextColor3 = WHITE
		end
	end

	-- ===== drag a special tile =====
	local dropping: string? = nil
	local dropInput: InputObject? = nil
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
			rim(card, DARK, 2)
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
				ghost:ClearAllChildren()
				round(ghost, 6)
				ghost.Size = UDim2.fromOffset(layout.cell * 1.3, layout.cell * 1.3)
				drawRoad(ghost, piece, 0)
				ghost.Visible = true
				moveGhost(pointer(input))
			end)
		end
	end

	-- ===== draw / erase on the grid =====
	local drawing: { BuildLayout.Spot }? = nil
	local drawInput: InputObject? = nil
	local pressedAt = 0
	local held = false -- a long press already erased its square

	local function cellUnder(at: Vector2): (number?, number?)
		return BuildLayout.cellAt(layout, at.X, at.Y, state.cols, state.rows)
	end

	grid.InputBegan:Connect(function(input: InputObject)
		if not isPress(input) or drawing or dropping then
			return
		end
		local c, r = cellUnder(pointer(input))
		if not (c and r) then
			return
		end
		drawing, drawInput = BuildLayout.extend({}, c, r), input
		pressedAt, held = os.clock(), false
		drawTrail(drawing :: { BuildLayout.Spot })
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
		if not moving then
			return
		end
		local at = pointer(input)
		if dropping and sameFinger(input, dropInput) then
			moveGhost(at)
		elseif drawing and not held and sameFinger(input, drawInput) then
			local c, r = cellUnder(at)
			if c and r then
				local path = drawing :: { BuildLayout.Spot }
				local before = #path
				BuildLayout.extend(path, c, r)
				if #path ~= before or path[#path].c ~= c then
					drawTrail(path)
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end
		if dropping and sameFinger(input, dropInput) then
			local id = dropping :: string
			dropping, dropInput = nil, nil
			ghost.Visible = false
			local c, r = cellUnder(pointer(input))
			if c and r then
				opts.onDrop(c, r, id)
			end
		elseif drawing and sameFinger(input, drawInput) then
			local path = drawing :: { BuildLayout.Spot }
			drawing, drawInput = nil, nil
			trail:ClearAllChildren()
			if held then
				return
			end
			if erasing then
				for _, p in path do
					opts.onRemove(p.c, p.r)
				end
			elseif #path >= 2 then
				opts.onPath(path)
			end
		end
	end)

	-- hold one square still to erase it
	RunService.Heartbeat:Connect(function()
		local path = drawing
		if path and not held and #path == 1 and os.clock() - pressedAt >= BuildLayout.HOLD then
			held = true
			trail:ClearAllChildren()
			if byKey[cellKey(path[1].c, path[1].r)] then
				opts.onRemove(path[1].c, path[1].r)
			end
		end
	end)

	local function relayout()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		layout = BuildLayout.fit(size.X, size.Y, state.cols, state.rows)
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
		eraseBtn.BackgroundColor3 = if erasing then Color3.fromRGB(150, 30, 30) else RED
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
		timerText.Text = BuildLayout.clock(seconds)
	end
	function screen.show(on: boolean)
		gui.Enabled = on
		if on then
			relayout()
		else
			drawing, dropping = nil, nil
			ghost.Visible = false
			trail:ClearAllChildren()
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
