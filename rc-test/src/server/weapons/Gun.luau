--!strict
-- Machine gun ("Gun" from a "?" box). One tap of FIRE = one short burst of bullets.
-- The server decides every bullet: it snaps to the nearest kart in a cone ahead (aim help, so a
-- phone thumb and a bot play fair; Weapons.cone, shared with the rocket lock), checks the line of
-- sight with a ray, then calls ctx.damage. A full
-- burst on one kart does BURST_DAMAGE (34: three hits smash a kart). Clients only get
-- "GunShot" fx (a tracer from the muzzle to where it hit) to draw. Plain `vector` maths, so Lune
-- tests run it.

-- shared/Weapons: Roblox from ReplicatedStorage, plain Lune (tests) by path
local function shared(name: string): any
	if script then
		local rs: any = game:GetService("ReplicatedStorage")
		return require(rs:WaitForChild("Shared"):WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("../../shared/" .. name)
end

local Weapons = shared("Weapons")
local WeaponMounts = shared("WeaponMounts")
local WeaponLooks = shared("WeaponLooks")

local Gun = {}

Gun.NAME = "Gun"
-- The arena is RC size: distances are set in big units (a kart is 3 x 5.5 big) and shrunk by
-- SCALE (= TrackData.RC_SCALE; a test checks), so a kart is about 1.4 studs long.
Gun.SCALE = 0.25
local S = Gun.SCALE
Gun.ammo = 4 -- bursts per box
Gun.cooldown = 0.5 -- seconds between bursts (a burst lasts (BULLETS-1) * GAP = 0.35 s)
Gun.BULLETS = 6
Gun.GAP = 0.07 -- seconds between bullets in a burst
Gun.BURST_DAMAGE = 34 -- a whole burst, split over its bullets
Gun.RANGE = 160 * S -- about 29 kart lengths, 44% of the arena's width
Gun.AIM_DEG = 25 -- aim help: snaps to the nearest kart this close to the aim
-- Bullets leave the barrel tip of the gun part that clicks onto the car (shared/WeaponMounts,
-- WeaponLooks). It is the Gun's own look, the same for every look and skin, so a skin never
-- changes where bullets start (looks only, no pay-to-win).
local gunLook = assert(WeaponLooks.forWeapon(Gun.NAME, nil), "the Gun has no look")
local AHEAD, UP = WeaponMounts.muzzle(gunLook.mount, gunLook.muzzles[1])
Gun.MUZZLE = AHEAD * 5.5 * S -- ahead of the kart centre
Gun.HEIGHT = UP * 5.5 * S -- above the kart centre

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean? }
export type Hit = { kartId: any?, position: Vector3 }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	raycast: (from: Vector3, to: Vector3, ignoreId: any?) -> Hit?,
	-- returns the health it really took (0 = blocked: a shield, not in the match)
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> number?,
	fx: (kind: string, data: { [string]: any }) -> (),
	after: (seconds: number, fn: () -> ()) -> (),
}

-- Bullet i's share of BURST_DAMAGE, in whole numbers that add up to it exactly (5,6,6,5,6,6).
function Gun.bulletDamage(i: number): number
	local n = Gun.BULLETS
	return math.floor(Gun.BURST_DAMAGE * i / n) - math.floor(Gun.BURST_DAMAGE * (i - 1) / n)
end

-- Damage through ctx and what it really took: the fx's `hurt` list names only karts that lost
-- health, so the client's hit flash and "-N" never guess. An older ctx returns nothing: all of it.
function Gun.hurt(ctx: Ctx, victim: any, attacker: any, amount: number, weapon: string): number
	local taken = ctx.damage(victim, attacker, amount, weapon)
	return if type(taken) == "number" then taken else amount
end

-- bumped by clear(): bullets still queued from an older burst do nothing
local gen = 0

local function flat(v: Vector3): Vector3?
	local f = vector.create(v.x, 0, v.z)
	local m = vector.magnitude(f)
	if m ~= m or m < 1e-4 then
		return nil
	end
	return f / m
end

-- Aim help (also Freeze's): the nearest kart that is alive, not shielded, not the shooter, in
-- `range` and within AIM_DEG of `dir` (Weapons.cone), and never more than Weapons.MAX_AIM_DEG
-- off the kart's nose `look`, so a cheat aiming at the edge can't hit sideways. `prefer` keeps a
-- burst on the kart it started on while that kart is still fair game. nil = fire straight.
function Gun.pickTarget(
	shooterId: any,
	from: Vector3,
	dir: Vector3,
	look: Vector3,
	karts: { Kart },
	range: number,
	prefer: any?
): Kart?
	local noseCos = math.cos(math.rad(Weapons.MAX_AIM_DEG))
	local list: { any } = {}
	for _, k in karts do
		local side = flat(k.cframe.Position - from)
		if side and vector.dot(side, look) >= noseCos then
			local row: any = {
				id = k.id,
				pos = k.cframe.Position,
				alive = k.alive,
				shield = k.shield,
				kart = k,
			}
			if prefer ~= nil and k.id == prefer then
				if Weapons.cone(from, dir, { row }, Gun.AIM_DEG, range, shooterId) then
					return k
				end
			end
			table.insert(list, row)
		end
	end
	local best: any = Weapons.cone(from, dir, list, Gun.AIM_DEG, range, shooterId)
	return if best then best.kart else nil
end

-- One bullet from the shooter's spot right now, along `aim` turned with the kart since the burst
-- began. Returns the victim's id when it hit a kart.
function Gun.shoot(shooterId: any, turn: Vector3, ctx: Ctx, i: number, prefer: any?): any?
	local shooter = ctx.getKart(shooterId)
	if not shooter or not shooter.alive then
		return nil
	end
	local cf = shooter.cframe
	local look = flat(cf.LookVector) or vector.create(0, 0, -1)
	-- the burst keeps the aim it started with, relative to the kart (turn = aim in kart space)
	local right = vector.create(-look.z, 0, look.x)
	local dir = flat(look * turn.z + right * turn.x) or look
	local from = cf.Position + look * Gun.MUZZLE + vector.create(0, Gun.HEIGHT, 0)
	local target = Gun.pickTarget(shooterId, cf.Position, dir, look, ctx.karts(), Gun.RANGE, prefer)
	local to = if target then target.cframe.Position else from + dir * Gun.RANGE
	local hit = ctx.raycast(from, to, shooterId)
	local victim: any? = nil
	local endAt = to
	if hit then
		endAt = hit.position
		if hit.kartId ~= nil and hit.kartId ~= shooterId then
			victim = hit.kartId
		end
	elseif target then
		victim = target.id -- nothing in the way: the bullet reaches the target
	end
	if victim ~= nil then
		local v = ctx.getKart(victim)
		if not v or not v.alive then
			victim = nil
		end
	end
	local hurt = {}
	if victim ~= nil then
		local taken = Gun.hurt(ctx, victim, shooterId, Gun.bulletDamage(i), Gun.NAME)
		if taken > 0 then
			table.insert(hurt, { id = victim, damage = taken })
		end
	end
	local data = { from = from, to = endAt, hit = victim ~= nil, owner = shooterId, hurt = hurt }
	ctx.fx("GunShot", data)
	return victim
end

-- The weapon contract: one burst along `aim` (WeaponServer already checked it). The first bullet
-- goes now, the rest every GAP seconds; a bullet does nothing once the shooter is smashed.
function Gun.fire(kart: Kart, aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local look = flat(kart.cframe.LookVector) or vector.create(0, 0, -1)
	local want = flat(aim) or look
	-- aim in kart space: z = forward part, x = right part
	local right = vector.create(-look.z, 0, look.x)
	local turn = vector.create(vector.dot(want, right), 0, vector.dot(want, look))
	local id = kart.id
	local myGen = gen
	local prefer = Gun.shoot(id, turn, ctx, 1, nil)
	for i = 2, Gun.BULLETS do
		ctx.after(Gun.GAP * (i - 1), function()
			if gen ~= myGen then
				return
			end
			local hit = Gun.shoot(id, turn, ctx, i, prefer)
			if hit ~= nil then
				prefer = hit
			end
		end)
	end
	return true
end

-- Match end / reset: the rest of any burst in the air is dropped.
function Gun.clear(_ctx: Ctx?)
	gen += 1
end

return Gun
