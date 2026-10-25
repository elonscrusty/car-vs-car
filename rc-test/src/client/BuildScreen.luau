--!strict
-- The build screen for the 5-min break (carter: "tiles that swap in with different road shapes
-- and some have hazards or powerups").
-- SWAP: drag a tile from the bar onto any square and it swaps in; the server turns it to fit the
--   road around it.
-- TURN: tap a tile on the grid to turn it a quarter (it spins; PC: R turns the last one). The tile
--   you just dropped or turned wears a yellow ring and a turn badge, and until you turn one the
--   hint says TAP TO TURN (carter: "add a way to rotate tiles").
--   The big TURN button turns the ringed tile too.
-- ERASE: turn ERASE on, then tap squares. UNDO takes back the last drop, turn or erase.
-- GAP: while the track is not READY, red marks show each road end that goes nowhere.
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
	stray: { [string]: boolean }?, -- "c,r" of tiles the loop skips (drawn dimmed)
	locks: { [string]: string }?, -- id -> what opens it ("150", "5 STARS"); missing = yours
	ready: boolean,
	why: string?, -- when not ready: "Road has a gap"
	secondsLeft: number,
	kind: string?, -- "race" | "drift": what the whole server does on this plot (default race)
}
export type Options = {
	onDrop: (c: number, r: number, piece: string) -> (), -- swap in, turned to fit
	onPlace: (c: number, r: number, piece: string, rot: number) -> (), -- as it is, turned rot
	onRemove: (c: number, r: number) -> (),
	onDone: () -> (),
	onKind: ((kind: string) -> ())?, -- RACE / DRIFT tapped
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
		-- dark mark on a bright road (JUMP, SAND), yellow on dark
		local col = piece.color
		local bright = col ~= nil and (col.R * 0.3 + col.G * 0.59 + col.B * 0.11) > 0.55
		local l = label(parent, piece.icon, if bright then DARK else YELLOW)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(w, w)
		-- arrows turn with the road (» is drawn pointing right, so a quarter back); words stay
		-- upright so they read
		l.Rotation = if piece.icon == "»"
			then rot * 90 - 90
			elseif piece.icon == "▲" then rot * 90
			else 0
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
	-- UNDO: what each square held before each change (nil = empty), newest last
	type Step = { c: number, r: number, before: Cell? }
	local undoList: { Step } = {}
	local loopUntil = 0 -- the loop line shows until then (until it has been seen once, the whole 5 s)
	local UNDO_MAX = 40

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
	local function timerWords(seconds: number): string
		local word = if state.kind == "drift" then "DRIFT IN " else "RACE IN "
		return word .. BuildLayout.clock(seconds)
	end

	-- RACE / DRIFT: two big buttons, the picked one lit (carter 23:42: owners pick)
	local mode = Instance.new("Frame")
	mode.Name = "Mode"
	mode.BackgroundTransparency = 1
	mode.Parent = gui
	local KIND_LIT: { [string]: Color3 } = {
		race = Color3.fromRGB(235, 80, 60),
		drift = Color3.fromRGB(70, 150, 235),
	}
	local kindBtns: { [string]: TextButton } = {}
	for i, k in { "race", "drift" } do
		local b = Instance.new("TextButton")
		b.Name = k
		b.Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 4, 0, 0)
		b.Size = UDim2.new(0.5, -4, 1, 0)
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = WHITE
		b.Text = if k == "race" then "🏁 RACE" else "💨 DRIFT"
		b.Parent = mode
		round(b, 12)
		rim(b, DARK, 2)
		pad(b, 0.18, 0.08)
		b.Activated:Connect(function()
			if state.kind ~= k and opts.onKind then
				opts.onKind(k)
			end
		end)
		kindBtns[k] = b
	end
	local function drawKind()
		local now = if state.kind == "drift" then "drift" else "race"
		for k, b in kindBtns do
			local lit = k == now
			b.BackgroundColor3 = if lit then KIND_LIT[k] else Color3.fromRGB(60, 64, 80)
			b.BackgroundTransparency = if lit then 0 else 0.2
			b.TextTransparency = if lit then 0 else 0.45
		end
	end

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
	local GREY = Color3.fromRGB(80, 86, 106)
	local undoBtn = bigButton("Undo", "UNDO", GREY)
	local turnBtn = bigButton("Turn", "TURN", Color3.fromRGB(70, 120, 220))
	local eraseBtn = bigButton("Erase", "ERASE", GREY)
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
		-- where the loop is broken: a red mark on each road end that goes nowhere
		local placed: { BuildLayout.Placed } = {}
		for _, cell in state.cells do
			local p = pieceById(cell.piece)
			if p then
				table.insert(
					placed,
					{ c = cell.c, r = cell.r, ends = BuildLayout.turn(p.ends, cell.rot) }
				)
			end
		end
		local open = if state.ready
				or #state.cells < 2
				or erasing
			then {}
			else BuildLayout.openEnds(placed)
		local EDGE_AT: { [string]: Vector2 } = {
			N = Vector2.new(0.5, 0),
			E = Vector2.new(1, 0.5),
			S = Vector2.new(0.5, 1),
			W = Vector2.new(0, 0.5),
		}
		for _, o in open do
			local px, py = BuildLayout.cellPos(layout, o.c, o.r, state.rows)
			local at = EDGE_AT[o.side]
			local mark = Instance.new("TextLabel")
			mark.Name = "Gap"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromOffset(px + at.X * layout.cell, py + at.Y * layout.cell)
			mark.Size = UDim2.fromOffset(layout.cell * 0.5, layout.cell * 0.5)
			mark.BackgroundColor3 = RED
			mark.Font = Enum.Font.GothamBlack
			mark.TextScaled = true
			mark.TextColor3 = WHITE
			mark.Text = "!"
			mark.ZIndex = 6
			mark.Parent = tiles
			round(mark, 100)
			rim(mark, WHITE, 2)
			TweenService:Create(
				mark,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.5 }
			):Play()
		end
		for r = 1, state.rows do
			for c = 1, state.cols do
				local f = square(tiles, c, r)
				f.BackgroundColor3 = if (c + r) % 2 == 0 then GRASS else GRASS_2
				-- a thin line round every square, so you can see where each tile ends
				local edge = rim(f, DARK, 1)
				edge.Transparency = 0.55
				local here = byKey[cellKey(c, r)]
				local piece = if here then pieceById(here.piece) else nil
				if here and piece then
					f.Name = cellKey(c, r)
					drawRoad(f, piece, here.rot)
					-- a tile off the loop: dimmed, so it doesn't look broken next to READY
					if state.stray and state.stray[cellKey(c, r)] then
						local dim = Instance.new("Frame")
						dim.Name = "Stray"
						dim.BackgroundColor3 = DARK
						dim.BackgroundTransparency = 0.45
						dim.BorderSizePixel = 0
						dim.Size = UDim2.fromScale(1, 1)
						dim.ZIndex = 4
						dim.Parent = f
					end
					if selected == cellKey(c, r) and not erasing then
						-- a ring and a turn badge: "tap me to turn"
						rim(f, YELLOW, 3)
						-- above its neighbours; the road bars come up with it (ZIndex is global
						-- here, so bars left at 1 would hide under the square's own grass)
						f.ZIndex = 2
						for _, road in f:GetChildren() do
							if road:IsA("Frame") then
								road.ZIndex = 2
							end
						end
						local badge = Instance.new("TextLabel")
						badge.Name = "Turn"
						badge.AnchorPoint = Vector2.new(1, 0)
						badge.Position = UDim2.new(1, 2, 0, -2)
						badge.Size = UDim2.fromScale(0.42, 0.42)
						badge.BackgroundColor3 = YELLOW
						badge.Font = Enum.Font.GothamBlack
						badge.TextScaled = true
						badge.TextColor3 = DARK
						badge.Text = "🔄" -- (↻ has no glyph in Roblox fonts)
						badge.ZIndex = 5
						badge.Parent = f
						round(badge, 100)
					end
				end
			end
		end
	end

	local function drawTop()
		timerText.Text = timerWords(state.secondsLeft)
		drawKind()
		status.BackgroundColor3 = if state.ready then GREEN else RED
		statusText.Text = BuildLayout.statusText(state.ready)
		local gap = not state.ready and state.why ~= nil and #state.cells > 1
		local turnTip = selected ~= nil and not turnTaught
		whyText.Text = BuildLayout.hint(state.ready, gap, erasing, turnTip)
		whyText.TextColor3 = if gap and not erasing then Color3.fromRGB(255, 140, 130) else WHITE
		-- the first break: the whole game in one line, for a few seconds each time it opens
		if os.clock() < loopUntil and not erasing then
			whyText.Text = "BUILD ▶ RACE ▶ COINS ▶ CARS"
			whyText.TextColor3 = YELLOW
		end
		-- TURN and UNDO look off when there is nothing for them to do
		local canTurn = selected ~= nil and byKey[selected] ~= nil and not erasing
		turnBtn.BackgroundTransparency = if canTurn then 0 else 0.55
		turnBtn.TextTransparency = if canTurn then 0 else 0.5
		undoBtn.BackgroundTransparency = if #undoList > 0 then 0 else 0.55
		undoBtn.TextTransparency = if #undoList > 0 then 0 else 0.5
	end

	local function remember(c: number, r: number)
		local was = byKey[cellKey(c, r)]
		table.insert(undoList, {
			c = c,
			r = r,
			before = if was then { c = c, r = r, piece = was.piece, rot = was.rot } else nil,
		})
		if #undoList > UNDO_MAX then
			table.remove(undoList, 1)
		end
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
			-- not yours yet: greyed, with a lock and what opens it (coins, or stars first)
			local lock = if state.locks then state.locks[id] else nil
			if lock then
				local shade = Instance.new("Frame")
				shade.Name = "Locked"
				shade.BackgroundColor3 = DARK
				shade.BackgroundTransparency = 0.3
				shade.Size = UDim2.fromScale(1, 1)
				shade.ZIndex = 4
				shade.Parent = tile
				round(shade, 6)
				local lockText = label(shade, `🔒\n{lock}`, YELLOW)
				lockText.ZIndex = 5
				pad(lockText, 0.12, 0.08)
				name.TextColor3 = Color3.fromRGB(130, 130, 140)
			end
			card.InputBegan:Connect(function(input: InputObject)
				if not isPress(input) or dropping then
					return
				end
				if lock then
					-- the server refuses locked tiles: say where they come from instead
					whyText.Text = "BUY IN THE SHOP"
					whyText.TextColor3 = YELLOW
					task.delay(2, drawTop)
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
		remember(c, r)
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
			remember(c, r)
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
			remember(c, r)
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
		place(mode, layout.mode)
		place(whyText, layout.why)
		place(tray, layout.tray)
		-- cards grow to fill the bar: as many ~100 px columns as fit, at least 2
		local cw = layout.tray.w - 16
		local cols = math.max(2, math.floor((cw + 8) / 108))
		local card = math.min(130, math.floor((cw - 8 * (cols - 1)) / cols))
		cardGrid.CellSize = UDim2.fromOffset(card, card + 16)
		place(undoBtn, layout.undo)
		place(turnBtn, layout.turn)
		place(eraseBtn, layout.erase)
		place(doneBtn, layout.done)
		drawGrid()
	end

	eraseBtn.Activated:Connect(function()
		erasing = not erasing
		eraseBtn.Text = if erasing then "ERASE: ON" else "ERASE"
		eraseBtn.BackgroundColor3 = if erasing then RED else GREY
		drawGrid()
		drawTop()
	end)
	turnBtn.Activated:Connect(function()
		local at = if selected and not erasing then byKey[selected] else nil
		if at then
			turnTile(at.c, at.r)
		end
	end)
	undoBtn.Activated:Connect(function()
		local step = table.remove(undoList)
		if not step then
			return
		end
		selected = cellKey(step.c, step.r)
		local was = step.before
		if was then
			opts.onPlace(step.c, step.r, was.piece, was.rot)
		else
			opts.onRemove(step.c, step.r)
		end
		drawTop()
	end)
	doneBtn.Activated:Connect(function()
		opts.onDone()
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	local screen = {} :: BuildScreen
	function screen.setState(s: State)
		local resized = s.cols ~= state.cols or s.rows ~= state.rows
		local function lockKey(l: { [string]: string }?): string
			local out = {}
			for id, v in l or {} do
				table.insert(out, id .. "=" .. v)
			end
			table.sort(out)
			return table.concat(out, ",")
		end
		local newTray = #s.specials ~= #state.specials
			or #s.pieces ~= #state.pieces
			or lockKey(s.locks) ~= lockKey(state.locks)
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
		timerText.Text = timerWords(seconds)
	end
	function screen.show(on: boolean)
		gui.Enabled = on
		Players.LocalPlayer:SetAttribute("Building", on) -- lobby buttons hide under the screen
		-- and the DRIVE (E) prompts in the world don't show through the tile bar
		pcall(function()
			(game:GetService("ProximityPromptService") :: any).Enabled = not on
		end)
		if on then
			if Players.LocalPlayer:GetAttribute("LoopShown") ~= true then
				loopUntil = os.clock() + 5
				task.delay(5.1, function()
					-- seen only once it stayed up the whole 5 s (a quick open and close doesn't count)
					if gui.Enabled and os.clock() >= loopUntil then
						Players.LocalPlayer:SetAttribute("LoopShown", true)
					end
					drawTop()
				end)
			end
			relayout()
			drawTop()
		else
			loopUntil = 0
			dropping, dropInput, dragged = nil, nil, false
			ghost.Visible = false
			undoList = {} -- the next break starts fresh
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
