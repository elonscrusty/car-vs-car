--!strict
-- ROCKETS (Car VS Car SMASH): 3 per pickup. Each flies fast from the kart's nose, bends a little
-- toward the nearest kart ahead (shared/Weapons.step), and booms on the first kart or wall in its
-- path, or at the end of its flight. The server moves every rocket and decides every hit; clients
-- get "RocketLaunch", "RocketTurn" and "RocketBoom" to draw it (client/WeaponFx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))

local Rockets = {}

Rockets.NAME = "Rockets"
Rockets.ammo = Weapons.DEFS.Rockets.ammo
Rockets.cooldown = Weapons.DEFS.Rockets.cooldown
Rockets.MAX_FLYING = 40 -- in the whole server (5 karts x 3 rockets is 15)
Rockets.STEP = 1 / 30 -- the longest bit of flight checked at once
Rockets.TURN_EVERY = 0.1 -- while it bends toward a kart, clients get its new path this often

type Flying = { id: number, r: Weapons.Rocket, sentAt: number }

local flying: { Flying } = {}
local nextId = 0

local function targets(ctx: any): { Weapons.Target }
	local out = {}
	for _, k in ctx.karts() do
		if k.alive then
			table.insert(out, { id = k.id, pos = k.cframe.Position })
		end
	end
	return out
end

function Rockets.fire(kart: any, aim: Vector3, ctx: any): boolean
	if #flying >= Rockets.MAX_FLYING then
		return false
	end
	nextId += 1
	local r = Weapons.rocket(kart.id, kart.cframe.Position, aim)
	table.insert(flying, { id = nextId, r = r, sentAt = ctx.now() })
	ctx.fx("RocketLaunch", { id = nextId, pos = r.pos, dir = r.dir, owner = kart.id })
	return true
end

local function boom(f: Flying, ctx: any, list: { Weapons.Target }, direct: any?)
	for _, d in Weapons.boom(f.r.pos, list, f.r.owner, direct) do
		ctx.damage(d.id, f.r.owner, d.damage, Rockets.NAME)
	end
	ctx.fx("RocketBoom", { id = f.id, pos = f.r.pos, hit = direct })
end

-- Move every rocket; boom the ones that hit something or ran out of time.
function Rockets.step(ctx: any, dt: number)
	if #flying == 0 then
		return
	end
	local list = targets(ctx)
	local i = 1
	while i <= #flying do
		local f = flying[i]
		local owner = f.r.owner
		local blocked = function(from: Vector3, to: Vector3): Vector3?
			local h = ctx.raycast(from, to, owner)
			-- karts are hit by the rocket's own check (a little wider than the kart)
			if h and h.kartId == nil then
				return h.position
			end
			return nil
		end
		local left = math.min(dt, 0.25)
		local what, who = nil, nil
		while left > 0 and what == nil do
			local bit = math.min(left, Rockets.STEP)
			left -= bit
			what, who = Weapons.step(f.r, bit, list, blocked)
		end
		if what ~= nil then
			boom(f, ctx, list, if what == "hit" then who else nil)
			table.remove(flying, i)
		else
			-- bending toward a kart: tell clients the new path now and then (they fly it straight
			-- in between)
			local now = ctx.now()
			if f.r.target ~= nil and now - f.sentAt >= Rockets.TURN_EVERY then
				f.sentAt = now
				ctx.fx("RocketTurn", { id = f.id, pos = f.r.pos, dir = f.r.dir })
			end
			i += 1
		end
	end
end

-- Match over: rockets in the air vanish without hurting anyone.
function Rockets.clear(ctx: any)
	for _, f in flying do
		ctx.fx("RocketBoom", { id = f.id, pos = f.r.pos, quiet = true })
	end
	table.clear(flying)
end

-- (tests) how many are in the air
function Rockets.count(): number
	return #flying
end

return Rockets
