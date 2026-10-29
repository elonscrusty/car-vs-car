--!strict
-- Flame Nozzle ("Flame"). One tap of FIRE = a short burst of fire from the nozzle on the hood. It
-- is close range and wide: every kart in the cone ahead (CONE_DEG each side of the aim) and inside
-- RANGE of the nozzle burns, TICKS times, GAP seconds apart. The server checks each tick: cone,
-- distance, and a ray for walls in the way, then calls ctx.damage. A kart that stays in the fire the
-- whole burst takes BURST_DAMAGE (34: three bursts smash a kart), the same as a gun burst.
-- Clients only get "FlameBurst" (once, to draw the stream) and "FlameTick" (to show who got
-- burned) fx. Plain `vector` maths, so Lune tests run it.

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

local Flame = {}

Flame.NAME = "Flame"
-- RC size: big units (a kart is 3 x 5.5 big) times SCALE (= TrackData.RC_SCALE; a test checks)
Flame.SCALE = 0.25
local S = Flame.SCALE
Flame.ammo = 3 -- bursts per pickup
Flame.cooldown = 1.4 -- seconds between bursts (a burst lasts (TICKS - 1) * GAP = 0.9 s)
Flame.TICKS = 6
Flame.GAP = 0.18 -- seconds between ticks
Flame.BURST_DAMAGE = 34 -- a whole burst on one kart, split over its ticks
Flame.RANGE = 24 * S -- from the nozzle: about 4 kart lengths, close range on purpose
Flame.CONE_DEG = 18 -- each side of the aim
-- The fire leaves the nozzle of the flame part that clicks onto the hood (shared/WeaponMounts,
-- WeaponLooks). It is the Flame's own look, the same for every skin, so a skin never changes
-- where the fire starts (looks only, no pay-to-win).
local flameLook = assert(WeaponLooks.forWeapon(Flame.NAME, nil), "the Flame has no look")
local AHEAD, UP = WeaponMounts.muzzle(flameLook.mount, flameLook.muzzles[1])
Flame.MUZZLE = AHEAD * 5.5 * S -- ahead of the kart centre
Flame.HEIGHT = UP * 5.5 * S -- above the kart centre

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

-- Tick i's share of BURST_DAMAGE, in whole numbers that add up to it exactly (5,6,6,5,6,6).
function Flame.tickDamage(i: number): number
	local n = Flame.TICKS
	return math.floor(Flame.BURST_DAMAGE * i / n) - math.floor(Flame.BURST_DAMAGE * (i - 1) / n)
end

-- bumped by clear(): ticks still queued from an older burst do nothing
local gen = 0

local function flat(v: Vector3): Vector3?
	local f = vector.create(v.x, 0, v.z)
	local m = vector.magnitude(f)
	if m ~= m or m < 1e-4 then
		return nil
	end
	return f / m
end

-- True when a kart at `at` is in the fire: alive, within RANGE of `from` (flat, seen from above)
-- and within CONE_DEG of `dir`.
function Flame.inFire(from: Vector3, dir: Vector3, at: Vector3): boolean
	local to = vector.create(at.x - from.x, 0, at.z - from.z)
	local d = vector.magnitude(to)
	if d ~= d or d > Flame.RANGE then
		return false
	end
	if d < 1e-4 then
		return true -- (right on the nozzle)
	end
	local cosA = math.clamp(vector.dot(to / d, dir), -1, 1)
	return math.acos(cosA) <= math.rad(Flame.CONE_DEG)
end

-- One tick of fire from the shooter's spot right now, along `turn` (the aim in kart space, so the
-- burst turns with the kart). Returns the ids it burned.
function Flame.tick(shooterId: any, turn: Vector3, ctx: Ctx, i: number): { any }
	local shooter = ctx.getKart(shooterId)
	if not shooter or not shooter.alive then
		return {}
	end
	local cf = shooter.cframe
	local look = flat(cf.LookVector) or vector.create(0, 0, -1)
	local right = vector.create(-look.z, 0, look.x)
	local dir = flat(look * turn.z + right * turn.x) or look
	local from = cf.Position + look * Flame.MUZZLE + vector.create(0, Flame.HEIGHT, 0)
	local hurt = {}
	local burned = {}
	for _, k in ctx.karts() do
		if k.id ~= shooterId and k.alive and Flame.inFire(from, dir, k.cframe.Position) then
			-- a wall (or another kart's body) in the way stops the fire; the kart's own body does not
			local hit = ctx.raycast(from, k.cframe.Position, shooterId)
			if hit == nil or hit.kartId == k.id then
				local taken = ctx.damage(k.id, shooterId, Flame.tickDamage(i), Flame.NAME)
				local did = if type(taken) == "number" then taken else Flame.tickDamage(i)
				table.insert(burned, k.id)
				if did > 0 then
					table.insert(hurt, { id = k.id, damage = did })
				end
			end
		end
	end
	ctx.fx("FlameTick", {
		pos = from,
		to = from + dir * Flame.RANGE,
		hit = #burned > 0,
		owner = shooterId,
		hurt = hurt,
	})
	return burned
end

-- The weapon contract: one burst along `aim` (WeaponServer already checked it). The first tick
-- goes now, the rest every GAP seconds; a tick does nothing once the shooter is smashed.
function Flame.fire(kart: Kart, aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local look = flat(kart.cframe.LookVector) or vector.create(0, 0, -1)
	-- the aim held to Weapons.MAX_AIM_DEG off the nose, so a cheat can't burn sideways
	local want = Weapons.aim(aim, look)
	local right = vector.create(-look.z, 0, look.x)
	local turn = vector.create(vector.dot(want, right), 0, vector.dot(want, look))
	local id = kart.id
	local myGen = gen
	local from = kart.cframe.Position + look * Flame.MUZZLE + vector.create(0, Flame.HEIGHT, 0)
	ctx.fx("FlameBurst", {
		pos = from,
		to = from + want * Flame.RANGE,
		life = (Flame.TICKS - 1) * Flame.GAP + Flame.GAP,
		range = Flame.RANGE,
		owner = id,
	})
	Flame.tick(id, turn, ctx, 1)
	for i = 2, Flame.TICKS do
		ctx.after(Flame.GAP * (i - 1), function()
			if gen ~= myGen then
				return
			end
			Flame.tick(id, turn, ctx, i)
		end)
	end
	return true
end

-- Match end / reset: the rest of any burst in the air is dropped.
function Flame.clear(_ctx: Ctx?)
	gen += 1
end

return Flame
