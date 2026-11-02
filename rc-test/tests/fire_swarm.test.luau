--!nocheck
-- FIRE SWARM, the special move (shared/FireSwarm, server/weapons/Swarm). A pretend ctx stands in
-- for WeaponServer, like tests/gunmine: karts are plain tables, after() queues calls run(dt) plays.

local H = require("./harness")
local Weapons = require("../src/shared/Weapons")
local Data = require("../src/shared/FireSwarm")
local Swarm = require("../src/server/weapons/Swarm")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

local function v(x, y, z)
	return vector.create(x, y, z)
end

local function kart(id, x, z, shield)
	return {
		id = id,
		alive = true,
		shield = shield == true,
		cframe = { Position = v(x, 0, z), LookVector = v(0, 0, -1) },
	}
end

local function world(karts)
	local w = { t = 0, karts = karts, hits = {}, fxs = {}, queue = {} }
	local ctx = {}
	function ctx.now()
		return w.t
	end
	function ctx.karts()
		return w.karts
	end
	function ctx.getKart(id)
		for _, k in w.karts do
			if k.id == id then
				return k
			end
		end
		return nil
	end
	function ctx.damage(victim, attacker, amount, weapon)
		local k = ctx.getKart(victim)
		if k and k.shield then
			return 0 -- (the real ctx: a shield takes nothing)
		end
		table.insert(
			w.hits,
			{ victim = victim, attacker = attacker, amount = amount, weapon = weapon }
		)
		return amount
	end
	function ctx.fx(kind, data)
		table.insert(w.fxs, { kind = kind, data = data })
	end
	function ctx.after(s, fn)
		table.insert(w.queue, { at = w.t + s, fn = fn })
	end
	function w.run(dt)
		w.t += dt
		local i = 1
		while i <= #w.queue do
			local q = w.queue[i]
			if q.at <= w.t then
				table.remove(w.queue, i)
				q.fn()
			else
				i += 1
			end
		end
	end
	function w.count(kind)
		local n = 0
		for _, f in w.fxs do
			if f.kind == kind then
				n += 1
			end
		end
		return n
	end
	function w.total(victim)
		local n = 0
		for _, h in w.hits do
			if h.victim == victim then
				n += h.amount
			end
		end
		return n
	end
	w.ctx = ctx
	return w
end

local AHEAD = v(0, 0, -1)
local K = Weapons.KART

local function total()
	return Data.boomTime(Data.COUNT - 1) + 0.1
end

test("fire swarm: 4 rockets, 4 dives and 4 booms, the locked kart takes 4 direct hits", function()
	local me, foe = kart(1, 0, 0), kart(2, 0, -8 * K)
	local w = world({ me, foe })
	local S = Swarm.weapon(Weapons, Data)
	truthy(S.fire(me, AHEAD, w.ctx))
	eq(w.count("SwarmLaunch"), 1)
	eq(w.fxs[1].data.target, 2, "locked onto the kart ahead")
	for _ = 1, 100 do
		w.run(0.02)
	end
	eq(w.count("SwarmDive"), Data.COUNT)
	eq(w.count("SwarmBoom"), Data.COUNT)
	eq(w.total(2), Data.SPEC.damage * Data.COUNT)
	eq(w.total(1), 0, "never the owner")
	eq(S.pending(), 0)
end)

test("fire swarm: it follows the kart to where it drives", function()
	local me, foe = kart(1, 0, 0), kart(2, 0, -8 * K)
	local w = world({ me, foe })
	local S = Swarm.weapon(Weapons, Data)
	S.fire(me, AHEAD, w.ctx)
	local t = 0
	while t < total() do
		w.run(0.02)
		t += 0.02
		foe.cframe = { Position = v(3 * K * t, 0, -8 * K), LookVector = AHEAD }
	end
	local boom
	for _, f in w.fxs do
		if f.kind == "SwarmBoom" then
			boom = f.data.pos
		end
	end
	truthy(boom.x > 0.5 * K, "the last boom landed where the kart had driven to")
end)

test("fire swarm: a kart that is not where the boom is takes only splash", function()
	local me, foe, near2 = kart(1, 0, 0), kart(2, 0, -8 * K), kart(3, 1.2 * K, -8 * K)
	local w = world({ me, foe, near2 })
	local S = Swarm.weapon(Weapons, Data)
	S.fire(me, AHEAD, w.ctx)
	for _ = 1, 100 do
		w.run(0.02)
	end
	truthy(w.total(3) > 0 and w.total(3) < w.total(2), "splash is less than a direct hit")
end)

test("fire swarm: a shielded kart takes nothing", function()
	local me, foe = kart(1, 0, 0), kart(2, 0, -8 * K, true)
	local w = world({ me, foe })
	local S = Swarm.weapon(Weapons, Data)
	S.fire(me, AHEAD, w.ctx)
	eq(w.fxs[1].data.target, nil, "a shielded kart is not locked")
	for _ = 1, 100 do
		w.run(0.02)
	end
	eq(w.total(2), 0)
end)

test("fire swarm: nobody ahead, it lands BLIND karts in front", function()
	local me = kart(1, 0, 0)
	local w = world({ me })
	local S = Swarm.weapon(Weapons, Data)
	truthy(S.fire(me, AHEAD, w.ctx))
	near(w.fxs[1].data.to.z, -Data.BLIND, 1e-6)
	for _ = 1, 100 do
		w.run(0.02)
	end
	eq(w.count("SwarmBoom"), Data.COUNT)
	eq(#w.hits, 0)
end)

test("fire swarm: at most MAX_PENDING rockets at once, and a match ending cancels them", function()
	local me = kart(1, 0, 0)
	local w = world({ me })
	local S = Swarm.weapon(Weapons, Data)
	local went = 0
	for _ = 1, 5 do
		if S.fire(me, AHEAD, w.ctx) then
			went += 1
		end
	end
	eq(went, Data.MAX_PENDING // Data.COUNT)
	S.clear(w.ctx)
	eq(S.pending(), 0)
	for _ = 1, 100 do
		w.run(0.02)
	end
	eq(w.count("SwarmBoom"), 0, "nothing booms after the match ended")
	eq(w.count("SwarmClear"), 1)
end)

test("fire swarm: a smashed target means a boom where it was, no damage", function()
	local me, foe = kart(1, 0, 0), kart(2, 0, -8 * K)
	local w = world({ me, foe })
	local S = Swarm.weapon(Weapons, Data)
	S.fire(me, AHEAD, w.ctx)
	foe.alive = false
	for _ = 1, 100 do
		w.run(0.02)
	end
	eq(w.count("SwarmBoom"), Data.COUNT)
	eq(#w.hits, 0)
end)

test("fire swarm: the refill meter and charge boxes", function()
	eq(Data.fill(100 + Data.REFILL, 100), 0, "just fired: empty")
	near(Data.fill(100 + Data.REFILL / 2, 100), 0.5, 1e-9)
	eq(Data.fill(90, 100), 1, "ready")
	eq(Data.fill(nil, 100), 0)
	eq(Data.fill(0 / 0, 100), 0)
	near(Data.charged(130, 100, 1 / 3), 130 - Data.REFILL / 3, 1e-9)
	eq(Data.charged(105, 100, 1), 100, "never before now")
	eq(Data.charged(130, 100, -1), 130)
	truthy(Data.boomTime(0) < Data.boomTime(Data.COUNT - 1))
end)

test("fire swarm: the numbers are RC size and the swarm is weaker than a nuke", function()
	truthy(Data.SPEC.damage * Data.COUNT < Weapons.NUKE.damage)
	truthy(Data.SPEC.splash < Weapons.ROCKET.splash)
	truthy(Data.LOCK_RANGE <= Weapons.KART * 35)
end)
