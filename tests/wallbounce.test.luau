--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Wall bounce (BattleDrive)")

local DT = 1 / 60

local function setup()
	local world = Mock.new()
	world.quiet = true
	local Drive = world.require("shared/BattleDrive")
	local Config = world.require("shared/BattleConfig")
	return world, Drive, Config
end

-- a car body 8 wide, 6 tall, 16 long that drives along +x
local function newCar(world, vx, vz)
	local model = world.instance("Model")
	local body = world.instance("Part")
	body.Size = Vector3.new(8, 6, 16)
	body.Position = Vector3.new(0, 4, 0)
	body.AssemblyLinearVelocity = Vector3.new(vx, 0, vz or 0)
	body.Parent = model
	return {
		body = body,
		model = model,
		L = 16,
		stagger = 0,
		slide = Vector3.new(0, 0, 0),
		lastForward = Vector3.new(1, 0, 0),
		momentum = false,
	}
end

local function wall(world, tags, elasticity)
	local p = world.instance("Part")
	for _, t in tags do
		p:AddTag(t)
	end
	p.CustomPhysicalProperties = { Elasticity = elasticity }
	return p
end

local function hitOf(inst, nx, nz)
	return { Instance = inst, Normal = Vector3.new(nx, 0, nz), Position = Vector3.new(6, 4, 0) }
end

H.test("a car at full speed hits a bouncy wall: it flies back as fast, with a hop", function()
	local world, Drive, Config = setup()
	local top = Config.Human.topSpeed
	local car = newCar(world, top)
	local w = wall(world, { "Bouncy" }, 1)
	world.workspace.Blockcast = function()
		return hitOf(w, -1, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT))
	local v = car.body.AssemblyLinearVelocity
	near(v.X, -top * Config.Human.bounceKeep * 1, 1e-6)
	near(v.Y, Config.Human.bounceHop, 1e-6)
	near(car.stagger, Config.Human.bounceStagger, 1e-9)
	near(car.slide.X, v.X, 1e-6)
	-- a bigger bounce than the old 0.85 of a 0.9 wall
	truthy(math.abs(v.X) > 0.85 * 0.9 * top + 1, "bigger than before")
end)

H.test("the bounce numbers are a real step up from the old ones, without gaining speed", function()
	local _, _, Config = setup()
	local H2 = Config.Human
	truthy(H2.bounceKeep > 0.85 and H2.bounceKeep <= 1, "keeps more, never more than it had")
	truthy(H2.bounceStagger > 0.6 and H2.bounceStagger <= 1, "a longer wobble, not a long lock")
	truthy(H2.bounceFriction > 0 and H2.bounceFriction < Config.Move.knockFriction, "slows gently")
	truthy(H2.bounceHop > 0 and H2.bounceHop <= 30, "a small hop")
end)

H.test("a full-speed head-on hit throws the car back about a car length and a half", function()
	-- a driven Studio test: 1 / 0.75 s / friction 2.2 threw it back 6 to 9 studs in half a second
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed)
	local w = wall(world, { "Bouncy" }, 1)
	world.workspace.Blockcast = function()
		return hitOf(w, -1, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT))
	local back, seconds, steps = 0, 0, 0
	while Drive.knockedStep(car, car.body.AssemblyLinearVelocity, DT) do
		back -= car.body.AssemblyLinearVelocity.X * DT
		seconds += DT
		steps += 1
		truthy(steps < 600, "the knock ends")
	end
	local lengths = back / car.L
	truthy(lengths > 1.4 and lengths < 2.2, `thrown back {lengths} car lengths`)
	near(seconds, Config.Human.bounceStagger, 2 * DT)
	eq(car.slide.Magnitude, 0, "the slide is over")
	truthy(
		math.abs(car.body.AssemblyLinearVelocity.X) < Config.Human.topSpeed,
		"back under top speed when control returns"
	)
end)

H.test("a crash knock still slows at the crash rate: only a wall slide is gentler", function()
	local world, Drive, Config = setup()
	local car = newCar(world, 30)
	car.stagger = 0.5
	-- no slide: a shove from a crash
	truthy(Drive.knockedStep(car, car.body.AssemblyLinearVelocity, DT))
	near(car.body.AssemblyLinearVelocity.X, 30 * (1 - Config.Move.knockFriction * DT), 1e-9)
end)

H.test("a glancing hit reflects about the wall's face", function()
	local world, Drive, Config = setup()
	local top = Config.Human.topSpeed
	local car = newCar(world, top * 0.7071, top * 0.7071)
	local w = wall(world, { "Bouncy" }, 1)
	world.workspace.Blockcast = function()
		return hitOf(w, -1, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT))
	local v = car.body.AssemblyLinearVelocity
	truthy(v.X < 0, "pushed back off the face")
	near(v.Z, top * 0.7071 * Config.Human.bounceKeep, 1e-6) -- along the wall: unchanged
end)

H.test("a slow car only bumps: no bounce under 30% of top speed", function()
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed * 0.25)
	local w = wall(world, { "Bouncy" }, 1)
	world.workspace.Blockcast = function()
		return hitOf(w, -1, 0)
	end
	eq(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT), false)
	eq(car.stagger, 0)
end)

H.test("a part that is not tagged Bouncy does not bounce the car", function()
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed)
	local plain = wall(world, {}, 1)
	world.workspace.Blockcast = function()
		return hitOf(plain, -1, 0)
	end
	eq(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT), false)
end)

H.test("the bowl's slope is looked past: the wall behind it still bounces the car", function()
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed)
	local slope = wall(world, { "BowlSlope" }, 0.5)
	local tire = wall(world, { "Bouncy" }, 1)
	local casts = 0
	world.workspace.Blockcast = function(_self, _cf, _size, _dir, params)
		casts += 1
		for _, skipped in params.FilterDescendantsInstances or {} do
			if skipped == slope then
				return hitOf(tire, -1, 0)
			end
		end
		return hitOf(slope, -0.2, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT), "bounced off the wall")
	eq(casts, 2, "one sweep, then one past the slope")
	truthy(car.body.AssemblyLinearVelocity.X < 0)
end)

H.test("only the slope in front and nothing behind it: no bounce, the car drives up", function()
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed)
	local slope = wall(world, { "BowlSlope" }, 0.5)
	world.workspace.Blockcast = function(_self, _cf, _size, _dir, params)
		for _, skipped in params.FilterDescendantsInstances or {} do
			if skipped == slope then
				return nil
			end
		end
		return hitOf(slope, -0.2, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	eq(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT), false)
	eq(car.stagger, 0)
	near(car.body.AssemblyLinearVelocity.X, Config.Human.topSpeed, 1e-9)
end)

H.test("two slope wedges in a row are both looked past", function()
	local world, Drive, Config = setup()
	local car = newCar(world, Config.Human.topSpeed)
	local s1 = wall(world, { "BowlSlope" }, 0.5)
	local s2 = wall(world, { "BowlSlope" }, 0.5)
	local tire = wall(world, { "Bouncy" }, 1)
	world.workspace.Blockcast = function(_self, _cf, _size, _dir, params)
		local skipped1, skipped2 = false, false
		for _, x in params.FilterDescendantsInstances or {} do
			skipped1 = skipped1 or x == s1
			skipped2 = skipped2 or x == s2
		end
		if not skipped1 then
			return hitOf(s1, -0.2, 0)
		elseif not skipped2 then
			return hitOf(s2, -0.2, 0)
		end
		return hitOf(tire, -1, 0)
	end
	world.workspace.Raycast = function()
		return nil
	end
	truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT))
end)

H.test(
	"a car already touching the wall (the sweep starts inside it) is caught by the ray",
	function()
		local world, Drive, Config = setup()
		local car = newCar(world, Config.Human.topSpeed)
		local w = wall(world, { "Bouncy" }, 1)
		world.workspace.Blockcast = function()
			return nil
		end
		world.workspace.Raycast = function()
			return hitOf(w, -1, 0)
		end
		truthy(Drive.wallBounce(car, car.body.AssemblyLinearVelocity, DT))
	end
)
