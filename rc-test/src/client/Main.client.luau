--!strict
-- RC car feel test, player side: drives the car, runs the camera, times laps.
-- Starts walking in the lobby; the server says "drive" (E on a plot's pad: drive that lobby plot,
-- right there; or MatchRunner: a spawn in the Smash arena) and "walk" (E again). `current` is the
-- slot being driven.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundLevels = require(ReplicatedStorage.Shared.SoundLevels)
local CarMath = require(ReplicatedStorage.Shared.CarMath)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local RaceStart = require(ReplicatedStorage.Shared.RaceStart)
local Features = require(ReplicatedStorage.Shared.Features)
local WarmupYard = require(ReplicatedStorage.Shared.WarmupYard)
local SmokeColors = require(ReplicatedStorage.Shared.SmokeColors)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Tuning = require(ReplicatedStorage.Shared.Tuning)
local RaceStats = require(ReplicatedStorage.Shared.RaceStats)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local RaceLooks = require(ReplicatedStorage.Shared.RaceLooks)

local setMode: (id: string) -> () = (Tuning :: any).setMode
local setScale: (s: number) -> () = (Tuning :: any).setScale
local setStats: (d: RaceStats.Drive?) -> () = (Tuning :: any).setStats

local BigCount = require(script.Parent.BigCount)
local GasHintUi = require(script.Parent.GasHintUi)
local GasHint = require(ReplicatedStorage.Shared.GasHint)
local CarSkin = require(script.Parent.CarSkin)
local ChaseCamera = require(script.Parent.ChaseCamera)
local Match = require(ReplicatedStorage.Shared.Match)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Lobby = require(script.Parent.Lobby)
local LakeLife = require(script.Parent.LakeLife)
local LobbyLife = require(script.Parent.LobbyLife)
local LobbyWelcome = require(script.Parent.LobbyWelcome)
local LobbySky = require(script.Parent.LobbySky)
local OtherCars = require(script.Parent.OtherCars)
local RCCar = require(script.Parent.RCCar)
local RaceFx = require(script.Parent.RaceFx)
local Sfx = require(script.Parent.Sfx)
local StartLights = require(script.Parent.StartLights)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RCControl") :: RemoteEvent
local carName = "Car_" .. player.UserId

-- The person's own walking controls: on in the lobby, off while driving (they would fight the
-- car keys and show a second phone stick).
local walking = true
local walkControls: any = nil
task.spawn(function()
	local ok, playerModule = pcall(function(): any
		-- not every place has one; don't wait forever
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return if module then require(module :: ModuleScript) else nil
	end)
	if ok and playerModule then
		walkControls = playerModule:GetControls()
		if walking then
			walkControls:Enable()
		else
			walkControls:Disable()
		end
	end
end)

local function waitForCar(): (Model, BasePart)
	local model = workspace:WaitForChild(carName) :: Model
	while model.PrimaryPart == nil do
		task.wait()
	end
	return model, model.PrimaryPart :: BasePart
end

local model, body = waitForCar()
-- the server parks an RC-size car on the street and puts the person on it; wait for them so
-- the wheels and the camera ignore the person
setScale(TrackData.RC_SCALE)
do
	local t0 = os.clock()
	while player.Character == nil and os.clock() - t0 < 5 do
		task.wait()
	end
end
local function ignoreList(): { Instance }
	local list: { Instance } = { model }
	if player.Character then
		table.insert(list, player.Character)
	end
	return list
end
-- Driver view watches from the person's eyes at the stand spot (set up below).
local getEye: () -> Vector3
local function eye(): Vector3
	return getEye()
end
-- each track has its own starting view; V tries the others
local VIEWS: { ChaseCamera.View } = { "chase", "driver", "top", "free" }
local VIEW_NAMES =
	{ chase = "CHASE CAM", driver = "DRIVER VIEW", top = "TOP VIEW", free = "FREE CAM" }
local TRACK_VIEW: { [string]: ChaseCamera.View } = { drift = "top", race = "chase", rock = "free" }
local view: ChaseCamera.View = "chase"
local viewTrack = "" -- the track the view was picked for
local showCam = false

local car = RCCar.new(model, ignoreList())
local camera = ChaseCamera.new(body, ignoreList(), eye)
camera.setView(view)
local effects = Effects.new(car.telemetry)
local bigCount = BigCount.new() -- the giant 3, 2, 1, GO! in the middle
local skin = CarSkin.new() -- real car models over the grey car (look only)
local SKINS: { [string]: string } = { rock = "RockCrawler", drift = "DriftCoupe" } -- track id -> CarSkins model
local rc = true -- always RC size: the lobby plots are the tracks

-- one track per lobby plot (its kind's data, placed where that plot sits)
local tracks: { TrackData.Track } = {}
local timers: { LapTimer.State } = {}
for i in LobbyLayout.slots() do
	local t: TrackData.Track = LobbyLayout.track(i)
	tracks[i] = t
	timers[i] = LapTimer.new(t.gates, t.mode)
end
-- the big race maps come after the plots (LobbyLayout.mapAt): the server race drives them
for k in RaceMaps.list() do
	local i = LobbyLayout.mapIndex(k)
	local t: TrackData.Track = LobbyLayout.track(i)
	tracks[i] = t
	timers[i] = LapTimer.new(t.gates, t.mode)
end
-- and the Smash arena after them (MatchRunner drives it)
local arenaAt = LobbyLayout.arenaIndex()
if arenaAt then
	local t: TrackData.Track = LobbyLayout.track(arenaAt)
	tracks[arenaAt] = t
	timers[arenaAt] = LapTimer.new(t.gates, t.mode)
end
-- and the warm-up yard, where kids waiting for the next round drive (WarmupYardServer)
if WarmupYard.on() then
	local yardAt = LobbyLayout.yardIndex()
	local t: TrackData.Track = LobbyLayout.track(yardAt)
	tracks[yardAt] = t
	timers[yardAt] = LapTimer.new(t.gates, t.mode)
end
local labels: { string } = {}
for i, id in TrackData.order do
	labels[i] = TrackData.get(id).label
end

local current = 1

-- the skin to draw: the track's Meshy model, else (Car VS Car) the toy car of the car you race
-- with, the one your plot shows (playtest u01: big races drew the grey box)
local function skinName(): string?
	local own = SKINS[tracks[current].id]
	if own or not Features.CVC then
		return own
	end
	local id = player:GetAttribute("RacerCar")
	if type(id) ~= "string" then
		return nil
	end
	-- carter's own model for this car, else its kart model, else the toy (see CarSkin.lookFor)
	return CarSkin.lookFor(id)
end

getEye = function(): Vector3
	local t = tracks[current]
	local spot = TrackData.standSpot(t)
	-- at the front rail of the deck (toward the track), so the deck floor doesn't fill the view
	local x, _, z = TrackData.toWorld(t, rc, spot.x, 0, spot.z - 13)
	-- eye height of a person standing on the raised stand (4.5 above it at real RC size)
	return Vector3.new(x, (TrackData.STAND_H + 4.5 / TrackData.RC_SCALE) * Tuning.scale, z)
end
local driftChain, driftTotal, driftHold = 0, 0, 0
local checkpoint = 0 -- last checkpoint flag driven through on this plot (0 = none)
local driftHeld = 0 -- seconds this slide has been held (longer = bigger multiplier)
local touched: { [number]: boolean } = {} -- drift touch zones already scored in this chain
-- a plot race: 3-2-1 lights on the start arch after landing on the start, then the clock starts (GO)
local countdown: RaceStart.State? = nil
local lamps: { BasePart } = {}
local jumped = false -- went over the line before GO: no timed lap until the car leaves the line
local waitMove = false -- free drive after GO: the lap clock starts when the car first moves
-- the Smash arena: this car's spawn spot, arena-local (nil = a plot's own start), and when it got
-- there (the HOLD GAS! hint's clock)
local grid: TrackData.Spawn? = nil
local raceGo: number? = nil
local movedSinceGo = false -- gas pressed or rolling since the spawn (the HOLD GAS! hint goes)

-- In the arena (the screens hide what doesn't belong in a round: they read Racing)
local function setRacing(on: boolean)
	player:SetAttribute("Racing", if on then true else nil)
end

local hud: Hud.Hud
local controls: Controls.Controls
local function goTo(index: number)
	if walking then
		return
	end
	current = index
	local t = tracks[index]
	setScale(if rc then TrackData.RC_SCALE else 1)
	setMode(t.id)
	-- a new track: its own view, and the old track's skid marks go
	if t.id ~= viewTrack or t.id == "rock" then
		viewTrack = t.id
		view = TRACK_VIEW[t.id] or "chase"
		showCam = false
		camera.setView(view)
		effects.clear()
	end
	LapTimer.reset(timers[index])
	checkpoint = 0
	StartLights.show(lamps, 0)
	countdown, jumped, waitMove = nil, false, false
	lamps = {}
	if t.id == "race" and grid == nil then
		countdown = RaceStart.new()
		lamps = StartLights.find(index)
		StartLights.show(lamps, 0)
	end
	driftChain, driftTotal, driftHold, driftHeld = 0, 0, 0, 0
	touched = {}
	local s = grid or t.spawn
	local x, y, z = TrackData.toWorld(t, rc, s.x, s.y, s.z)
	local dx, dz = TrackData.dirToWorld(t, rc, s.dx, s.dz)
	local pos = Vector3.new(x, y, z)
	remote:FireServer("place", rc, index)
	car.teleport(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
	-- top view: the plot's far end up the screen, whichever way the plot is turned
	local ux, uz = TrackData.dirToWorld(t, rc, 0, -1)
	camera.setUp(Vector3.new(ux, 0, uz))
	camera.snap()
	hud.setActiveTrack(TrackData.index(t.id))
	hud.setDrift(0, 0, t.id == "drift")
end

-- Back to the plot's start with a short beep (fell off, stuck, or the R key).
local beep = Instance.new("Sound")
beep.Name = "ResetBeep"
beep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
beep.Volume = SoundLevels.RESET_BEEP
beep.Parent = script
-- start lights: a low beep for each red lamp, a high one for green
local startBeep = Instance.new("Sound")
startBeep.Name = "StartBeep"
startBeep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
startBeep.Volume = SoundLevels.START_BEEP
startBeep.Parent = script
local stuckTime = 0
local stuckFrom = Vector3.zero
local creep = 0 -- average ground speed lately (for the stuck check)
local FALL = -8 -- big-size studs: below this the car fell off the world
local raceFx = RaceFx.new() -- carter's picks 14 + 15: speed lines on BOOST, sparks on hits
-- Plots with checkpoint flags: a reset (R, RESET, fell off, out) brings the car back to the last
-- flag it drove through instead of the start. R twice quickly = start.
local lastReset = -10
local function reset(why: string?, from: string?)
	if walking then
		return
	end
	-- (Studio: what asked for the last reset, and was it taken)
	body:SetAttribute("LastReset", `{from or "R"} {math.floor(os.clock() * 10) / 10}`)
	-- smashed in the arena: the server holds the car and brings it back itself
	if grid and player:GetAttribute("Health") == 0 then
		return
	end
	stuckTime = 0
	beep:Play()
	local now = os.clock()
	local again = now - lastReset < 1.5
	lastReset = now
	local t = tracks[current]
	local cps = t.checkpoints
	if cps and checkpoint > 0 and not again then
		local s = cps[checkpoint].spawn
		local x, y, z = TrackData.toWorld(t, rc, s.x, s.y, s.z)
		local dx, dz = TrackData.dirToWorld(t, rc, s.dx, s.dz)
		local pos = Vector3.new(x, y, z)
		car.teleport(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
		camera.snap()
		hud.flash("BACK TO CHECKPOINT")
		return
	end
	goTo(current)
	if why then
		hud.flash(why)
	end
end

-- tyre smoke colour pick; the player's star count (set by the stars server) opens more colours
local smokeIndex = 1
local function starCount(): number
	local n = player:GetAttribute("Stars")
	return if type(n) == "number" then n else 0
end

local gui = Hud.createGui()
hud = Hud.new(gui, labels)
local gasHint = GasHintUi.new(gui) -- HOLD GAS! when the car sits on the line after GO
controls = Controls.new(gui, reset, function()
	if tracks[current].id == "rock" then
		return -- rocks is free cam only
	end
	showCam = camera.toggleOrbit()
	if not showCam then
		camera.setView(view) -- back to the view picked before
	end
	hud.flash(if showCam then "SHOW CAM" else VIEW_NAMES[view])
end, function()
	if tracks[current].id == "rock" then
		hud.flash(VIEW_NAMES.free) -- rocks is free cam only
		return
	end
	local i = table.find(VIEWS, view) or 0
	view = VIEWS[i % #VIEWS + 1]
	showCam = false
	camera.setView(view)
	hud.flash(VIEW_NAMES[view])
end, function()
	-- tyre smoke colour: the next one this player's stars have opened (all of them in Studio,
	-- where nobody can win stars yet, and all of them while stars are off: Features.STARS)
	local all = RunService:IsStudio() or not Features.STARS
	local stars = starCount()
	local nextIndex = SmokeColors.nextOpen(smokeIndex, stars, all)
	if nextIndex == smokeIndex then
		local locked = SmokeColors.nextLocked(stars)
		hud.flash(if locked then `{locked.name} SMOKE: ⭐ {locked.stars}` else "SMOKE")
		return
	end
	smokeIndex = nextIndex
	local c = SmokeColors.LIST[smokeIndex]
	effects.setSmokeColor(Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3]))
	hud.flash(`{c.name} SMOKE`)
end, function(on: boolean)
	hud.flash(if on then "AUTO GAS ON" else "AUTO GAS OFF")
end)

-- Walking <-> driving. Only the server switches (E on a stand, or WALK), this side follows.
-- The Smash arena: no WALK in a round (the end screen's LEAVE is the way out; one tap on a WALK
-- over the car left the race before)
local lobby = Lobby.new(remote, function(): boolean
	return grid == nil
end)
local function showDriveHud()
	gui.Enabled = not walking
end
local function setWalking(on: boolean)
	LobbySky.set(on)
	walking = on
	showDriveHud()
	if on then
		gasHint.set(false)
	end
	lobby.setDriving(not on)
	-- Roblox's own thumbstick and jump button sit under STEER and GAS on a phone: only while walking
	GuiService.TouchControlsEnabled = on
	if walkControls then
		if on then
			walkControls:Enable()
		else
			walkControls:Disable()
		end
	end
	local cam = workspace.CurrentCamera
	local char = player.Character
	if on then
		camera.setView("chase") -- clears see-through walls
		cam.CameraType = Enum.CameraType.Custom
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		-- the camera would keep the way it looked in the race: from your pad facing the road
		-- that put it inside your own plot's gate, its legs filling the screen (Studio final pass
		-- 07). Once the server has moved you home (on your pad, facing your plot), look over your
		-- shoulder the way you face. Car VS Car only: the old plot drive puts you facing the road.
		local root0 = char and char:FindFirstChild("HumanoidRootPart")
		local from = if root0 and root0:IsA("BasePart") then root0.Position else nil
		task.spawn(function()
			if not Features.CVC then
				return
			end
			-- (the move home can reach this screen a moment after the "walk" message)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local waited = 0
			while waited < 1 and from and root and root:IsA("BasePart") do
				if (root.Position - from).Magnitude > 8 then
					break
				end
				waited += task.wait()
			end
			-- (not while the plot camera has the view: it would knock it off, Studio round 4)
			if
				walking
				and player:GetAttribute("PlotCam") ~= true
				and root
				and root:IsA("BasePart")
			then
				local look = root.CFrame.LookVector
				local at = root.Position + Vector3.new(0, 2, 0)
				cam.CFrame = CFrame.lookAt(
					at - Vector3.new(look.X, 0, look.Z).Unit * 12 + Vector3.new(0, 4, 0),
					at
				)
			end
		end)
	end
end

remote.OnClientEvent:Connect(function(kind: unknown, index: unknown, gridSpot: unknown)
	if kind == "walk" then
		grid, raceGo, movedSinceGo = nil, nil, false
		setRacing(false)
		setStats(nil)
		setWalking(true)
		-- parked on its springs while walking: base numbers (not the rock plot's tall ones), and
		-- a fresh car so no held heading or leftover boost moves it
		setMode("race")
		car.destroy()
		car = RCCar.new(model, ignoreList())
		LobbyLife.start() -- butterflies and birds (looks only, this screen)
		LobbyWelcome.start() -- first time only: street lights on, confetti
		LakeLife.start() -- sailboats drift, ducks paddle, the water glints (this screen)
	elseif kind == "drive" and type(index) == "number" and tracks[index] then
		setWalking(false)
		-- fresh hooks: the person may have respawned since the last drive
		car.destroy()
		effects.destroy()
		car = RCCar.new(model, ignoreList())
		camera = ChaseCamera.new(body, ignoreList(), eye)
		camera.setView(view)
		showCam = false
		effects = Effects.new(car.telemetry)
		-- ("drive", slot, spot): MatchRunner puts this car on an arena spawn (arena-local)
		grid = nil
		if type(gridSpot) == "table" then
			local g = gridSpot :: any
			if
				type(g.x) == "number"
				and type(g.y) == "number"
				and type(g.z) == "number"
				and type(g.dx) == "number"
				and type(g.dz) == "number"
			then
				grid = { x = g.x, y = g.y, z = g.z, dx = g.dx, dz = g.dz }
			end
		end
		-- the Smash arena: no lights, no laps; a (re)spawn drives at once
		raceGo = if grid then os.clock() else nil
		movedSinceGo = false
		stuckTime = 0
		setRacing(grid ~= nil)
		if grid then
			controls.autoOff() -- every round starts with AUTO GAS off (critic runs 1 and 2)
		end
		setStats(nil)
		goTo(index)
	end
end)
setWalking(true)
LobbyLife.start() -- butterflies and birds (looks only, this screen)
LobbyWelcome.start() -- the first moment here: street lights on, confetti
LakeLife.start() -- the lake moves from the start: sailboats drift, ducks paddle, glints

local function timerText(): string
	local t = tracks[current]
	local s = timers[current]
	if t.mode == "free" or grid then
		return "" -- (the Smash round's clock is the match HUD's)
	end
	local now = os.clock()
	local lines = {}
	if t.mode == "loop" then
		local cur = if s.running then CarMath.formatTime(now - s.startTime) else "-:--.-"
		table.insert(lines, `LAP {s.laps + 1}   {cur}`)
		if s.last then
			table.insert(lines, `LAST {CarMath.formatTime(s.last)}`)
		end
	else
		local cur = if s.running then CarMath.formatTime(now - s.startTime) else "-:--.-"
		if s.finished and s.last then
			cur = CarMath.formatTime(s.last)
		end
		table.insert(lines, `CLIMB   {cur}`)
	end
	if s.best then
		table.insert(lines, `BEST {CarMath.formatTime(s.best)}`)
	end
	return table.concat(lines, "\n")
end

-- no keys: the parked car while walking still stands on its springs (without them it sank onto
-- its belly with the wheels under the road, Studio PR 936 check)
local IDLE: RCCar.Input = { steer = 0, throttle = 0, brake = 0, drift = false }
RunService.PreSimulation:Connect(function(dt: number)
	if body.Parent == nil then
		return
	end
	if walking then
		car.step(dt, IDLE)
		return
	end
	local input = controls.read()
	car.step(dt, input)

	local t = tracks[current]
	local p = body.Position
	local lx, ly, lz = TrackData.toLocal(t, rc, p.X, p.Y, p.Z)
	local timer = timers[current]
	local event: string? = nil
	local cd = countdown
	if cd then
		local step = RaceStart.update(cd, dt)
		if step then
			StartLights.show(lamps, step)
			startBeep.PlaybackSpeed = if step >= RaceStart.GO then 1.6 else 0.8
			-- (carter's pick 13: louder in the big race; the sounds helper adds a real stinger)
			startBeep.Volume = SoundLevels.START_BEEP
			startBeep:Play()
			Sfx.count(RaceStart.GO - step) -- 3, 2, 1, then 0 = GO (the sounds helper's)
			bigCount.show(step, RaceStart.label(step), step >= RaceStart.GO)
			-- (the new screens show the car's name tag from the first count, CvcScreens)
			player:SetAttribute("CountStep", step)
		end
		if step == RaceStart.GO then
			countdown = nil
			waitMove = true -- (on your own the clock waits for you to go)
		elseif LapTimer.inside(timer.gates[1], lx, ly, lz) then
			-- over the line before green: no clock this time (drive round, or R twice to start over)
			countdown, jumped = nil, true
			StartLights.show(lamps, 0)
			hud.flash("TOO EARLY!")
		end
	elseif jumped then
		jumped = LapTimer.inside(timer.gates[1], lx, ly, lz)
	elseif waitMove then
		local v = body.AssemblyLinearVelocity
		if input.throttle > 0 or Vector3.new(v.X, 0, v.Z).Magnitude > 2 * Tuning.scale then
			waitMove = false
			LapTimer.go(timer, os.clock())
		end
	else
		event = LapTimer.update(timer, os.clock(), lx, ly, lz)
	end
	-- the arena: still on the spawn 2 s after it = a big HOLD GAS! (a new kid didn't know what
	-- to press; look only, GasHint)
	if raceGo and not movedSinceGo then
		local v = body.AssemblyLinearVelocity
		movedSinceGo = input.throttle > 0 or Vector3.new(v.X, 0, v.Z).Magnitude > 2 * Tuning.scale
	end
	local goAt = raceGo
	gasHint.set(
		not walking and GasHint.shows(if goAt then os.clock() - goAt else nil, movedSinceGo, false)
	)
	if event == "lap" then
		hud.flash(`LAP  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "finish" then
		hud.flash(`SUMMIT!  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "start" then
		hud.flash("GO!")
	end

	-- gas or brake held but the car gets nowhere for a while (Tuning.stuckWait) = stuck (wedged,
	-- on a wall, spinning its wheels on a slope): start over. Uses the car's average ground speed
	-- over about half a second, so a car creeping or pivoting along a wall still counts as stuck, while
	-- slow rock crawling (several times faster) never does.
	local pressing = input.throttle > 0 or input.brake > 0
	local moved = Vector3.new(p.X - stuckFrom.X, 0, p.Z - stuckFrom.Z).Magnitude
	stuckFrom = p
	-- (capped, so a teleport back to the start doesn't hide being stuck for long)
	local rate = math.min(moved / math.max(dt, 1e-3), 20 * Tuning.scale)
	creep += (rate - creep) * (1 - math.exp(-2 * dt))
	if pressing and creep < 1.6 * Tuning.scale then
		stuckTime += dt
	else
		stuckTime = 0
	end
	-- rocks: being stuck is part of crawling, so it never resets by itself (R or RESET does)
	if stuckTime > Tuning.stuckWait and t.id ~= "rock" then
		-- (Smash: no race talk, audit R6-2)
		local smash = player:GetAttribute("InMatch") == true or WarmupYard.on()
		reset(if smash then "OOPS! FLIPPING YOU BACK" else "STUCK - BACK TO START", "stuck")
	end
	-- fell off the world, or got out of the plot
	local lx, _, lz = TrackData.toLocal(t, rc, p.X, p.Y, p.Z)
	local cps = t.checkpoints
	if cps then
		for k = checkpoint + 1, #cps do
			if LapTimer.inside(cps[k].gate, lx, ly, lz) then
				checkpoint = k
				hud.flash("CHECKPOINT")
			end
		end
	end
	if p.Y < FALL * Tuning.scale / TrackData.RC_SCALE then
		reset(nil, "fell")
	elseif t.map == nil and not TrackData.inPlot(lx, lz) then
		reset("OUT - BACK TO START", "out")
	end

	if t.id == "drift" then
		local tel = car.telemetry
		local gain = CarMath.driftPoints(tel.speed, tel.slip, dt)
		if gain > 0 and tel.grounded > 0 then
			driftHeld += dt
			driftChain += gain * CarMath.driftCombo(driftHeld)
			driftHold = 0.8
			-- sliding through a glowing touch zone: a bonus, once per zone per chain
			local plot = TrackData.plot(t.id)
			local zone = plot.touchZone and plot.touchZone(lx, lz)
			if zone and not touched[zone] then
				touched[zone] = true
				local bonus = plot.TOUCH_BONUS * CarMath.driftCombo(driftHeld)
				driftChain += bonus
				hud.flash(`TOUCH +{math.floor(bonus)}`)
			end
		elseif driftChain > 0 then
			driftHold -= dt
			if driftHold <= 0 or tel.speed < 8 * Tuning.scale then
				driftTotal += driftChain
				hud.popScore(driftChain)
				driftChain, driftHeld = 0, 0
				touched = {}
			end
		end
		hud.setDrift(driftChain, driftTotal, true, CarMath.driftCombo(driftHeld))
	end
end)

-- other players' cars: wheels and names (their bodies come from the server)
local otherCars = OtherCars.new(function(): string
	return carName
end)

local boosting = false -- was on a boost last frame
local speedWas = 0 -- flat speed last frame (sparks on a hard stop)
-- carter's pick 18: in the arena your own car wears a yellow YOU (the others wear their names:
-- OtherCars), so you find it in the crowd
-- your own league badge over your head (Leaderboards) never shows on your own screen: the chase
-- cam caught it behind AUTO GAS, and from the plot stand it hid your first station and its sign
-- (Studio score/20). Others still see it; your league is on the HUD chip.
task.spawn(function()
	while true do
		local head = player.Character and player.Character:FindFirstChild("Head")
		local badge = head and head:FindFirstChild("LeagueBadge")
		if badge and badge:IsA("BillboardGui") and badge.Enabled then
			badge.Enabled = false
		end
		task.wait(0.5)
	end
end)
local youTag = Instance.new("BillboardGui")
youTag.Name = "YouTag"
youTag.Size = UDim2.fromOffset(90, 30)
-- (not AlwaysOnTop: on carter's PC no AlwaysOnTop billboard drew at all, Studio score/16-18)
youTag.AlwaysOnTop = false
youTag.MaxDistance = 1200
youTag.ResetOnSpawn = false
youTag.Enabled = false
do
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 220, 40)
	l.TextStrokeTransparency = 0
	l.Text = "▼ YOU"
	l.Parent = youTag
end
youTag.Adornee = body
youTag.Parent = body -- (on the car, like CarTag: from PlayerGui it never showed in Studio)
local placeWasAt = Vector3.zero -- where the car was last frame (a reset jumps: no sparks)

local airTime = 0 -- seconds in the air up to last frame

local hiddenChar: Model? = nil -- the body last hidden or shown for the driver view
local hiddenAs = -1
local hideAgainAt = 0
local hudTextAt = 0 -- next speed / clock text
local camLostFor = 0 -- seconds the chase camera has been far from the kart (arena)
RunService:BindToRenderStep("RCCar", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	otherCars.update(dt)
	if walking then
		-- a respawn can hand the camera a new person: follow them
		local cam = workspace.CurrentCamera
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and cam.CameraSubject ~= hum then
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum
		end
		youTag.Enabled = false
		raceFx.update(dt, false) -- a race that ended mid-BOOST: fade its speed lines out
		car.render(dt) -- keep the parked car's wheels drawn
		skin.update(car, skinName())
		effects.quiet()
		return
	end
	if body.Parent == nil then
		return
	end
	car.render(dt)
	skin.update(car, skinName())
	effects.update(dt)
	-- boost pads and jumps: a word on screen so you know what happened
	local tel = car.telemetry
	-- just over the car's roof (it was 4x higher: off the top of the screen under the chase camera,
	-- Studio 10-26; then still floating well above it once it drew, Studio score/24)
	youTag.StudsOffsetWorldSpace = Vector3.new(0, 1.6 * Tuning.scale, 0)
	youTag.Enabled = grid ~= nil and Features.CVC
	raceFx.update(dt, tel.boost > 0)
	local fv = body.AssemblyLinearVelocity
	local flatNow = Vector3.new(fv.X, 0, fv.Z).Magnitude
	local warped = (body.Position - placeWasAt).Magnitude > speedWas * dt * 3 + 2
	placeWasAt = body.Position
	if not warped and RaceLooks.slammed(speedWas, flatNow, Tuning.scale) then
		local ahead = body.CFrame.LookVector
		raceFx.sparks(
			body.Position + ahead * Tuning.bodyZ / 2,
			-ahead + Vector3.yAxis * 0.6,
			Tuning.scale / TrackData.RC_SCALE
		)
		Sfx.spark()
	end
	speedWas = flatNow
	if tel.boost > 0 and not boosting then
		-- camera.kick(14) widens the view, but the race camera is locked: off until carter says yes
		hud.flash("BOOST!")
	end
	boosting = tel.boost > 0
	if tel.landed > 0 and airTime > 0.45 then
		hud.flash("BIG AIR!")
	end
	airTime = tel.air
	camera.update(dt)
	-- in the arena the chase camera always comes back to your own kart (Studio round 3: it sat
	-- ~40 studs off, on a wall, for 30-60 s while the kart drove on); only which kart it
	-- follows, never how it follows (ChaseCamera is locked)
	if grid ~= nil and view == "chase" and not showCam then
		local far = (workspace.CurrentCamera.CFrame.Position - body.Position).Magnitude
		local lost
		camLostFor, lost =
			Match.camLost(camLostFor, far, 3 * (Tuning.camDistance + Tuning.camHeight), dt)
		if lost then
			if RunService:IsStudio() then
				print(`[Main] camera lost the kart ({math.floor(far)} studs): back behind it`)
			end
			camera.snap()
		end
	else
		camLostFor = 0
	end
	controls.setRock(tracks[current].id == "rock")
	controls.setRace(grid ~= nil)
	hud.setRace(grid ~= nil)
	-- driver view looks out of the person's eyes: hide them on this screen so the head and hat
	-- don't block the view
	-- (only when the view or the body changes, or once a second for a hat that loads late: not a
	-- GetDescendants every frame on a phone)
	local char = player.Character
	local clock = os.clock()
	if char then
		local hide = if view == "driver" and not showCam then 1 else 0
		if char ~= hiddenChar or hide ~= hiddenAs or clock >= hideAgainAt then
			hiddenChar, hiddenAs, hideAgainAt = char, hide, clock + 1
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and d.LocalTransparencyModifier ~= hide then
					d.LocalTransparencyModifier = hide
				end
			end
		end
	end
	-- speed and clock text 10 times a second, not every frame (new strings each time)
	if clock >= hudTextAt then
		hudTextAt = clock + 0.1
		-- speed shown in big-size numbers so both sizes read the same
		-- flat speed, so a car settling on its springs reads 0
		local v = body.AssemblyLinearVelocity
		hud.setSpeed(Vector3.new(v.X, 0, v.Z).Magnitude / Tuning.scale)
		hud.setTimer(timerText())
	end
end)
