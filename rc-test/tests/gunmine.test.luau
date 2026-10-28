--!nocheck
-- GUNMINE row: machine gun, mines and freeze (src/server/weapons). A pretend ctx stands in for
-- WeaponServer: karts are plain tables, walls are spans of x the ray can't cross, after() queues
-- calls that run(dt) plays later.

local H = require("./harness")
local Gun = require("../src/server/weapons/Gun")
local Mine = require("../src/server/weapons/Mine")
local Freeze = require("../src/server/weapons/Freeze")
local Weapons = require("../src/shared/Weapons")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

local function v(x, y, z)
	return vector.create(x, y, z)
end

-- a kart at (x, 0, z) facing -z (Roblox forward) unless `look` is given
local function kart(id, x, z, look)
	return {
		id = id,
		alive = true,
		cframe = { Position = v(x, 0, z), LookVector = look or v(0, 0, -1) },
	}
end

local function world(karts)
	local w = { t = 0, karts = karts, hits = {}, fxs = {}, queue = {}, walls = {}, frozen = {} }
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
	-- walls: a wall at z = wz blocks any ray that crosses it
	function ctx.raycast(from, to, _ignore)
		for _, wz in w.walls do
			if (from.z - wz) * (to.z - wz) < 0 then
				local t = (wz - from.z) / (to.z - from.z)
				return { kartId = nil, position = from + (to - from) * t }
			end
		end
		return nil
	end
	function ctx.damage(victim, attacker, amount, weapon)
		local h = { victim = victim, attacker = attacker, amount = amount, weapon = weapon }
		table.insert(w.hits, h)
	end
	function ctx.fx(kind, data)
		table.insert(w.fxs, { kind = kind, data = data })
	end
	function ctx.after(s, fn)
		table.insert(w.queue, { at = w.t + s, fn = fn })
	end
	function ctx.place(_kind, _at)
		return nil
	end
	function ctx.freeze(id, s)
		w.frozen[id] = s
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
	function w.total(victim, weapon)
		local n = 0
		for _, h in w.hits do
			if h.victim == victim and (weapon == nil or h.weapon == weapon) then
				n += h.amount
			end
		end
		return n
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
	w.ctx = ctx
	return w
end

local AHEAD = v(0, 0, -1)

-- ===== registry =====

test("gunmine: Gun, Mine and Freeze are weapons with the same numbers as their modules", function()
	for _, m in { Gun, Mine, Freeze } do
		local def = Weapons.DEFS[m.NAME]
		truthy(def, m.NAME .. " in Weapons.DEFS")
		truthy(table.find(Weapons.NAMES, m.NAME), m.NAME .. " in Weapons.NAMES")
		eq(m.ammo, def.ammo, m.NAME .. " ammo")
		eq(m.cooldown, def.cooldown, m.NAME .. " cooldown")
	end
end)

-- ===== RC scale (FINISH-JOBS SCALE rule: a kart is 5.5 big x RC_SCALE long) =====

test("gunmine: distances are RC size and make sense next to a kart", function()
	local TrackData = require("../src/shared/TrackData")
	local ArenaData = require("../src/shared/ArenaData")
	local kartLen = 5.5 * TrackData.RC_SCALE
	local arena = ArenaData.SIZE * TrackData.RC_SCALE
	for _, m in { Gun, Mine, Freeze } do
		eq(m.SCALE, TrackData.RC_SCALE, m.NAME .. " scale")
	end
	-- the gun and freeze reach far, but not across the whole arena
	for _, m in { Gun, Freeze } do
		truthy(m.RANGE >= 20 * kartLen and m.RANGE <= arena * 0.6, m.NAME .. " range")
		truthy(m.MUZZLE > kartLen / 2 and m.MUZZLE < kartLen, m.NAME .. " muzzle at the nose")
	end
	-- a mine lands clear of the tail, and a kart touching it (nose or side) sets it off
	truthy(Mine.BEHIND > kartLen / 2, "mine behind the tail")
	truthy(Mine.RADIUS > kartLen / 2 and Mine.RADIUS < kartLen * 1.5, "mine radius about a kart")
end)

-- ===== gun =====

test("gun: bullet damage adds up to exactly 34 per burst, all whole numbers", function()
	local sum = 0
	for i = 1, Gun.BULLETS do
		local d = Gun.bulletDamage(i)
		eq(d, math.floor(d), "whole")
		truthy(d > 0, "positive")
		sum += d
	end
	eq(sum, 34, "burst total")
end)

test("gun: a full burst on a kart ahead does 34 and three bursts smash", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
	truthy(Gun.fire(w.karts[1], AHEAD, w.ctx))
	eq(w.total(2, "Gun"), Gun.bulletDamage(1), "first bullet lands at once")
	w.run(1)
	eq(w.total(2, "Gun"), 34, "whole burst")
	eq(#w.fxs, Gun.BULLETS, "one tracer per bullet")
	for _, h in w.hits do
		eq(h.attacker, 1, "attacker")
	end
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	truthy(w.total(2) >= 100, "three bursts = smash")
end)

test("gun: aim help reaches a kart a little off to the side, not one far off", function()
	local w = world({ kart(1, 0, 0), kart(2, 2.5, -15), kart(3, 15, -5) })
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	eq(w.total(2), 34, "kart 9 degrees off is hit")
	eq(w.total(3), 0, "kart 72 degrees off is not")
end)

test("gun: never hits a kart behind, out of range, smashed, or the shooter", function()
	local behind = kart(2, 0, 7.5)
	local far = kart(3, 0, -(Gun.RANGE + 20))
	local dead = kart(4, 0, -5)
	dead.alive = false
	local w = world({ kart(1, 0, 0), behind, far, dead })
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	eq(#w.hits, 0, "no hits")
	eq(#w.fxs, Gun.BULLETS, "still shoots tracers")
end)

test("gun: a wall in between stops the bullets", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -12.5) })
	table.insert(w.walls, -6.25)
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	eq(#w.hits, 0, "blocked")
	near(w.fxs[1].data.to.z, -6.25, 1e-3, "tracer stops at the wall")
end)

test("gun: the burst stops when the shooter is smashed mid-burst", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -7.5) })
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.karts[1].alive = false
	w.run(1)
	eq(w.total(2), Gun.bulletDamage(1), "only the first bullet")
	eq(Gun.fire(w.karts[1], AHEAD, w.ctx), false, "a smashed kart can't fire")
end)

test("gun: the burst follows the kart as it turns", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10), kart(3, 10, 0) })
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	-- the kart turns to face +x (kart 3) before the rest of the burst
	w.karts[1].cframe = { Position = v(0, 0, 0), LookVector = v(1, 0, 0) }
	w.run(1)
	eq(w.total(2), Gun.bulletDamage(1), "first bullet on kart 2")
	eq(w.total(3), 34 - Gun.bulletDamage(1), "the rest on kart 3")
end)

test("gun: junk aim (zero or straight up) shoots straight ahead", function()
	for _, aim in { v(0, 0, 0), v(0, 1, 0), v(0 / 0, 0, 0) } do
		local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
		Gun.fire(w.karts[1], aim, w.ctx)
		w.run(1)
		eq(w.total(2), 34, "straight ahead")
	end
end)

test("gun: clear drops the rest of a burst still in the air", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	Gun.clear(w.ctx)
	w.run(1)
	eq(w.total(2), Gun.bulletDamage(1), "only the bullet before clear")
	Gun.fire(w.karts[1], AHEAD, w.ctx)
	w.run(1)
	eq(w.total(2), Gun.bulletDamage(1) + 34, "the next burst is whole")
end)

-- ===== mine =====

test("mine: drops behind the kart on the road", function()
	Mine.clear()
	local w = world({ kart(1, 0, 0) })
	truthy(Mine.fire(w.karts[1], AHEAD, w.ctx))
	local m = Mine.live()[1]
	near(m.position.z, Mine.BEHIND, 1e-6, "behind (+z when facing -z)")
	near(m.position.y, -Mine.DROP, 1e-6, "on the road")
	near(m.position.x, 0, 1e-6, "in line")
end)

test("mine: not armed for 0.5 s, then the next kart over it takes 34", function()
	Mine.clear()
	local other = kart(2, 0, Mine.BEHIND)
	local w = world({ kart(1, 0, 0), other })
	Mine.fire(w.karts[1], AHEAD, w.ctx)
	w.t = Mine.ARM - 0.01
	Mine.step(w.ctx)
	eq(#w.hits, 0, "not armed yet")
	w.t = Mine.ARM
	Mine.step(w.ctx)
	eq(w.total(2, "Mine"), 34, "boom")
	eq(w.hits[1].attacker, 1, "owner gets the smash")
	eq(#Mine.live(), 0, "used up")
	eq(w.count("MineBoom"), 1, "boom fx")
	Mine.step(w.ctx)
	eq(w.total(2), 34, "only once")
end)

test("mine: never hurts its owner, a smashed kart, or a kart outside the radius", function()
	Mine.clear()
	local dead = kart(3, 0, Mine.BEHIND)
	dead.alive = false
	local far = kart(4, Mine.RADIUS + 1, Mine.BEHIND)
	local w = world({ kart(1, 0, 0), dead, far })
	Mine.fire(w.karts[1], AHEAD, w.ctx)
	-- the owner reverses onto it
	w.karts[1].cframe = { Position = v(0, 0, Mine.BEHIND), LookVector = AHEAD }
	w.t = 5
	Mine.step(w.ctx)
	eq(#w.hits, 0, "no hits")
	eq(#Mine.live(), 1, "still there")
end)

test("mine: one boom hurts every kart inside the radius", function()
	Mine.clear()
	local w = world({ kart(1, 0, 0), kart(2, 0.5, Mine.BEHIND), kart(3, -0.5, Mine.BEHIND) })
	Mine.fire(w.karts[1], AHEAD, w.ctx)
	w.t = 1
	Mine.step(w.ctx)
	eq(w.total(2), 34)
	eq(w.total(3), 34)
	eq(w.count("MineBoom"), 1, "one boom")
end)

test("mine: fizzles after its life; 3 per kart, the oldest goes; clear removes all", function()
	Mine.clear()
	local w = world({ kart(1, 0, 0), kart(2, 500, 500) })
	Mine.fire(w.karts[1], AHEAD, w.ctx)
	w.t = Mine.LIFE
	Mine.step(w.ctx)
	eq(#Mine.live(), 0, "fizzled")
	for i = 1, Mine.PER_KART + 1 do
		w.karts[1].cframe = { Position = v(i * 20, 0, 0), LookVector = AHEAD }
		Mine.fire(w.karts[1], AHEAD, w.ctx)
	end
	eq(#Mine.live(), Mine.PER_KART, "capped")
	near(Mine.live()[1].position.x, 40, 1e-6, "the first one went")
	w.karts[2].cframe = { Position = v(0, 0, 0), LookVector = AHEAD }
	Mine.fire(w.karts[2], AHEAD, w.ctx)
	eq(#Mine.live(), Mine.PER_KART + 1, "another kart's mine doesn't push them out")
	Mine.clear()
	eq(#Mine.live(), 0, "cleared")
	eq(w.count("MineBoom"), 0, "no booms from fizzles or clear")
end)

-- ===== freeze =====

test("freeze: first hit freezes and hurts a little, the second shatters", function()
	Freeze.clear()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
	truthy(Freeze.fire(w.karts[1], AHEAD, w.ctx))
	eq(w.total(2, "Freeze"), Freeze.DAMAGE, "freeze damage")
	eq(w.frozen[2], Freeze.FROZEN, "kart stopped")
	truthy(Freeze.isFrozen(2, w.t), "frozen")
	w.t = 1
	Freeze.fire(w.karts[1], AHEAD, w.ctx)
	truthy(w.total(2, "Freeze") >= 100, "shattered = smashed")
	eq(w.frozen[2], 0, "ice gone")
	local kinds = {}
	for _, f in w.fxs do
		table.insert(kinds, f.kind)
	end
	eq(table.concat(kinds, ","), "FreezeShot,FreezeHit,FreezeShot,Shatter")
end)

test("freeze: once the ice melts, the next hit only freezes again", function()
	Freeze.clear()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
	Freeze.fire(w.karts[1], AHEAD, w.ctx)
	w.t = Freeze.FROZEN + 0.1
	Freeze.step(w.ctx)
	truthy(not Freeze.isFrozen(2, w.t), "melted")
	eq(w.frozen[2], 0, "let go when it melts")
	Freeze.fire(w.karts[1], AHEAD, w.ctx)
	eq(w.total(2), Freeze.DAMAGE * 2, "two plain freezes")
end)

test("freeze: walls block it; a miss still uses the shot; smashed karts are forgotten", function()
	Freeze.clear()
	local w = world({ kart(1, 0, 0), kart(2, 0, -10) })
	table.insert(w.walls, -5)
	truthy(Freeze.fire(w.karts[1], AHEAD, w.ctx), "shot went")
	eq(#w.hits, 0, "blocked")
	w.walls = {}
	Freeze.fire(w.karts[1], AHEAD, w.ctx)
	w.karts[2].alive = false
	w.t = 0.5
	Freeze.step(w.ctx)
	truthy(not Freeze.isFrozen(2, w.t), "forgotten")
	eq(w.frozen[2], 0, "let go")
	Freeze.clear(w.ctx)
end)
