--!strict
-- The practice drive of the first-time tutorial (carter's L6, L13, L56, L57, L60), on this device
-- only: the player walks into the blue portal, the screen fades, the junkyard (PracticeYard) is built
-- far away, the Ram Truck stands at its start line and the player drives it with the same wheel,
-- GAS button, keys, weight and camera as in a fight. Smashing 3 boxes ends it; so does SKIP or the
-- time limit. Then the yard is taken apart and the character is back at the lobby spawn.
--
-- The server only parks the character (TutorialService "practiceEnter") and brings it back
-- ("practiceExit"); the car, the boxes and the camera are all local, so nothing here can be seen or
-- hurt by another player. Every step is wrapped so a mistake here ends the practice, never the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local PracticeCamera = require(ReplicatedStorage.Shared.PracticeCamera)
local PracticeLayout = require(ReplicatedStorage.Shared.PracticeLayout)
local PracticeRules = require(ReplicatedStorage.Shared.PracticeRules)
local PracticeYard = require(ReplicatedStorage.Shared.PracticeYard)
local TutorialConfig = require(ReplicatedStorage.Shared.TutorialConfig)
local BattleDriver = require(script.Parent.BattleDriver)
local PracticeCar = require(script.Parent.PracticeCar)
local SoundFx = require(script.Parent.SoundFx)
local SteerInput = require(script.Parent.SteerInput)

local PracticeClient = {}

export type Deps = {
	remotes: { LobbyAction: RemoteEvent },
	fade: (toBlack: boolean, seconds: number) -> (), -- yields until the fade is over (TutorialUi)
	-- "gas" (seconds), "steer" (seconds), "boxes" (count so far), "practiceFailed" (it could not start);
	-- "timeUp" and "practiceBroken" (the time ran out / the code failed) are sent once while the
	-- yard still stands: the caller answers with `leave`
	onEvent: (name: string, value: any?) -> (),
	touch: boolean, -- a phone: the big GAS button is drawn
}

export type Practice = {
	enter: () -> (), -- the whole way in: ask the server, fade, build, fade in (calls onEvent "practiceFailed" if it cannot)
	leave: (done: (() -> ())?) -> (), -- the whole way out; `done` runs when the player is back in the lobby
	handleServer: (event: string) -> (), -- the server's answers: "practiceReady" | "practiceRefused" | "practiceExited"
	isActive: () -> boolean, -- in the yard or on the way in or out
	isReady: () -> boolean, -- in the yard, faded in, the car can be driven
	destroy: () -> (),
}

-- The same green as the GAS button in a fight (BattleUi).
local GAS_COLOR = Color3.fromRGB(80, 210, 120)
local TEXT_COLOR = Color3.fromRGB(245, 247, 255)
local CHAMPIONS_GUIS = { "CVC_Champions", "CVC_ChampionsDim", "CVC_ChampionsHud" }
local ANSWER_SECONDS = 4 -- how long the server may take to say yes
local EXIT_SECONDS = 3
local MAX_FRAME_ERRORS = 3

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function PracticeClient.new(deps: Deps): Practice
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local H = BattleConfig.Human
	local origin =
		Vector3.new(PracticeLayout.origin.x, PracticeLayout.origin.y, PracticeLayout.origin.z)

	local state = "idle" -- "idle" | "entering" | "active" | "leaving"
	local wantLeave = false
	local answers: { string } = {}

	-- the one wheel for every visit (SteerInput hooks the keyboard once; start/stop are cheap)
	local steer: SteerInput.SteerInput? = nil

	-- what is alive while the yard stands
	local yard: PracticeYard.Yard? = nil
	local car: PracticeCar.Car? = nil
	local driver: BattleDriver.Driver? = nil
	local frameConn: RBXScriptConnection? = nil
	local inputConns: { RBXScriptConnection } = {}
	local practiceGui: ScreenGui? = nil
	local hiddenGuis: { [ScreenGui]: boolean } = {}
	local camState = PracticeCamera.new()
	local camSmooth: CFrame? = nil
	local shake, fovKick = 0.0, 0.0
	local alive: { boolean } = {}
	local spots: { PracticeRules.Spot } = {}
	local smashed = 0
	local startedAt = 0.0
	local frameErrors = 0
	local reported = false -- "timeUp" / "practiceBroken" are said once

	local function waitFor(names: { string }, seconds: number): string?
		local waited = 0.0
		while true do
			for i, a in answers do
				if table.find(names, a) then
					table.remove(answers, i)
					return a
				end
			end
			if waited >= seconds then
				return nil
			end
			waited += task.wait(0.05)
		end
	end

	local function setChampions(on: boolean)
		if on then
			for g, was in hiddenGuis do
				if g.Parent ~= nil then
					g.Enabled = was
				end
			end
			table.clear(hiddenGuis)
		else
			for _, name in CHAMPIONS_GUIS do
				local g = playerGui:FindFirstChild(name)
				if g ~= nil and g:IsA("ScreenGui") then
					local gui = g :: ScreenGui
					if hiddenGuis[gui] == nil then
						hiddenGuis[gui] = gui.Enabled
					end
					gui.Enabled = false
				end
			end
		end
	end

	local function restoreCamera()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
	end

	-- the big GAS button (phones), like the one in a fight
	local function makeGasButton(wheel: SteerInput.SteerInput)
		local gui: ScreenGui = make("ScreenGui", {
			Name = "TutorialPractice",
			ResetOnSpawn = false,
			DisplayOrder = 8,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, playerGui)
		practiceGui = gui
		if not deps.touch then
			return
		end
		local button: TextButton = make("TextButton", {
			Name = "PracticeGas",
			Size = UDim2.fromScale(0.14, 0.24),
			Position = UDim2.fromScale(0.85, 0.74),
			BackgroundColor3 = GAS_COLOR,
			AutoButtonColor = true,
			Font = Enum.Font.GothamBold,
			Text = "GAS",
			TextColor3 = TEXT_COLOR,
			TextScaled = true,
		}, gui)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
		make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 8 }, button)
		make("UIPadding", {
			PaddingLeft = UDim.new(0.06, 0),
			PaddingRight = UDim.new(0.06, 0),
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
		}, button)
		local held: InputObject? = nil
		table.insert(
			inputConns,
			button.InputBegan:Connect(function(input: InputObject)
				if
					held == nil
					and (
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					held = input
					wheel.setGas(true)
				end
			end)
		)
		table.insert(
			inputConns,
			UserInputService.InputEnded:Connect(function(input: InputObject)
				if held ~= nil and input == held then
					held = nil
					wheel.setGas(false)
				end
			end)
		)
	end

	local function teardown()
		if frameConn ~= nil then
			frameConn:Disconnect()
			frameConn = nil
		end
		for _, c in inputConns do
			c:Disconnect()
		end
		table.clear(inputConns)
		if driver ~= nil then
			driver.stop()
			driver = nil
		end
		if steer ~= nil then
			steer.setGas(false)
			steer.stop()
		end
		if practiceGui ~= nil then
			practiceGui:Destroy()
			practiceGui = nil
		end
		if car ~= nil then
			car.destroy()
			car = nil
		end
		if yard ~= nil then
			yard.destroy()
			yard = nil
		end
		camSmooth = nil
		setChampions(true)
	end

	-- one frame of the practice (camera, smashing boxes, the lesson's events)
	local function frame(dt: number): string?
		local c, y, wheel = car, yard, steer
		if c == nil or y == nil or wheel == nil or c.body.Parent == nil then
			return nil
		end
		local body = c.body
		local pos = body.Position
		local rel = pos - origin
		if PracticeRules.outside(rel.X, rel.Y, rel.Z) then
			c.reset()
			return nil
		end

		-- what the lesson listens for
		local steerValue, gasValue = wheel.read()
		if gasValue > 0.5 then
			deps.onEvent("gas", dt)
		end
		if math.abs(steerValue) >= TutorialConfig.steerThreshold then
			deps.onEvent("steer", dt)
		end

		-- boxes: a rolling car that touches one smashes it
		local v = body.AssemblyLinearVelocity
		local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
		local look = body.CFrame.LookVector
		local hits = PracticeRules.smashed(
			spots,
			alive,
			{ x = rel.X, z = rel.Z, yawDeg = PracticeRules.yawOf(look.X, look.Z) },
			c.L,
			speed
		)
		for _, i in hits do
			alive[i] = false
			smashed += 1
			PracticeYard.burst(y.crates[i], v)
			shake = math.max(shake, 2.5)
			fovKick = math.max(fovKick, 5)
			SoundFx.play("hitHard")
		end
		if #hits > 0 then
			deps.onEvent("boxes", smashed)
		end

		-- the chase camera: behind and above the car, like in a fight
		local camera = workspace.CurrentCamera
		if camera ~= nil then
			local flatLook = Vector3.new(look.X, 0, look.Z)
			local carYaw = if flatLook.Magnitude > 1e-3 then math.atan2(look.X, look.Z) else 0
			local eye, at =
				PracticeCamera.aim(camState, { x = rel.X, y = rel.Y, z = rel.Z }, carYaw, c.L, dt)
			local target = CFrame.lookAt(
				origin + Vector3.new(eye.x, eye.y, eye.z),
				origin + Vector3.new(at.x, at.y, at.z)
			)
			local cur = camSmooth
			if cur == nil then
				cur = target
			else
				cur = cur:Lerp(target, math.clamp(H.camSmooth * dt, 0, 1))
			end
			camSmooth = cur
			local shaken = cur :: CFrame
			if shake > 0.02 then
				shaken = shaken
					* CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
				shake *= math.max(0, 1 - 6 * dt)
			else
				shake = 0
			end
			camera.CFrame = shaken
			fovKick *= math.max(0, 1 - 4 * dt)
			camera.FieldOfView = H.camFov + fovKick
		end

		if not reported and PracticeRules.timeUp(os.clock() - startedAt) then
			reported = true -- too slow: the lesson carries on without the boxes
			deps.onEvent("timeUp")
		end
		return nil
	end

	local function build(): string?
		local newYard = PracticeYard.build(workspace, origin)
		yard = newYard
		table.clear(alive)
		table.clear(spots)
		for i, crate in newYard.crates do
			alive[i] = true
			spots[i] = { x = crate.x, z = crate.z }
		end
		smashed = 0
		reported = false
		local newCar, why = PracticeCar.spawn(newYard.root, newYard.spawn())
		if newCar == nil then
			error(why or "no car")
		end
		car = newCar

		-- the wheel / keys, the GAS button, the driving code
		local wheel: SteerInput.SteerInput = steer
			or SteerInput.new(function() end, {
				wheel = true,
				sendFull = function() end, -- nothing is sent: the practice has no server fight
			})
		steer = wheel
		wheel.start()
		makeGasButton(wheel)
		local d = BattleDriver.new(function()
			return wheel.read()
		end, function()
			return if car ~= nil then car.body else nil
		end)
		d.start()
		driver = d

		-- the camera
		local camera = workspace.CurrentCamera
		if camera ~= nil then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = H.camFov
		end
		camState = PracticeCamera.new()
		camSmooth = nil
		shake, fovKick = 0, 0
		setChampions(false)
		startedAt = os.clock()
		frameErrors = 0
		frameConn = RunService.RenderStepped:Connect(function(dt: number)
			local ok, err = pcall(frame, dt)
			if not ok then
				frameErrors += 1
				warn("[Tutorial] practice frame: " .. tostring(err))
				if frameErrors >= MAX_FRAME_ERRORS and not reported then
					reported = true
					deps.onEvent("practiceBroken")
				end
			end
		end)
		return nil
	end

	local function enterSequence(): boolean
		answers = {}
		deps.remotes.LobbyAction:FireServer("practiceEnter")
		if waitFor({ "practiceReady", "practiceRefused" }, ANSWER_SECONDS) ~= "practiceReady" then
			return false
		end
		deps.fade(true, 0.3)
		local ok, err = pcall(build)
		if not ok then
			warn("[Tutorial] the practice yard could not be built: " .. tostring(err))
			teardown()
			restoreCamera()
			answers = {}
			deps.remotes.LobbyAction:FireServer("practiceExit")
			waitFor({ "practiceExited" }, EXIT_SECONDS)
			deps.fade(false, 0.3)
			return false
		end
		deps.fade(false, 0.4)
		return true
	end

	local function leaveSequence(): boolean
		deps.fade(true, 0.3)
		teardown()
		answers = {}
		deps.remotes.LobbyAction:FireServer("practiceExit")
		waitFor({ "practiceExited" }, EXIT_SECONDS)
		restoreCamera()
		deps.fade(false, 0.4)
		return true
	end

	local self = {} :: Practice

	self.leave = function(done: (() -> ())?)
		if state == "entering" then
			wantLeave = true -- as soon as the yard is up, go back out
			if done ~= nil then
				task.spawn(function()
					while state == "entering" or state == "active" or state == "leaving" do
						task.wait(0.1)
					end
					done()
				end)
			end
			return
		end
		if state ~= "active" then
			if done ~= nil then
				done()
			end
			return
		end
		state = "leaving"
		task.spawn(function()
			local ok, err = pcall(leaveSequence)
			if not ok then
				warn("[Tutorial] leaving the practice yard: " .. tostring(err))
			end
			state = "idle"
			if done ~= nil then
				done()
			end
		end)
	end

	self.enter = function()
		if state ~= "idle" then
			return
		end
		state, wantLeave = "entering", false
		task.spawn(function()
			local ok, result = pcall(enterSequence)
			if not ok or result ~= true then
				if not ok then
					warn("[Tutorial] entering the practice yard: " .. tostring(result))
				end
				state = "idle"
				deps.onEvent("practiceFailed")
				return
			end
			state = "active"
			if wantLeave then
				self.leave(nil)
			end
		end)
	end

	self.handleServer = function(event: string)
		table.insert(answers, event)
		-- the server brought the character back by itself (its safety timer): the practice is over
		if event == "practiceExited" and state == "active" then
			self.leave(function()
				deps.onEvent("practiceFailed")
			end)
		end
	end

	self.isActive = function(): boolean
		return state ~= "idle"
	end

	self.isReady = function(): boolean
		return state == "active"
	end

	self.destroy = function()
		teardown()
		restoreCamera()
		state = "idle"
	end

	return self
end

return PracticeClient
