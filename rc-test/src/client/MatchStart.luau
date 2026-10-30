--!strict
-- The match start (carter's pick A1, 10-29): a giant 3, 2, 1 that slams in with a shake, a ring and
-- sparks, "GET READY!" wobbling under it, then a green GO! with a flash, confetti and a zoom.
-- Looks only: the server starts the round at once (the spawn shield covers the first 2 s) and
-- nothing waits for this. It plays when the round number changes and you are in that round.
-- Reduced motion: the words only, no slam, shake, sparks or flash.
-- Also ROUND OVER! (carter's pick A, 10-29): a gold slam at 0:00 with a ring, sparks and a flash
-- before the between-rounds screen opens (client/SmashEnd).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local SmashFx = require(script.Parent:WaitForChild("SmashFx"))

local player = Players.LocalPlayer

local MatchStart = {}

local NAVY = Color3.fromRGB(13, 44, 64)
local RED = Color3.fromRGB(255, 70, 60)
local GREEN = Color3.fromRGB(80, 230, 100)
local SUN = Color3.fromRGB(255, 217, 59)
local WHITE = Color3.new(1, 1, 1)
local CONFETTI = {
	SUN,
	Color3.fromRGB(255, 79, 154),
	GREEN,
	Color3.fromRGB(90, 180, 255),
	RED,
}

local started = false
local roundOverFn: (() -> ())? = nil -- set by start()

local function tween(obj: Instance, secs: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(
		obj,
		TweenInfo.new(secs, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

function MatchStart.start()
	if started then
		return
	end
	started = true

	local PHONE = Base.phone()
	local spot = if PHONE then SmashJuice.START_TOUCH else SmashJuice.START
	local rng = Random.new()
	local runId = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchStart"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19 -- under the smash words (20)
	gui.Parent = player:WaitForChild("PlayerGui")

	local function stroked(l: TextLabel, px: number)
		local st = Instance.new("UIStroke")
		st.Color = NAVY
		st.Thickness = px
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
		return st
	end

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.AnchorPoint = Vector2.new(0.5, 0.5)
	number.Position = UDim2.fromScale(0.5, spot.num.y)
	number.Size = UDim2.fromScale(spot.num.w, spot.num.h)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.LuckiestGuy
	number.TextScaled = true
	number.Text = ""
	number.Visible = false
	local numberStroke = stroked(number, if PHONE then 6 else 10)
	local numberPop = Instance.new("UIScale")
	numberPop.Parent = number
	number.Parent = gui

	local ready = Instance.new("TextLabel")
	ready.Name = "Ready"
	ready.AnchorPoint = Vector2.new(0.5, 0.5)
	ready.Position = UDim2.fromScale(0.5, spot.ready.y)
	ready.Size = UDim2.fromScale(spot.ready.w, spot.ready.h)
	ready.BackgroundTransparency = 1
	ready.Font = Base.FONT
	ready.TextScaled = true
	ready.Text = "GET READY!"
	ready.TextColor3 = WHITE
	ready.Visible = false
	local readyStroke = stroked(ready, if PHONE then 3 else 5)
	local readyPop = Instance.new("UIScale")
	readyPop.Parent = ready
	ready.Parent = gui

	-- a ring that bursts out from the number
	local function ring(color: Color3, thick: number, delay: number, y: number?)
		task.delay(delay, function()
			local d = gui.AbsoluteSize.Y * spot.num.h * 0.8
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, y or spot.num.y)
			f.Size = UDim2.fromOffset(d * 0.3, d * 0.3)
			f.BackgroundTransparency = 1
			Base.corner(f, 999)
			local st = Instance.new("UIStroke")
			st.Color = color
			st.Thickness = thick
			st.Parent = f
			f.Parent = gui
			tween(f, 0.75, { Size = UDim2.fromOffset(d * 2.4, d * 2.4) })
			tween(st, 0.75, { Transparency = 1 })
			task.delay(0.8, function()
				f:Destroy()
			end)
		end)
	end

	-- little stars (or confetti with `fall`) flying out of the number
	local function sparks(
		n: number,
		colors: { Color3 },
		reach: number,
		size: number,
		fall: number,
		y0: number?
	)
		local y = gui.AbsoluteSize.Y
		for i = 1, n do
			local a = math.pi * 2 * i / n + rng:NextNumber(-0.15, 0.15)
			local r = y * reach * rng:NextNumber(0.7, 1.3)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, y0 or spot.num.y)
			f.Size = UDim2.fromOffset(size, size)
			f.Rotation = rng:NextNumber(0, 90)
			f.BackgroundColor3 = colors[(i - 1) % #colors + 1]
			f.BorderSizePixel = 0
			f.Parent = gui
			local life = if fall > 0 then 1.3 else 0.7
			tween(f, life, {
				Position = UDim2.new(
					0.5,
					math.cos(a) * r,
					y0 or spot.num.y,
					math.sin(a) * r + fall * y
				),
				Rotation = f.Rotation + rng:NextNumber(-360, 360),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(size * 0.3, size * 0.3),
			})
			task.delay(life + 0.05, function()
				f:Destroy()
			end)
		end
	end

	local function hold(id: number, secs: number, fn: () -> ())
		task.delay(secs, function()
			if runId == id then
				fn()
			end
		end)
	end

	local function showNumber(id: number, text: string, color: Color3, reduced: boolean)
		number.Text = text
		number.TextColor3 = color
		number.TextTransparency = 0
		numberStroke.Transparency = 0
		number.Visible = true
		if reduced then
			numberPop.Scale = 1
			number.Rotation = 0
			return
		end
		local go = text == "GO!"
		numberPop.Scale = if go then 0.1 else 3.2
		number.Rotation = if go then -20 else -14
		tween(numberPop, if go then 0.45 else 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(number, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
		-- (a number goes away small; GO! blows up and fades)
		hold(id, if go then 1.0 else 0.78, function()
			tween(
				numberPop,
				if go then 0.35 else 0.22,
				{ Scale = if go then 2.6 else 0.2 },
				Enum.EasingStyle.Quad
			)
			tween(number, 0.3, { TextTransparency = 1 })
			tween(numberStroke, 0.3, { Transparency = 1 })
			tween(number, 0.3, { Rotation = if go then 0 else 10 })
		end)
	end

	local function play(id: number)
		local reduced = Base.reduced()
		local total = 3 * SmashJuice.START_STEP
		ready.Text = "GET READY!"
		ready.TextColor3 = WHITE
		ready.TextTransparency = 0
		readyStroke.Transparency = 0
		ready.Visible = true
		ready.Rotation = 0
		readyPop.Scale = 1
		if not reduced then
			-- (wobbles until the next word replaces it)
			ready.Rotation = -3
			TweenService:Create(
				ready,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Rotation = 3 }
			):Play()
			TweenService:Create(
				readyPop,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.1 }
			):Play()
		end
		for i = 0, 2 do
			hold(id, i * SmashJuice.START_STEP, function()
				local n = 3 - i
				showNumber(id, tostring(n), RED, reduced)
				Sfx.count(n)
				if not reduced then
					SmashFx.kick(0.35, 0)
					ring(SUN, if PHONE then 8 else 14, 0)
					ring(WHITE, if PHONE then 4 else 7, 0.12)
					sparks(10, { SUN }, 0.3, if PHONE then 12 else 18, 0)
					sparks(6, { WHITE }, 0.22, if PHONE then 8 else 12, 0)
				end
			end)
		end
		hold(id, total, function()
			showNumber(id, "GO!", GREEN, reduced)
			Sfx.count(0)
			ready.Text = "SMASH!"
			ready.TextColor3 = SUN
			if not reduced then
				SmashFx.kick(0.5, 6)
				ring(GREEN, if PHONE then 10 else 16, 0)
				ring(WHITE, if PHONE then 4 else 7, 0.12)
				sparks(14, { GREEN }, 0.5, if PHONE then 12 else 18, 0)
				sparks(10, { SUN }, 0.4, if PHONE then 10 else 16, 0)
				sparks(30, CONFETTI, 0.45, if PHONE then 8 else 12, 0.35)
				flash.BackgroundTransparency = 0.15
				tween(flash, 0.55, { BackgroundTransparency = 1 })
			end
		end)
		hold(id, total + SmashJuice.START_GO_SECONDS, function()
			tween(ready, 0.25, { TextTransparency = 1 })
			tween(readyStroke, 0.25, { Transparency = 1 })
			task.delay(0.3, function()
				if runId == id then
					ready.Visible = false
					number.Visible = false
				end
			end)
		end)
	end

	-- ROUND OVER!: a gold slam at 0:00 (the end screen waits SmashJuice.ROUND_OVER_SECONDS for it)
	local over = if PHONE then SmashJuice.ROUND_OVER_TOUCH else SmashJuice.ROUND_OVER
	local overWord = Instance.new("TextLabel")
	overWord.Name = "RoundOver"
	overWord.AnchorPoint = Vector2.new(0.5, 0.5)
	overWord.Position = UDim2.fromScale(0.5, over.word.y)
	overWord.Size = UDim2.fromScale(over.word.w, over.word.h)
	overWord.BackgroundTransparency = 1
	overWord.Font = Enum.Font.LuckiestGuy
	overWord.TextScaled = true
	overWord.Text = "ROUND OVER!"
	overWord.TextColor3 = SUN
	overWord.Visible = false
	local overStroke = stroked(overWord, if PHONE then 6 else 10)
	local overPop = Instance.new("UIScale")
	overPop.Parent = overWord
	overWord.Parent = gui
	local overSub = Instance.new("TextLabel")
	overSub.Name = "TimesUp"
	overSub.AnchorPoint = Vector2.new(0.5, 0.5)
	overSub.Position = UDim2.fromScale(0.5, over.sub.y)
	overSub.Size = UDim2.fromScale(over.sub.w, over.sub.h)
	overSub.BackgroundTransparency = 1
	overSub.Font = Base.FONT
	overSub.TextScaled = true
	overSub.Text = "Time's up!"
	overSub.TextColor3 = SUN
	overSub.Visible = false
	local subStroke = stroked(overSub, if PHONE then 3 else 5)
	overSub.Parent = gui
	roundOverFn = function()
		runId += 1 -- (a 3-2-1 still on screen goes away)
		number.Visible = false
		ready.Visible = false
		local id = runId
		local reduced = Base.reduced()
		overWord.TextTransparency = 0
		overStroke.Transparency = 0
		overSub.TextTransparency = 0
		subStroke.Transparency = 0
		overWord.Visible = true
		overSub.Visible = true
		Sfx.count(0)
		if reduced then
			overPop.Scale = 1
			overWord.Rotation = 0
		else
			overPop.Scale = 3.4
			overWord.Rotation = -12
			tween(overPop, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(overWord, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
			SmashFx.kick(0.45, 0)
			ring(WHITE, if PHONE then 6 else 10, 0, over.word.y)
			sparks(14, { SUN }, 0.5, if PHONE then 12 else 18, 0, over.word.y)
			sparks(8, { WHITE }, 0.35, if PHONE then 8 else 12, 0, over.word.y)
			flash.BackgroundTransparency = 0.2
			tween(flash, 0.5, { BackgroundTransparency = 1 })
		end
		hold(id, SmashJuice.ROUND_OVER_SECONDS - 0.3, function()
			tween(overWord, 0.25, { TextTransparency = 1 })
			tween(overStroke, 0.25, { Transparency = 1 })
			tween(overSub, 0.25, { TextTransparency = 1 })
			tween(subStroke, 0.25, { Transparency = 1 })
			task.delay(0.3, function()
				if runId == id then
					overWord.Visible = false
					overSub.Visible = false
				end
			end)
		end)
	end

	-- a new round: show it if you are in it (InMatch can arrive a moment after the round number)
	workspace:GetAttributeChangedSignal("MatchRound"):Connect(function()
		runId += 1
		local id = runId
		number.Visible = false
		ready.Visible = false
		overWord.Visible = false
		overSub.Visible = false
		task.delay(0.25, function()
			if runId == id and player:GetAttribute("InMatch") == true then
				play(id)
			end
		end)
	end)
	-- you left or the round ended: put it all away
	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if player:GetAttribute("InMatch") ~= true then
			runId += 1
			number.Visible = false
			ready.Visible = false
			overWord.Visible = false
			overSub.Visible = false
		end
	end)
end

-- play ROUND OVER! now; true when it is up (the caller then waits SmashJuice.ROUND_OVER_SECONDS)
function MatchStart.roundOver(): boolean
	local f = roundOverFn
	if f then
		f()
		return true
	end
	return false
end

return MatchStart
