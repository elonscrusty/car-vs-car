--!strict
-- Machine gun ("Gun" from a "?" box). One tap of FIRE = one short burst of bullets.
-- The server decides every bullet: it picks the target in front of the kart (a little aim help,
-- so a phone thumb and a bot play fair), checks the line of sight with a ray, then calls
-- ctx.damage. The client only sees "GunShot" fx (a tracer from the muzzle to where it hit).
-- The client's aim is ignored: the kart's own facing is the aim.

local Gun = {}

Gun.ammo = 4 -- bursts per box
Gun.cooldown = 0.45 -- seconds between bursts (a burst lasts BULLETS-1 gaps = 0.35 s)
Gun.BULLETS = 6
Gun.GAP = 0.07 -- seconds between bullets in a burst
Gun.DAMAGE = 5 -- per bullet; a full burst is 30, so 4 full bursts smash a kart (health 100)
Gun.RANGE = 110 -- studs
Gun.CONE = math.cos(math.rad(18)) -- a target this close to straight ahead gets aimed at
Gun.MUZZLE = 4 -- studs in front of the kart centre
Gun.HEIGHT = 1.5 -- studs above the kart centre

export type Kart = { id: any, cframe: CFrame, alive: boolean }
export type Hit = { kartId: any?, position: Vector3 }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	-- first thing between the two points (world or a kart other than ignoreId); nil when clear
	raycast: (from: Vector3, to: Vector3, ignoreId: any?) -> Hit?,
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> (),
	fx: (kind: string, data: { [string]: any }) -> (),
	after: (seconds: number, fn: () -> ()) -> (),
}

local function muzzle(cf: CFrame): Vector3
	return cf.Position + cf.LookVector * Gun.MUZZLE + cf.UpVector * Gun.HEIGHT
end

-- The best target for a shooter: alive, not the shooter, in range and inside the aim cone.
-- The one closest to straight ahead wins (ties go to the nearer one). `prefer` keeps a burst on
-- the kart it started on while that kart is still a fair target.
function Gun.pickTarget(shooter: Kart, karts: { Kart }, prefer: any?): Kart?
	local from = shooter.cframe.Position
	local look = shooter.cframe.LookVector
	local best: Kart? = nil
	local bestScore = -math.huge
	for _, k in karts do
		if k.id == shooter.id or not k.alive then
			continue
		end
		local to = k.cframe.Position - from
		local dist = to.Magnitude
		if dist < 0.001 or dist > Gun.RANGE then
			continue
		end
		local dot = look:Dot(to / dist)
		if dot < Gun.CONE then
			continue
		end
		if k.id == prefer then
			return k
		end
		local score = dot - dist / (Gun.RANGE * 100)
		if score > bestScore then
			best, bestScore = k, score
		end
	end
	return best
end

-- One bullet from the shooter's current spot. Returns the victim's id when it hit a kart.
function Gun.shoot(shooterId: any, ctx: Ctx, prefer: any?): any?
	local shooter = ctx.getKart(shooterId)
	if not shooter or not shooter.alive then
		return nil
	end
	local from = muzzle(shooter.cframe)
	local target = Gun.pickTarget(shooter, ctx.karts(), prefer)
	local to = if target
		then target.cframe.Position
		else from + shooter.cframe.LookVector * Gun.RANGE
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
	if victim ~= nil then
		ctx.damage(victim, shooterId, Gun.DAMAGE, "Gun")
	end
	ctx.fx("GunShot", { from = from, to = endAt, hit = victim ~= nil, shooter = shooterId })
	return victim
end

-- The weapon contract: one burst. The first bullet goes now, the rest every GAP seconds. A
-- bullet stops the burst if the shooter is gone or smashed (Gun.shoot checks).
function Gun.fire(kart: Kart, _aim: any, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local shooterId = kart.id
	local first = Gun.shoot(shooterId, ctx, nil)
	local prefer = first
	for i = 1, Gun.BULLETS - 1 do
		ctx.after(Gun.GAP * i, function()
			local hit = Gun.shoot(shooterId, ctx, prefer)
			if hit ~= nil then
				prefer = hit
			end
		end)
	end
	return true
end

return Gun
