--!nocheck
-- The practice drive on the fake Roblox (carter's L6, L13, L56, L57, L60): the way in and out, the
-- yard and the Ram Truck, driving with the phone buttons and the PC keys, smashing boxes, the time
-- limit, and every way it can go wrong. The fake world has a flat floor and moves the car by its
-- velocity, so the real driving code (BattleDrive) really drives it.
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local V3, V2, CF, Enum = Mock.V3, Mock.V2, Mock.CF, Mock.Enum

print("PracticeClient")

local MENUS = { "CVC_Champions", "CVC_ChampionsDim", "CVC_ChampionsHud" }

-- `touch`: a phone (the GAS button and the stick) or a PC (keys).
local function setup(touch: boolean?)
	local phone = touch ~= false
	local world = Mock.new("./src", { fakeClock = true })
	world.quiet = true
	world.input.TouchEnabled = phone
	world.input.KeyboardEnabled = not phone
	local player = world.newLocalPlayer("Dana", 7)
	local gui = player.PlayerGui
	local env: any = {
		world = world,
		player = player,
		gui = gui,
		sent = {},
		events = {},
		fades = {},
		menus = {},
		auto = true, -- the fake server answers at once
		enterAnswer = "practiceReady",
		layout = world.require("shared/PracticeLayout"),
		config = world.require("shared/TutorialConfig"),
		physics = true,
	}
	for _, name in MENUS do
		local g = world.instance("ScreenGui")
		g.Name = name
		g.Parent = gui
		env.menus[name] = g
	end

	-- a flat floor: a ray pointing down hits it, a sideways ray hits nothing
	local floor = world.instance("Part")
	floor.Name = "TestFloor"
	world.workspace.Raycast = function(_self: any, from: any, dir: any)
		if dir.Y < 0 then
			return {
				Instance = floor,
				Position = V3.new(from.X, from.Y + dir.Y, from.Z),
				Normal = V3.new(0, 1, 0),
			}
		end
		return nil
	end

	local PracticeClient = world.requireClient("PracticeClient")
	env.practice = PracticeClient.new({
		remotes = {
			LobbyAction = {
				FireServer = function(_self: any, action: string)
					table.insert(env.sent, action)
					if env.auto then
						if action == "practiceEnter" and env.enterAnswer ~= nil then
							env.practice.handleServer(env.enterAnswer)
						elseif action == "practiceExit" then
							env.practice.handleServer("practiceExited")
						end
					end
				end,
			},
		},
		fade = function(toBlack: boolean)
			table.insert(env.fades, toBlack)
		end,
		onEvent = function(name: string, value: any)
			table.insert(env.events, { name = name, value = value })
		end,
		touch = phone,
	})

	function env.count(name: string): number
		local n = 0
		for _, ev in env.events do
			if ev.name == name then
				n += 1
			end
		end
		return n
	end
	function env.yard()
		return world.workspace:FindFirstChild("PracticeYard")
	end
	function env.body()
		local yard = env.yard()
		local car = if yard then yard:FindFirstChild("PracticeCar") else nil
		return if car then car:FindFirstChild("Body") else nil
	end
	-- one frame: the game steps, then the (fake) physics moves the car by what the driving code set
	function env.tick(dt: number?)
		local d = dt or 0.05
		world.step(d)
		local body = env.body()
		if body ~= nil and env.physics then
			local v, w, at = body.AssemblyLinearVelocity, body.AssemblyAngularVelocity, body.CFrame
			local look = at.LookVector
			local yaw = math.atan2(-look.X, -look.Z) + w.Y * d
			local p = at.Position + v * d
			body.CFrame = CF.new(p.X, p.Y, p.Z) * CF.Angles(0, yaw, 0)
		end
	end
	function env.run(seconds: number)
		for _ = 1, math.floor(seconds / 0.05 + 0.5) do
			env.tick(0.05)
		end
	end
	-- put the car at yard coordinates, nose toward -z, rolling at `speed`
	function env.place(x: number, z: number, speed: number?)
		local o = env.layout.origin
		local body = env.body()
		body.CFrame = CF.new(o.x + x, o.y + 0.5, o.z + z)
		body.AssemblyLinearVelocity = V3.new(0, 0, -(speed or 0))
	end
	function env.key(code: any, down: boolean)
		local input = { KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }
		if down then
			world.input.InputBegan:Fire(input, false)
		else
			world.input.InputEnded:Fire(input, false)
		end
	end
	function env.flatSpeed(): number
		local v = env.body().AssemblyLinearVelocity
		return math.sqrt(v.X * v.X + v.Z * v.Z)
	end
	return env
end

local function yardPosition(e: any): (number, number)
	local o = e.layout.origin
	local p = e.body().Position
	return p.X - o.x, p.Z - o.z
end

-- Which way the nose points, in radians: 0 = toward -z, negative = turned right, positive = left.
local function yawOf(e: any): number
	local look = e.body().CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

H.test("the way in: ask, fade out, build the yard and the Ram Truck, fade in", function()
	local e = setup()
	eq(e.practice.isActive(), false)
	e.practice.enter()
	eq(e.sent[1], "practiceEnter")
	eq(e.practice.isActive(), true)
	eq(e.practice.isReady(), true)
	eq(e.fades[1], true, "to black first")
	eq(e.fades[2], false, "then clear")
	eq(e.count("practiceFailed"), 0)
	local yard = e.yard()
	truthy(yard, "the yard")
	local car = yard:FindFirstChild("PracticeCar")
	truthy(car, "the truck")
	eq(car:GetAttribute("ClientDriven"), true, "driven on this device")
	eq(car:GetAttribute("FighterId"), "RamTruck")
	truthy(type(car:GetAttribute("CarL")) == "number" and car:GetAttribute("CarL") > 5)
	-- at the start spot, in the yard, far from the lobby
	local x, z = yardPosition(e)
	near(x, e.layout.spawn.x, 2)
	near(z, e.layout.spawn.z, 2)
	truthy(e.layout.origin.x < -1000, "far away")
	-- nose toward -z
	local look = e.body().CFrame.LookVector
	truthy(look.Z < -0.9, "the nose points into the yard: " .. look.Z)
end)

H.test("the camera and the menus: ours while driving", function()
	local e = setup()
	e.practice.enter()
	eq(e.world.camera.CameraType, Enum.CameraType.Scriptable)
	local config = e.world.require("shared/BattleConfig")
	eq(e.world.camera.FieldOfView, config.Human.camFov)
	for name, g in e.menus do
		eq(g.Enabled, false, name .. " is hidden while driving")
	end
end)

H.test("a phone gets the big GAS button and the steering stick, and nothing else", function()
	local e = setup(true)
	e.practice.enter()
	local practiceGui = e.gui:FindFirstChild("TutorialPractice")
	truthy(practiceGui, "the practice screen")
	local gas = practiceGui:FindFirstChild("PracticeGas")
	truthy(gas, "GAS")
	eq(gas.Text, "GAS")
	truthy(gas.Position.X.Scale >= 0.8 and gas.Position.Y.Scale >= 0.6, "bottom right")
	truthy(e.gui:FindFirstChild("SteerGui"):FindFirstChild("Stick"), "the stick")
	-- no EXIT button (carter L55): the only way out is SKIP or finishing
	for _, d in e.gui:GetDescendants() do
		if d:IsA("TextButton") then
			truthy(d.Text ~= "EXIT" and d.Text ~= "Exit", "no exit button")
		end
	end
end)

H.test("a PC gets no GAS button: the keys drive", function()
	local e = setup(false)
	e.practice.enter()
	eq(e.gui:FindFirstChild("TutorialPractice"):FindFirstChild("PracticeGas"), nil)
end)

H.test("holding the GAS button is heard, and the truck drives forward", function()
	local e = setup(true)
	e.practice.enter()
	local button = e.gui:FindFirstChild("TutorialPractice"):FindFirstChild("PracticeGas")
	local input = { UserInputType = Enum.UserInputType.Touch }
	e.run(0.5)
	eq(e.count("gas"), 0, "idle: no gas")
	local _, z0 = yardPosition(e)
	button.InputBegan:Fire(input)
	e.run(2)
	truthy(e.count("gas") >= 30, "gas heard every frame: " .. e.count("gas"))
	local _, z1 = yardPosition(e)
	truthy(z1 < z0 - 15, "the truck rolled north: " .. z0 .. " -> " .. z1)
	truthy(e.flatSpeed() > 15, "and is quick: " .. e.flatSpeed())
	-- the seconds add up to the time the lesson asks for
	local total = 0
	for _, ev in e.events do
		if ev.name == "gas" then
			total += ev.value
		end
	end
	truthy(total >= e.config.gasSeconds, "gas seconds: " .. total)
	-- let go: no more gas
	e.world.input.InputEnded:Fire(input)
	local before = e.count("gas")
	e.run(0.5)
	eq(e.count("gas"), before, "released")
end)

H.test("sliding the stick is heard as steering, and the truck turns right", function()
	local e = setup(true)
	e.practice.enter()
	local steerGui = e.gui:FindFirstChild("SteerGui")
	local stick = steerGui:FindFirstChild("Stick")
	stick.AbsolutePosition = V2.new(40, 500)
	stick.AbsoluteSize = V2.new(160, 160)
	local zone = steerGui:FindFirstChild("SteerZone")
	truthy(zone, "the whole lower left steers")
	eq(e.count("steer"), 0)
	local input = { UserInputType = Enum.UserInputType.Touch, Position = V3.new(120, 580, 0) }
	zone.InputBegan:Fire(input)
	e.run(0.2)
	eq(e.count("steer"), 0, "a touch with no slide does not steer")
	near(yawOf(e), 0, 0.01, "and does not turn")
	input.Position = V3.new(190, 580, 0) -- slid right
	e.world.input.InputChanged:Fire(input)
	e.run(0.3)
	truthy(e.count("steer") >= 5, "steer heard: " .. e.count("steer"))
	truthy(yawOf(e) < -0.2, "the nose turned right: " .. yawOf(e))
	-- slid back to the middle: it stops turning
	input.Position = V3.new(120, 580, 0)
	e.world.input.InputChanged:Fire(input)
	e.run(0.3)
	local settled = yawOf(e)
	e.run(0.3)
	near(yawOf(e), settled, 0.05, "straight again")
	-- slid left: it turns the other way
	input.Position = V3.new(50, 580, 0)
	e.world.input.InputChanged:Fire(input)
	e.run(0.3)
	truthy(yawOf(e) > settled + 0.2, "and now left")
end)

H.test("on a PC, W drives and A / D steer", function()
	local e = setup(false)
	e.practice.enter()
	e.key(Enum.KeyCode.W, true)
	e.run(1.5)
	truthy(e.count("gas") >= 20)
	eq(e.count("steer"), 0, "no steering yet")
	truthy(e.flatSpeed() > 10)
	near(yawOf(e), 0, 0.01, "straight")
	e.key(Enum.KeyCode.D, true)
	e.run(0.3)
	truthy(e.count("steer") >= 3, "steer heard: " .. e.count("steer"))
	local right = yawOf(e)
	truthy(right < -0.2, "turning right: " .. right)
	e.key(Enum.KeyCode.D, false)
	e.key(Enum.KeyCode.A, true)
	local steers = e.count("steer")
	e.run(0.8)
	truthy(e.count("steer") > steers, "left counts too")
	truthy(yawOf(e) > right + 0.2, "turned back left: " .. yawOf(e))
	e.key(Enum.KeyCode.A, false)
	e.key(Enum.KeyCode.W, false)
end)

H.test("the chase camera stays behind and above the truck", function()
	local e = setup(false)
	e.practice.enter()
	e.key(Enum.KeyCode.W, true)
	e.run(2)
	local cam = e.world.camera.CFrame.Position
	local car = e.body().Position
	truthy(cam.Y > car.Y + 3, "above: " .. cam.Y .. " vs " .. car.Y)
	truthy(cam.Z > car.Z + 5, "behind (the truck drives toward -z): " .. cam.Z .. " vs " .. car.Z)
	local look = e.world.camera.CFrame.LookVector
	truthy(look.Z < -0.3, "looking along the truck's way")
end)

H.test("smashing boxes: each one counts once, with a count so far", function()
	local e = setup(false)
	e.practice.enter()
	local crates = e.layout.crates
	-- rolling slowly does not smash
	e.place(crates[1].x, crates[1].z + 3, 2)
	e.tick(0.05)
	eq(e.count("boxes"), 0, "creeping against a box does not smash it")
	-- rolling fast through the first box
	e.physics = false
	for i = 1, 3 do
		e.place(crates[i].x, crates[i].z + 4, 30)
		e.tick(0.05)
		eq(e.count("boxes"), i)
		eq(e.events[#e.events].value, i, "count so far")
		-- driving through it again smashes nothing more
		e.place(crates[i].x, crates[i].z + 4, 30)
		e.tick(0.05)
		eq(e.count("boxes"), i)
	end
	-- the burst crates fly: their parts are free now
	local yard = e.yard()
	local flying = 0
	for _, d in yard:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Anchored == false
			and d.Name ~= "Body"
			and d.AssemblyLinearVelocity.Y > 5
		then
			flying += 1
		end
	end
	truthy(flying > 3, "pieces fly: " .. flying)
	-- the camera is shaken
	e.tick(0.05)
end)

H.test("a truck thrown out of the yard is put back at the start", function()
	local e = setup(false)
	e.practice.enter()
	e.physics = false
	e.place(400, 0, 0)
	e.tick(0.05)
	local x, z = yardPosition(e)
	near(x, e.layout.spawn.x, 2)
	near(z, e.layout.spawn.z, 2)
	eq(e.flatSpeed(), 0)
	e.place(0, 0, 0)
	e.body().CFrame = CF.new(e.layout.origin.x, e.layout.origin.y - 100, e.layout.origin.z)
	e.tick(0.05)
	near(select(2, yardPosition(e)), e.layout.spawn.z, 2)
end)

H.test("the practice runs out of time by itself, once", function()
	local e = setup(false)
	e.practice.enter()
	e.physics = false
	e.run(e.config.practiceMaxSeconds - 5)
	eq(e.count("timeUp"), 0)
	e.run(10)
	eq(e.count("timeUp"), 1)
	e.run(5)
	eq(e.count("timeUp"), 1, "said once")
end)

H.test(
	"the way out: fade, take the yard apart, ask the server, give back the menus and the camera",
	function()
		local e = setup(true)
		e.practice.enter()
		e.key(Enum.KeyCode.W, true)
		e.run(0.5)
		local done = 0
		e.practice.leave(function()
			done += 1
		end)
		eq(done, 1, "done once the player is back")
		eq(e.practice.isActive(), false)
		eq(e.sent[#e.sent], "practiceExit")
		eq(e.fades[#e.fades], false)
		eq(e.yard(), nil, "no yard left in the world")
		eq(e.gui:FindFirstChild("TutorialPractice"), nil)
		eq(e.gui:FindFirstChild("SteerGui"), nil, "the stick is gone")
		for name, g in e.menus do
			eq(g.Enabled, true, name .. " is back")
		end
		eq(e.world.camera.CameraType, Enum.CameraType.Custom)
		eq(e.world.camera.FieldOfView, 70)
		eq(e.world.camera.CameraSubject, e.player.Character.Humanoid)
		-- no frame of the old practice is left running
		local events = #e.events
		e.run(0.5)
		eq(#e.events, events)
		-- and it can be entered again (a replay)
		e.practice.enter()
		eq(e.practice.isReady(), true)
		truthy(e.yard())
		eq(e.count("practiceFailed"), 0)
	end
)

H.test("a menu that was already hidden stays hidden after the drive", function()
	local e = setup(true)
	e.menus.CVC_ChampionsDim.Enabled = false
	e.practice.enter()
	e.practice.leave(nil)
	eq(e.menus.CVC_ChampionsDim.Enabled, false)
	eq(e.menus.CVC_Champions.Enabled, true)
end)

H.test("the server says no: nothing is built and the lesson goes on", function()
	local e = setup()
	e.enterAnswer = "practiceRefused"
	e.practice.enter()
	eq(e.practice.isActive(), false)
	eq(e.count("practiceFailed"), 1)
	eq(e.yard(), nil)
	eq(e.fades[1], nil, "the screen never went black")
	eq(table.concat(e.sent, ","), "practiceEnter", "nothing to bring back")
	for _, g in e.menus do
		eq(g.Enabled, true)
	end
end)

H.test(
	"the server never answers: after a few seconds the lesson goes on, and the player is asked back",
	function()
		local e = setup()
		e.enterAnswer = nil
		e.practice.enter()
		eq(e.practice.isActive(), true, "waiting")
		eq(e.count("practiceFailed"), 0)
		e.run(2)
		eq(e.count("practiceFailed"), 0)
		e.run(3)
		eq(e.count("practiceFailed"), 1)
		eq(e.practice.isActive(), false)
		eq(e.yard(), nil)
		eq(table.concat(e.sent, ","), "practiceEnter,practiceExit")
	end
)

H.test("a slow server still works: the yard comes up when the answer arrives", function()
	local e = setup()
	e.auto = false
	e.practice.enter()
	e.run(1)
	eq(e.practice.isReady(), false)
	eq(e.yard(), nil)
	e.practice.handleServer("practiceReady")
	e.run(0.2)
	eq(e.practice.isReady(), true)
	truthy(e.yard())
end)

H.test("SKIP while the yard is still coming: it goes straight back out", function()
	local e = setup()
	e.auto = false
	e.practice.enter()
	e.run(0.5)
	local done = 0
	e.practice.leave(function()
		done += 1
	end)
	eq(done, 0, "still entering")
	e.practice.handleServer("practiceReady")
	e.run(0.3) -- the yard comes up, then it leaves again
	e.practice.handleServer("practiceExited")
	e.run(0.5)
	eq(done, 1)
	eq(e.practice.isActive(), false)
	eq(e.yard(), nil)
end)

H.test("leaving when nothing is up just says done", function()
	local e = setup()
	local done = 0
	e.practice.leave(function()
		done += 1
	end)
	eq(done, 1)
	eq(#e.sent, 0)
end)

H.test(
	"the server brings the player back by itself (its safety timer): the practice ends",
	function()
		local e = setup()
		e.practice.enter()
		eq(e.practice.isReady(), true)
		e.practice.handleServer("practiceExited")
		e.run(0.5)
		eq(e.practice.isActive(), false)
		eq(e.count("practiceFailed"), 1)
		eq(e.yard(), nil)
		for _, g in e.menus do
			eq(g.Enabled, true)
		end
	end
)

H.test(
	"a broken frame three times in a row ends the practice instead of looping on errors",
	function()
		local e = setup()
		e.practice.enter()
		e.physics = false
		-- a camera that refuses to be moved: every frame of the practice fails
		local real = e.world.camera
		e.world.workspace.CurrentCamera = setmetatable({}, {
			__index = function(_, k)
				return real[k]
			end,
			__newindex = function(_, k, v)
				if k == "CFrame" then
					error("boom")
				end
				real[k] = v
			end,
		})
		e.run(0.5)
		eq(e.count("practiceBroken"), 1, "said once")
		-- the caller leaves
		e.practice.leave(nil)
		eq(e.yard(), nil)
	end
)

H.test("destroy takes everything down at any time", function()
	local e = setup()
	e.practice.enter()
	e.practice.destroy()
	eq(e.yard(), nil)
	eq(e.gui:FindFirstChild("TutorialPractice"), nil)
	eq(e.world.camera.CameraType, Enum.CameraType.Custom)
	for _, g in e.menus do
		eq(g.Enabled, true)
	end
	e.run(0.5)
end)
