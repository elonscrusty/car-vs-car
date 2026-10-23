--!strict
-- The build screen for the 5-min break: your plot's grid on the left, the tile tray on the
-- right, ROTATE / REMOVE / DONE at the bottom right, the countdown and RACE READY chip on top.
-- Tap a tile in the tray, then tap a square to put it there. Tap a placed tile to turn it.
-- REMOVE makes taps clear squares. This screen only draws and reports taps: the server checks
-- every place / remove (see the Build your own track thread) and sends back the new state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildLayout = require(ReplicatedStorage.Shared.BuildLayout)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)

export type Piece = {
	id: string,
	name: string,
	ends: BuildLayout.Ends, -- at rotation 0
	owned: boolean,
	price: number?, -- coins, shown when not owned
	icon: string?, -- a short mark drawn on the road (ramp ▲, boost »)
	color: Color3?, -- road colour (default asphalt)
}
-- c = column (1 = left), r = row (1 = front, next to the stand; drawn at the bottom)
export type Cell = { c: number, r: number, piece: string, rot: number }
export type State = {
	cols: number,
	rows: number,
	cells: { Cell },
	pieces: { Piece },
	ready: boolean,
	why: string?, -- when not ready: "Road has a gap"
	secondsLeft: number,
}
export type Options = {
	onPlace: (col: number, row: number, piece: string, rot: number) -> (),
	onRemove: (col: number, row: number) -> (),
	onDone: () -> (),
	onBuy: ((piece: string) -> ())?,
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
local BLUE = Color3.fromRGB(70, 130, 235)
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

local function place(obj: GuiObject, r: BuildLayout.Rect)
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

-- a road tile drawn from its ends: a middle square plus an arm to each open side
local function drawRoad(parent: GuiObject, piece: Piece, rot: number)
	local e = BuildLayout.turn(piece.ends, rot)
	local w = 0.42
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

function BuildScreen.new(opts: Options): BuildScreen
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = HudLayout.POPUP
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local state: State =
		{ cols = 8, rows = 8, cells = {}, pieces = {}, ready = false, secondsLeft = 0 }
	local chosen: string? = nil -- piece id picked in the tray
	local rot = 0 -- rotation for the next placed tile
	local erasing = false

	-- ===== grid =====
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundColor3 = GRASS
	grid.Parent = gui
	round(grid, 10)
	rim(grid, DARK, 3)

	-- ===== top: countdown and loop chip =====
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.BackgroundColor3 = YELLOW
	timer.Parent = gui
	round(timer, 20)
	rim(timer, Color3.fromRGB(176, 112, 10), 2)
	local timerText = label(timer, "BUILD 5:00", Color3.fromRGB(70, 35, 0))
	local timerPad = Instance.new("UIPadding")
	timerPad.PaddingTop = UDim.new(0.12, 0)
	timerPad.PaddingBottom = UDim.new(0.12, 0)
	timerPad.Parent = timerText

	local status = Instance.new("Frame")
	status.Name = "Status"
	status.Parent = gui
	round(status, 20)
	local statusText = label(status, "", WHITE)
	local statusPad = timerPad:Clone()
	statusPad.Parent = statusText
	local whyText = label(gui, "", Color3.fromRGB(255, 120, 110))
	whyText.Name = "Why"
	whyText.TextXAlignment = Enum.TextXAlignment.Right
	local whyStroke = rim(whyText, DARK, 1.5)
	whyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- ===== tray =====
	local tray = Instance.new("ScrollingFrame")
	tray.Name = "Tray"
	tray.BackgroundColor3 = DARK
	tray.BackgroundTransparency = 0.15
	tray.ScrollBarThickness = 6
	tray.ScrollingDirection = Enum.ScrollingDirection.Y
	tray.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tray.CanvasSize = UDim2.new()
	tray.Parent = gui
	round(tray, 12)
	local trayPad = Instance.new("UIPadding")
	trayPad.PaddingTop = UDim.new(0, 8)
	trayPad.PaddingLeft = UDim.new(0, 8)
	trayPad.PaddingRight = UDim.new(0, 8)
	trayPad.PaddingBottom = UDim.new(0, 8)
	trayPad.Parent = tray
	local trayGrid = Instance.new("UIGridLayout")
	trayGrid.CellSize = UDim2.fromOffset(BuildLayout.CARD, BuildLayout.CARD + 18)
	trayGrid.CellPadding = UDim2.fromOffset(8, 8)
	trayGrid.SortOrder = Enum.SortOrder.LayoutOrder
	trayGrid.Parent = tray

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
		local p = Instance.new("UIPadding")
		p.PaddingTop = UDim.new(0.22, 0)
		p.PaddingBottom = UDim.new(0.22, 0)
		p.PaddingLeft = UDim.new(0.08, 0)
		p.PaddingRight = UDim.new(0.08, 0)
		p.Parent = b
		return b
	end
	local rotateBtn = bigButton("Rotate", "ROTATE ↻", BLUE)
	local removeBtn = bigButton("Remove", "REMOVE", RED)
	local doneBtn = bigButton("Done", "DONE", GREEN)

	local layout = BuildLayout.fit(844, 390, state.cols, state.rows)
	local byKey: { [string]: Cell } = {}

	local function pieceById(id: string): Piece?
		for _, p in state.pieces do
			if p.id == id then
				return p
			end
		end
		return nil
	end

	local drawTray: () -> ()

	local function drawGrid()
		grid:ClearAllChildren()
		round(grid, 10)
		rim(grid, DARK, 3)
		local cell = layout.cell
		for r = 1, state.rows do
			for c = 1, state.cols do
				local b = Instance.new("TextButton")
				b.Name = cellKey(c, r)
				b.Text = ""
				b.AutoButtonColor = false
				b.BorderSizePixel = 0
				b.BackgroundColor3 = if (c + r) % 2 == 0 then GRASS else GRASS_2
				local px, py = BuildLayout.cellPos(layout, c, r, state.rows)
				b.Position = UDim2.fromOffset(px, py)
				b.Size = UDim2.fromOffset(cell, cell)
				b.Parent = grid
				local here = byKey[cellKey(c, r)]
				local piece = if here then pieceById(here.piece) else nil
				if here and piece then
					drawRoad(b, piece, here.rot)
				end
				b.Activated:Connect(function()
					if erasing then
						if here then
							opts.onRemove(c, r)
						end
					elseif here then
						opts.onPlace(c, r, here.piece, (here.rot + 1) % 4) -- tap a tile to turn it
					elseif chosen then
						opts.onPlace(c, r, chosen, rot)
					end
				end)
			end
		end
	end

	drawTray = function()
		for _, ch in tray:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i, p in state.pieces do
			local card = Instance.new("TextButton")
			card.Name = p.id
			card.LayoutOrder = i
			card.Text = ""
			card.AutoButtonColor = true
			card.BackgroundColor3 = if p.owned
				then Color3.fromRGB(245, 245, 240)
				else Color3.fromRGB(150, 150, 158)
			card.Parent = tray
			round(card, 10)
			rim(
				card,
				if chosen == p.id and not erasing then YELLOW else DARK,
				if chosen == p.id then 4 else 2
			)
			local tile = Instance.new("Frame")
			tile.BackgroundColor3 = GRASS
			tile.BorderSizePixel = 0
			tile.Position = UDim2.fromOffset(6, 6)
			tile.Size = UDim2.new(1, -12, 0, BuildLayout.CARD - 12)
			tile.Parent = card
			round(tile, 6)
			drawRoad(tile, p, if chosen == p.id then rot else 0)
			local name = label(card, if p.owned then p.name else `{p.price or "?"} coins`, DARK)
			name.Position = UDim2.new(0, 4, 1, -20)
			name.Size = UDim2.new(1, -8, 0, 16)
			if not p.owned then
				local lock = label(tile, "🔒", WHITE)
				lock.ZIndex = 4
				lock.Size = UDim2.fromScale(0.5, 0.5)
				lock.Position = UDim2.fromScale(0.25, 0.25)
			end
			card.Activated:Connect(function()
				if not p.owned then
					if opts.onBuy then
						opts.onBuy(p.id)
					end
					return
				end
				erasing = false
				if chosen == p.id then
					rot = (rot + 1) % 4 -- tap again to turn it
				else
					chosen, rot = p.id, 0
				end
				drawTray()
				removeBtn.BackgroundColor3 = RED
			end)
		end
	end

	local function drawTop()
		timerText.Text = `BUILD {BuildLayout.clock(state.secondsLeft)}`
		status.BackgroundColor3 = if state.ready then GREEN else RED
		statusText.Text = BuildLayout.statusText(state.ready)
		whyText.Text = if state.ready then "" else (state.why or "")
	end

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
		place(rotateBtn, layout.rotate)
		place(removeBtn, layout.remove)
		place(doneBtn, layout.done)
		drawGrid()
	end

	rotateBtn.Activated:Connect(function()
		rot = (rot + 1) % 4
		drawTray()
	end)
	removeBtn.Activated:Connect(function()
		erasing = not erasing
		removeBtn.BackgroundColor3 = if erasing then Color3.fromRGB(150, 30, 30) else RED
		drawTray()
	end)
	doneBtn.Activated:Connect(function()
		opts.onDone()
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	local screen = {} :: BuildScreen
	function screen.setState(s: State)
		local resized = s.cols ~= state.cols or s.rows ~= state.rows
		state = s
		byKey = {}
		for _, cell in s.cells do
			byKey[cellKey(cell.c, cell.r)] = cell
		end
		if chosen and not pieceById(chosen) then
			chosen = nil
		end
		if chosen == nil then
			for _, p in s.pieces do
				if p.owned then
					chosen = p.id
					break
				end
			end
		end
		if resized then
			relayout()
		else
			drawGrid()
		end
		drawTray()
		drawTop()
	end
	function screen.setSeconds(seconds: number)
		state.secondsLeft = seconds
		drawTop()
	end
	function screen.show(on: boolean)
		gui.Enabled = on
		if on then
			relayout()
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
