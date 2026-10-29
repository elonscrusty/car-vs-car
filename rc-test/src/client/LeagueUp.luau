--!strict
-- Car VS Car league-up ceremony (Silver, Gold, Diamond): the big moment around the LEAGUE UP!
-- screen (Flow.leagueUp). Four beats (vault "Reward Moments and Celebrations"):
--   1 build-up: the world tints the new league's color, a beam of light on your car
--   2 reveal:   (Gold, Diamond) one soft white flash, then the screen with the league's rays
--               behind the new badge, more confetti, the league's name and its real reward
--               (bigger race prizes); Diamond shakes the badge and says TOP LEAGUE!
--   3 AWESOME! shows last, after `hold` seconds, so a tapping kid doesn't skip it
--   4 after:    (Gold, Diamond) fireworks pop over your car, then the world tint fades
-- Sound: one Sfx.fireworks() at the start (the SOUNDS row owns it), nothing else.
-- What each league adds is League.CEREMONY. Reduced motion keeps the colors, words and sounds
-- and drops the flash, shake, beam and fireworks.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local League = require(Shared:WaitForChild("League"))
local UiScreens = require(Shared:WaitForChild("UiScreens"))
local Ui = script.Parent:WaitForChild("Ui")
local Base = require(Ui:WaitForChild("Base"))
local Anim = require(Ui:WaitForChild("Anim"))
local Kit = require(Ui:WaitForChild("Kit"))
local Screen = require(Ui:WaitForChild("Screen"))
local Flow = require(Ui:WaitForChild("Screens"):WaitForChild("Flow"))
local KitWindows = require(Ui:WaitForChild("Screens"):WaitForChild("KitWindows"))
local Features = require(Shared:WaitForChild("Features"))
local SMASH = (Features :: any).SMASH == true
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local LeagueUp = {}

local BUILD_UP = 0.7 -- seconds of beat 1 before the screen

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- where your car (or you) is in the world
local function here(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = workspace.CurrentCamera
	return if cam then cam.Focus.Position else Vector3.zero
end

local function tween(obj: Instance, secs: number, goal: { [string]: any })
	TweenService
		:Create(obj, TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- beat 1: the world takes the league's color (faded out again by the returned function)
local function tint(color: Color3): () -> ()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LeagueUpTint"
	cc.Parent = Lighting
	tween(
		cc,
		0.4,
		{ TintColor = Color3.new(1, 1, 1):Lerp(color, 0.45), Brightness = 0.05, Saturation = 0.2 }
	)
	local gone = false
	return function()
		if gone then
			return
		end
		gone = true
		tween(cc, 0.8, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 })
		task.delay(0.9, function()
			cc:Destroy()
		end)
	end
end

-- beat 1: a beam of light on your car, in the league's color
local function beam(at: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = "LeagueUpBeam"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 1
	p.Size = Vector3.new(60, 2, 2)
	p.CFrame = CFrame.new(at + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	tween(p, 0.3, { Transparency = 0.35, Size = Vector3.new(60, 7, 7) })
	task.delay(BUILD_UP + 0.6, function()
		tween(p, 0.5, { Transparency = 1 })
	end)
	task.delay(BUILD_UP + 1.2, function()
		p:Destroy()
	end)
end

-- beat 2: one soft white flash over everything (one only: the vault's flash limit)
local function flash()
	local g = Instance.new("ScreenGui")
	g.Name = "LeagueUpFlash"
	g.ScreenInsets = Enum.ScreenInsets.None
	g.ResetOnSpawn = false
	g.DisplayOrder = Base.ORDER.celebrate + 3
	g:SetAttribute("NoKart", true)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0.15
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	tween(f, 0.45, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		g:Destroy()
	end)
end

-- beat 4: a firework pops over your car
local function firework(at: Vector3, color: Color3, i: number)
	local start = at + Vector3.new(math.random(-10, 10), 2, math.random(-10, 10))
	local p = Instance.new("Part")
	p.Name = "LeagueUpFirework"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Position = start
	p.Parent = workspace
	local up = 16 + (i % 3) * 4
	tween(p, 0.55, { Position = start + Vector3.new(0, up, 0) })
	task.delay(0.55, function()
		p.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.1, 0)
		e.Speed = NumberRange.new(14, 22)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, -10, 0)
		e.Rate = 0
		e.Parent = p
		e:Emit(45)
	end)
	task.delay(2.2, function()
		p:Destroy()
	end)
end

-- beat 2 + 3: the layers on top of the LEAGUE UP! screen
local function dress(h: Screen.Handle, c: League.Ceremony, color: Color3)
	local canvas = h.gui.canvas
	local back = h.gui.back
	-- the league's rays behind the new badge
	local newSpot = canvas:FindFirstChild("New") :: GuiObject?
	local np = UiScreens.piece("leagueUp", "New")
	local rays = Kit.rays(canvas, np.x + np.w / 2, np.y + np.h / 2, 340, "go", 0.3)
	for _, r in rays:GetChildren() do
		if r:IsA("Frame") then
			r.BackgroundColor3 = color
		end
	end
	if newSpot then
		newSpot.ZIndex = 2
	end
	-- more confetti the higher the league
	local backdrop = back and back:FindFirstChild("Backdrop") :: GuiObject?
	if backdrop and c.confetti > 0 then
		Kit.confetti(backdrop, c.confetti)
	end
	-- the league's name and what it gives, where a reward goes
	local rp = UiScreens.piece("leagueUp", "Reward")
	local _, panel = Kit.placedPanel(canvas, rp)
	Base.text(panel, "League", 10, 5, rp.w - 20, 24, if c.top then "TOP LEAGUE!" else c.name, {
		color = color,
		stroke = 4,
	})
	Base.text(panel, "Pay", 10, 31, rp.w - 20, 20, c.pay, { color = Base.color("ink") })
	Anim.pop(panel, 0.5, 0.3, 0.5)
	-- Diamond: the new badge shakes as it lands
	if c.shake and newSpot and not Base.reduced() then
		task.delay(0.4, function()
			for i, deg in { -8, 8, -6, 6, -3, 0 } do
				task.delay((i - 1) * 0.07, function()
					if newSpot.Parent then
						Anim.to(newSpot, 0.07, { Rotation = deg })
					end
				end)
			end
		end)
	end
	-- buttons come last
	local ok = canvas:FindFirstChild("Awesome") :: GuiObject?
	if ok then
		ok.Visible = false
		task.delay(c.hold, function()
			if ok.Parent then
				ok.Visible = true
				Anim.pop(ok, 0.35, 0.6)
			end
		end)
	end
end

-- Play the ceremony for league `from` -> `to` (nothing if it isn't a step up). Yields for the
-- build-up (so a queue of big moments waits); `closed` runs when AWESOME! is tapped.
function LeagueUp.play(from: number, to: number, closed: (() -> ())?)
	local c = League.ceremony(from, to)
	if not c then
		return
	end
	local color = rgb(c.color)
	local calm = Base.reduced()
	local at = here()
	-- 1 build-up
	local untint = tint(color)
	if not calm then
		beam(at, color)
	end
	-- the one league-up sound (the SOUNDS row's "leagueUp" cue)
	Sfx.fireworks()
	task.wait(BUILD_UP)
	-- 2 reveal
	if c.flash and not calm then
		flash()
	end
	local done = false
	local function after()
		if done then
			return
		end
		done = true
		-- 4 fireworks over your car, then the color fades
		local n = if calm then 0 else c.fireworks
		for i = 1, n do
			task.delay((i - 1) * 0.35, firework, here(), color, i)
		end
		task.delay(n * 0.35 + 0.8, untint)
		if closed then
			closed()
		end
	end
	local ok = function()
		Screen.closeOver()
		after()
	end
	local h: Screen.Handle
	if SMASH then
		-- carter's kit v41 look: everything dress() adds is on the screen itself
		h = KitWindows.leagueUp({
			to = c.to,
			name = c.name,
			pay = (string.gsub(c.pay, "^Races", "Matches")),
			color = color,
			confetti = c.confetti,
			hold = c.hold,
			shake = c.shake,
			top = c.top,
		}, { ok = ok })
	else
		h = Flow.leagueUp({ from = from, to = c.to }, { ok = ok })
		dress(h, c, color)
	end
	-- closed some other way (another big moment, a race): still finish cleanly
	local gui = h.gui.gui
	local watch: RBXScriptConnection
	watch = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			watch:Disconnect()
			after()
		end
	end)
end

return LeagueUp
