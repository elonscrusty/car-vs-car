--!strict
local Harness = require("./harness")
local Rules = require("../src/shared/SoccerBotRules")
local Config = require("../src/shared/SoccerBotConfig")
local Field = require("../src/shared/SoccerFieldConfig")
local BotLevels = require("../src/shared/BotLevels")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("SoccerBot")

local HALF = Field.length / 2

local function view(over: { [string]: any }): Rules.View
	local v: any = {
		now = 10,
		seed = 1,
		team = 1,
		isKeeper = false,
		x = -30,
		z = 0,
		fx = 1,
		fz = 0,
		speed = 0,
		maxSpeed = 60,
		bx = 0,
		bz = 0,
		bvx = 0,
		bvz = 0,
		hasRival = false,
		rx = 0,
		rz = 0,
		boostReady = true,
		specialReady = false,
		kind = "",
		radius = 0,
		level = BotLevels.get("hard"),
		useMoves = true,
	}
	for k, val in over do
		v[k] = val
	end
	return v :: Rules.View
end

-- Tiny car model: heading h, speed along the nose, steer turns it, gas pushes it.
type Sim = { x: number, z: number, h: number, speed: number }

local function simStep(s: Sim, c: Rules.Cmd, dt: number)
	s.h += c.steer * 3 * dt
	local target = c.throttle * 60
	s.speed += math.clamp(target - s.speed, -50 * dt, 50 * dt)
	s.x += math.cos(s.h) * s.speed * dt
	s.z += math.sin(s.h) * s.speed * dt
end

local function runSim(
	s: Sim,
	team: number,
	isKeeper: boolean,
	ball: { x: number, z: number },
	seconds: number,
	level: string
): (number, number, number)
	local mem = Rules.newMemory()
	local dt = 1 / 30
	local nearest, idleFrames, t = math.huge, 0, 0
	local lv = BotLevels.get(level)
	while t < seconds do
		local c = Rules.step(
			mem,
			view({
				now = 10 + t,
				team = team,
				isKeeper = isKeeper,
				x = s.x,
				z = s.z,
				fx = math.cos(s.h),
				fz = math.sin(s.h),
				speed = s.speed,
				bx = ball.x,
				bz = ball.z,
				level = lv,
				useMoves = false,
			}),
			dt
		)
		simStep(s, c, dt)
		s.x = math.clamp(s.x, -HALF, HALF)
		s.z = math.clamp(s.z, -Field.width / 2, Field.width / 2)
		local d = math.sqrt((s.x - ball.x) ^ 2 + (s.z - ball.z) ^ 2)
		nearest = math.min(nearest, d)
		if math.abs(s.speed) < 1 then
			idleFrames += 1
		end
		t += dt
	end
	return nearest, idleFrames * dt, s.speed
end

test("numbers make sense", function()
	truthy(Config.keeperHold < Field.keeperClearRadius)
	truthy(Config.detourSide > Config.detourClear)
	truthy(Config.reverseLook > 0 and Config.unstickSeconds > 0)
	truthy(Config.boostMinDist < Config.boostMaxDist)
end)

test("reversing: never toward the own goal mouth, free elsewhere", function()
	-- Team 1 defends -X. Nose toward +X means backing toward the own goal.
	truthy(Rules.reverseUnsafe(1, -HALF + 20, 0, 1, 0))
	truthy(Rules.reverseUnsafe(1, -HALF + 20, 5, 1, 0.1))
	-- Backing the other way, or too far from the goal line, or into a wall beside the mouth: fine.
	truthy(not Rules.reverseUnsafe(1, -HALF + 20, 0, -1, 0))
	truthy(not Rules.reverseUnsafe(1, 0, 0, 1, 0))
	truthy(not Rules.reverseUnsafe(1, -HALF + 20, 30, 1, 0))
	-- Team 2 mirrors it.
	truthy(Rules.reverseUnsafe(2, HALF - 20, 0, -1, 0))
	truthy(not Rules.reverseUnsafe(2, HALF - 20, 0, 1, 0))
end)

test("keeper holds its post while the ball is far, and stands still facing the ball", function()
	local c = Rules.step(
		Rules.newMemory(),
		view({ isKeeper = true, x = -HALF + Field.keeperDepth, z = 0, bx = 30, bz = 1 }),
		1 / 30
	)
	eq(c.throttle, 0)
	truthy(not c.boost and not c.special)
	-- Away from the post it drives back to it (not toward the ball).
	local c2 = Rules.step(
		Rules.newMemory(),
		view({ isKeeper = true, x = 10, z = 0, fx = -1, bx = 30 }),
		1 / 30
	)
	truthy(c2.throttle > 0)
	truthy(c2.tx < -HALF + 20)
end)

test("keeper never leaves its goal while the ball is up the field", function()
	local s: Sim = { x = 0, z = 20, h = 0.5, speed = 10 }
	local mem = Rules.newMemory()
	local worst = -math.huge
	for i = 1, 30 * 20 do
		local c = Rules.step(
			mem,
			view({
				now = 10 + i / 30,
				isKeeper = true,
				x = s.x,
				z = s.z,
				fx = math.cos(s.h),
				fz = math.sin(s.h),
				speed = s.speed,
				bx = 35,
				bz = -10,
				level = BotLevels.get("medium"),
			}),
			1 / 30
		)
		simStep(s, c, 1 / 30)
		if i > 30 * 12 then
			worst = math.max(worst, s.x)
		end
	end
	truthy(worst < -HALF + 25, "keeper should be back near its goal, x=" .. worst)
end)

test("keeper clears a ball close to its goal (drives out, no boost)", function()
	local c = Rules.step(
		Rules.newMemory(),
		view({ isKeeper = true, x = -HALF + 9, z = 0, bx = -HALF + 14, bz = 3 }),
		1 / 30
	)
	truthy(not c.boost)
	truthy(c.throttle > 0)
end)

test("chaser on the wrong side swings round the ball instead of through it", function()
	-- Team 1 attacks +X. Car is past the ball (closer to the enemy goal), nose toward the own side.
	local tx, tz = Rules.aim(view({ x = 20, z = 1, fx = -1, fz = 0, bx = 0, bz = 0 }))
	truthy(math.abs(tz) > Config.detourClear, "waypoint should sit beside the ball")
	truthy(tx > -Field.length)
	-- With a clear path behind the ball, it just goes to the staging point behind it.
	local ax, az = Rules.aim(view({ x = -40, z = 30, bx = 0, bz = 0 }))
	truthy(ax < 0)
	truthy(math.abs(az) < 3)
end)

test("chaser from anywhere reaches the ball without circling", function()
	local starts = {
		{ x = 20, z = 10, h = math.pi },
		{ x = -40, z = -25, h = 0 },
		{ x = 30, z = 25, h = 1.2 },
		{ x = -10, z = 0, h = math.pi },
	}
	for i, st in starts do
		local s: Sim = { x = st.x, z = st.z, h = st.h, speed = 0 }
		local near = runSim(s, 1, false, { x = 0, z = 0 }, 12, "medium")
		truthy(near < 9, "start " .. i .. " got no closer than " .. near)
	end
end)

test("chaser keeps moving: never stands still for long", function()
	local s: Sim = { x = 54, z = 30, h = 0, speed = 0 } -- nose into the corner
	local _, idle = runSim(s, 1, false, { x = 40, z = 30 }, 15, "easy")
	truthy(idle < 4, "idle seconds " .. idle)
end)

test("a stopped car far from the ball gets an unstick move, and not toward its own goal", function()
	local mem = Rules.newMemory()
	-- Backed against its own goal line, nose away: reversing would be fine (away from goal)...
	for i = 1, 60 do
		Rules.step(
			mem,
			view({
				now = 10 + i / 30,
				x = -HALF + 6,
				z = 30,
				fx = 1,
				fz = 0,
				bx = 0,
				bz = -30,
				speed = 0,
			}),
			1 / 30
		)
		if mem.unstick > 0 then
			break
		end
	end
	truthy(mem.unstick > 0, "unstick should start")
	-- ...but nose toward +X in front of the own goal mouth means backing into it: go forward instead.
	local mem2 = Rules.newMemory()
	for i = 1, 60 do
		Rules.step(
			mem2,
			view({
				now = 10 + i / 30,
				x = -HALF + 20,
				z = 0,
				fx = 1,
				fz = 0,
				bx = 5,
				bz = 40,
				speed = 0,
			}),
			1 / 30
		)
		if mem2.unstick > 0 then
			break
		end
	end
	truthy(mem2.unstick > 0)
	truthy(not mem2.unstickBack, "must not reverse into its own goal")
end)

test("no reversing into the own goal when the target is right behind", function()
	-- Car in front of its own goal facing +X; aim point just behind it (toward the goal).
	local c = Rules.step(
		Rules.newMemory(),
		view({ x = -HALF + 22, z = 0, fx = 1, fz = 0, bx = -HALF + 14, bz = 0, speed = 3 }),
		1 / 30
	)
	truthy(c.throttle >= 0, "throttle " .. c.throttle)
end)

test("boost: open lane and aimed at a far target", function()
	local c = Rules.step(Rules.newMemory(), view({ x = -50, z = 0, bx = 20, bz = 0 }), 1 / 30)
	truthy(c.boost)
end)

test(
	"boost: not with a rival in the lane, a wall close ahead, or pointing at the own goal",
	function()
		local blocked = Rules.step(
			Rules.newMemory(),
			view({ x = -50, z = 0, bx = 20, bz = 0, hasRival = true, rx = -20, rz = 3 }),
			1 / 30
		)
		truthy(not blocked.boost)
		local wall = Rules.step(Rules.newMemory(), view({ x = 40, z = 0, bx = 80, bz = 0 }), 1 / 30)
		truthy(not wall.boost)
		local own = Rules.step(
			Rules.newMemory(),
			view({ x = -10, z = 0, fx = -1, fz = 0, bx = -50, bz = 0, now = 10 }),
			1 / 30
		)
		truthy(not own.boost)
		-- Off the nose: no boost.
		local off = Rules.step(
			Rules.newMemory(),
			view({ x = -50, z = 0, fx = 0, fz = 1, bx = 20, bz = 0 }),
			1 / 30
		)
		truthy(not off.boost)
	end
)

test("boost: not when already fast, not for the keeper, not when on cooldown", function()
	truthy(not Rules.step(Rules.newMemory(), view({ x = -50, bx = 20, speed = 70 }), 1 / 30).boost)
	truthy(
		not Rules.step(Rules.newMemory(), view({ x = -50, bx = 20, isKeeper = true }), 1 / 30).boost
	)
	truthy(
		not Rules.step(Rules.newMemory(), view({ x = -50, bx = 20, boostReady = false }), 1 / 30).boost
	)
end)

test("useMoves = false or moveUse 0 means no boost and no ability", function()
	local off = Rules.step(
		Rules.newMemory(),
		view({ x = -50, bx = 20, useMoves = false, specialReady = true, kind = "dash" }),
		1 / 30
	)
	truthy(not off.boost and not off.special)
	local lv = table.clone(BotLevels.get("hard"))
	lv.moveUse = 0
	local none = Rules.step(
		Rules.newMemory(),
		view({ x = -50, bx = 20, level = lv, specialReady = true, kind = "dash" }),
		1 / 30
	)
	truthy(not none.boost and not none.special)
end)

test("move use follows the level: easy takes fewer chances than hard", function()
	local function count(level: string): number
		local n = 0
		for i = 1, 400 do
			local c = Rules.step(
				Rules.newMemory(),
				view({ now = i * Config.moveCheck, x = -50, bx = 20, level = BotLevels.get(level) }),
				1 / 30
			)
			if c.boost then
				n += 1
			end
		end
		return n
	end
	local e, h = count("easy"), count("hard")
	truthy(e < h, "easy " .. e .. " hard " .. h)
	truthy(h == 400)
end)

test("abilities fire where they fit the car's kind", function()
	local function fires(kind: string, over: { [string]: any }): boolean
		local base: { [string]: any } = { specialReady = true, kind = kind, radius = 20 }
		for k, val in over do
			base[k] = val
		end
		return Rules.step(Rules.newMemory(), view(base), 1 / 30).special
	end
	truthy(fires("dash", { x = -50, bx = 0 })) -- 50 studs, aimed, lane open
	truthy(not fires("dash", { x = -50, bx = 0, specialReady = false }))
	truthy(not fires("dash", { x = -10, bx = 0 })) -- too close
	truthy(fires("slam", { x = -5, bx = 0 })) -- ball inside reach
	truthy(not fires("slam", { x = -50, bx = 0 }))
	truthy(fires("ram", { x = -30, bx = 0 }))
	truthy(not fires("ram", { x = -30, bx = 0, fx = 0, fz = 1 }))
	truthy(fires("shield", { hasRival = true, rx = -20, rz = 5 }))
	truthy(not fires("shield", { hasRival = true, rx = 40, rz = 5 }))
	truthy(fires("magnet", { hasRival = true, rx = -40, rz = 0 })) -- rival 10 studs away, inside 0.35..0.95 of the radius
end)

test("aim points stay on the field", function()
	for _, bx in { -HALF - 20, 0, HALF + 20 } do
		for _, team in { 1, 2 } do
			local tx, tz = Rules.aim(view({ team = team, bx = bx, bz = 100, x = 0, z = 0 }))
			truthy(math.abs(tx) <= HALF and math.abs(tz) <= Field.width / 2)
		end
	end
end)
