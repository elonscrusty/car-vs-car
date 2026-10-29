--!strict
-- Car VS Car SMASH weapons (shared/Weapons + server/weapons/Flight): aim checks, ammo and
-- cooldown, the fire remote's rate limit, rocket and nuke flight, hits, misses, walls, booms.
local H = require("./harness")
local Weapons = require("../src/shared/Weapons")
local Flight = require("../src/server/weapons/Flight")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Weapons")

local v = vector.create
-- test spots were drawn with a kart about 6 units long; at() turns them into real RC studs
local U = Weapons.KART / 6
local function at(x: number, y: number, z: number): Vector3
	return v(x * U, y * U, z * U)
end
local AHEAD = v(0, 0, -1)

test("aim: junk from a client means straight ahead", function()
	for _, junk in
		{ nil, "left", 5, true, {}, v(0 / 0, 0, 1), v(math.huge, 0, 0), v(0, 0, 0), v(0, 5, 0) } :: { any }
	do
		eq(Weapons.aim(junk, AHEAD), AHEAD)
	end
end)

test("aim: a small turn is kept, flattened; a big one stops at the limit", function()
	local a = Weapons.aim(v(0.2, 3, -1), AHEAD)
	near(a.y, 0)
	near(vector.magnitude(a), 1)
	truthy(a.x > 0)
	-- straight back is turned to exactly MAX_AIM_DEG off ahead
	local back = Weapons.aim(v(1, 0, 1), AHEAD)
	near(math.deg(math.acos(vector.dot(back, AHEAD))), Weapons.MAX_AIM_DEG, 1e-3)
	truthy(back.x > 0) -- toward the side it asked for
	local back2 = Weapons.aim(v(-1, 0, 1), AHEAD)
	truthy(back2.x < 0)
end)

test("give: only real weapons; a pickup replaces the old weapon with full ammo", function()
	local h = Weapons.held()
	eq(Weapons.give(h, "Banana"), false)
	eq(Weapons.give(h, nil), false)
	eq(h.name, "")
	truthy(Weapons.give(h, "Nuke"))
	eq(h.ammo, Weapons.DEFS.Nuke.ammo)
	truthy(Weapons.give(h, "Rockets"))
	eq(h.name, "Rockets")
	eq(h.ammo, 3)
end)

test("take: ammo runs out, the cooldown holds shots back, empty hands fire nothing", function()
	local h = Weapons.held()
	eq(Weapons.take(h, 0), nil)
	Weapons.give(h, "Rockets")
	eq(Weapons.take(h, 10), "Rockets")
	eq(Weapons.take(h, 10.1), nil) -- cooldown 0.6
	eq(h.ammo, 2)
	eq(Weapons.take(h, 10.6), "Rockets")
	eq(Weapons.take(h, 11.2), "Rockets")
	eq(h.ammo, 0)
	eq(h.name, "")
	eq(Weapons.take(h, 20), nil)
end)

test("rate limit: a burst of 6 asks, then about 8 a second", function()
	local b = Weapons.bucket(0)
	local ok = 0
	for _ = 1, 50 do
		if Weapons.allow(b, 0) then
			ok += 1
		end
	end
	eq(ok, Weapons.BURST)
	ok = 0
	for i = 1, 100 do
		if Weapons.allow(b, i * 0.01) then -- 100 asks in 1 s
			ok += 1
		end
	end
	truthy(ok >= 7 and ok <= 9)
	-- a clock that jumps back doesn't refill it
	eq(Weapons.allow(b, -100), false)
end)

-- fly a shot until something happens (or 6 s)
local function fly(r: Weapons.Rocket, targets: { Weapons.Target }, wall: number?): (string?, any?)
	local blocked = if wall
		then function(from: Vector3, to: Vector3): Vector3?
			if to.z <= wall and from.z > wall then
				return v(to.x, to.y, wall)
			end
			return nil
		end
		else nil
	for _ = 1, 360 do
		local what, who = Weapons.step(r, 1 / 60, targets, blocked)
		if what then
			return what, who
		end
	end
	return nil, nil
end

test("rocket: hits the kart ahead, never its owner", function()
	local r = Weapons.rocket("me", v(0, 0, 0), AHEAD)
	local what, who =
		fly(r, { { id = "me", pos = v(0, 0, 0) }, { id = "bot", pos = v(0, 0, -60) } })
	eq(what, "hit")
	eq(who, "bot")
	truthy(r.pos.z > -60 + Weapons.ROCKET.hitRadius + 1 - 2)
end)

test("rocket: bends toward a kart a little off line, but not one far to the side", function()
	local r = Weapons.rocket("me", v(0, 0, 0), AHEAD)
	local what, who = fly(r, { { id = "bot", pos = at(25, 0, -100) } })
	eq(what, "hit")
	eq(who, "bot")
	local r2 = Weapons.rocket("me", v(0, 0, 0), AHEAD)
	local what2 = fly(r2, { { id = "bot", pos = at(80, 0, -20) } })
	eq(what2, "gone") -- a miss: it flew on and blew up at the end
end)

test("aim help: cone picks the nearest live, unshielded kart ahead, never the shooter", function()
	local K = Weapons.KART
	local me = v(0, 0, 0)
	local function pick(list, deg, range)
		local t = Weapons.cone(me, AHEAD, list, deg or 35, range or 20 * K, "me")
		return t and t.id
	end
	-- nearest of two ahead
	eq(
		pick({ { id = "far", pos = v(0, 0, -10 * K) }, { id = "near", pos = v(2 * K, 0, -5 * K) } }),
		"near"
	)
	-- the shooter itself, a dead kart and a shielded kart are never picked
	eq(pick({ { id = "me", pos = v(0, 0, -2 * K) } }), nil)
	eq(pick({ { id = "dead", pos = v(0, 0, -3 * K), alive = false } }), nil)
	eq(
		pick({
			{ id = "shield", pos = v(0, 0, -3 * K), shield = true },
			{ id = "ok", pos = v(0, 0, -9 * K) },
		}),
		"ok"
	)
	-- 30 degrees off: in a 35 cone, not a 25 one; 40 off: out
	local a30 = v(math.sin(math.rad(30)) * 8 * K, 0, -math.cos(math.rad(30)) * 8 * K)
	local a40 = v(math.sin(math.rad(40)) * 8 * K, 0, -math.cos(math.rad(40)) * 8 * K)
	eq(pick({ { id = "a", pos = a30 } }), "a")
	eq(pick({ { id = "a", pos = a30 } }, 25), nil)
	eq(pick({ { id = "b", pos = a40 } }), nil)
	-- height doesn't count (flat angle); range does
	eq(pick({ { id = "up", pos = v(0, 4 * K, -6 * K) } }), "up")
	eq(pick({ { id = "far", pos = v(0, 0, -21 * K) } }), nil)
	-- junk aim: nobody
	eq(Weapons.cone(me, v(0, 1, 0), { { id = "x", pos = v(0, 0, -K) } }, 35, 20 * K), nil)
end)

test(
	"aim help: a rocket locks on at fire, leaves straight at the kart and follows its dodge",
	function()
		local K = Weapons.KART
		local bot = {
			id = "bot",
			pos = v(math.sin(math.rad(30)) * 10 * K, 0, -math.cos(math.rad(30)) * 10 * K),
		}
		local r = Weapons.rocket("me", v(0, 0, 0), AHEAD, Weapons.ROCKET, { bot })
		eq(r.target, "bot")
		near(vector.dot(r.dir, vector.normalize(bot.pos)), 1)
		-- the bot swerves sideways at top speed (17 karts a second): still caught
		local what, who
		for _ = 1, 360 do
			bot.pos += v(17 * K / 60, 0, 0)
			what, who = Weapons.step(r, 1 / 60, { bot })
			if what then
				break
			end
		end
		eq(what, "hit")
		eq(who, "bot")
		-- a cheat aiming at the 30 degree edge can't lock a kart 60 degrees off its nose and leave
		-- straight at it: the launch stays within MAX_AIM_DEG of the nose
		local edge = v(math.sin(math.rad(30)), 0, -math.cos(math.rad(30)))
		local wide = {
			id = "wide",
			pos = v(math.sin(math.rad(60)) * 8 * K, 0, -math.cos(math.rad(60)) * 8 * K),
		}
		local r3 = Weapons.rocket("me", v(0, 0, 0), edge, Weapons.ROCKET, { wide }, AHEAD)
		truthy(vector.dot(r3.dir, AHEAD) >= math.cos(math.rad(Weapons.MAX_AIM_DEG)) - 1e-6)
		-- nobody in the cone: straight on as aimed
		local r2 = Weapons.rocket(
			"me",
			v(0, 0, 0),
			AHEAD,
			Weapons.ROCKET,
			{ { id = "side", pos = v(10 * K, 0, 0) } }
		)
		eq(r2.target, nil)
		near(r2.dir.z, -1)
	end
)

test("rocket: a wall stops it before the kart behind the wall", function()
	local r = Weapons.rocket("me", v(0, 0, 0), AHEAD)
	local what, who = fly(r, { { id = "bot", pos = at(0, 0, -80) } }, -40 * U)
	eq(what, "wall")
	eq(who, nil)
	near(r.pos.z, -40 * U)
end)

test("rocket: a miss ends after its flight time", function()
	local r = Weapons.rocket("me", v(0, 0, 0), AHEAD)
	eq((fly(r, {})), "gone")
	near(r.age, Weapons.ROCKET.life, 0.05)
end)

test(
	"boom: direct hit takes full damage, close karts a splash, far ones and the owner nothing",
	function()
		local list = {
			{ id = "me", pos = v(0, 0, 0) },
			{ id = "hit", pos = at(0, 0, -50) },
			{ id = "near", pos = at(6, 0, -50) },
			{ id = "far", pos = at(40, 0, -50) },
		}
		local got = {}
		for _, d in Weapons.boom(at(0, 0, -50), list, "me", "hit") do
			got[d.id] = d.damage
		end
		eq(got.hit, Weapons.ROCKET.damage)
		truthy(got.near and got.near > 0 and got.near < Weapons.ROCKET.splashDamage)
		eq(got.far, nil)
		eq(got.me, nil)
	end
)

test("nuke: slow and big; one boom smashes a crowd of karts", function()
	truthy(Weapons.NUKE.speed < Weapons.ROCKET.speed)
	truthy(Weapons.NUKE.splash >= Weapons.ROCKET.splash * 2)
	local crowd = {}
	for i = 1, 5 do
		table.insert(crowd, { id = i, pos = at((i - 3) * 5, 0, -70) })
	end
	local r = Weapons.rocket("me", v(0, 0, 0), AHEAD, Weapons.NUKE)
	local what, who = fly(r, crowd)
	eq(what, "hit")
	local smashed = 0
	for _, d in Weapons.boom(r.pos, crowd, "me", who, Weapons.NUKE) do
		if d.damage >= 75 then
			smashed += 1
		end
	end
	truthy(smashed >= 4)
end)

test("every weapon in NAMES has a def; every flying one a flight", function()
	for _, name in Weapons.NAMES do
		truthy(Weapons.DEFS[name])
	end
	truthy(Weapons.FLIGHTS.Rockets and Weapons.FLIGHTS.Nuke)
end)

-- a pretend server for the flying weapons: karts as points, a clock, a log of damage and fx
local function fakeCtx(karts: { any })
	local c = { t = 0, hurt = {}, sent = {} }
	function c.now()
		return c.t
	end
	function c.karts()
		return karts
	end
	function c.raycast()
		return nil
	end
	function c.damage(victim: any, attacker: any, amount: number, weapon: string)
		table.insert(
			c.hurt,
			{ victim = victim, attacker = attacker, amount = amount, weapon = weapon }
		)
	end
	function c.fx(kind: string, data: any)
		table.insert(c.sent, { kind = kind, data = data })
	end
	return c
end

local function kart(id: any, x: number, z: number, alive: boolean?)
	return {
		id = id,
		cframe = { Position = at(x, 0, z), LookVector = AHEAD },
		alive = alive ~= false,
	}
end

test("server rockets: fire, fly, hit, damage goes to the match with who and what", function()
	local Rockets = Flight.weapon("Rockets", Weapons)
	local me, bot = kart(1, 0, 0), kart(-1, 0, -60)
	local ctx = fakeCtx({ me, bot })
	truthy(Rockets.fire(me, AHEAD, ctx))
	eq(Flight.count("Rockets"), 1)
	eq(ctx.sent[1].kind, "RocketLaunch")
	for _ = 1, 120 do
		ctx.t += 1 / 60
		Rockets.step(ctx, 1 / 60)
	end
	eq(Flight.count("Rockets"), 0)
	eq(#ctx.hurt, 1)
	eq(ctx.hurt[1].victim, -1)
	eq(ctx.hurt[1].attacker, 1)
	eq(ctx.hurt[1].amount, Weapons.ROCKET.damage)
	eq(ctx.hurt[1].weapon, "Rockets")
	eq(ctx.sent[#ctx.sent].kind, "RocketBoom")
	-- the boom says who the server really hurt and by how much, for the client's flash and "-N"
	local hurt = ctx.sent[#ctx.sent].data.hurt
	eq(#hurt, 1)
	eq(hurt[1].id, -1)
	eq(hurt[1].damage, Weapons.ROCKET.damage)
end)

test(
	"server rockets: a kart the match didn't hurt (shield) is left out of the boom's hurt list",
	function()
		local Rockets = Flight.weapon("Rockets", Weapons)
		local me, bot = kart(1, 0, 0), kart(-1, 0, -60)
		local ctx = fakeCtx({ me, bot })
		function ctx.damage()
			return 0
		end
		truthy(Rockets.fire(me, AHEAD, ctx))
		for _ = 1, 120 do
			ctx.t += 1 / 60
			Rockets.step(ctx, 1 / 60)
		end
		local last = ctx.sent[#ctx.sent]
		eq(last.kind, "RocketBoom")
		eq(last.data.hit, -1)
		eq(#last.data.hurt, 0)
	end
)

test(
	"server rockets: nose against a wall, the shot booms there and never comes out the far side",
	function()
		local Rockets = Flight.weapon("Rockets", Weapons)
		local me, bot = kart(1, 0, 0), kart(-1, 0, -60)
		local ctx = fakeCtx({ me, bot })
		local wall = at(0, 0, -2)
		function ctx.raycast(from: Vector3, to: Vector3)
			-- a wall across z = -2 (in test units)
			if from.z > wall.z and to.z <= wall.z then
				return { position = vector.create(to.x, to.y, wall.z) }
			end
			return nil
		end
		truthy(Rockets.fire(me, AHEAD, ctx))
		ctx.t += 1 / 60
		Rockets.step(ctx, 1 / 60)
		eq(Flight.count("Rockets"), 0)
		local last = ctx.sent[#ctx.sent]
		eq(last.kind, "RocketBoom")
		truthy(last.data.pos.z > wall.z)
		eq(#ctx.hurt, 0)
	end
)

test(
	"server rockets: a smashed kart can't be hit; a long hitch can't tunnel through a kart",
	function()
		local Rockets = Flight.weapon("Rockets", Weapons)
		local me, dead, bot = kart(1, 0, 0), kart(-1, 0, -30, false), kart(-2, 0, -60)
		local ctx = fakeCtx({ me, dead, bot })
		Rockets.fire(me, AHEAD, ctx)
		Rockets.step(ctx, 5) -- one huge step (moves at most MAX_DT, in small bits)
		for _ = 1, 60 do
			Rockets.step(ctx, 1 / 30)
		end
		eq(#ctx.hurt, 1)
		eq(ctx.hurt[1].victim, -2)
	end
)

test("server nuke: one boom hurts every kart around; match end clears shots quietly", function()
	local Nuke = Flight.weapon("Nuke", Weapons)
	local list = { kart(1, 0, 0) }
	for i = 1, 4 do
		table.insert(list, kart(-i, (i - 2.5) * 6, -80))
	end
	local ctx = fakeCtx(list)
	truthy(Nuke.fire(list[1], AHEAD, ctx))
	for _ = 1, 240 do
		Nuke.step(ctx, 1 / 60)
	end
	eq(#ctx.hurt, 4)
	-- clear: nothing left, no damage
	Nuke.fire(list[1], AHEAD, ctx)
	local before = #ctx.hurt
	Nuke.clear(ctx)
	eq(Flight.count(), 0)
	eq(#ctx.hurt, before)
	truthy(ctx.sent[#ctx.sent].data.quiet)
end)

test("server: at most MAX_FLYING shots in the air at once", function()
	local Rockets = Flight.weapon("Rockets", Weapons)
	local me = kart(1, 0, 0)
	local ctx = fakeCtx({ me })
	local ok = 0
	for _ = 1, Flight.MAX_FLYING + 10 do
		if Rockets.fire(me, AHEAD, ctx) then
			ok += 1
		end
	end
	eq(ok, Flight.MAX_FLYING)
	Rockets.clear(ctx)
	eq(Flight.count(), 0)
end)

test("rockets: 3 direct hits smash a full-health kart, 2 don't", function()
	truthy(Weapons.ROCKET.damage * 3 >= 100)
	truthy(Weapons.ROCKET.damage * 2 < 100)
	truthy(Weapons.NUKE.damage >= 100)
end)

test(
	"get and feed words: real weapons only; MatchRunner gets lowercase one-of-a-kind words",
	function()
		eq(Weapons.get("Banana"), nil)
		eq(Weapons.get("Rockets"), Weapons.DEFS.Rockets)
		eq(Weapons.feedWord("Rockets"), "rocket")
		eq(Weapons.feedWord("Nuke"), "nuke")
		eq(Weapons.feedWord("Gun"), "machine gun")
		eq(Weapons.feedWord("Freeze"), "freeze ray")
		eq(Weapons.feedWord("Zap"), "zap")
	end
)

test("sizes fit the RC-scale arena: measured in kart lengths", function()
	local K = Weapons.KART
	near(K, 5.5 * 0.25)
	for _, f in { Weapons.ROCKET, Weapons.NUKE } do
		truthy(f.hitRadius >= 0.5 * K and f.hitRadius <= 1.5 * K)
		truthy(f.ahead > 0.5 * K and f.ahead <= 1.5 * K) -- leaves from its own kart's nose
		truthy(f.speed * f.life >= 50 * K) -- reaches most of the way across (about 65 karts)
	end
	-- a rocket outruns a kart (the arena's top speed, about 14 karts a second); the nuke can be outrun
	local top = 95 * 0.25 * require("../src/shared/Match").SPEED_SCALE -- (Tuning.topSpeed at RC size)
	truthy(Weapons.ROCKET.speed > top)
	truthy(Weapons.NUKE.speed < top * 0.95, "a kart at full speed gets away from the nuke")
	truthy(Weapons.ROCKET.splash <= 3 * K)
	truthy(Weapons.NUKE.splash >= 6 * K and Weapons.NUKE.splash <= 65 * K / 6)
end)
