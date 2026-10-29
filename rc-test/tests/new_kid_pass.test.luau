--!nocheck
-- Car VS Car SMASH: a new kid's first match on the real server scripts (auditor R4-1). A kid with
-- no skill, driving like the real game: the Studio test thumb's brain (shared/ThumbBrain: boxes
-- when empty-handed, chases a kart when armed, sees 0.3 s late, wobbles, backs up) on a kart with
-- the real RC car's numbers (Tuning: top speed, grip-limited steering, wheelbase) that bumps into the
-- arena's walls and trees, and FIRE up the real remote a ping late, aimed where the camera looks.
-- (The old pretend kid slid with instant turns through walls: it passed while Studio's thumb
-- came 8th.) Against the real bots (ArenaBots: easy on a rookie) and the real weapons, it must
-- get 2+ smashes and a top-5 place, and be smashed 1-3 times itself (some chaos), but never in
-- the first 30 s, in 16 of 20 seeded first matches (20, not 10: one seed swinging can't flip it).
-- And no cliff after the rookie matches (auditor R9-3): the same kid in a later match, against
-- full bots, still makes the top half with 3+ smashes in 12 of 20.
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: a no-skill new kid's first match")

local KID = 601
local RUNS, NEED = 20, 16
local BEAT = 0.05
local PING = 0.1 -- s: the FIRE press reaches the server this late (a phone on wifi)
local CAM_LAG = 0.2 -- s: FIRE aims where the chase camera looks, a little behind the nose
local FIRE_GAP = 0.12 -- s between FIRE presses the button lets through (MatchHud)

-- The kid drives like the real RC kart (Tuning's top speed, grip-limited steering, the wheelbase,
-- RC scale) and bumps into the arena's walls and trees (ArenaBrain.blocked). Its thumb is the
-- Studio test thumb's (shared/ThumbBrain: sees ~0.3 s late, wobbles, FIRE a moment after a kart
-- lines up), and FIRE goes up the real remote PING s late, aimed where the camera looks.
local function kid(S, player)
	local TrackData = S.require("Shared.TrackData")
	local LobbyLayout = S.require("Shared.LobbyLayout")
	local Weapons = S.require("Shared.Weapons")
	local Tuning = S.require("Shared.Tuning")
	local ThumbBrain = S.require("Shared.ThumbBrain")
	local ArenaBrain = S.require("Shared.ArenaBrain")
	local ArenaData = S.require("Shared.ArenaData")
	local MR = S.require("MatchRunner")
	local CollectionService = S.game:GetService("CollectionService")
	local world = ArenaBrain.fromArena(ArenaData)
	local brain = ThumbBrain.new(ArenaBrain.rng(math.random(1, 2 ^ 30))) -- (math.randomseed(seed))
	local scale = TrackData.RC_SCALE
	local accel, base = Tuning.accel * scale, 2 * Tuning.wheelZ * scale
	local top = Tuning.topSpeed * scale
	local brakeAccel, reverseTop = Tuning.brakeAccel * scale, Tuning.reverseTop * scale
	local lastFire = -math.huge
	local seen, t = 0, nil
	local x, y, z, fx, fz, v, wheel = 0, 0, 0, 0, -1, 0, 0
	local backing = false
	local looks = {} :: { { at: number, x: number, z: number } }
	local shots = {} :: { { at: number, aim: any } }
	local me = {
		smashed = {} :: { number },
		startAt = nil :: number?,
		alive = true,
		backs = 0,
		shots = 0,
		picks = 0,
		held = false,
		crawl = 0,
		armedFor = 0,
		inCone = 0,
	}
	local function toLocal(px: number, pz: number): (number, number)
		local lx, _, lz = TrackData.toLocal(t, true, px, y, pz)
		return lx, lz
	end
	-- what the kid sees of the arena (cliffs, ramps), as TestThumb hands ThumbBrain
	local map = {
		sight = function(ax: number, az: number, bx: number, bz: number): boolean
			local lax, laz = toLocal(ax, az)
			local lbx, lbz = toLocal(bx, bz)
			return ArenaBrain.sight(world, lax, laz, lbx, lbz)
		end,
		via = function(px: number, pz: number, gx: number, gz: number): (number, number)
			local lx, lz = toLocal(px, pz)
			local lgx, lgz = toLocal(gx, gz)
			local wx, wz = ArenaBrain.via(world, lx, lz, lgx, lgz)
			if wx == lgx and wz == lgz then
				return gx, gz
			end
			local ox, _, oz = TrackData.toWorld(t, true, wx, y, wz)
			return ox, oz
		end,
	}
	S.game:GetService("RunService").Heartbeat:Connect(function(dt)
		local car = S.workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and car.PrimaryPart
		if not body then
			return
		end
		local now = S.now()
		-- FIRE presses that have reached the server by now
		while shots[1] and shots[1].at <= now do
			S.send(player, Weapons.REMOTE, table.remove(shots, 1).aim)
			me.shots += 1
		end
		local drives = S.got(player, "RCControl", "drive")
		if #drives > seen then
			seen = #drives
			local g = drives[#drives][4]
			if type(g) == "table" then
				t = LobbyLayout.track(drives[#drives][3])
				x, y, z = TrackData.toWorld(t, true, g.x, g.y, g.z)
				local ax, _, az =
					TrackData.toWorld(t, true, g.x + (g.dx or 0), g.y, g.z + (g.dz or -1))
				local d = math.sqrt((ax - x) ^ 2 + (az - z) ^ 2)
				if d > 1e-3 then
					fx, fz = (ax - x) / d, (az - z) / d
				end
				v, wheel = 0, 0
				ThumbBrain.calm(brain) -- (a respawn, as TestThumb does)
			end
		end
		body.AssemblyLinearVelocity = roblox.Vector3.zero
		-- (when the kid gets smashed, s into the round)
		if player:GetAttribute("InMatch") then
			me.startAt = me.startAt or now
			local up = (player:GetAttribute("Health") or 0) > 0
			if me.alive and not up then
				table.insert(me.smashed, now - (me.startAt :: number))
			end
			me.alive = up
		end
		if
			not (t and player:GetAttribute("InMatch") and (player:GetAttribute("Health") or 0) > 0)
		then
			return
		end
		local boxes = {}
		for _, m in CollectionService:GetTagged("SmashBox") do
			local home = m:GetAttribute("Home")
			if m:GetAttribute("Up") == true and home then
				table.insert(boxes, { x = home.Position.X, z = home.Position.Z })
			end
		end
		local karts = {}
		for _, k in MR.karts() do
			if k.id ~= player.UserId and k.alive and k.pos then
				table.insert(karts, { x = k.pos.X, z = k.pos.Z })
			end
		end
		local ammo = player:GetAttribute("Ammo")
		local w = player:GetAttribute("Weapon")
		local armed = type(w) == "string" and w ~= "" and (type(ammo) ~= "number" or ammo > 0)
		if armed and not me.held then
			me.picks += 1
		end
		me.held = armed
		if armed then
			me.armedFor += dt
		end
		if math.abs(v) < 2 then
			me.crawl += dt
		end
		local out = ThumbBrain.step(
			brain,
			now,
			{ x = x, z = z, fx = fx, fz = fz, speed = math.abs(v) },
			boxes,
			karts,
			armed,
			if t then map else nil
		)
		local steer = out.steer
		-- (the thumb backs up itself, ThumbBrain: brake slows the kart, then reverses it, as RCCar)
		if out.brake > 0 and not backing then
			me.backs += 1
		end
		backing = out.brake > 0
		-- the kart: speed, front wheels that turn at steerRate up to the grip limit, wheelbase
		if out.brake > 0 and v > 0.5 then
			v = math.max(v - out.brake * brakeAccel * dt, 0)
		elseif out.brake > 0 then
			v = math.max(v - out.brake * accel * dt, -reverseTop)
		else
			v = math.clamp(v + out.throttle * accel * dt, -reverseTop, top)
		end
		local lim = Tuning.steerLow
			+ (Tuning.steerHigh - Tuning.steerLow)
				* math.clamp(math.abs(v) / top, 0, 1) ^ Tuning.steerCurve
		local want = steer * lim
		wheel += math.clamp(want - wheel, -Tuning.steerRate * dt, Tuning.steerRate * dt)
		local turn = v * math.tan(wheel) / base * dt -- + = to the right
		local c, s = math.cos(turn), math.sin(turn)
		fx, fz = fx * c - fz * s, fz * c + fx * s -- (right of (fx, fz) is (-fz, fx))
		local nx, nz = x + fx * v * dt, z + fz * v * dt
		local function hit(px: number, pz: number): boolean
			return ArenaBrain.blocked(world, toLocal(px, pz))
		end
		local x0, z0 = x, z
		if not hit(nx, nz) then
			x, z = nx, nz
		elseif not hit(nx, z) then
			x = nx
		elseif not hit(x, nz) then
			z = nz
		end
		if x ~= nx or z ~= nz then
			-- scraping a wall: the kart only goes as fast as it really moves along its nose
			-- (so a nose on a wall reads as stuck, as on the real kart)
			v = if dt > 0 then ((x - x0) * fx + (z - z0) * fz) / dt else 0
		end
		body.CFrame =
			roblox.CFrame.lookAt(roblox.Vector3.new(x, y, z), roblox.Vector3.new(x + fx, y, z + fz))
		body.AssemblyLinearVelocity = roblox.Vector3.new(fx, 0, fz) * v
		-- the camera's look: the nose CAM_LAG s ago
		table.insert(looks, { at = now, x = fx, z = fz })
		while #looks > 1 and looks[2].at <= now - CAM_LAG do
			table.remove(looks, 1)
		end
		if out.fire and now - lastFire >= FIRE_GAP then
			lastFire = now
			local l = looks[1]
			table.insert(shots, { at = now + PING, aim = roblox.Vector3.new(l.x, 0, l.z) })
		end
	end)
	return me
end

-- `matches`: how many the kid has played before (nil: none, a first match)
local function firstMatch(seed: number, matches: number?): (number, number, { number }, number)
	math.randomseed(seed) -- (bot names, spawn picks: math.random)
	local S = Fake.server(Fake.store(), { seed = seed, jobId = "newkid-" .. seed })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local p = S.join(KID)
	local me = kid(S, p)
	S.advance(2 + seed * 0.37, BEAT) -- (joins at a different moment each time)
	S.send(p, "Garage", "pick", "race_bolt")
	S.advance(1, BEAT)
	if matches then
		-- a kid who has played before: past the rookie matches, raced, no new-kid safety
		local data = S.require("PlayerData").get(p)
		local Profile = S.require("Shared.Profile")
		data.matches = matches
		data.stage = math.max(data.stage, Profile.STAGE.RACED)
	end
	MR.join(p)
	local t0 = S.now()
	while #S.got(p, "MatchResult") == 0 and S.now() - t0 < MR.MATCH_SECS + 30 do
		S.advance(1, BEAT)
	end
	local smashes, place = p:GetAttribute("Smashes") or 0, p:GetAttribute("Place") or 0
	S.close()
	print(
		string.format(
			"         (boxes %d, shots %d, %.0f s at a crawl, %.0f s armed)",
			me.picks,
			me.shots,
			me.crawl,
			me.armedFor
		)
	)
	return smashes, place, me.smashed, me.backs
end

test(
	"a no-skill kid's first match: 2+ smashes, top 5 and smashed 1-3 times (never in the first 30 s) in 16 of 20 runs",
	function()
		local good, early = 0, 0
		for seed = 1, RUNS do
			local smashes, place, smashed, backs = firstMatch(seed)
			local first = smashed[1]
			if first and first < 30 then
				early += 1
			end
			local ok = smashes >= 2
				and place >= 1
				and place <= 5
				and #smashed >= 1
				and #smashed <= 3
			if ok then
				good += 1
			end
			print(
				string.format(
					"       seed %d: %d smashes, place %d, smashed %d times (first at %s), backed up %d times%s",
					seed,
					smashes,
					place,
					#smashed,
					if first then string.format("%.0f s", first) else "-",
					backs,
					if ok then "" else "  <- miss"
				)
			)
		end
		print(string.format("       %d of %d first matches pass", good, RUNS))
		truthy(good >= NEED, `{good} of {RUNS}`)
		eq(early, 0, "smashed in the first 30 s")
	end
)

test(
	"no cliff after the rookie matches: the same kid in their 6th match (full bots) is top 4 with 3+ smashes in 12 of 20 runs",
	function()
		local good = 0
		for seed = 1, RUNS do
			local smashes, place, smashed = firstMatch(100 + seed, 5)
			local ok = smashes >= 3 and place >= 1 and place <= 4
			if ok then
				good += 1
			end
			print(
				string.format(
					"       seed %d: %d smashes, place %d, smashed %d times%s",
					100 + seed,
					smashes,
					place,
					#smashed,
					if ok then "" else "  <- miss"
				)
			)
		end
		print(string.format("       %d of %d 6th matches pass", good, RUNS))
		truthy(good >= 12, `{good} of {RUNS}`)
	end
)

test(
	"a seasoned kid (11th match, the sharpest bots): top 4 in about 4 of 5, 1st in only about a third, smashed 4-8 times",
	function()
		local top4, wins, hurt = 0, 0, 0
		for seed = 1, RUNS do
			local smashes, place, smashed = firstMatch(200 + seed, 10)
			if place >= 1 and place <= 4 then
				top4 += 1
			end
			if place == 1 then
				wins += 1
			end
			hurt += #smashed
			print(
				string.format(
					"       seed %d: %d smashes, place %d, smashed %d times",
					200 + seed,
					smashes,
					place,
					#smashed
				)
			)
		end
		local avg = hurt / RUNS
		print(
			string.format(
				"       top 4 in %d of %d, 1st in %d, smashed %.1f times a match",
				top4,
				RUNS,
				wins,
				avg
			)
		)
		truthy(top4 >= 14, `top 4 in {top4} of {RUNS}`)
		truthy(wins >= 4 and wins <= 9, `1st in {wins} of {RUNS}`)
		truthy(avg >= 4 and avg <= 8, `smashed {avg} times a match`)
	end
)
