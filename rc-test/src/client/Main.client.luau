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
local LobbyLife = require(script.Parent.LobbyLife)
local LobbySky = require(script.Parent.LobbySky)
local RCCar = require(script.Parent.RCCar)

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
local skin = CarSkin.new() -- the truck model on the rock car (look only)
local rc = true -- always RC size: the lobby plots are the tracks

-- one track per lobby plot (its kind's data, placed where that plot sits)
local tracks: { TrackData.Track } = {}
local timers: { LapTimer.State } = {}
for i in LobbyLayout.slots() do
	local t: TrackData.Track = LobbyLayout.track(i)
	tracks[i] = t
	timers[i] = LapTimer.new(t.gates, t.mode)
end
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
	LapTimer.reset(timers[index])
	checkpoint = 0
	driftChain, driftTotal, driftHold, driftHeld = 0, 0, 0, 0
	local s = t.spawn
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

-- tyre smoke colour pick, and the star count that opens more colours (sent by the stars server)
local smokeIndex = 1
local stars = 0
task.spawn(function()
	local starsEvent = ReplicatedStorage:WaitForChild("StarsEvent", 30)
	if starsEvent and starsEvent:IsA("RemoteEvent") then
		starsEvent.OnClientEvent:Connect(function(kind: unknown, info: unknown)
			if kind == "stars" and type(info) == "number" then
				stars = info
			elseif
				kind == "run"
				and type(info) == "table"
				and type((info :: any).stars) == "number"
			then
				stars = (info :: any).stars
			end
		end)
	end
end)

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
end)

-- Walking <-> driving. Only the server switches (E on a stand, or WALK), this side follows.
local lobby = Lobby.new(remote, function(): boolean
	return true
end)
local function setWalking(on: boolean)
	LobbySky.set(on)
	walking = on
	gui.Enabled = not on
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

remote.OnClientEvent:Connect(function(kind: unknown, index: unknown)
	if kind == "walk" then
		setWalking(true)
		LobbyLife.start() -- butterflies and birds (looks only, this screen)
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
		goTo(index)
	end
end)
setWalking(true)

local function timerText(): string
	local t = tracks[current]
	local s = timers[current]
	if t.mode == "free" then
		return ""
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

RunService.PreSimulation:Connect(function(dt: number)
	if walking or body.Parent == nil then
		return
	end
	local input = controls.read()
	car.step(dt, input)

	local t = tracks[current]
	local p = body.Position
	local lx, ly, lz = TrackData.toLocal(t, rc, p.X, p.Y, p.Z)
	local event = LapTimer.update(timers[current], os.clock(), lx, ly, lz)
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
		elseif driftChain > 0 then
			driftHold -= dt
			if driftHold <= 0 or tel.speed < 8 * Tuning.scale then
				driftTotal += driftChain
				hud.popScore(driftChain)
				driftChain, driftHeld = 0, 0
			end
		end
		hud.setDrift(driftChain, driftTotal, true, CarMath.driftCombo(driftHeld))
	end
end)

RunService:BindToRenderStep("RCCar", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if walking then
		-- a respawn can hand the camera a new person: follow them
		local cam = workspace.CurrentCamera
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and cam.CameraSubject ~= hum then
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum
		end
		car.render(dt) -- keep the parked car's wheels drawn
		skin.update(car, tracks[current].id == "rock")
		effects.quiet()
		return
	end
	if body.Parent == nil then
		return
	end
	car.render(dt)
	skin.update(car, tracks[current].id == "rock")
	effects.update(dt)
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
