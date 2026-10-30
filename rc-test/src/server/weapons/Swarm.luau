--!strict
-- FIRE SWARM on the server (shared/FireSwarm has the numbers): the special's one engine. A tap
-- picks the kart to lock onto, tells clients (SwarmLaunch), and queues one dive and one boom per
-- rocket. Each boom lands where the locked kart is at that moment (or where it was when the lock
-- ended if the kart is gone) and hurts through ctx.damage like every other weapon. Clients only
-- draw:
--   "SwarmLaunch" { owner, from, dir, to, target?, count }  the rockets climb out of the car
--   "SwarmLock"   { owner, to }                             the red ring follows the target
--   "SwarmDive"   { owner, i, to, arrive }                  rocket i dives onto `to`
--   "SwarmBoom"   { owner, i, pos, hurt }                   rocket i blew up (hurt = { { id, damage } })
--   "SwarmClear"  { }                                       match over: every swarm vanishes
-- Plain Luau with the shared modules passed in, so Lune tests run it with a fake ctx.

local Swarm = {}

Swarm.LOCK_STEP = 0.25 -- the ring is moved this often until the dives begin

function Swarm.weapon(Weapons: any, Data: any): { [string]: any }
	local W = {}
	W.NAME = Data.NAME
	local generation = 0 -- a match ending bumps it: swarms still queued do nothing
	local pending = 0 -- rockets queued, all karts together

	local function targets(ctx: any): { any }
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

	function W.fire(kart: any, aim: Vector3, ctx: any): boolean
		if pending + Data.COUNT > Data.MAX_PENDING then
			return false
		end
		local from = Weapons.vec(kart.cframe.Position) or vector.zero
		local lock = Data.lock(from, aim, targets(ctx), kart.id)
		local targetId = if lock then lock.id else nil
		local start = if lock then Weapons.vec(lock.pos) else nil
		start = start or (from + aim * Data.BLIND)
		local mine = generation
		local owner = kart.id
		pending += Data.COUNT

		-- where the swarm lands now: the locked kart, else where it last was
		local last: Vector3 = start :: Vector3
		local function landing(): Vector3
			if targetId ~= nil then
				local k = ctx.getKart(targetId)
				local pos = k and k.alive and Weapons.vec(k.cframe.Position)
				if pos then
					last = pos
				end
			end
			return last
		end

		ctx.fx("SwarmLaunch", {
			owner = owner,
			from = from,
			dir = aim,
			to = last,
			target = targetId,
			count = Data.COUNT,
		})
		-- the red ring follows the target until the first dive
		local locks = math.floor(Data.DIVE_AT / Swarm.LOCK_STEP)
		for s = 1, locks do
			ctx.after(s * Swarm.LOCK_STEP, function()
				if generation == mine then
					ctx.fx("SwarmLock", { owner = owner, to = landing() })
				end
			end)
		end
		for i = 0, Data.COUNT - 1 do
			ctx.after(Data.diveTime(i), function()
				if generation == mine then
					ctx.fx(
						"SwarmDive",
						{ owner = owner, i = i, to = landing(), arrive = Data.DIVE }
					)
				end
			end)
			ctx.after(Data.boomTime(i), function()
				if generation ~= mine then
					return
				end
				pending = math.max(0, pending - 1)
				local at = landing()
				local list = targets(ctx)
				-- a direct hit: the locked kart is (still) where the boom is, and not shielded
				local direct = nil
				for _, t in list do
					if
						t.id == targetId
						and not t.shield
						and vector.magnitude(t.pos - at) <= Data.SPEC.hitRadius
					then
						direct = t.id
					end
				end
				local hurt = {}
				for _, d in Weapons.boom(at, list, owner, direct, Data.SPEC) do
					local ok, taken = pcall(ctx.damage, d.id, owner, d.damage, Data.NAME)
					if not ok then
						warn("[Swarm] damage failed: " .. tostring(taken))
					elseif type(taken) ~= "number" or taken > 0 then
						table.insert(hurt, {
							id = d.id,
							damage = if type(taken) == "number" then taken else d.damage,
						})
					end
				end
				ctx.fx("SwarmBoom", { owner = owner, i = i, pos = at, hurt = hurt })
			end)
		end
		return true
	end

	-- Match over: swarms on their way vanish without hurting anyone.
	function W.clear(ctx: any)
		generation += 1
		pending = 0
		ctx.fx("SwarmClear", {})
	end

	-- (tests) rockets queued now
	function W.pending(): number
		return pending
	end

	return W
end

return Swarm
