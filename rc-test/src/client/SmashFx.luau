--!strict
-- Smash juice (phase 4, JUICE row): listens to the SmashFeed remote and your Health, and plays
--   * "You SMASHED <name>!" big in the middle top, popping in, with a white edge flash, confetti,
--     a shake and a little slow-mo (the camera punches in, holds, and eases back)
--   * a streak word under it (DOUBLE SMASH!, TRIPLE SMASH!, SMASH STREAK x3!)
--   * when you get smashed: "You were smashed by X's rocket" in red, a hard shake, and the camera
--     swings over to X with a big 3-2-1, then hands back when you respawn (or after 3.5 s)
--   * a red edge flash and a small shake when you take a hit
-- All numbers live in shared/SmashJuice. Everything is made once at start, so a smash only sets
-- properties: the words are on screen on the next frame (hard target ≤ 0.1 s, logged as
-- "[SmashFx] shown in N ms"). Looks only: the server decides every hit, and driving stays LOCKED
-- (the shake and zoom are laid over the chase camera after it runs, never fed back into it).
local CollectionService = game:GetService("CollectionService")
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
local addFeel: ((SmashJuice.Feel) -> ())? = nil -- set by start()
local timings: { number } = {} -- last few "event → on screen" times, seconds

local function tween(obj: Instance, secs: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(
		obj,
		TweenInfo.new(secs, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
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
	local by = word(gui, "SmashedBy", CHERRY, 0.22, 0.09)
	local count = word(gui, "Count", Color3.new(1, 1, 1), 0.36, 0.18)

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
		local thrown = 0
		for _, b in bits do
			if thrown >= n then
				break
			end
			if b.life <= 0 then
				thrown += 1
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

	-- camera: shake + zoom punch + killer camera, laid over whatever camera ran this frame. If
	-- nothing set the camera since our last frame, ours is taken back off first, so it never
	-- piles up (vault "Snippets - Camera Shake and FX").
	local trauma = 0
	local punch, slow, punchAt = 0, 0, -math.huge
	local fps = 60
	local noiseT = 0
	local seed = rng:NextNumber(0, 1000)
	local baseCf, outCf = CFrame.identity, CFrame.identity
	local baseFov, outFov = 70, -1
	local pending: number? = nil -- os.clock() of words waiting to be seen on screen

	-- the killer camera
	local killcam = false
	local killAt = 0
	local killFrom = CFrame.identity
	local killer: SmashJuice.Side? = nil
	local killerModel: Instance? = nil -- the kart, once found (no tag scan every frame)
	local lastWant: CFrame? = nil
	local shownCount: number? = nil

	local function feel(f: SmashJuice.Feel)
		trauma = SmashJuice.addTrauma(trauma, f.trauma)
		if f.punch > 0 then
			punch, slow, punchAt = f.punch, f.slow, os.clock()
		end
	end
	addFeel = feel

	-- where the killer's kart is: the kart the server named, a tagged "Kart" model with their
	-- OwnerId / KartName, or their character
	local function killerAt(s: SmashJuice.Side): CFrame?
		local k = killerModel or s.kart
		if k and k:IsDescendantOf(workspace) then
			if k:IsA("Model") then
				return k:GetPivot()
			elseif k:IsA("BasePart") then
				return k.CFrame
			end
		end
		for _, m in CollectionService:GetTagged("Kart") do
			if
				m:IsA("Model")
				and m:IsDescendantOf(workspace)
				and (
					(s.userId and m:GetAttribute("OwnerId") == s.userId)
					or (not s.userId and m:GetAttribute("KartName") == s.name)
				)
			then
				killerModel = m
				return m:GetPivot()
			end
		end
		local p = if s.userId then Players:GetPlayerByUserId(s.userId) else nil
		local char = p and p.Character
		if char then
			return char:GetPivot()
		end
		return nil
	end

	local function endKillcam()
		killcam = false
		killer = nil
		killerModel = nil
		lastWant = nil
		shownCount = nil
		count.Visible = false
	end

	RunService:BindToRenderStep(
		"SmashFx",
		Enum.RenderPriority.Camera.Value + 3,
		function(dt: number)
			if pending then
				local ms = (os.clock() - pending) * 1000
				table.insert(timings, ms / 1000)
				if #timings > 20 then
					table.remove(timings, 1)
				end
				if RunService:IsStudio() then
					print(string.format("[SmashFx] shown in %d ms", math.floor(ms + 0.5)))
				end
				pending = nil
			end
			fps += ((1 / math.max(dt, 1 / 240)) - fps) * math.min(dt * 2, 1)
			local cam = workspace.CurrentCamera
			if cam then
				-- the default camera (walking) builds on last frame's view, so only a Scriptable
				-- camera (the chase camera) gets the shake and the killer view; the zoom is fine on both
				local scriptable = cam.CameraType == Enum.CameraType.Scriptable
				if cam.CFrame == outCf then
					cam.CFrame = baseCf
				end
				if cam.FieldOfView == outFov then
					cam.FieldOfView = baseFov
				end
				baseCf, baseFov = cam.CFrame, cam.FieldOfView
				local cf = baseCf

				if killcam then
					local t = os.clock() - killAt
					local n = SmashJuice.countdown(t)
					if n ~= shownCount then
						shownCount = n
						if n then
							showWord(count, tostring(n), 0.9, 1.8)
						end
					end
					if t >= SmashJuice.KILLCAM_MAX then
						endKillcam()
					else
						local at = killer and killerAt(killer)
						if at then
							local pos = at.Position
							local back = -at.LookVector * Vector3.new(1, 0, 1)
							back = if back.Magnitude > 1e-3 then back.Unit else Vector3.zAxis
							local want = CFrame.lookAt(
								pos
									+ back * SmashJuice.KILLCAM_BACK
									+ Vector3.yAxis * SmashJuice.KILLCAM_UP,
								pos
							)
							lastWant = want
							cf = killFrom:Lerp(want, SmashJuice.flyAlpha(t))
						else
							-- killer gone: keep looking where it was, and count
							cf = if lastWant
								then killFrom:Lerp(lastWant, SmashJuice.flyAlpha(t))
								else killFrom
						end
					end
				end

				local fov = baseFov - SmashJuice.punchAt(punch, slow, os.clock() - punchAt)
				if trauma > 0 then
					noiseT += dt * SmashJuice.noiseHz(fps)
					local p, y, r = SmashJuice.tilt(
						trauma,
						2 * math.noise(noiseT, seed),
						2 * math.noise(noiseT, seed + 31),
						2 * math.noise(noiseT, seed + 67)
					)
					cf *= CFrame.Angles(math.rad(p), math.rad(y), math.rad(r))
					trauma = SmashJuice.decay(trauma, dt)
				end
				if scriptable and cf ~= baseCf then
					cam.CFrame = cf
				end
				if fov ~= baseFov then
					cam.FieldOfView = fov
				end
				outCf, outFov = cam.CFrame, cam.FieldOfView
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
		end
	)

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
			local word2 = myStreak:smash(at)
			by.Visible = false
			showWord(you, SmashJuice.smashLine(f.weapon), SmashJuice.WORDS_SECONDS, 1.8)
			showWord(
				name,
				SmashJuice.shortName(f.victim.name) .. "!",
				SmashJuice.WORDS_SECONDS,
				2.2
			)
			if word2 then
				showWord(streak, word2, SmashJuice.STREAK_SECONDS, 2.6)
			end
			local juice = SmashJuice.feel("mySmash", myStreak.run, reduced)
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
			local other = if f.attacker and not f.attacker.me then f.attacker else nil
			showWord(
				by,
				SmashJuice.deathLine(f.weapon, other and other.name),
				SmashJuice.SMASHED_BY_SECONDS,
				1.6
			)
			local juice = SmashJuice.feel("smashed", nil, reduced)
			feel(juice)
			edge(CHERRY, juice.flash)
			pending = at
			-- the killer camera (it's info, so reduced motion keeps it)
			killcam = true
			killAt = at
			killFrom = baseCf
			killer = other
			killerModel = nil
			lastWant = nil
			shownCount = nil
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
			if c.Name == "SmashFeed" and c:IsA("RemoteEvent") then
				conn:Disconnect()
				hook(c)
			end
		end)
	end

	-- Health (the server sets it): going down is a hit; coming back up is the respawn, which hands
	-- the camera back
	local h0 = player:GetAttribute("Health")
	local lastHealth: number? = if type(h0) == "number" then h0 else nil
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
		elseif was and h > was and killcam and os.clock() - killAt > 0.5 then
			endKillcam()
		end
	end)
end

-- a boom (rocket, mine) at `at`: shakes you by how near it was. WeaponFx can call this.
function SmashFx.boom(at: Vector3)
	local cam = workspace.CurrentCamera
	local add = addFeel
	if not cam or not add then
		return
	end
	add(SmashJuice.feel("boom", (cam.CFrame.Position - at).Magnitude, Base.reduced()))
end

-- the last few "smash arrived → words on screen" times in seconds (for the Studio timing log)
function SmashFx.timings(): { number }
	return table.clone(timings)
end

return SmashFx
