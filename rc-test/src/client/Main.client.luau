--!strict
-- RC car feel test, player side: drives the car, runs the camera, times laps.
-- Starts walking in the lobby; the server says "drive" (E on a plot's pad: drive that lobby plot,
-- right there) and "walk" (E again). `current` is the lobby plot being driven.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundLevels = require(ReplicatedStorage.Shared.SoundLevels)
local CarMath = require(ReplicatedStorage.Shared.CarMath)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local RaceStart = require(ReplicatedStorage.Shared.RaceStart)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local Features = require(ReplicatedStorage.Shared.Features)
local SmokeColors = require(ReplicatedStorage.Shared.SmokeColors)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Tuning = require(ReplicatedStorage.Shared.Tuning)
local RaceStats = require(ReplicatedStorage.Shared.RaceStats)
local RaceStand = require(ReplicatedStorage.Shared.RaceStand)
local RoadSteer = require(ReplicatedStorage.Shared.RoadSteer)
local BackOnTrack = require(ReplicatedStorage.Shared.BackOnTrack)
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
local RoadArrow = require(script.Parent.RoadArrow)
local StartLights = require(script.Parent.StartLights)

local player = Players.LocalPlayer
-- laps in this server race (the server sets it: a first race is shorter)
local function raceLaps(): number
	local n = player:GetAttribute("RaceLaps")
	return if type(n) == "number" and n >= 1 then n else ServerRace.LAPS
end
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
-- a put-back car's body sits at least this high over what's under it (big-car units)
local PUT_BACK_CLEAR = 2.5
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
-- Car VS Car big race: the fixed camera from your spot on the driver stand is off: carter 10-26
-- "make the camera follow the car all times", so the race uses the normal chase views. (Set this
-- true to bring the stand camera back; the view button then swaps it with the normal views.)
local STAND_CAM = false
local standCam = STAND_CAM
local standLook: Vector3? = nil
local standFov = 40

local car = RCCar.new(model, ignoreList())
local camera = ChaseCamera.new(body, ignoreList(), eye)
camera.setView(view)
local effects = Effects.new(car.telemetry)
local roadArrow = RoadArrow.new(ignoreList()) -- where to go next in a race (looks only)
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
-- race: 3-2-1 lights on the start arch after landing on the start, then the clock starts (GO)
local countdown: RaceStart.State? = nil
local lamps: { BasePart } = {}
local jumped = false -- went over the line before GO: no timed lap until the car leaves the line
local early = false -- server race: over the line before GO (the race still starts at GO for it)
local waitMove = false -- free drive after GO: the lap clock starts when the car first moves
-- server race: this car's grid spot, plot-local (nil = the plot's own start), and whether it
-- got its GO
local grid: TrackData.Spawn? = nil
local gridGone = false
local raceGo: number? = nil -- server race: when this car got its GO (race clock)
local raceDone: number? = nil -- server race: this car's finish time (its laps are all done)
local raceOver = false -- server race: the results are in (finished or not: no more laps, no clock)
local movedSinceGo = false -- server race: gas pressed or rolling since GO (the HOLD GAS! hint goes)
local wrongFor = 0 -- server race: seconds this car has been driving the wrong way

-- Car VS Car BOOST button: the UI's thumb button fires this (local only, nothing to cheat: the
-- push is the boost pad's push, for the car's trained Boost seconds). One BOOST at GO and one more
-- each new lap, saved up to BOOST_MAX. The button reads these LocalPlayer attributes:
-- Racing (GO to finish), BoostLeft, BoostSecs, BoostOn (pushing right now).
local BOOST_MAX = 3
local boostTap = Instance.new("BindableEvent")
boostTap.Name = "BoostTap"
boostTap.Parent = ReplicatedStorage
local boostLeft, boostUntil = 0, 0
local function setRacing(on: boolean)
	player:SetAttribute("Racing", if on then true else nil)
	if not on then
		boostLeft = 0
		player:SetAttribute("BoostLeft", nil)
		player:SetAttribute("BoostOn", nil)
	end
end
local function addBoost()
	boostLeft = math.min(boostLeft + 1, BOOST_MAX)
	player:SetAttribute("BoostLeft", boostLeft)
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
	-- (a reset in a server race keeps its laps: the server keeps counting them too)
	if not gridGone then
		LapTimer.reset(timers[index])
	end
	checkpoint = 0
	StartLights.show(lamps, 0)
	countdown, jumped, waitMove, early = nil, false, false, false
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
local lost = BackOnTrack.newLost() -- big race: still, off the road or WRONG WAY for a while
local movedSincePut = true -- big race: gas or rolling since the last put-back (the still clock waits)
local lastRoad: { x: number, z: number }? = nil -- big race: where the car was last on the road (map-local)
-- a first race: put back near the same spot again soon = a little further on each time
local PUT_SAME, PUT_SOON, PUT_PUSH = 40, 20, 3 -- big units, seconds, road samples
local putRoad: { x: number, z: number }? = nil
local putAt, putAgain = -100, 0
local steerLoops: { [string]: { { x: number, z: number } } } = {} -- each map's centre line
local steerAt: number? = nil -- the centre line sample the car was last nearest
-- the countdown's small screen shake (MASTER race moment: 3 sound cues + a shake): how strong and
-- how long it has left; added on top of the camera, which stays as it is
local raceFx = RaceFx.new() -- carter's picks 14 + 15: speed lines on BOOST, sparks on hits
local SHAKE_TIME = 0.25
local shakeBy, shakeLeft = 0, 0
local shakeRng = Random.new()
local lostRoads: { [string]: { BackOnTrack.Road } } = {} -- each map's roads (BackOnTrack.roads)
-- Plots with checkpoint flags: a reset (R, RESET, fell off, out) brings the car back to the last
-- flag it drove through instead of the start. R twice quickly = start.
local lastReset = -10
local function reset(why: string?, from: string?)
	if walking then
		return
	end
	-- (Studio: what asked for the last reset, and was it taken)
	body:SetAttribute("LastReset", `{from or "R"} {math.floor(os.clock() * 10) / 10}`)
	-- a big race before its GO: the car waits on its grid spot; nothing puts it back or flashes
	-- (Studio focus-786: BACK ON TRACK on the grid 2.7 s before GO)
	if grid and (countdown ~= nil or raceGo == nil) then
		body:SetAttribute("LastReset", `{from or "R"} before GO, skipped`)
		return
	end
	stuckTime = 0
	wrongFor = 0
	beep:Play()
	local now = os.clock()
	local again = now - lastReset < 1.5
	lastReset = now
	local t = tracks[current]
	-- Car VS Car big race: off the track, stuck or R = back on the road at the last gate passed,
	-- facing the way to go (the small loss: the bit since that gate, from a standstill). It used
	-- to be the grid, a whole lap's loss.
	local timer = timers[current]
	if Features.CVC and grid and gridGone and raceGo and raceDone == nil and #timer.gates > 0 then
		-- (a TOO EARLY car's lap clock waits for its next time over the line: next = 1, the gate
		-- before the line. It used to drop to the grid, and the lost clocks never ran for it)
		-- (back near where it left the road, not the last gate: Studio after-810 put a kid stuck on
		-- the first bend back on the start line every time)
		local m = if t.map then RaceMaps.get(t.map) else nil
		local road = lastRoad
		local push = 0
		if road and player:GetAttribute("EasyRace") == true then
			local was = putRoad
			local same = was ~= nil
				and now - putAt < PUT_SOON
				and (road.x - was.x) ^ 2 + (road.z - was.z) ^ 2 < PUT_SAME ^ 2
			putAgain = if same then putAgain + 1 else 0
			if not same then
				putRoad = { x = road.x, z = road.z }
			end
			putAt = now
			push = putAgain * PUT_PUSH
		end
		local g = (
			if m and road
				then BackOnTrack.roadSpot(
					t,
					m.loop(),
					timer.gates,
					timer.next,
					road.x,
					road.z,
					push
				)
				else nil
		) or BackOnTrack.spot(t, timer.gates, timer.next) :: BackOnTrack.Spot
		local x, y, z = TrackData.toWorld(t, rc, g.x, g.y, g.z)
		local dx, dz = TrackData.dirToWorld(t, rc, g.dx, g.dz)
		-- on top of whatever is there: a spot on a jump ramp put the car inside it, stuck for good
		-- (Studio after-818: put back into the same ramp from 74 s to the time limit)
		local probe = RaycastParams.new()
		probe.FilterType = Enum.RaycastFilterType.Exclude
		probe.FilterDescendantsInstances = ignoreList()
		probe.RespectCanCollide = true
		local up = 6 * Tuning.scale -- (low: a tunnel roof above must not catch it)
		local hit = workspace:Raycast(Vector3.new(x, y + up, z), Vector3.new(0, -up * 2, 0), probe)
		local clear = PUT_BACK_CLEAR * Tuning.scale
		if hit and hit.Position.Y + clear > y then
			y = hit.Position.Y + clear
		end
		local pos = Vector3.new(x, y, z)
		car.teleport(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
		camera.snap()
		hud.flash("BACK ON TRACK")
		-- AUTO GAS off: left on, it drove the car into the same post 8 times in 66 s (critic run 2);
		-- and the still clock waits for gas, so a car left sitting there isn't put back again.
		-- A first race keeps it on: a kid who never steers still gets round (Studio after-810).
		if player:GetAttribute("EasyRace") ~= true then
			controls.autoOff()
		end
		movedSincePut = false
		return
	end
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
	if STAND_CAM and Features.CVC and grid and tracks[current].map then
		standCam = not standCam
		standLook = nil
		camera.setView(view)
		hud.flash(if standCam then "STAND CAM" else VIEW_NAMES[view])
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
-- Car VS Car: no WALK in the middle of a big race (it sat right over the car, and one tap left the
-- race); the race ends by itself and walks everyone back
local lobby = Lobby.new(remote, function(): boolean
	return not (Features.CVC and grid ~= nil and not raceOver)
end)
-- after a race the result card (ServerRace "Result") has the screen: the driving buttons and
-- chips (AUTO GAS, the lap clock, BRAKE, GAS...) step away while it shows (AUTO GAS sat on its
-- ribbon, Studio morning-podium; CvcLayout.AFTER_RACE_HIDES)
local resultCard: GuiObject? = nil
local function showDriveHud()
	gui.Enabled = not walking and not (resultCard ~= nil and resultCard.Visible)
end
task.spawn(function()
	local race = player:WaitForChild("PlayerGui"):WaitForChild("ServerRace", 60)
	local card = race and race:WaitForChild("Result", 60)
	if card and card:IsA("GuiObject") then
		resultCard = card
		card:GetPropertyChangedSignal("Visible"):Connect(showDriveHud)
	end
end)
local function setWalking(on: boolean)
	LobbySky.set(on)
	walking = on
	showDriveHud()
	if on then
		roadArrow.hide()
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

-- server race: the results are in for this car's race (sent to every racer, finished or not)
task.spawn(function() -- (never holds up the drive/walk hookup below)
	local raceEvent = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent
	raceEvent.OnClientEvent:Connect(function(what: unknown)
		if what == "result" and grid then
			raceOver = true
			setRacing(false)
		end
	end)
end)

remote.OnClientEvent:Connect(function(kind: unknown, index: unknown, gridSpot: unknown)
	if kind == "walk" then
		grid, gridGone, raceGo, raceDone, raceOver, movedSinceGo =
			nil, false, nil, nil, false, false
		setRacing(false)
		setStats(nil)
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
		gridGone, raceGo, raceDone, raceOver, movedSinceGo = false, nil, nil, false, false
		setRacing(false)
		-- a new race: no clock carries over from the last one
		lost.still, lost.off, lost.wrong, lost.air = 0, 0, 0, 0
		stuckTime, wrongFor, movedSincePut = 0, 0, true
		lastRoad = nil
		-- the Smash arena: no lights, no laps; a (re)spawn drives at once (MatchRunner)
		if grid and tracks[index].mode == "arena" then
			gridGone, raceGo = true, os.clock()
		end
		if grid then
			controls.autoOff() -- every race starts with AUTO GAS off (critic runs 1 and 2)
		end
		-- Car VS Car: in the big race the car drives with its trained bars (the server sets them)
		local drive = if Features.CVC and grid
			then RaceStats.fromAttributes(function(n: string): any
				return player:GetAttribute(n)
			end)
			else nil
		setStats(drive)
		player:SetAttribute("BoostSecs", if drive then drive.boostSecs else nil)
		goTo(index)
	end
end)
boostTap.Event:Connect(function()
	local secs = player:GetAttribute("BoostSecs")
	if walking or not (raceGo and raceDone == nil) or boostLeft <= 0 or type(secs) ~= "number" then
		return
	end
	if os.clock() < boostUntil then
		return -- (still pushing: a double tap doesn't waste one)
	end
	boostLeft -= 1
	player:SetAttribute("BoostLeft", boostLeft)
	car.boost(secs)
	boostUntil = os.clock() + secs
	player:SetAttribute("BoostOn", true)
	task.delay(secs, function()
		if os.clock() >= boostUntil - 0.01 then
			player:SetAttribute("BoostOn", nil)
		end
	end)
end)
setWalking(true)
LobbyLife.start() -- butterflies and birds (looks only, this screen)
LobbyWelcome.start() -- the first moment here: street lights on, confetti
LakeLife.start() -- the lake moves from the start: sailboats drift, ducks paddle, glints

-- server race: passing someone pops up your new place ("UP TO 2ND!"); a short wait between pops so
-- two cars side by side swapping places don't flash it over and over
local placeWas, placeAt = 0, 0
player:GetAttributeChangedSignal("RacePlace"):Connect(function()
	local place = player:GetAttribute("RacePlace")
	if type(place) ~= "number" then
		placeWas = 0
		return
	end
	local go = raceGo
	local up = placeWas > 0 and place < placeWas
	placeWas = place
	if
		up
		and grid
		and go
		and raceDone == nil
		and os.clock() - go > 3
		and os.clock() - placeAt > 3
	then
		placeAt = os.clock()
		hud.flash(`UP TO {ServerRace.ordinal(place)}!`)
	end
end)

local function timerText(): string
	local t = tracks[current]
	local s = timers[current]
	if t.mode == "free" and not (grid and raceGo) then
		return ""
	end
	if grid and raceOver then
		return "" -- the result card is up: no LAP 1/2 and a clock still running for a car that didn't finish
	end
	local now = os.clock()
	local lines = {}
	local go = raceGo
	if grid and go then
		-- server race: laps out of the race's laps, and the race clock (stops at the finish); a
		-- drift round has no laps (its clock is the red pill, its score the drift box)
		local done = raceDone
		if t.id == "drift" then
			table.insert(lines, "DRIFT!")
		elseif done then
			table.insert(lines, `FINISHED {CarMath.formatTime(done)}`)
		else
			local lap = math.min(s.laps + 1, raceLaps())
			table.insert(lines, `LAP {lap}/{raceLaps()}   {CarMath.formatTime(now - go)}`)
		end
		-- the live place the server works out
		local place, cars = player:GetAttribute("RacePlace"), player:GetAttribute("RaceCars")
		if type(place) == "number" and type(cars) == "number" and cars > 1 then
			-- (gold, so the place stands out: phone 10-28 review fix 2)
			table.insert(
				lines,
				`<font color="#FFC72C">{ServerRace.ordinal(place)} OF {cars}</font>`
			)
		end
	elseif grid then
		-- server race, on the grid before GO (it showed a solo "LAP 1  -:--.-" here)
		table.insert(
			lines,
			if t.id == "drift" then "DRIFT!" else `LAP 1/{raceLaps()}   {CarMath.formatTime(0)}`
		)
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
	-- (a server race: no BEST under FINISHED, it was the same time twice, phone 10-28)
	if s.best and not (grid and go) then
		table.insert(lines, `BEST {CarMath.formatTime(s.best)}`)
	end
	return table.concat(lines, "\n")
end

RunService.PreSimulation:Connect(function(dt: number)
	if walking or body.Parent == nil then
		return
	end
	local input = controls.read()
	if grid and countdown then
		-- server race, lights still red: the car waits on the line for GO (carter 10-26: AUTO GAS
		-- or a held GAS rolled it over the line = TOO EARLY and an extra lap). Steering still works.
		input = { steer = input.steer, throttle = 0, brake = 0, drift = false }
	elseif grid and (raceDone ~= nil or raceOver) then
		-- server race, over the line: the car brakes to a stop at the finish and stays there (it
		-- drove on, AUTO GAS too, and stuck on a sign until the results, phone 10-28 t096-t100).
		-- Brake only while rolling forward: held at a stop it would back up.
		local rolling = car.telemetry.vLong > 3
		input =
			{ steer = input.steer, throttle = 0, brake = if rolling then 1 else 0, drift = false }
	elseif
		grid
		and raceGo
		and Features.CVC
		and tracks[current].map
		and tracks[current].id ~= "drift"
		and math.abs(input.steer) < 0.05
		and input.throttle > 0
		and player:GetAttribute("EasyRace") == true
	then
		-- a first race and gas but no steering: aim along the road (RoadSteer). Steering wins.
		local t = tracks[current]
		local mapId = t.map :: string
		local loop = steerLoops[mapId]
		if loop == nil then
			local m = RaceMaps.get(mapId)
			loop = if m then m.loop() else {}
			steerLoops[mapId] = loop
		end
		if #loop > 2 then
			local p = body.Position
			local lx, ly, lz = TrackData.toLocal(t, rc, p.X, p.Y, p.Z)
			local k = RoadSteer.nearest(loop, lx, lz, steerAt)
			steerAt = k
			local ax, az = RoadSteer.aim(loop, k)
			local wx, _, wz = TrackData.toWorld(t, rc, ax, ly, az)
			local cf = body.CFrame
			local to = Vector3.new(wx - p.X, 0, wz - p.Z)
			local angle = math.atan2(to:Dot(cf.RightVector), to:Dot(cf.LookVector))
			input = {
				steer = RoadSteer.steer(angle),
				throttle = input.throttle,
				brake = input.brake,
				drift = input.drift,
			}
		end
	end
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
			startBeep.Volume = SoundLevels.START_BEEP * (if grid then 1.8 else 1)
			if grid then
				Sfx.count(RaceStart.GO - step) -- 3, 2, 1, then 0 = GO (the sounds helper's)
				-- (radians: a nudge on 3, 2, 1, a bigger one on GO)
				shakeBy = if step >= RaceStart.GO then 0.018 else 0.008
				shakeLeft = SHAKE_TIME
			else
				startBeep:Play()
			end
			bigCount.show(step, RaceStart.label(step), step >= RaceStart.GO)
			-- (the new screens show the car's name tag from the first count, CvcScreens)
			player:SetAttribute("CountStep", step)
		end
		if step == RaceStart.GO then
			countdown = nil
			gridGone = grid ~= nil
			raceGo = if grid then os.clock() else nil
			if grid and Features.CVC then
				setRacing(true)
				addBoost()
			end
			-- (the server race clock runs from GO; on your own the clock waits for you to go)
			if grid and early then
				-- like the server: its laps count from its next time over the line
				jumped = true
			elseif grid then
				LapTimer.go(timer, os.clock())
			else
				waitMove = true
			end
		elseif grid and LapTimer.inside(timer.gates[1], lx, ly, lz) then
			-- server race: the lights keep going and the race is still on at GO (it used to drop
			-- this car's screen out of the race: no LAP 2/3, no FINAL LAP)
			if not early then
				early = true
				hud.flash("TOO EARLY!")
			end
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
	elseif raceDone == nil and not raceOver then
		event = LapTimer.update(timer, os.clock(), lx, ly, lz)
	end
	-- server race: still on the line 2 s after GO = a big HOLD GAS! (a new kid didn't know what
	-- to press; look only, GasHint)
	if raceGo and not movedSinceGo then
		local v = body.AssemblyLinearVelocity
		movedSinceGo = input.throttle > 0 or Vector3.new(v.X, 0, v.Z).Magnitude > 2 * Tuning.scale
	end
	local goAt = raceGo
	gasHint.set(
		not walking
			and GasHint.shows(
				if goAt then os.clock() - goAt else nil,
				movedSinceGo,
				raceDone ~= nil or raceOver
			)
	)
	-- server race: the last lap is the finish (the server keeps the real order)
	local go = raceGo
	if event == "lap" and grid and go and t.id ~= "drift" and timer.laps >= raceLaps() then
		event = nil
		raceDone = os.clock() - go
		hud.flash(`FINISH!  {CarMath.formatTime(raceDone :: number)}`, true)
		-- (at once, the frame you cross: MASTER asks for confetti within 0.5 s)
		raceFx.confetti(body.Position + Vector3.new(0, 2 * Tuning.scale, 0), 90, Tuning.scale * 4)
		setRacing(false)
	end
	roadArrow.update(t, timer, rc, lx, lz)
	-- server race: driving away from the next gate for a while = a big WRONG WAY!
	local wrongNow = false
	if grid and go and raceDone == nil and not raceOver and timer.running and #timer.gates > 0 then
		local g = timer.gates[((timer.next - 1) % #timer.gates) + 1]
		local wx, _, wz = TrackData.toWorld(t, rc, g.x, ly, g.z)
		local v = body.AssemblyLinearVelocity
		local back = ServerRace.wrongWay(v.X, v.Z, wx - p.X, wz - p.Z, 12 * Tuning.scale)
		wrongNow = back
		wrongFor = if back then wrongFor + dt else 0
		if wrongFor >= 1.2 then
			wrongFor = -1.3 -- show it again in a bit if they keep going
			hud.flash("WRONG WAY!")
		end
	else
		wrongFor = 0
	end
	if event == "lap" and grid and go and t.id ~= "drift" then
		-- server race: which lap you're on now, and a loud one for the last lap
		if Features.CVC then
			addBoost()
		end
		if timer.laps == raceLaps() - 1 then
			hud.flash("FINAL LAP!")
			startBeep.PlaybackSpeed = 1.3
			startBeep:Play()
		else
			hud.flash(`LAP {timer.laps + 1}/{raceLaps()}`)
		end
	elseif event == "lap" then
		hud.flash(`LAP  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "finish" then
		hud.flash(`SUMMIT!  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "start" and grid then
		hud.flash(`LAP 1/{raceLaps()}`) -- (a TOO EARLY car's laps start now, mid-race)
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
	if BackOnTrack.stuck(stuckTime, Tuning.stuckWait, t.id) then
		reset("STUCK - BACK TO START", "stuck")
	end
	-- Car VS Car big race: lost for a few seconds (nose in a wall with no pedal held, off every
	-- road or under the floor, WRONG WAY) = R: back on the road at the last gate (critic run 1).
	-- Only where the car is put (BackOnTrack.lost), never how it drives.
	local mapId = t.map
	if
		Features.CVC
		and grid
		and gridGone
		and mapId
		and t.id ~= "drift"
		and t.mode ~= "arena"
		and raceDone == nil
		and not raceOver
	then
		local roads = lostRoads[mapId]
		if roads == nil then
			local m = RaceMaps.get(mapId)
			roads = if m then BackOnTrack.roads(m) else {}
			lostRoads[mapId] = roads
		end
		local under = ly < BackOnTrack.UNDER
		local off = under or (#roads > 0 and BackOnTrack.offRoad(roads, lx, lz))
		if not off and car.telemetry.grounded > 0 then
			lastRoad = { x = lx, z = lz } -- (where a put-back goes: BackOnTrack.roadSpot)
		end
		local goAt = raceGo
		if not movedSincePut then
			local v = body.AssemblyLinearVelocity
			movedSincePut = input.throttle > 0
				or Vector3.new(v.X, 0, v.Z).Magnitude > 2 * Tuning.scale
		end
		local why = BackOnTrack.lost(
			lost,
			dt,
			if goAt then os.clock() - goAt else nil,
			movedSinceGo and movedSincePut,
			creep < 1.6 * Tuning.scale,
			off,
			car.telemetry.grounded == 0 and not under,
			-- (backing up counts as WRONG WAY but faces the right way: a kid still holding S after
			-- a put-back would be put back again and again)
			wrongNow and input.brake == 0
		)
		-- (Studio reads these to see why a lost car was or wasn't put back)
		local seen = string.format(
			"%.0f %.0f %.0f %d",
			lost.still * 2,
			lost.off * 2,
			lost.wrong * 2,
			if off then 1 else 0
		)
		if body:GetAttribute("LostClocks") ~= seen then
			body:SetAttribute("LostClocks", seen)
		end
		if why then
			reset(nil, why)
		end
	elseif lost.still ~= 0 or lost.off ~= 0 or lost.wrong ~= 0 or lost.air ~= 0 then
		lost.still, lost.off, lost.wrong, lost.air = 0, 0, 0, 0
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
	if BackOnTrack.fell(p.Y, Tuning.scale) then
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
-- carter's pick 18: in the big race your own car wears a yellow YOU (the others wear their names:
-- OtherCars), so you find it from the stand
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

-- Car VS Car: the other leagues' racers stand on the same stand spots; this screen hides them
-- (their cars too: OtherCars). A few times a second is enough.
local leagueCheck = 0
local hiddenPeople: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
-- (standing = the stand cam is on: the racers beside you on the stand fade, so they don't hide
-- your car on the front straight; Maps' stand-view render backyard-near.png)
local function hideOtherLeagues(dt: number, standing: boolean)
	leagueCheck -= dt
	if leagueCheck > 0 then
		return
	end
	leagueCheck = 0.3
	local mine = player:GetAttribute("RaceGroup")
	for _, p in Players:GetPlayers() do
		if p == player then
			continue
		end
		local theirs = p:GetAttribute("RaceGroup")
		local fade = if mine ~= nil
				and theirs ~= nil
				and theirs ~= mine
			then 1
			elseif standing and theirs ~= nil then RaceStand.FADE
			else 0
		if fade ~= (hiddenPeople[p] or 0) then
			local char = p.Character
			if char then
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						(d :: any).LocalTransparencyModifier = fade
					end
				end
			end
			hiddenPeople[p] = if fade > 0 then fade else nil
		end
	end
end
local airTime = 0 -- seconds in the air up to last frame

local hiddenChar: Model? = nil -- the body last hidden or shown for the driver view
local hiddenAs = -1
local hideAgainAt = 0
local hudTextAt = 0 -- next speed / clock text
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
	-- Car VS Car big race: from the stand, above and behind your spot, turning to watch your car
	-- and zooming in as it goes far (RaceStand)
	local k = player:GetAttribute("StandSpot")
	local spot = if Features.CVC
			and grid
			and standCam
			and not showCam
			and type(k) == "number"
		then RaceStand.spot(tracks[current], k)
		else nil
	if spot then
		local cx, cy, cz = RaceStand.camAt(spot)
		local from = Vector3.new(cx, cy, cz)
		local target = body.Position
		local look = standLook
		look = if look then look:Lerp(target, math.min(1, 12 * dt)) else target
		standLook = look
		local want = RaceStand.fov((target - from).Magnitude)
		standFov += (want - standFov) * math.min(1, 4 * dt)
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.lookAt(from, look)
		cam.FieldOfView = standFov
	else
		standLook = nil
	end
	if shakeLeft > 0 then
		shakeLeft = math.max(0, shakeLeft - dt)
		local a = shakeBy * shakeLeft / SHAKE_TIME
		local cam = workspace.CurrentCamera
		cam.CFrame *= CFrame.Angles(shakeRng:NextNumber(-a, a), shakeRng:NextNumber(-a, a), 0)
	end
	hideOtherLeagues(dt, spot ~= nil)
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
