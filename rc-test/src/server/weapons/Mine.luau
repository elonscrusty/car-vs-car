--!strict
-- Mine ("Mine" from a "?" box). One tap of FIRE drops a mine on the road behind the kart. It arms
-- after ARM seconds; then any other kart that drives within RADIUS sets it off and takes DAMAGE.
-- Your own mines never hurt you. The server checks every trigger (step, each server tick) with
-- plain distance maths, no physics touches, so a client can't fake or dodge a hit.
-- The mine itself is a server part (everyone sees it, also players who join late); the boom
-- is "MineBoom" fx ("MineDrop" when one lands, for its sound). Plain `vector` maths, so Lune
-- tests run it.

local Mine = {}

Mine.NAME = "Mine"
-- RC size: big units (a kart is 3 x 5.5 big) times SCALE (= TrackData.RC_SCALE; a test checks)
Mine.SCALE = 0.25
local S = Mine.SCALE
Mine.ammo = 3 -- mines per box
Mine.cooldown = 0.6
Mine.ARM = 0.5 -- seconds before a dropped mine can go off
Mine.RADIUS = 5 * S -- mine to a kart's centre: touching its nose or side sets it off
Mine.DAMAGE = 34 -- three hits smash a kart
Mine.LIFE = 30 -- seconds; an untouched mine fizzles out
Mine.PER_KART = 3 -- live mines per kart; a 4th removes that kart's oldest
Mine.BEHIND = 5 * S -- behind the kart centre: just clear of its tail
Mine.DROP = 1.5 * S -- below the kart centre (on the road)

export type Kart = { id: any, cframe: CFrame, alive: boolean }
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	-- returns the health it really took (0 = blocked: a shield, not in the match)
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> number?,
	fx: (kind: string, data: { [string]: any }) -> (),
	place: ((kind: string, at: Vector3) -> Instance?)?,
}

export type LiveMine = {
	n: number,
	owner: any,
	position: Vector3,
	armsAt: number,
	diesAt: number,
	part: Instance?,
}

local live: { LiveMine } = {}
local count = 0

-- A small low-poly mine: a dark navy puck with a cherry-red neon light on top (clients blink it),
-- in workspace.Mines. Only used when WeaponServer's ctx has no `place`.
local function build(at: Vector3): Instance
	local cf = CFrame.new(at.X, at.Y, at.Z) -- (by numbers: the pretend server can't take a vector here)
	local model = Instance.new("Model")
	model.Name = "Mine"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, 2.4, 2.4) * S
	base.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(34, 36, 64)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Parent = model
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(0.8, 0.8, 0.8) * S
	light.CFrame = cf + Vector3.new(0, 0.4 * S, 0)
	light.Color = Color3.fromRGB(232, 53, 46)
	light.Material = Enum.Material.Neon
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.CanTouch = false
	light.Parent = model
	model.PrimaryPart = base
	local folder = workspace:FindFirstChild("Mines")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Mines"
		folder.Parent = workspace
	end
	model.Parent = folder
	return model
end

local function remove(i: number)
	local m = table.remove(live, i)
	if m and m.part then
		m.part:Destroy()
	end
end

function Mine.live(): { LiveMine }
	return live
end

-- Where a mine lands for a kart at `cf`: behind it, down on the road, lying flat.
function Mine.dropSpot(cf: CFrame): Vector3
	local l = cf.LookVector
	local back = vector.create(l.x, 0, l.z)
	local m = vector.magnitude(back)
	back = if m > 1e-4 then back / m else vector.create(0, 0, -1)
	return cf.Position - back * Mine.BEHIND - vector.create(0, Mine.DROP, 0)
end

-- The weapon contract: drop one mine.
function Mine.fire(kart: Kart, _aim: Vector3, ctx: Ctx): boolean
	if not kart.alive then
		return false
	end
	local now = ctx.now()
	-- at the limit, this kart's oldest mine goes (live is in drop order)
	local oldest: number? = nil
	local mine = 0
	for i, m in live do
		if m.owner == kart.id then
			mine += 1
			oldest = oldest or i
		end
	end
	if mine >= Mine.PER_KART and oldest then
		remove(oldest)
	end
	local pos = Mine.dropSpot(kart.cframe)
	local part: Instance? = nil
	if ctx.place then
		part = ctx.place("Mine", pos)
	else
		part = build(pos)
	end
	count += 1
	table.insert(live, {
		n = count,
		owner = kart.id,
		position = pos,
		armsAt = now + Mine.ARM,
		diesAt = now + Mine.LIFE,
		part = part,
	})
	ctx.fx("MineDrop", { position = pos, owner = kart.id })
	return true
end

-- Each server tick: old mines fizzle; an armed mine with another live kart close by goes off
-- (one boom per mine; it hurts every other kart inside the radius, never its owner).
function Mine.step(ctx: Ctx, _dt: number?)
	local now = ctx.now()
	local karts = ctx.karts()
	local i = 1
	while i <= #live do
		local m = live[i]
		if now >= m.diesAt then
			remove(i)
			continue
		end
		if now < m.armsAt then
			i += 1
			continue
		end
		local victims = {}
		for _, k in karts do
			if k.alive and k.id ~= m.owner then
				if vector.magnitude(k.cframe.Position - m.position) <= Mine.RADIUS then
					table.insert(victims, k.id)
				end
			end
		end
		if #victims == 0 then
			i += 1
			continue
		end
		remove(i)
		-- hurt: only the karts that really lost health (an older ctx returns nothing: all of it)
		local hurt = {}
		for _, id in victims do
			local taken = ctx.damage(id, m.owner, Mine.DAMAGE, Mine.NAME)
			taken = if type(taken) == "number" then taken else Mine.DAMAGE
			if taken > 0 then
				table.insert(hurt, { id = id, damage = taken })
			end
		end
		ctx.fx("MineBoom", { position = m.position, owner = m.owner, hurt = hurt })
	end
end

-- Match end / reset: every mine goes, with no boom.
function Mine.clear(_ctx: Ctx?)
	for i = #live, 1, -1 do
		remove(i)
	end
end

return Mine
