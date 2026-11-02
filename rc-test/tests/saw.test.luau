--!nocheck
-- SAW row: the Road Saw car's buzzsaw (src/server/weapons/Saw). A pretend ctx stands in for
-- WeaponServer: karts are plain tables, a clock, a log of damage and fx.

local H = require("./harness")
local Saw = require("../src/server/weapons/Saw")
local Weapons = require("../src/shared/Weapons")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

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
	local w = { t = 0, hits = {}, fxs = {}, takes = {} }
	local ctx = {}
	function ctx.now()
		return w.t
	end
	function ctx.karts()
		return karts
	end
	function ctx.damage(victim, attacker, amount, weapon)
		local h = { victim = victim, attacker = attacker, amount = amount, weapon = weapon }
		table.insert(w.hits, h)
		local t = w.takes[victim]
		return if t ~= nil then math.min(t, amount) else nil
	end
	function ctx.fx(kind, data)
		table.insert(w.fxs, { kind = kind, data = data })
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

test("saw: the weapon list has it with the module's numbers, at RC size", function()
	local def = Weapons.DEFS.Saw
	truthy(def and table.find(Weapons.NAMES, "Saw"))
	eq(Saw.ammo, def.ammo)
	eq(Saw.cooldown, def.cooldown)
	eq(Saw.SCALE, TrackData.RC_SCALE)
	eq(Weapons.feedWord("Saw"), "buzzsaw")
end)

test("saw: the strip is just ahead of the nose, not behind or far to the side", function()
	local cf = kart("a", 0, 0).cframe
	truthy(Saw.inStrip(cf, v(0, 0, -3 * Saw.SCALE)), "straight ahead")
	truthy(Saw.inStrip(cf, v(0, 0, -Saw.REACH + 0.01)), "at the far end")
	truthy(not Saw.inStrip(cf, v(0, 0, -Saw.REACH - 0.1)), "past the reach")
	truthy(not Saw.inStrip(cf, v(0, 0, 3 * Saw.SCALE)), "behind the kart")
	truthy(not Saw.inStrip(cf, v(Saw.WIDE + 0.1, 0, -3 * Saw.SCALE)), "too far to the side")
	truthy(Saw.inStrip(cf, v(Saw.WIDE - 0.1, 0, -3 * Saw.SCALE)), "inside the width")
end)

test("saw: nothing is cut until it revs; then one cut per tick; never the owner", function()
	Saw.clear()
	local karts = { kart("a", 0, 0), kart("b", 0, -3 * Saw.SCALE) }
	local w = world(karts)
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 0, "idle saw cuts nothing")
	truthy(Saw.fire(karts[1], v(0, 0, -1), w.ctx))
	eq(w.count("SawRev"), 1)
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 1)
	eq(w.hits[1].victim, "b")
	eq(w.hits[1].attacker, "a")
	eq(w.hits[1].weapon, "Saw")
	eq(w.hits[1].amount, Saw.DAMAGE)
	w.t += Saw.TICK * 0.5
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 1, "not again inside a tick")
	w.t += Saw.TICK
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 2, "the next tick cuts again")
	for _, h in w.hits do
		truthy(h.victim ~= "a", "never the owner")
	end
	eq(w.count("SawHit"), 2)
end)

test("saw: the rev ends, a dead owner stops, a shield (0 taken) draws no sparks", function()
	Saw.clear()
	local karts = { kart("a", 0, 0), kart("b", 0, -3 * Saw.SCALE) }
	local w = world(karts)
	Saw.fire(karts[1], v(0, 0, -1), w.ctx)
	w.takes.b = 0 -- shielded
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 1)
	eq(w.count("SawHit"), 0, "no sparks on a shield")
	w.takes.b = nil
	w.t = Saw.REV + 0.1
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 1, "rev over: no more cuts")
	truthy(not Saw.revving("a", w.t))
	Saw.fire(karts[1], v(0, 0, -1), w.ctx)
	karts[1].alive = false
	w.t += Saw.TICK + 0.1
	Saw.step(w.ctx, 0.05)
	eq(#w.hits, 1, "a smashed saw kart cuts nothing")
	karts[1].alive = false
	truthy(not Saw.fire(karts[1], v(0, 0, -1), w.ctx), "a dead kart can't rev")
end)

test("saw: about three seconds of touching smashes a kart", function()
	truthy(Saw.DAMAGE * (3 / Saw.TICK) >= 100)
	truthy(Saw.DAMAGE * (3 / Saw.TICK) <= 120)
end)

test("saw spin: revving whirls, idle crawls, the speed eases and never overshoots", function()
	local SawSpin = require("../src/client/SawSpin")
	eq(SawSpin.wanted(2), SawSpin.REV)
	eq(SawSpin.wanted(0), SawSpin.IDLE)
	eq(SawSpin.wanted(-1), SawSpin.IDLE)
	local s = SawSpin.IDLE
	for _ = 1, 600 do
		s = SawSpin.ease(s, SawSpin.REV, 1 / 60)
		truthy(s <= SawSpin.REV)
	end
	truthy(s > SawSpin.REV * 0.99, "reaches the rev")
	eq(SawSpin.ease(1, 5, 10), 5, "a long frame lands on the wanted speed")
end)
