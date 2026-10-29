--!nocheck
-- Flame Nozzle (src/server/weapons/Flame): a burst of fire close ahead of the hood. A pretend ctx
-- stands in for WeaponServer (karts are plain tables, walls are spans the ray can't cross, after()
-- queues calls that run(dt) plays later), like gunmine.test.
local H = require("./harness")
local Flame = require("../src/server/weapons/Flame")
local Weapons = require("../src/shared/Weapons")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

local function v(x, y, z)
	return vector.create(x, y, z)
end

-- a kart at (x, 0, z) facing -z (Roblox forward)
local function kart(id, x, z)
	return {
		id = id,
		alive = true,
		cframe = { Position = v(x, 0, z), LookVector = v(0, 0, -1) },
	}
end

local function world(karts)
	local w = { t = 0, karts = karts, hits = {}, fxs = {}, queue = {}, walls = {}, takes = {} }
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
	-- a wall at z = wz blocks any ray that crosses it
	function ctx.raycast(from, to, _ignore)
		for _, wz in w.walls do
			if (from.z - wz) * (to.z - wz) < 0 then
				return { kartId = nil, position = from }
			end
		end
		return nil
	end
	function ctx.damage(victim, attacker, amount, weapon)
		table.insert(
			w.hits,
			{ victim = victim, attacker = attacker, amount = amount, weapon = weapon }
		)
		local t = w.takes[victim]
		if t ~= nil then
			return math.min(t, amount)
		end
		return nil
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
	function w.total(victim)
		local n = 0
		for _, h in w.hits do
			if h.victim == victim then
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
local KART = 5.5 * TrackData.RC_SCALE
-- the whole burst plays out: every tick has run
local function burst(w, k)
	truthy(Flame.fire(k, AHEAD, w.ctx), "fire accepted")
	for _ = 1, Flame.TICKS * 2 do
		w.run(Flame.GAP)
	end
end

print("Flame nozzle")

test("flame: a weapon with the same numbers as its module, at RC size", function()
	local def = Weapons.DEFS.Flame
	truthy(def and table.find(Weapons.NAMES, "Flame"), "in Weapons")
	eq(Flame.ammo, def.ammo, "ammo")
	eq(Flame.cooldown, def.cooldown, "cooldown")
	eq(Weapons.feedWord("Flame"), "flame", "kill-list word")
	near(Flame.SCALE, TrackData.RC_SCALE, 1e-9, "scale")
	truthy(Flame.RANGE >= 2 * KART and Flame.RANGE <= 8 * KART, "close range: a few karts")
	-- the fire leaves the nozzle on the hood: ahead of the middle and past the nose, above the hood
	truthy(Flame.MUZZLE > KART / 2 and Flame.MUZZLE < KART * 1.2, "muzzle at the nozzle")
	truthy(Flame.HEIGHT > 0 and Flame.HEIGHT < KART, "muzzle above the hood")
end)

test("flame: a burst adds up to BURST_DAMAGE in whole numbers", function()
	local sum = 0
	for i = 1, Flame.TICKS do
		local d = Flame.tickDamage(i)
		eq(d, math.floor(d), "whole number")
		truthy(d > 0, "every tick hurts")
		sum += d
	end
	eq(sum, Flame.BURST_DAMAGE, "the burst")
	eq(Flame.BURST_DAMAGE, 34, "three bursts smash a kart (health 100)")
end)

test(
	"flame: a kart close ahead burns for the whole burst, one behind or far away does not",
	function()
		local me, ahead, behind, far, side =
			kart(1, 0, 0),
			kart(2, 0, -Flame.RANGE * 0.6),
			kart(3, 0, 3),
			kart(4, 0, -Flame.RANGE * 2),
			kart(5, Flame.RANGE * 0.6, -0.5)
		local w = world({ me, ahead, behind, far, side })
		burst(w, me)
		eq(w.total(2), Flame.BURST_DAMAGE, "the kart ahead takes the whole burst")
		eq(w.total(3), 0, "behind: nothing")
		eq(w.total(4), 0, "too far: nothing")
		eq(w.total(5), 0, "off to the side, outside the cone: nothing")
		eq(w.total(1), 0, "never the shooter")
		for _, h in w.hits do
			eq(h.weapon, "Flame", "the weapon's name")
			eq(h.attacker, 1, "the shooter")
		end
		eq(w.count("FlameBurst"), 1, "one stream to draw")
		eq(w.count("FlameTick"), Flame.TICKS, "a tick each")
	end
)

test("flame: it burns every kart in the cone at once", function()
	local me, a, b =
		kart(1, 0, 0), kart(2, 0.2, -Flame.RANGE * 0.5), kart(3, -0.2, -Flame.RANGE * 0.8)
	local w = world({ me, a, b })
	burst(w, me)
	eq(w.total(2), Flame.BURST_DAMAGE, "first")
	eq(w.total(3), Flame.BURST_DAMAGE, "second")
end)

test(
	"flame: a wall in the way stops the fire; a dead kart or a shielded one takes nothing",
	function()
		local me, ahead = kart(1, 0, 0), kart(2, 0, -Flame.RANGE * 0.6)
		local w = world({ me, ahead })
		w.walls = { -Flame.RANGE * 0.3 }
		burst(w, me)
		eq(w.total(2), 0, "wall in the way")
		local me2, dead = kart(1, 0, 0), kart(2, 0, -Flame.RANGE * 0.6)
		dead.alive = false
		local w2 = world({ me2, dead })
		burst(w2, me2)
		eq(#w2.hits, 0, "a smashed kart is not burned")
		-- a shield: the match takes 0, so the fx names nobody as hurt
		local me3, shielded = kart(1, 0, 0), kart(2, 0, -Flame.RANGE * 0.6)
		local w3 = world({ me3, shielded })
		w3.takes[2] = 0
		burst(w3, me3)
		local hurtNobody = true
		for _, f in w3.fxs do
			if f.kind == "FlameTick" and #f.data.hurt > 0 then
				hurtNobody = false
			end
		end
		truthy(hurtNobody, "blocked: not in hurt")
	end
)

test("flame: the burst follows the kart's turn, and a clear drops the rest of it", function()
	local me, ahead = kart(1, 0, 0), kart(2, 0, -Flame.RANGE * 0.6)
	local w = world({ me, ahead })
	Flame.fire(me, AHEAD, w.ctx)
	w.run(Flame.GAP) -- tick 2
	Flame.clear(w.ctx) -- match over
	for _ = 1, Flame.TICKS do
		w.run(Flame.GAP)
	end
	truthy(w.total(2) < Flame.BURST_DAMAGE, "the rest of the burst was dropped")
	-- the shooter is smashed mid-burst: no more fire
	local me2, ahead2 = kart(1, 0, 0), kart(2, 0, -Flame.RANGE * 0.6)
	local w2 = world({ me2, ahead2 })
	Flame.fire(me2, AHEAD, w2.ctx)
	me2.alive = false
	for _ = 1, Flame.TICKS do
		w2.run(Flame.GAP)
	end
	eq(w2.total(2), Flame.tickDamage(1), "only the first tick landed")
	-- a smashed kart cannot fire at all
	local dead = kart(1, 0, 0)
	dead.alive = false
	eq(Flame.fire(dead, AHEAD, world({ dead }).ctx), false, "no fire from a smashed kart")
end)

test("flame: the client draws it and the kill list names it", function()
	local fs = require("@lune/fs")
	local fx = fs.readFile("src/client/WeaponFxGunMine.luau")
	truthy(fx:find('kind == "FlameBurst"', 1, true), "the stream is drawn")
	local juice = require("../src/shared/SmashJuice")
	truthy(
		juice
			.deathLine("flame", "Rocket Raccoon")
			:find("burned by Rocket Raccoon's flamethrower", 1, true),
		"death line"
	)
end)
