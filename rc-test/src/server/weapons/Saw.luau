--!strict
-- Saw (the Road Saw car's buzzsaw, car 7). One tap of FIRE revs the saw built into the nose for REV
-- seconds. While it is revving, any other live kart whose middle sits in the strip just ahead of
-- the nose takes DAMAGE every TICK seconds (it keeps cutting as long as they touch). Karts and
-- walls are not pushed; the saw only hurts. A shield blocks it (ctx.damage returns 0). Your own
-- saw never hurts you.
-- The server checks every cut with plain distance maths (step, each server tick), so a client
-- can't fake or dodge one. Clients get "SawRev" { owner, seconds } (the blades spin fast) and
-- "SawHit" { owner, id, position } (sparks) to draw. Plain `vector` maths, so Lune tests run it.

local Saw = {}

Saw.NAME = "Saw"
-- RC size: big units (a kart is 3 x 5.5 big) times SCALE (= TrackData.RC_SCALE; a test checks)
Saw.SCALE = 0.25
local S = Saw.SCALE
Saw.ammo = 3 -- revs per pickup
Saw.cooldown = 1
Saw.REV = 4 -- seconds the saw spins hard after a tap
Saw.TICK = 0.25 -- seconds between cuts on one kart
Saw.DAMAGE = 9 -- a cut (health 100): about 3 seconds of touching smashes a kart
Saw.REACH = 7.5 * S -- the strip's far end, ahead of the saw kart's middle (its nose is at 2.75)
Saw.BACK = 1.5 * S -- and its near end: a kart already alongside the nose still gets cut
Saw.WIDE = 3 * S -- half the strip's width, to either side of the nose

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean? }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	-- returns the health it really took (0 = blocked: a shield, not in the match)
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> number?,
	fx: (kind: string, data: { [string]: any }) -> (),
}

-- kart id -> server time its rev ends
local revUntil: { [any]: number } = {}
-- "owner>victim" -> server time of the next cut on that kart
local nextCut: { [string]: number } = {}

-- Is a kart middle at `pos` in the strip ahead of the saw kart at `cf`? (flat, seen from above)
function Saw.inStrip(cf: CFrame, pos: Vector3): boolean
	local look = cf.LookVector
	local fwd = vector.create(look.x, 0, look.z)
	local m = vector.magnitude(fwd)
	if m < 1e-4 then
		return false
	end
	fwd /= m
	local side = vector.create(-fwd.z, 0, fwd.x)
	local to = vector.create(pos.x - cf.Position.x, 0, pos.z - cf.Position.z)
	local ahead = vector.dot(to, fwd)
	local across = math.abs(vector.dot(to, side))
	return ahead >= -Saw.BACK and ahead <= Saw.REACH and across <= Saw.WIDE
end

function Saw.revving(id: any, now: number): boolean
	local t = revUntil[id]
	return t ~= nil and now < t
end

-- The weapon contract: rev the saw (a tap while revving just runs it again from full).
function Saw.fire(kart: Kart, _aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	revUntil[kart.id] = ctx.now() + Saw.REV
	ctx.fx("SawRev", { owner = kart.id, seconds = Saw.REV })
	return true
end

-- Each server tick: every revving kart cuts the karts in its strip (one cut per TICK per kart).
function Saw.step(ctx: Ctx, _dt: number?)
	if next(revUntil) == nil then
		return
	end
	local now = ctx.now()
	local karts = ctx.karts()
	for _, k in karts do
		local owner = k.id
		local until_ = revUntil[owner]
		if until_ == nil then
			continue
		end
		if now >= until_ or not k.alive then
			revUntil[owner] = nil
			continue
		end
		for _, v in karts do
			if v.id ~= owner and v.alive and Saw.inStrip(k.cframe, v.cframe.Position) then
				local key = tostring(owner) .. ">" .. tostring(v.id)
				if now >= (nextCut[key] or 0) then
					nextCut[key] = now + Saw.TICK
					local taken = ctx.damage(v.id, owner, Saw.DAMAGE, Saw.NAME)
					taken = if type(taken) == "number" then taken else Saw.DAMAGE
					if taken > 0 then
						ctx.fx("SawHit", { owner = owner, id = v.id, position = v.cframe.Position })
					end
				end
			end
		end
	end
end

-- Match end / reset: every saw stops.
function Saw.clear(_ctx: Ctx?)
	table.clear(revUntil)
	table.clear(nextCut)
end

return Saw
