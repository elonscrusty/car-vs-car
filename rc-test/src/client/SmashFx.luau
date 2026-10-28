--!strict
-- Smash juice (phase 4, JUICE row): listens to the SmashFeed remote and your Health, and plays
--   * "You SMASHED <name>!" big in the middle top, popping in, with a white edge flash, confetti,
--     a shake and a little slow-mo (the camera punches in, holds, and eases back)
--   * a streak word under it from your 2nd smash in a row (DOUBLE SMASH! ...)
--   * "SMASHED by <name>" in red when you get smashed, with a hard shake
--   * a red edge flash and a small shake when you take a hit
-- All numbers live in shared/SmashJuice. Everything is made once at start, so a smash only sets
-- properties: the words are on screen on the next frame (hard target ≤ 0.1 s, logged as
-- "[SmashFx] shown in N ms"). Looks only: the server decides every hit, and driving stays LOCKED
-- (the shake and zoom are laid over the chase camera after it runs, never fed back into it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local Ui = script.Parent:WaitForChild("Ui")
local Base = require(Ui:WaitForChild("Base"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local SmashFx = {}

local CONFETTI = 48 -- pool size (the most one smash ever throws)
local NAVY = Color3.fromRGB(28, 32, 64)
local CHERRY = Color3.fromRGB(230, 50, 60)
local SUN = Color3.fromRGB(255, 210, 60)
local PINK = Color3.fromRGB(255, 90, 170)

local started = false
local timings: { number } = {} -- last few "event → on screen" times, seconds

local function tween(obj: Instance, secs: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(obj, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function word(parent: Instance, name: string, color: Color3, y: number, h: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.9, h)
	l.BackgroundTransparency = 1
	l.Font = Base.FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = ""
	l.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = NAVY
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = l
	local max = Instance.new("UITextSizeConstraint")
	max.MaxTextSize = 64
	max.Parent = l
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = l
	l.Parent = parent
	return l
end

-- one word line: pop in now, fade out after `secs` (a newer show cancels the old fade)
local function showWord(l: TextLabel, text: string, secs: number, from: number)
	local id = (l:GetAttribute("ShowId") or 0) :: number + 1
	l:SetAttribute("ShowId", id)
	l.Text = text
	l.TextTransparency = 0
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	l.Visible = true
	local pop = l:FindFirstChild("Pop") :: UIScale
	if Base.reduced() then
		pop.Scale = 1
	else
		pop.Scale = from
		tween(pop, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(secs, function()
		if l:GetAttribute("ShowId") ~= id then
			return
		end
		tween(l, 0.25, { TextTransparency = 1 })
		if stroke then
			tween(stroke, 0.25, { Transparency = 1 })
		end
		task.delay(0.26, function()
			if l:GetAttribute("ShowId") == id then
				l.Visible = false
			end
		end)
	end)
end

function SmashFx.start()
	if started then
		return
	end
	started = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "SmashFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20 -- over the HUD, under windows
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the edge flash: a frame with a see-through middle (a UIGradient on 4 sides is costly, so
	-- one frame with a thick UIStroke-like border made of 4 bars)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.Parent = gui
	local bars: { Frame } = {}
	for i, spec in
		{
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.07) },
			{ UDim2.fromScale(0, 0.93), UDim2.fromScale(1, 0.07) },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.05, 1) },
			{ UDim2.fromScale(0.95, 0), UDim2.fromScale(0.05, 1) },
		}
	do
		local b = Instance.new("Frame")
		b.Name = "Edge" .. i
		b.Position = spec[1]
		b.Size = spec[2]
		b.BorderSizePixel = 0
		b.BackgroundTransparency = 1
		b.Parent = flash
		table.insert(bars, b)
	end

	-- the words (below the health bar at the top middle, above the car)
	local you = word(gui, "YouSmashed", Color3.new(1, 1, 1), 0.2, 0.07)
	local name = word(gui, "Name", SUN, 0.29, 0.13)
	local streak = word(gui, "Streak", PINK, 0.4, 0.09)
	local by = word(gui, "SmashedBy", CHERRY, 0.29, 0.11)

	-- the confetti pool
	type Bit = { frame: Frame, vx: number, vy: number, spin: number, life: number }
	local bits: { Bit } = {}
	local rng = Random.new()
	for i = 1, CONFETTI do
		local f = Instance.new("Frame")
		f.Name = "Confetti" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.Visible = false
		f.Parent = gui
		local c = SmashJuice.CONFETTI[(i - 1) % #SmashJuice.CONFETTI + 1]
		f.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
		table.insert(bits, { frame = f, vx = 0, vy = 0, spin = 0, life = 0 })
	end
	local live = 0

	local function confetti(n: number)
		local count = 0
		for _, b in bits do
			if count >= n then
				break
			end
			if b.life <= 0 then
				count += 1
				b.life = rng:NextNumber(1.1, 1.6)
				b.vx = rng:NextNumber(-0.55, 0.55)
				b.vy = rng:NextNumber(-0.75, -0.35)
				b.spin = rng:NextNumber(-540, 540)
				local s = rng:NextInteger(7, 13)
				b.frame.Size = UDim2.fromOffset(s, math.floor(s * 0.6))
				b.frame.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.12, 0.12), 0.29)
				b.frame.Rotation = rng:NextNumber(0, 360)
				b.frame.BackgroundTransparency = 0
				b.frame.Visible = true
				live += 1
			end
		end
	end

	local function edge(color: Color3, strength: number)
		if strength <= 0 then
			return
		end
		for _, b in bars do
			b.BackgroundColor3 = color
			b.BackgroundTransparency = 1 - 0.6 * strength
			tween(b, 0.35, { BackgroundTransparency = 1 })
		end
	end

	-- camera: shake + zoom punch, laid over whatever camera ran this frame
	local trauma = 0
	local punch, slow, punchAt = 0, 0, -math.huge
	local fps = 60
	local noiseT = 0
	local seed = rng:NextNumber(0, 1000)
	local pushedFov = 0
	local pending: number? = nil -- os.clock() of a smash waiting to be seen on screen

	local function feel(f: SmashJuice.Feel)
		trauma = SmashJuice.addTrauma(trauma, f.trauma)
		if f.punch > 0 then
			punch, slow, punchAt = f.punch, f.slow, os.clock()
		end
	end

	RunService:BindToRenderStep("SmashFx", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if pending then
			table.insert(timings, os.clock() - pending)
			if #timings > 20 then
				table.remove(timings, 1)
			end
			print(string.format("[SmashFx] shown in %d ms", math.floor((os.clock() - pending) * 1000 + 0.5)))
			pending = nil
		end
		fps += ((1 / math.max(dt, 1 / 240)) - fps) * math.min(dt * 2, 1)
		local cam = workspace.CurrentCamera
		if cam then
			-- the zoom is set fresh each frame from the base FOV (ours taken back off first)
			local base = cam.FieldOfView + pushedFov
			pushedFov = SmashJuice.punchAt(punch, slow, os.clock() - punchAt)
			cam.FieldOfView = base - pushedFov
			if trauma > 0 then
				noiseT += dt * SmashJuice.noiseHz(fps)
				local p, y, r = SmashJuice.tilt(
					trauma,
					math.noise(noiseT, seed),
					math.noise(noiseT, seed + 31),
					math.noise(noiseT, seed + 67)
				)
				cam.CFrame *= CFrame.Angles(math.rad(p), math.rad(y), math.rad(r))
				trauma = SmashJuice.decay(trauma, dt)
			end
		end
		if live > 0 then
			for _, b in bits do
				if b.life > 0 then
					b.life -= dt
					b.vy += 1.4 * dt
					local pos = b.frame.Position
					b.frame.Position =
						UDim2.fromScale(pos.X.Scale + b.vx * dt * 0.6, pos.Y.Scale + b.vy * dt)
					b.frame.Rotation += b.spin * dt
					if b.life < 0.3 then
						b.frame.BackgroundTransparency = 1 - b.life / 0.3
					end
					if b.life <= 0 then
						b.frame.Visible = false
						live -= 1
					end
				end
			end
		end
	end)

	local myStreak = SmashJuice.streak()

	local function cue(nameOf: string)
		-- the SOUNDS row owns the cue table; play it when it exists
		local fn = (Sfx :: any)[nameOf]
		if type(fn) == "function" then
			task.spawn(fn)
		end
	end

	local function onFeed(attacker: unknown, victim: unknown, weapon: unknown)
		local at = os.clock()
		local f = SmashJuice.read(attacker, victim, weapon, player.UserId)
		if not f then
			return
		end
		local reduced = Base.reduced()
		if f.attacker and f.attacker.me and not f.victim.me then
			local n = myStreak:smash()
			by.Visible = false
			showWord(you, "You SMASHED", SmashJuice.WORDS_SECONDS, 1.8)
			showWord(name, SmashJuice.shortName(f.victim.name) .. "!", SmashJuice.WORDS_SECONDS, 2.2)
			local sw = SmashJuice.streakWord(n)
			if sw then
				showWord(streak, sw, SmashJuice.STREAK_SECONDS, 2.6)
			end
			local juice = SmashJuice.feel("mySmash", n, reduced)
			feel(juice)
			edge(Color3.new(1, 1, 1), juice.flash)
			confetti(juice.confetti)
			pending = at
			cue("smash")
		elseif f.victim.me then
			myStreak:reset()
			you.Visible = false
			name.Visible = false
			streak.Visible = false
			local who = if f.attacker and not f.attacker.me then SmashJuice.shortName(f.attacker.name) else nil
			showWord(by, if who then `SMASHED by {who}` else "SMASHED!", SmashJuice.SMASHED_BY_SECONDS, 1.6)
			local juice = SmashJuice.feel("smashed", nil, reduced)
			feel(juice)
			edge(CHERRY, juice.flash)
			pending = at
		end
	end

	local function hook(remote: Instance)
		if remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onFeed)
		end
	end
	local feed = ReplicatedStorage:FindFirstChild("SmashFeed")
	if feed then
		hook(feed)
	else
		-- the match server makes it; wait for it without blocking the caller
		local conn: RBXScriptConnection
		conn = ReplicatedStorage.ChildAdded:Connect(function(c: Instance)
			if c.Name == "SmashFeed" then
				conn:Disconnect()
				hook(c)
			end
		end)
	end

	-- a hit: Health went down (the server sets it; a respawn back to full is not a hit)
	local lastHealth: number? = nil
	player:GetAttributeChangedSignal("Health"):Connect(function()
		local h = player:GetAttribute("Health")
		if type(h) ~= "number" then
			return
		end
		local was = lastHealth
		lastHealth = h
		if was and h < was and h > 0 then
			local juice = SmashJuice.feel("hit", was - h, Base.reduced())
			feel(juice)
			edge(CHERRY, juice.flash)
		end
	end)
end

-- a boom (rocket, mine) at `at`: shakes you by how near it was. WeaponFx can call this.
function SmashFx.boom(at: Vector3)
	local cam = workspace.CurrentCamera
	if not cam or not started then
		return
	end
	local _ = SmashJuice.feel("boom", (cam.Focus.Position - at).Magnitude, Base.reduced())
	-- the trauma is applied through the same path as a hit
	SmashFx._feel(SmashJuice.feel("boom", (cam.Focus.Position - at).Magnitude, Base.reduced()))
end

-- the last few "smash arrived → words on screen" times in seconds (for the Studio timing log)
function SmashFx.timings(): { number }
	return table.clone(timings)
end

return SmashFx
