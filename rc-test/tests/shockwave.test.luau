--!nocheck
-- The Ice Viper's Shockwave special (shared/Shockwave, server/weapons/Shockwave, client/ShockwaveFx).
-- A pretend ctx stands in for WeaponServer: karts are plain tables, after() queues calls that
-- run(dt) plays later.
local fs = require("@lune/fs")
local H = require("./harness")
local Core = require("../src/shared/Shockwave")
local Shockwave = require("../src/server/weapons/Shockwave")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Shockwave")

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

local function world(karts, withPush)
	local w = { t = 0, karts = karts, hits = {}, fxs = {}, queue = {}, pushes = {} }
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
	if withPush ~= false then
		function ctx.push(id, vel, up)
			table.insert(w.pushes, { id = id, v = vel, up = up })
		end
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
	w.ctx = ctx
	return w
end

local R = Core.RANGE

test("shockwave: the fan reaches karts ahead, not behind, beside or too far", function()
	local from, dir = v(0, 0, 0), v(0, 0, -1)
	local karts = {
		kart(1, 0, 0), -- the owner
		kart(2, 0, -R * 0.5), -- dead ahead
		kart(3, R * 0.3, -R * 0.5), -- ahead, a bit to the side
		kart(4, 0, R * 0.5), -- behind
		kart(5, R * 0.9, 0), -- straight to the right (90 degrees: outside the 126 fan)
		kart(6, 0, -R * 1.5), -- too far
	}
	local got = Core.victims(from, dir, karts, 1)
	local ids = {}
	for _, x in got do
		ids[x.id] = true
	end
	truthy(ids[2] and ids[3], "ahead is hit")
	truthy(not ids[1], "never the owner")
	truthy(not ids[4], "not behind")
	truthy(not ids[5], "not beside")
	truthy(not ids[6], "not out of range")
	eq(#got, 2)
end)

test("shockwave: a kart right at the muzzle is hit from any side", function()
	local got = Core.victims(v(0, 0, 0), v(0, 0, -1), { kart(2, 0, Core.NEAR * 0.5) }, 1)
	eq(#got, 1)
end)

test("shockwave: dead and shielded karts are left alone", function()
	local dead = kart(2, 0, -R * 0.4)
	dead.alive = false
	local bubble = kart(3, 0, -R * 0.4)
	bubble.shield = true
	eq(#Core.victims(v(0, 0, 0), v(0, 0, -1), { dead, bubble }, 1), 0)
end)

test("shockwave: nearer karts are hit first, harder, and shoved away from the muzzle", function()
	local got =
		Core.victims(v(0, 0, 0), v(0, 0, -1), { kart(3, 0, -R * 0.8), kart(2, 0, -R * 0.2) }, 1)
	eq(got[1].id, 2)
	eq(got[2].id, 3)
	truthy(got[1].delay < got[2].delay, "the rings reach the near one first")
	truthy(got[1].delay >= Core.CHARGE, "nothing is hit before the charge ends")
	truthy(vector.magnitude(got[1].push) > vector.magnitude(got[2].push), "weaker with distance")
	near(vector.magnitude(got[2].push), Core.PUSH * (1 - 0.5 * 0.8), 1e-4)
	truthy(got[1].push.z < 0 and math.abs(got[1].push.x) < 1e-6, "away from the muzzle")
	eq(got[1].push.y, 0)
	eq(got[1].up, Core.HOP)
end)

test("shockwave: the special refills over REFILL seconds, one shot at a time", function()
	local slot = Core.slot()
	truthy(Core.ready(slot, 0))
	eq(Core.charge(slot, 0), 1)
	truthy(Core.use(slot, 100))
	truthy(not Core.use(slot, 100 + Core.REFILL - 0.1), "not ready yet")
	near(Core.charge(slot, 100 + Core.REFILL / 2), 0.5, 1e-6)
	truthy(not Core.ready(slot, 100 + Core.REFILL - 0.1))
	truthy(Core.ready(slot, 100 + Core.REFILL))
	truthy(Core.use(slot, 100 + Core.REFILL))
end)

test("shockwave: fire sends the rings now and hits each kart when the rings arrive", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -R * 0.4), kart(3, 0, R * 0.4) })
	truthy(Shockwave.fire(w.ctx.getKart(1), v(0, 0, -1), w.ctx))
	eq(#w.fxs, 1)
	eq(w.fxs[1].kind, "Shockwave")
	eq(#w.fxs[1].data.hits, 1)
	eq(w.fxs[1].data.charge, Core.CHARGE)
	eq(#w.hits, 0, "nothing hurts before the rings arrive")
	w.run(Core.CHARGE - 0.01)
	eq(#w.hits, 0, "still charging")
	w.run(R / Core.SPEED + 0.05)
	eq(#w.hits, 1)
	eq(w.hits[1].victim, 2)
	eq(w.hits[1].attacker, 1)
	eq(w.hits[1].amount, Core.DAMAGE)
	eq(w.hits[1].weapon, "Shockwave")
	eq(#w.pushes, 1)
	eq(w.pushes[1].id, 2)
	truthy(w.pushes[1].v.z < 0, "shoved away from the cannon")
	eq(w.pushes[1].up, Core.HOP)
	local hit
	for _, f in w.fxs do
		if f.kind == "ShockHit" then
			hit = f
		end
	end
	truthy(hit and hit.data.id == 2, "the hit flash names the kart")
	eq(hit.data.hurt[1].damage, Core.DAMAGE)
end)

test("shockwave: a kart smashed or shielded before the rings arrive is skipped", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -R * 0.4), kart(3, 0, -R * 0.5) })
	Shockwave.fire(w.ctx.getKart(1), v(0, 0, -1), w.ctx)
	w.karts[2].alive = false
	w.karts[3].shield = true
	w.run(5)
	eq(#w.hits, 0)
	eq(#w.pushes, 0)
end)

test("shockwave: a smashed shooter's rings do nothing, and it can't fire dead", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -R * 0.4) })
	Shockwave.fire(w.ctx.getKart(1), v(0, 0, -1), w.ctx)
	w.karts[1].alive = false
	w.run(5)
	eq(#w.hits, 0)
	truthy(not Shockwave.fire(w.karts[1], v(0, 0, -1), w.ctx), "a smashed kart can't fire")
end)

test("shockwave: clear() drops shoves still waiting", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -R * 0.4) })
	Shockwave.fire(w.ctx.getKart(1), v(0, 0, -1), w.ctx)
	Shockwave.clear(w.ctx)
	w.run(5)
	eq(#w.hits, 0)
end)

test("shockwave: a server with no push still hurts (nothing breaks)", function()
	local w = world({ kart(1, 0, 0), kart(2, 0, -R * 0.4) }, false)
	truthy(Shockwave.fire(w.ctx.getKart(1), v(0, 0, -1), w.ctx))
	w.run(5)
	eq(#w.hits, 1)
	eq(#w.pushes, 0)
end)

test("shockwave: the cannon points where the kart faces, whatever the aim says", function()
	local w = world({ kart(1, 0, 0), kart(2, R * 0.4, 0) }) -- a kart to the right, kart 1 faces -z
	Shockwave.fire(w.ctx.getKart(1), v(1, 0, 0), w.ctx) -- aim help says "right"
	w.run(5)
	eq(#w.hits, 0)
end)

test("shockwave: the game is wired for it", function()
	local server = fs.readFile("src/server/WeaponServer.luau")
	truthy(server:find("push = function(id: any, v: Vector3, up: number)", 1, true), "ctx.push")
	truthy(server:find('"Knock"', 1, true), "a player's car is told to shove itself")
	local match = fs.readFile("src/server/MatchRunner.luau")
	truthy(match:find("function MatchRunner.knock", 1, true), "bots are shoved by MatchRunner")
	local bots = fs.readFile("src/server/ArenaBots.luau")
	truthy(bots:find("function ArenaBots.knock", 1, true), "ArenaBots moves a shoved bot")
	local fx = fs.readFile("src/client/WeaponFx.client.luau")
	truthy(fx:find('kind == "Shockwave"', 1, true), "WeaponFx hands the rings to ShockwaveFx")
	truthy(fx:find('"ShockwaveFx"', 1, true))
	local draw = fs.readFile("src/client/ShockwaveFx.luau")
	truthy(draw:find("AssemblyLinearVelocity", 1, true), "the client shoves its own car")
	truthy(draw:find("KNOCK_MAX", 1, true), "and never more than the cap")
end)
