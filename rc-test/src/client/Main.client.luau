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

local ChaseCamera = require(script.Parent.ChaseCamera)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local RCCar = require(script.Parent.RCCar)

local player = Players.LocalPlayer
local model = workspace:WaitForChild("Car_" .. player.UserId) :: Model
while model.PrimaryPart == nil do
	task.wait()
end
local body = model.PrimaryPart :: BasePart

local car = RCCar.new(model)
local camera = ChaseCamera.new(body, { model })
local effects = Effects.new(car.telemetry)

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
local driftChain, driftTotal, driftHold = 0, 0, 0

local hud: Hud.Hud
local function goTo(index: number)
	current = index
	local t = tracks[index]
	setMode(t.id)
	effects.clear()
	LapTimer.reset(timers[index])
	driftChain, driftTotal, driftHold = 0, 0, 0
	local s = t.spawn
	local pos = Vector3.new(t.originX + s.x, s.y, s.z)
	car.teleport(CFrame.lookAt(pos, pos + Vector3.new(s.dx, 0, s.dz)))
	camera.snap()
	hud.setActiveTrack(index)
	hud.setDrift(0, 0, t.id == "drift")
end

local gui = Hud.createGui()
hud = Hud.new(gui, labels, goTo)
local controls = Controls.new(
	gui,
	function()
		goTo(current)
	end,
	goTo,
	function()
		local on = camera.toggleOrbit()
		hud.flash(if on then "SHOW CAM" else "CHASE CAM")
	end
)
goTo(1)

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
	car.step(dt, controls.read())

	local t = tracks[current]
	local p = body.Position
	local event = LapTimer.update(timers[current], os.clock(), p.X - t.originX, p.Y, p.Z)
	if event == "lap" then
		hud.flash(`LAP  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "finish" then
		hud.flash(`SUMMIT!  {CarMath.formatTime(timers[current].last :: number)}`)
	elseif event == "start" then
		hud.flash("GO!")
	end

	-- fell off the world
	if p.Y < -40 then
		goTo(current)
	end

	if t.id == "drift" then
		local tel = car.telemetry
		local gain = CarMath.driftPoints(tel.speed, tel.slip, dt)
		if gain > 0 and tel.grounded > 0 then
			driftChain += gain
			driftHold = 0.8
		elseif driftChain > 0 then
			driftHold -= dt
			if driftHold <= 0 or tel.speed < 8 then
				driftTotal += driftChain
				hud.flash(`+{math.floor(driftChain)}`)
				driftChain = 0
			end
		end
		hud.setDrift(driftChain, driftTotal, true)
	end
end)

RunService:BindToRenderStep("RCCar", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	car.render(dt)
	effects.update(dt)
	camera.update(dt)
	hud.setSpeed(car.telemetry.speed)
	hud.setTimer(timerText())
end)
