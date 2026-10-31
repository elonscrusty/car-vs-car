--!strict
-- Flying weapons on the server (ROCKETS, NUKE): the one engine both use. A shot flies from the
-- kart's nose; shared/Weapons.step moves it, bends it a little toward a kart ahead and says what
-- it hit; a boom hurts every kart in reach (Weapons.boom) through ctx.damage. Clients only draw:
-- "RocketLaunch" { id, kind, pos, dir }, "RocketTurn" { id, pos, dir }, "RocketBoom" { id, kind,
-- pos, hit?, hurt?, quiet? } (client/WeaponFx; hurt = { { id, damage } }: every kart the
-- server really hurt and by how much, for the hit flash and "-N"). Plain Luau with the Weapons module passed in, so Lune
-- tests run it with a fake ctx.

-- shared/*: Roblox from ReplicatedStorage, plain Lune (tests) by path
local function shared(name: string): any
	if script then
		local rs: any = game:GetService("ReplicatedStorage")
		return require(rs:WaitForChild("Shared"):WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("../../shared/" .. name)
end

local WeaponMounts = shared("WeaponMounts")
local WeaponLooks = shared("WeaponLooks")

local Flight = {}

Flight.MAX_FLYING = 40 -- in the whole server, all flying weapons together
Flight.STEP = 1 / 30 -- the longest bit of flight checked at once
Flight.TURN_EVERY = 0.1 -- while it bends toward a kart, clients get its new path this often
Flight.MAX_DT = 0.25 -- a long server hitch moves a shot at most this much at once

Flight.TURN_DEG = 4 -- ... and only once it has bent at least this much since the last word

type Flying = { id: number, kind: string, r: any, sentAt: number, sentDir: Vector3, atWall: boolean? }

-- The Missile Rack fires its tubes in this order: left, right, middle on the low row, then the same
-- on the top row, one rocket per tube, then round again. (WeaponLooks lists the rack's muzzles
-- by column: 1-2 left, 3-4 middle, 5-6 right; odd = low, even = top.)
local TUBE_ORDER = { 1, 5, 3, 2, 6, 4 }
local tubeCount: { [any]: number } = {}

-- Where tube number `n` (1, 2, 3 ...) of the rack on a kart at `at`, facing `look`, is. `kartLen` is
-- the kart's length in studs. nil when the Rockets have no look. Looks only: the shot itself still
-- flies from the nose, the client blends from the tube into that path (client/WeaponFx).
function Flight.tubeSpot(at: Vector3, look: Vector3, n: number, kartLen: number): Vector3?
	local rack = WeaponLooks.forWeapon("Rockets", nil)
	local muzzle = rack and rack.muzzles[TUBE_ORDER[(n - 1) % #TUBE_ORDER + 1]]
	if not rack or not muzzle then
		return nil
	end
	local fwd = vector.create(look.x, 0, look.z)
	local mag = vector.magnitude(fwd)
	fwd = if mag > 1e-4 then fwd / mag else vector.create(0, 0, -1)
	local right = vector.create(-fwd.z, 0, fwd.x)
	local ahead, up = WeaponMounts.muzzle(rack.mount, muzzle)
	return at
		+ fwd * (ahead * kartLen)
		+ right * (WeaponMounts.side(muzzle) * kartLen)
		+ vector.create(0, up * kartLen, 0)
end

-- shared by every flying weapon: ids are unique and the cap counts them all
local flying: { Flying } = {}
local nextId = 0

local function targets(ctx: any, Weapons: any): { any }
	local out = {}
	for _, k in ctx.karts() do
		if k.alive then
			local pos = Weapons.vec(k.cframe.Position)
			if pos then
				table.insert(out, { id = k.id, pos = pos, shield = k.shield == true })
			end
		end
	end
	return out
end

-- LOCK-ON: tell the match which kart a rocket chases (ctx.mark is optional: tests may not have it)
local function setLock(ctx: any, f: any, id: any)
	if f.lock == id then
		return
	end
	if type(ctx.mark) == "function" then
		if f.lock ~= nil then
			ctx.mark(f.lock, false)
		end
		if id ~= nil then
			ctx.mark(id, true)
		end
	end
	f.lock = id
end

-- walls and ground stop a shot; karts are hit by the shot's own check (a little wider than a
-- kart), so the ray looks through them
local stepCtx: any = nil
local function blocked(from: Vector3, to: Vector3): Vector3?
	local h = stepCtx.raycast(from, to, nil, true)
	return if h then h.position else nil
end

-- A weapon module ({ ammo, cooldown, fire, step, clear }) for the flying weapon `name`.
function Flight.weapon(name: string, Weapons: any): { [string]: any }
	local spec = Weapons.FLIGHTS[name]
	local def = Weapons.DEFS[name]
	assert(spec and def, "no flight for " .. name)
	local W = {}
	W.NAME = name
	W.ammo = def.ammo
	W.cooldown = def.cooldown

	function W.fire(kart: any, aim: Vector3, ctx: any): boolean
		if #flying >= Flight.MAX_FLYING then
			return false
		end
		nextId += 1
		local from = Weapons.vec(kart.cframe.Position) or vector.zero
		local r = Weapons.rocket(
			kart.id,
			from,
			aim,
			spec,
			targets(ctx, Weapons),
			Weapons.vec(kart.cframe.LookVector)
		)
		-- nose against a wall: the shot would start inside it (a ray from inside a part sees
		-- nothing), so look from the kart's middle to the start and boom right there on a wall
		local h = ctx.raycast(from + vector.create(0, spec.up, 0), r.pos, nil, true)
		local wall = h and Weapons.vec(h.position)
		if wall then
			r.pos = wall - r.dir * 0.05
		end
		table.insert(flying, {
			id = nextId,
			kind = name,
			r = r,
			sentAt = ctx.now(),
			sentDir = r.dir,
			atWall = wall ~= nil,
		})
		-- a Rockets shot also says which rack tube it left from (the Nuke has no rack)
		local tube: Vector3? = nil
		if name == "Rockets" then
			local n = (tubeCount[kart.id] or 0) + 1
			tubeCount[kart.id] = n
			tube = Flight.tubeSpot(
				from,
				Weapons.vec(kart.cframe.LookVector) or vector.create(0, 0, -1),
				n,
				Weapons.KART
			)
		end
		ctx.fx(
			"RocketLaunch",
			{ id = nextId, kind = name, pos = r.pos, dir = r.dir, owner = kart.id, from = tube }
		)
		return true
	end

	-- Move this weapon's shots; boom the ones that hit something or ran out of time.
	function W.step(ctx: any, dt: number)
		stepCtx = ctx
		local list: { any }? = nil
		local i = 1
		while i <= #flying do
			local f = flying[i]
			if f.kind ~= name then
				i += 1
				continue
			end
			list = list or targets(ctx, Weapons)
			local owner = f.r.owner
			local left = math.min(dt, Flight.MAX_DT)
			local what, who = nil, nil
			if f.atWall then
				what = "wall"
			end
			while left > 1e-6 and what == nil do
				local bit = math.min(left, Flight.STEP)
				left -= bit
				what, who = Weapons.step(f.r, bit, list, blocked)
			end
			setLock(ctx, f, if what == nil then f.r.target else nil)
			if what ~= nil then
				local direct = if what == "hit" then who else nil
				table.remove(flying, i)
				local hurt = {}
				for _, d in Weapons.boom(f.r.pos, list :: { any }, owner, direct, spec) do
					local ok, taken = pcall(ctx.damage, d.id, owner, d.damage, name)
					if not ok then
						warn("[Flight] damage failed: " .. tostring(taken))
					elseif type(taken) ~= "number" or taken > 0 then
						table.insert(hurt, {
							id = d.id,
							damage = if type(taken) == "number" then taken else d.damage,
						})
					end
				end
				ctx.fx("RocketBoom", {
					id = f.id,
					kind = name,
					pos = f.r.pos,
					hit = direct,
					hurt = hurt,
					owner = owner,
				})
			else
				local now = ctx.now()
				local bent = vector.dot(f.r.dir, f.sentDir) < math.cos(math.rad(Flight.TURN_DEG))
				if bent and now - f.sentAt >= Flight.TURN_EVERY then
					f.sentAt, f.sentDir = now, f.r.dir
					ctx.fx("RocketTurn", { id = f.id, pos = f.r.pos, dir = f.r.dir })
				end
				i += 1
			end
		end
	end

	-- Match over: this weapon's shots vanish without hurting anyone.
	function W.clear(ctx: any)
		local i = 1
		while i <= #flying do
			local f = flying[i]
			if f.kind == name then
				setLock(ctx, f, nil)
				ctx.fx("RocketBoom", { id = f.id, kind = name, pos = f.r.pos, quiet = true })
				table.remove(flying, i)
			else
				i += 1
			end
		end
	end

	return W
end

-- (tests) how many shots are in the air, of one kind or all
function Flight.count(kind: string?): number
	local n = 0
	for _, f in flying do
		if kind == nil or f.kind == kind then
			n += 1
		end
	end
	return n
end

return Flight
