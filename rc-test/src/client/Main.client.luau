--!strict
-- RC car feel test, player side: drives the car, runs the camera, times laps.
-- Starts walking in the lobby; the server says "drive" (E on a plot's pad: drive that lobby plot,
-- right there) and "walk" (E again). `current` is the lobby plot being driven.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local RaceStart = require(ReplicatedStorage.Shared.RaceStart)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local SmokeColors = require(ReplicatedStorage.Shared.SmokeColors)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local setMode: (id: string) -> () = (Tuning :: any).setMode
local setScale: (s: number) -> () = (Tuning :: any).setScale

local CarSkin = require(script.Parent.CarSkin)
local ChaseCamera = require(script.Parent.ChaseCamera)
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
local RoadArrow = require(script.Parent.RoadArrow)
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
local roadArrow = RoadArrow.new(ignoreList()) -- where to go next in a race (looks only)
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
-- a plot whose owner built their own track: refresh its copy and its lap timer
require(ReplicatedStorage.Shared.PlotTracks).watch(function(i: number)
	local t: TrackData.Track = LobbyLayout.track(i)
	tracks[i] = t
	timers[i] = LapTimer.new(t.gates, t.mode)
end)
local labels: { string } = {}
for i, id in TrackData.order do
	labels[i] = TrackData.get(id).label
end

local current = 1

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
-- race: 3-2-1 lights on the start arch after landing on the start, then the clock starts (GO)
local countdown: RaceStart.State? = nil
local lamps: { BasePart } = {}
local jumped = false -- went over the line before GO: no timed lap until the car leaves the line
-- server race: this car's grid spot, plot-local (nil = the plot's own start), and whether it
-- got its GO
local grid: TrackData.Spawn? = nil
local gridGone = false
local raceGo: number? = nil -- server race: when this car got its GO (race clock)
local raceDone: number? = nil -- server race: this car's finish time (its laps are all done)
local wrongFor = 0 -- server race: seconds this car has been driving the wrong way

local hud: Hud.Hud
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
	-- (a reset in a server race keeps its laps: the server keeps counting them too)
	if not gridGone then
		LapTimer.reset(timers[index])
	end
	checkpoint = 0
	StartLights.show(lamps, 0)
	countdown, jumped = nil, false
	lamps = {}
	-- (a reset in a server race after its GO goes back to the grid without the lights again)
	if (t.id == "race" or grid ~= nil) and not gridGone then
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
beep.Volume = 0.5
beep.Parent = script
-- start lights: a low beep for each red lamp, a high one for green
local startBeep = Instance.new("Sound")
startBeep.Name = "StartBeep"
startBeep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
startBeep.Volume = 0.6
startBeep.Parent = script
local stuckTime = 0
local stuckFrom = Vector3.zero
local creep = 0 -- average ground speed lately (for the stuck check)
-- Plots with checkpoint flags: a reset (R, RESET, fell off, out) brings the car back to the last
-- flag it drove through instead of the start. R twice quickly = start.
local lastReset = -10
local function reset(why: string?)
	if walking then
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
local controls = Controls.new(gui, reset, function()
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
	-- where nobody can win stars yet)
	local all = RunService:IsStudio()
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
local lobby = Lobby.new(remote, function(): boolean
	return true
end)
local function setWalking(on: boolean)
	LobbySky.set(on)
	walking = on
	gui.Enabled = not on
	if on then
		roadArrow.hide()
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
	end
end

remote.OnClientEvent:Connect(function(kind: unknown, index: unknown, gridSpot: unknown)
	if kind == "walk" then
		grid, gridGone, raceGo, raceDone = nil, false, nil, nil
		setWalking(true)
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
		-- ("drive", slot, spot): the server race puts this car on its grid spot (plot-local)
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
		gridGone, raceGo, raceDone = false, nil, nil
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
	if t.mode == "free" then
		return ""
	end
	local now = os.clock()
	local lines = {}
	local go = raceGo
	if grid and go then
		-- server race: laps out of the race's laps, and the race clock (stops at the finish)
		local done = raceDone
		if done then
			table.insert(lines, `FINISHED   {CarMath.formatTime(done)}`)
		else
			local lap = math.min(s.laps + 1, ServerRace.LAPS)
			table.insert(lines, `LAP {lap}/{ServerRace.LAPS}   {CarMath.formatTime(now - go)}`)
		end
		-- the live place the server works out
		local place, cars = player:GetAttribute("RacePlace"), player:GetAttribute("RaceCars")
		if type(place) == "number" and type(cars) == "number" and cars > 1 then
			table.insert(lines, `{ServerRace.ordinal(place)} OF {cars}`)
		end
	elseif t.mode == "loop" then
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

RunService.PreSimulation:Connect(function(dt: number)
	if walking or body.Parent == nil then
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
			startBeep:Play()
			hud.flash(RaceStart.label(step))
		end
		if step == RaceStart.GO then
			countdown = nil
			gridGone = grid ~= nil
			raceGo = if grid then os.clock() else nil
			LapTimer.go(timer, os.clock())
		elseif LapTimer.inside(timer.gates[1], lx, ly, lz) then
			-- over the line before green: no clock this time (drive round, or R twice to start over)
			countdown, jumped = nil, true
			StartLights.show(lamps, 0)
			hud.flash("TOO EARLY!")
		end
	elseif jumped then
		jumped = LapTimer.inside(timer.gates[1], lx, ly, lz)
	elseif raceDone == nil then
		event = LapTimer.update(timer, os.clock(), lx, ly, lz)
	end
	-- server race: the last lap is the finish (the server keeps the real order)
	local go = raceGo
	if event == "lap" and grid and go and timer.laps >= ServerRace.LAPS then
		event = nil
		raceDone = os.clock() - go
		hud.flash(`FINISH!  {CarMath.formatTime(raceDone :: number)}`)
	end
	roadArrow.update(t, timer, rc, lx, lz)
	-- server race: driving away from the next gate for a while = a big WRONG WAY!
	if grid and go and raceDone == nil and timer.running and #timer.gates > 0 then
		local g = timer.gates[((timer.next - 1) % #timer.gates) + 1]
		local wx, _, wz = TrackData.toWorld(t, rc, g.x, ly, g.z)
		local v = body.AssemblyLinearVelocity
		local back = ServerRace.wrongWay(v.X, v.Z, wx - p.X, wz - p.Z, 12 * Tuning.scale)
		wrongFor = if back then wrongFor + dt else 0
		if wrongFor >= 1.2 then
			wrongFor = -1.3 -- show it again in a bit if they keep going
			hud.flash("WRONG WAY!")
		end
	else
		wrongFor = 0
	end
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
		reset("STUCK - BACK TO START")
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
	if p.Y < -8 * Tuning.scale / TrackData.RC_SCALE then
		reset()
	elseif not TrackData.inPlot(lx, lz) then
		reset("OUT - BACK TO START")
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
local airTime = 0 -- seconds in the air up to last frame

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
		car.render(dt) -- keep the parked car's wheels drawn
		skin.update(car, SKINS[tracks[current].id])
		effects.quiet()
		return
	end
	if body.Parent == nil then
		return
	end
	car.render(dt)
	skin.update(car, SKINS[tracks[current].id])
	effects.update(dt)
	-- boost pads and jumps: a word on screen so you know what happened
	local tel = car.telemetry
	if tel.boost > 0 and not boosting then
		-- camera.kick(14) widens the view, but the race camera is locked: off until carter says yes
		hud.flash("BOOST!")
	end
	boosting = tel.boost > 0
	if tel.landed > 0 and airTime > 0.8 then
		hud.flash("BIG AIR!")
	end
	airTime = tel.air
	camera.update(dt)
	controls.setRock(tracks[current].id == "rock")
	-- driver view looks out of the person's eyes: hide them on this screen so the head and hat
	-- don't block the view
	local char = player.Character
	if char then
		local hide = if view == "driver" and not showCam then 1 else 0
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.LocalTransparencyModifier ~= hide then
				d.LocalTransparencyModifier = hide
			end
		end
	end
	-- speed shown in big-size numbers so both sizes read the same
	-- flat speed, so a car settling on its springs reads 0
	local v = body.AssemblyLinearVelocity
	hud.setSpeed(Vector3.new(v.X, 0, v.Z).Magnitude / Tuning.scale)
	hud.setTimer(timerText())
end)
