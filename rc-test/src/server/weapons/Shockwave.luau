--!strict
-- SHOCKWAVE, the Ice Viper's special (carter picked "Ice Rings" 10-29). It follows the weapon
-- contract (fire / clear), but it is not in a "?" box: the special button's slot spends it
-- (shared/Shockwave.slot: ready after REFILL seconds) and calls fire(kart, aim, ctx).
-- The Nose Cannon charges for CHARGE seconds, then rings leave its muzzle in a fan. Each kart in
-- the fan is hurt and shoved when the rings reach it (ctx.push, if the server has one): the server
-- decides all of it, clients only draw "Shockwave" (the rings) and "ShockHit" (a flash) and obey
-- "Knock" for their own car. Plain `vector` maths, so Lune tests run it.

-- shared/Shockwave: Roblox from ReplicatedStorage, plain Lune (tests) by path
local function shared(name: string): any
	if script then
		local rs: any = game:GetService("ReplicatedStorage")
		return require(rs:WaitForChild("Shared"):WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("../../shared/" .. name)
end

local Core = shared("Shockwave")

local Shockwave = {}

Shockwave.NAME = Core.NAME
Shockwave.ammo = 1
Shockwave.cooldown = Core.REFILL

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean? }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	-- returns the health it really took (0 = blocked: a shield, not in the match)
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> number?,
	fx: (kind: string, data: { [string]: any }) -> (),
	after: (seconds: number, fn: () -> ()) -> (),
	-- shoves kart `id`: v = a flat velocity to add (studs/s), up = a hop (studs/s)
	push: ((id: any, v: Vector3, up: number) -> ())?,
}

-- bumped by clear(): shoves still waiting on their rings do nothing
local gen = 0

-- The weapon contract: the rings leave the kart's nose now (after the charge glow). `aim` is
-- ignored: the cannon points where the kart faces.
function Shockwave.fire(kart: Kart, _aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local from, look = Core.muzzle(kart)
	local owner = kart.id
	local hits = Core.victims(from, look, ctx.karts(), owner)
	local who = {}
	for _, v in hits do
		table.insert(who, { id = v.id, delay = v.delay })
	end
	ctx.fx("Shockwave", {
		from = from,
		dir = look,
		owner = owner,
		charge = Core.CHARGE,
		range = Core.RANGE,
		speed = Core.SPEED,
		arc = Core.ARC_DEG,
		hits = who,
	})
	local myGen = gen
	for _, v in hits do
		ctx.after(v.delay, function()
			if gen ~= myGen then
				return
			end
			-- the kart as it is when the rings arrive: smashed, or in a respawn bubble, it is skipped
			local k = ctx.getKart(v.id)
			local shooter = ctx.getKart(owner)
			if not k or not k.alive or k.shield == true or not shooter or not shooter.alive then
				return
			end
			local taken = ctx.damage(v.id, owner, Core.DAMAGE, Core.NAME)
			local hurt = if type(taken) == "number" then taken else Core.DAMAGE
			ctx.fx("ShockHit", {
				id = v.id,
				position = k.cframe.Position,
				owner = owner,
				hurt = if hurt > 0 then { { id = v.id, damage = hurt } } else {},
			})
			if ctx.push then
				ctx.push(v.id, v.push, v.up)
			end
		end)
	end
	return true
end

-- Match end / reset: shoves still on their way are dropped.
function Shockwave.clear(_ctx: Ctx?)
	gen += 1
end

return Shockwave
