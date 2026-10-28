--!strict
-- Car VS Car screens: the motion of spec section 7. Entrances (windows bounce in, titles swing,
-- the X spins, lists rise one after another, bars fill, numbers count up, shouts and GO! slam)
-- and idle life (bobs, pulses, wiggles, nudges, shakes, sweeps). Everything stops when the
-- device asks for reduced motion (Base.reduced): things just show at their end.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(Shared:WaitForChild("UiMotion"))
local Base = require(script.Parent:WaitForChild("Base"))

local M = UiTheme.MOTION
local Back, Sine, Quad, Linear =
	Enum.EasingStyle.Back, Enum.EasingStyle.Sine, Enum.EasingStyle.Quad, Enum.EasingStyle.Linear
local Out, InOut = Enum.EasingDirection.Out, Enum.EasingDirection.InOut

local Anim = {}

-- ===== one Heartbeat for everything that runs every frame =====

export type Ticker = { obj: Instance, fn: (t: number) -> () }
local tickers: { Ticker } = {}
local clock = 0

local function onScreen(obj: Instance): boolean
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	return gui ~= nil and gui.Enabled
end

RunService.Heartbeat:Connect(function(dt: number)
	clock += dt
	local i = 1
	while i <= #tickers do
		local tk = tickers[i]
		if not tk.obj.Parent then
			tickers[i] = tickers[#tickers]
			tickers[#tickers] = nil
		else
			if onScreen(tk.obj) then
				tk.fn(clock)
			end
			i += 1
		end
	end
end)

-- fn(t) every frame while obj is alive and its screen is on (t: seconds since start)
function Anim.tick(obj: Instance, fn: (t: number) -> ())
	table.insert(tickers, { obj = obj, fn = fn })
end

function Anim.now(): number
	return clock
end

-- ===== tweens =====

-- A tween that is skipped (jumps to the end) with reduced motion.
function Anim.to(
	obj: Instance,
	secs: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	delay: number?
): Tween?
	if Base.reduced() then
		for k, v in props do
			(obj :: any)[k] = v
		end
		return nil
	end
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(secs, style or Quad, dir or Out, 0, false, delay or 0),
		props
	)
	tw:Play()
	return tw
end

-- A back-and-forth that never stops (idle life). Nothing with reduced motion.
function Anim.loop(
	obj: Instance,
	secs: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	delay: number?
): Tween?
	if Base.reduced() then
		return nil
	end
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(secs / 2, style or Sine, InOut, -1, true, delay or 0),
		props
	)
	tw:Play()
	return tw
end

-- fn every `period` seconds (the first after `first`, default one period), while obj lives.
function Anim.every(obj: Instance, period: number, fn: () -> (), first: number?)
	if Base.reduced() then
		return
	end
	local nextAt = clock + (first or period)
	Anim.tick(obj, function(t)
		if t >= nextAt then
			nextAt = t + period
			fn()
		end
	end)
end

-- The UIScale of obj (made if missing).
function Anim.scaler(obj: Instance): UIScale
	local s = obj:FindFirstChild("Pop")
	if s and s:IsA("UIScale") then
		return s
	end
	local made = Instance.new("UIScale")
	made.Name = "Pop"
	made.Parent = obj
	return made
end

-- ===== entrances =====

-- Grow in from `from` (default 80%) with a bounce.
function Anim.pop(obj: GuiObject, secs: number?, from: number?, delay: number?)
	local s = Anim.scaler(obj)
	s.Scale = from or M.windowFrom
	Anim.to(s, secs or M.windowIn, { Scale = 1 }, Back, Out, delay)
end

-- A window: body 80% -> 100% (0.38 s, Back), title swings in, X spins in, then the title wobbles.
function Anim.windowIn(win: GuiObject, title: GuiObject?, close: GuiObject?)
	Anim.pop(win, M.windowIn, M.windowFrom)
	if title then
		local ts = Anim.scaler(title)
		local rest = title.Rotation
		ts.Scale = M.titleFrom
		title.Rotation = rest + M.titleTilt
		Anim.to(ts, M.titleIn, { Scale = 1 }, Back, Out, M.titleDelay)
		Anim.to(title, M.titleIn, { Rotation = rest }, Back, Out, M.titleDelay)
		task.delay(M.titleDelay + M.titleIn + 0.5, function()
			if title.Parent then
				Anim.loop(title, M.titleWobble, { Rotation = rest - 2 }, Sine)
			end
		end)
	end
	if close then
		local cs = Anim.scaler(close)
		local rest = close.Rotation
		cs.Scale = 0
		close.Rotation = rest - 185
		Anim.to(cs, M.closeIn, { Scale = 1 }, Back, Out, M.closeDelay)
		Anim.to(close, M.closeIn, { Rotation = rest }, Back, Out, M.closeDelay)
	end
end

-- The i-th item of a list: rises 16 px and grows 94% -> 100%, 0.06 s after the one before.
function Anim.rise(obj: GuiObject, i: number)
	local s = Anim.scaler(obj)
	local home = obj.Position
	local delay = UiMotion.stagger(i)
	if Base.reduced() then
		return
	end
	s.Scale = M.listFrom
	obj.Position = home + UDim2.fromOffset(0, M.listRise * Base.k)
	local wasVisible = obj.Visible
	obj.Visible = false
	task.delay(delay, function()
		obj.Visible = wasVisible
		Anim.to(s, M.listIn, { Scale = 1 }, Back, Out)
		Anim.to(obj, M.listIn, { Position = home }, Back, Out)
	end)
end

-- A list of items, in order.
function Anim.cascade(list: { GuiObject })
	for i, obj in list do
		Anim.rise(obj, i)
	end
end

-- Shout words: 30% -> 112% -> 100% in 0.6 s. GO!: 20% -> 118% -> 94% -> 100%.
local function keyed(obj: GuiObject, keys: UiMotion.Keys, secs: number)
	local s = Anim.scaler(obj)
	if Base.reduced() then
		s.Scale = 1
		return
	end
	local start = clock
	s.Scale = keys[1][2]
	local done = false
	Anim.tick(s, function(t)
		if done then
			return
		end
		local f = (t - start) / secs
		s.Scale = UiMotion.keyed(keys, f)
		if f >= 1 then
			done = true
		end
	end)
end
function Anim.shout(obj: GuiObject)
	keyed(obj, UiMotion.SHOUT_KEYS, M.shoutIn)
end
function Anim.slam(obj: GuiObject)
	keyed(obj, UiMotion.GO_KEYS, 0.9)
end

-- A card flips on its up-down axis (90 deg to 0) in 0.18 s: drawn as its width growing.
function Anim.flip(holder: GuiObject)
	local full = holder:GetAttribute("FullW")
	if type(full) ~= "number" then
		full = holder.Size.X.Scale
		holder:SetAttribute("FullW", full)
	end
	local fw = full :: number
	if Base.reduced() then
		return
	end
	holder.Size = UDim2.new(0, 0, holder.Size.Y.Scale, holder.Size.Y.Offset)
	Anim.to(
		holder,
		M.cardFlip,
		{ Size = UDim2.new(fw, 0, holder.Size.Y.Scale, holder.Size.Y.Offset) },
		Quad,
		Out
	)
end

-- Words count up to `to` (from `from`, default 0) in 0.9 s; fmt makes the words.
function Anim.countUp(label: TextLabel, from: number, to: number, fmt: ((n: number) -> string)?)
	local f = fmt or UiMotion.commas
	if Base.reduced() or from == to then
		Base.setText(label, f(to))
		return
	end
	local start = clock
	local done = false
	label:SetAttribute("CountTo", to)
	Anim.tick(label, function(t)
		if done or label:GetAttribute("CountTo") ~= to then
			done = true
			return
		end
		local n = UiMotion.countUp(from, to, t - start, M.countUp)
		Base.setText(label, f(n))
		if n == to then
			done = true
		end
	end)
end

-- A bar's fill grows from empty to `to` (0..1) over 1 s, 0.25 s in.
function Anim.grow(fill: GuiObject, to: number, delay: number?)
	local size = UDim2.new(math.clamp(to, 0, 1), 0, 1, 0)
	if Base.reduced() then
		fill.Size = size
		return
	end
	fill.Size = UDim2.new(0, 0, 1, 0)
	Anim.to(fill, M.barFill, { Size = size }, Enum.EasingStyle.Quint, Out, delay or M.barDelay)
end

-- ===== idle life =====

-- Up and down `px`, one round trip every `period` s, starting `phase` s in.
function Anim.bob(obj: GuiObject, period: number?, px: number?, phase: number?)
	if Base.reduced() then
		return
	end
	local home = obj.Position
	local per = period or M.carBob
	local amp = px or 5
	local off = phase or 0
	Anim.tick(obj, function(t)
		obj.Position = home + UDim2.fromOffset(0, UiMotion.bob(t + off, per, amp) * Base.k)
	end)
end

-- Breathe: scale 1 <-> `to` (BOOST full: 1.07 every 0.9 s).
function Anim.pulse(obj: GuiObject, to: number?, period: number?): Tween?
	return Anim.loop(Anim.scaler(obj), period or M.boostPulse, { Scale = to or 1.07 })
end

-- A tag wiggles between -4 and -8 deg and grows 7%, every 2.4 s.
function Anim.wiggle(obj: GuiObject)
	obj.Rotation = -4
	Anim.loop(obj, M.tagWiggle, { Rotation = -8 })
	Anim.loop(Anim.scaler(obj), M.tagWiggle, { Scale = 1.07 })
end

-- A quick nudge (-8, +6, -3 deg) every 4.5 s.
function Anim.nudge(obj: GuiObject, first: number?)
	Anim.every(obj, M.sideNudge, function()
		-- (only the next thing to tap moves: the rest go quiet, auditor L2)
		if obj:GetAttribute("Quiet") == true then
			return
		end
		local steps = { -8, 6, -3, 0 }
		for i, deg in steps do
			task.delay((i - 1) * 0.09, function()
				Anim.to(obj, 0.09, { Rotation = deg }, Sine, InOut)
			end)
		end
	end, first)
end

-- A shake burst (closed crate) every 2.4 s.
function Anim.shake(obj: GuiObject)
	Anim.every(obj, M.crateShake, function()
		local steps = { -7, 7, -5, 5, -2, 0 }
		for i, deg in steps do
			task.delay((i - 1) * 0.1, function()
				Anim.to(obj, 0.1, { Rotation = deg }, Sine, InOut)
			end)
		end
		local s = Anim.scaler(obj)
		task.delay(0.6, function()
			Anim.to(s, 0.12, { Scale = 1.04 }, Sine, Out)
			task.delay(0.12, function()
				Anim.to(s, 0.2, { Scale = 1 }, Sine, Out)
			end)
		end)
	end, 0.6)
end

-- The red count dot: bounce to 135% and up 3 px every 1.8 s.
function Anim.dot(obj: GuiObject)
	local home = obj.Position
	local s = Anim.scaler(obj)
	Anim.every(obj, M.dotBounce, function()
		Anim.to(s, 0.15, { Scale = 1.35 }, Quad, Out)
		Anim.to(obj, 0.15, { Position = home - UDim2.fromOffset(0, 3 * Base.k) }, Quad, Out)
		task.delay(0.15, function()
			Anim.to(s, 0.35, { Scale = 1 }, Back, Out)
			Anim.to(obj, 0.35, { Position = home }, Back, Out)
		end)
	end, 1)
end

-- Spin round and round, one turn every `secs` (rays: 30 s).
function Anim.spin(obj: GuiObject, secs: number)
	if Base.reduced() then
		return
	end
	local start = obj.Rotation
	Anim.tick(obj, function(t)
		obj.Rotation = start + (t / secs * 360) % 360
	end)
end

-- A white light sweep across a big lime button every 2.8 s. `clip` is the button's face.
function Anim.shine(clip: GuiObject)
	if Base.reduced() then
		return
	end
	local band = Instance.new("Frame")
	band.Name = "Shine"
	band.BackgroundColor3 = Base.WHITE
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.fromScale(0.22, 1.6)
	band.Position = UDim2.fromScale(-0.3, 0.5)
	band.Rotation = 18
	band.ZIndex = 2
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	band.Parent = clip
	Anim.every(band, M.shine, function()
		band.Position = UDim2.fromScale(-0.3, 0.5)
		Anim.to(band, 1.1, { Position = UDim2.fromScale(1.3, 0.5) }, Sine, InOut)
	end, 1)
end

-- The press: squash to 90% for 0.1 s, then spring back.
function Anim.press(button: GuiButton)
	local s = Anim.scaler(button)
	button.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			Anim.to(s, M.press, { Scale = M.pressTo }, Quad, Out)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			Anim.to(s, 0.3, { Scale = 1 }, Back, Out)
		end
	end)
end

Anim.Back, Anim.Sine, Anim.Linear, Anim.Out, Anim.InOut = Back, Sine, Linear, Out, InOut

return Anim
