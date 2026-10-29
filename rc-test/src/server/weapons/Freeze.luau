--!strict
-- Freeze ("Freeze" from a "?" box). One tap of FIRE = one ice shot straight ahead (the gun's
-- aim help, Gun.pickTarget). A kart it hits is frozen in an ice block for FROZEN seconds: it
-- can't drive (ctx.freeze stops it) and takes DAMAGE. A second freeze hit while it is still
-- frozen SHATTERS it: a smash at once ("You were shattered by X"). Two shots per box, so one box
-- can do both.
-- The server decides every hit; clients get "FreezeShot", "FreezeHit" and "Shatter" fx to draw.
-- Plain `vector` maths, so Lune tests run it.

-- the gun's aim help (one function for both): Roblox by script.Parent, plain Lune by path
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent:WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Gun = sibling("Gun")

local Freeze = {}

Freeze.NAME = "Freeze"
-- RC size: big units (a kart is 3 x 5.5 big) times SCALE (= TrackData.RC_SCALE; a test checks)
Freeze.SCALE = 0.25
local S = Freeze.SCALE
Freeze.ammo = 2
Freeze.cooldown = 0.8
Freeze.FROZEN = 2.5 -- seconds stuck in the ice
Freeze.DAMAGE = 10 -- the freeze itself hurts a little
Freeze.SHATTER = 1000 -- more than any health: a shattered kart is smashed
Freeze.RANGE = 160 * S -- the gun's reach
Freeze.MUZZLE = 3.5 * S
Freeze.HEIGHT = 1.5 * S

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean? }
export type Hit = { kartId: any?, position: Vector3 }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	raycast: (from: Vector3, to: Vector3, ignoreId: any?) -> Hit?,
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> (),
	fx: (kind: string, data: { [string]: any }) -> (),
	-- stops (seconds > 0) or frees (0) a kart; WeaponServer / MatchRunner does the real stop
	freeze: ((id: any, seconds: number) -> ())?,
}

-- kart id -> server time its ice melts
local frozenUntil: { [any]: number } = {}

function Freeze.isFrozen(id: any, now: number): boolean
	local t = frozenUntil[id]
	return t ~= nil and now < t
end

local function flat(v: Vector3): Vector3?
	local f = vector.create(v.x, 0, v.z)
	local m = vector.magnitude(f)
	if m ~= m or m < 1e-4 then
		return nil
	end
	return f / m
end

-- The weapon contract: one ice shot along `aim` (already checked by WeaponServer).
function Freeze.fire(kart: Kart, aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local cf = kart.cframe
	local look = flat(cf.LookVector) or vector.create(0, 0, -1)
	local dir = flat(aim) or look
	local from = cf.Position + look * Freeze.MUZZLE + vector.create(0, Freeze.HEIGHT, 0)
	local target = Gun.pickTarget(kart.id, cf.Position, dir, look, ctx.karts(), Freeze.RANGE)
	local to = if target then target.cframe.Position else from + dir * Freeze.RANGE
	local hit = ctx.raycast(from, to, kart.id)
	local victim: any? = nil
	local endAt = to
	if hit then
		endAt = hit.position
		if hit.kartId ~= nil and hit.kartId ~= kart.id then
			victim = hit.kartId
		end
	elseif target then
		victim = target.id
	end
	local v = if victim ~= nil then ctx.getKart(victim) else nil
	if not v or not v.alive then
		victim = nil
	end
	ctx.fx("FreezeShot", { from = from, to = endAt, hit = victim ~= nil, owner = kart.id })
	if victim == nil or v == nil then
		return true
	end
	local now = ctx.now()
	if Freeze.isFrozen(victim, now) then
		-- second hit: shatter
		frozenUntil[victim] = nil
		if ctx.freeze then
			ctx.freeze(victim, 0)
		end
		ctx.fx("Shatter", { id = victim, position = v.cframe.Position, owner = kart.id })
		ctx.damage(victim, kart.id, Freeze.SHATTER, Freeze.NAME)
	else
		frozenUntil[victim] = now + Freeze.FROZEN
		if ctx.freeze then
			ctx.freeze(victim, Freeze.FROZEN)
		end
		ctx.fx("FreezeHit", {
			id = victim,
			position = v.cframe.Position,
			seconds = Freeze.FROZEN,
			owner = kart.id,
		})
		ctx.damage(victim, kart.id, Freeze.DAMAGE, Freeze.NAME)
	end
	return true
end

-- Each tick: melted ice and karts smashed some other way are let go.
function Freeze.step(ctx: Ctx, _dt: number?)
	if next(frozenUntil) == nil then
		return
	end
	local now = ctx.now()
	local alive: { [any]: boolean } = {}
	for _, k in ctx.karts() do
		alive[k.id] = k.alive
	end
	for id, t in frozenUntil do
		if now >= t or not alive[id] then
			frozenUntil[id] = nil
			if ctx.freeze then
				ctx.freeze(id, 0)
			end
		end
	end
end

-- Match end / reset: all ice melts.
function Freeze.clear(ctx: Ctx?)
	for id in frozenUntil do
		if ctx and ctx.freeze then
			ctx.freeze(id, 0)
		end
	end
	table.clear(frozenUntil)
end

return Freeze
