--!strict
-- RC car feel test, player side: drives the car, runs the camera, switches tracks, times laps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local LapTimer = require(ReplicatedStorage.Shared.LapTimer)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local setMode: (id: string) -> () = (Tuning :: any).setMode
local setScale: (s: number) -> () = (Tuning :: any).setScale

local ChaseCamera = require(script.Parent.ChaseCamera)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local RCCar = require(script.Parent.RCCar)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RCControl") :: RemoteEvent
local carName = "Car_" .. player.UserId

-- The person's own walking controls would fight the car keys (and show a phone stick).
task.spawn(function()
	local ok, playerModule = pcall(function(): any
		-- not every place has one; don't wait forever
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return if module then require(module :: ModuleScript) else nil
	end)
	if ok and playerModule then
		playerModule:GetControls():Disable()
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
local driverView = false

local car = RCCar.new(model, ignoreList())
local camera = ChaseCamera.new(body, ignoreList(), eye)
local effects = Effects.new(car.telemetry)
local rc = false -- flipped to real RC size right after start-up
local swapping = false

local tracks: { TrackData.Track } = {}
local timers: { LapTimer.State } = {}
local labels: { string } = {}
for i, id in TrackData.order do
	local t = TrackData.get(id)
	tracks[i] = t
	timers[i] = LapTimer.new(t.gates, t.mode)
	labels[i] = t.label
end

local current = 1

getEye = function(): Vector3
	local t = tracks[current]
	local spot = TrackData.standSpot(t)
	local x, _, z = TrackData.toWorld(t, rc, spot.x, 0, spot.z)
	-- eye height of a person at real RC size (18 at the big size)
	return Vector3.new(x, 4.5 / TrackData.RC_SCALE * Tuning.scale, z)
end
local driftChain, driftTotal, driftHold = 0, 0, 0

local hud: Hud.Hud
local function goTo(index: number)
	if swapping then
		return
	end
	current = index
	local t = tracks[index]
	setScale(if rc then TrackData.RC_SCALE else 1)
	setMode(t.id)
	effects.clear()
	LapTimer.reset(timers[index])
	driftChain, driftTotal, driftHold = 0, 0, 0
	local s = t.spawn
	local x, y, z = TrackData.toWorld(t, rc, s.x, s.y, s.z)
	local pos = Vector3.new(x, y, z)
	remote:FireServer("place", rc, index)
	car.teleport(CFrame.lookAt(pos, pos + Vector3.new(s.dx, 0, s.dz)))
	camera.snap()
	hud.setActiveTrack(index)
	hud.setDrift(0, 0, t.id == "drift")
end

-- The server builds a new car at the other size; hook everything onto it.
local function swapSize()
	if swapping then
		return
	end
	swapping = true
	rc = not rc
	hud.flash(if rc then "RC SIZE" else "BIG SIZE")
	local old = model
	remote:FireServer("place", rc, current)
	local t0 = os.clock()
	while workspace:FindFirstChild(carName) == old do
		if os.clock() - t0 > 5 then
			-- the server didn't answer: stay at the old size
			rc = not rc
			swapping = false
			return
		end
		task.wait()
	end
	car.destroy()
	effects.destroy()
	model, body = waitForCar()
	if rc then
		-- wait a moment for the person to appear so the camera and wheels ignore them
		local t0 = os.clock()
		while player.Character == nil and os.clock() - t0 < 3 do
			task.wait()
		end
	end
	setScale(if rc then TrackData.RC_SCALE else 1)
	car = RCCar.new(model, ignoreList())
	camera = ChaseCamera.new(body, ignoreList(), eye)
	camera.setDriver(driverView)
	effects = Effects.new(car.telemetry)
	swapping = false
	goTo(current)
end

-- Back to the plot's start with a short beep (fell off, stuck, or the R key).
local beep = Instance.new("Sound")
beep.Name = "ResetBeep"
beep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
beep.Volume = 0.5
beep.Parent = script
local stuckTime = 0
local function reset()
	stuckTime = 0
	beep:Play()
	goTo(current)
end

local gui = Hud.createGui()
hud = Hud.new(gui, labels, goTo)
local controls = Controls.new(gui, reset, goTo, function()
	local on = camera.toggleOrbit()
	if on then
		driverView = false
	end
	hud.flash(if on then "SHOW CAM" elseif driverView then "DRIVER VIEW" else "CHASE CAM")
end, function()
	task.spawn(swapSize)
end, function()
	driverView = not driverView
	camera.setDriver(driverView)
	hud.flash(if driverView then "DRIVER VIEW" else "CHASE CAM")
end)
goTo(1)
task.spawn(swapSize)

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
	if swapping or body.Parent == nil then
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

	-- gas held but the car barely moves for 3 s = stuck: start over (slow rock crawling is
	-- still far faster than this)
	local v = body.AssemblyLinearVelocity
	if input.throttle > 0 and Vector3.new(v.X, 0, v.Z).Magnitude < 1 * Tuning.scale then
		stuckTime += dt
	else
		stuckTime = 0
	end
	if stuckTime > 3 then
		reset()
		hud.flash("STUCK - BACK TO START")
	end

	-- fell off the world
	if p.Y < -8 * Tuning.scale / TrackData.RC_SCALE then
		reset()
	end

	if t.id == "drift" then
		local tel = car.telemetry
		local gain = CarMath.driftPoints(tel.speed, tel.slip, dt)
		if gain > 0 and tel.grounded > 0 then
			driftChain += gain
			driftHold = 0.8
		elseif driftChain > 0 then
			driftHold -= dt
			if driftHold <= 0 or tel.speed < 8 * Tuning.scale then
				driftTotal += driftChain
				hud.flash(`+{math.floor(driftChain)}`)
				driftChain = 0
			end
		end
		hud.setDrift(driftChain, driftTotal, true)
	end
end)

RunService:BindToRenderStep("RCCar", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if swapping or body.Parent == nil then
		return
	end
	car.render(dt)
	effects.update(dt)
	camera.update(dt)
	-- driver view looks out of the person's eyes: hide them on this screen so the head and hat
	-- don't block the view
	local char = player.Character
	if char then
		local hide = if driverView then 1 else 0
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
