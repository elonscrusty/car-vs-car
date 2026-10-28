--!nocheck
-- Car VS Car SMASH, the match loop on the real server scripts (FINISH-JOBS row LOOPTEST): Main,
-- Stars and CarShop on the pretend server (tests/fakeroblox.luau) with Features.SMASH on. A new
-- kid queues, plays a round in the real MatchRunner (a pretend screen rams the nearest bot: bumps
-- hurt), gets coins and the first round's free crate, opens it, plays the next round (back to
-- back after the break), then leaves and rejoins on a 2nd server. A kid who queues mid-round
-- waits for the next one. Every thread error or warn fails the test.
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: the match loop on the real server scripts")

local KID, LATE = 501, 502
local BEAT = 0.05
local ROUND = 60 -- (a short round keeps the test quick; the rules don't depend on its length)
local RAM_SPEED = 22 -- studs/s, an RC kart near its top speed

local function boot(store, jobId: string)
	local S = Fake.server(store, { jobId = jobId })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	S.require("MatchRunner").MATCH_SECS = ROUND
	return S
end

local function trouble(S): string
	local out = {}
	for _, e in S.errors do
		table.insert(out, "ERROR " .. e)
	end
	for _, w in S.warns do
		table.insert(out, "WARN " .. w)
	end
	return table.concat(out, "\n")
end

local function carIds(data): string
	local ids = {}
	for _, c in data.garage do
		table.insert(ids, c.id)
	end
	return table.concat(ids, ",")
end

-- The kid's screen: puts the car on the spawn the server sent ("drive"), then while in a round
-- rams the nearest live bot (the server sees the car's speed in AssemblyLinearVelocity).
local function rammer(S, player)
	local TrackData = S.require("Shared.TrackData")
	local LobbyLayout = S.require("Shared.LobbyLayout")
	local MR = S.require("MatchRunner")
	local me = { seen = 0, on = true }
	S.game:GetService("RunService").Heartbeat:Connect(function(dt)
		local car = S.workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and car.PrimaryPart
		if not body then
			return
		end
		local drives = S.got(player, "RCControl", "drive")
		if #drives > me.seen then
			me.seen = #drives
			local g = drives[#drives][4]
			if type(g) == "table" then
				local t = LobbyLayout.track(drives[#drives][3])
				body.CFrame = roblox.CFrame.new(TrackData.toWorld(t, true, g.x, g.y, g.z))
			end
		end
		body.AssemblyLinearVelocity = roblox.Vector3.zero
		if
			not (
				me.on
				and player:GetAttribute("InMatch")
				and (player:GetAttribute("Health") or 0) > 0
			)
		then
			return
		end
		local best, bestD = nil, math.huge
		for _, k in MR.karts() do
			if k.id < 0 and k.alive and k.pos then
				local d = (k.pos - body.Position).Magnitude
				if d < bestD then
					best, bestD = k, d
				end
			end
		end
		if not best then
			return
		end
		local dir = (best.pos - body.Position) * roblox.Vector3.new(1, 0, 1)
		if dir.Magnitude < 1e-3 then
			return
		end
		dir = dir.Unit
		local step = math.min(RAM_SPEED * dt, math.max(bestD - 1.4, 0))
		body.CFrame = roblox.CFrame.new(body.Position + dir * step)
		body.AssemblyLinearVelocity = dir * RAM_SPEED
	end)
	return me
end

local store = Fake.store()
local S = boot(store, "smash-A")
local MR = S.require("MatchRunner")
local PlayerData = S.require("PlayerData")
local kid = S.join(KID)
rammer(S, kid)
S.advance(3, BEAT)
local data = PlayerData.get(kid)

-- advance until `cond` or `limit` seconds; returns the seconds it took (nil = never)
local function waitFor(cond: () -> boolean, limit: number): number?
	local t0 = S.now()
	while S.now() - t0 < limit do
		if cond() then
			return S.now() - t0
		end
		S.advance(0.5, BEAT)
	end
	return if cond() then S.now() - t0 else nil
end

local roundStart = 0
local coins0 = 0

test("queue: the kid is in a round within 10 s, full health, 8 karts", function()
	S.send(kid, "Garage", "pick", "race_bolt")
	S.advance(1, BEAT)
	coins0 = data.coins
	eq(MR.join(kid), true, "join")
	local took = waitFor(function()
		return kid:GetAttribute("InMatch") == true
	end, 10)
	truthy(took, "in a round")
	roundStart = S.now()
	eq(kid:GetAttribute("Health"), 100, "health")
	eq(#MR.karts(), 8, "karts (bots fill)")
	truthy(type(S.workspace:GetAttribute("MatchEndsAt")) == "number", "MatchEndsAt")
	eq(trouble(S), "", "errors or warns")
end)

local late
test("a kid who queues mid-round waits for the next one", function()
	late = S.join(LATE)
	S.advance(3, BEAT)
	S.send(late, "Garage", "pick", "race_dart")
	S.advance(1, BEAT)
	eq(MR.join(late), true, "join")
	S.advance(2, BEAT)
	eq(late:GetAttribute("InMatch"), nil, "not in this round")
	eq(late:GetAttribute("MatchQueued"), true, "queued")
	eq(trouble(S), "", "errors or warns")
end)

test("first smash (a bump) within 30 s; the bot is back in 3 s with a shield", function()
	local took = waitFor(function()
		return (kid:GetAttribute("Smashes") or 0) >= 1
	end, 30)
	truthy(took, "a smash within 30 s of spawning")
	print(`       first smash {math.floor(S.now() - roundStart + 0.5)} s into the round`)
	truthy(#S.got(kid, "SmashFeed") >= 1, "the kill feed told the kid")
	-- the smashed bot: down now, back within Match.RESPAWN with a bubble
	local feed = S.got(kid, "SmashFeed")
	local victim = feed[#feed][3]
	local vid = type(victim) == "table"
		and (victim.userId or (victim.kart and tonumber(string.match(victim.kart.Name, "-?%d+$"))))
	truthy(vid, "the feed names the victim's kart")
	local back = waitFor(function()
		for _, k in MR.karts() do
			if k.id == vid then
				return k.alive and k.shield
			end
		end
		return false
	end, 3.5)
	truthy(back, "back within 3 s, shielded")
	eq(trouble(S), "", "errors or warns")
end)

local result1
test("round 1 over: places, coins in the save, the free crate", function()
	local took = waitFor(function()
		return #S.got(kid, "MatchResult") >= 1
	end, ROUND + 5)
	truthy(took, "MatchResult came")
	result1 = S.got(kid, "MatchResult")[1]
	local coins = result1[3]
	truthy(type(coins) == "number" and coins > 0, "paid")
	truthy(data.coins >= coins0 + coins, `coins in the save ({data.coins} vs {coins0} + {coins})`)
	eq(data.crates, 1, "the first round's free crate")
	truthy(type(result1[4]) == "number", "next round time")
	-- the screens' crate count comes from the Garage lists: they must say 1 too
	local lists = S.got(kid, "Garage", "cars")
	eq(lists[#lists][3].crates, 1, "the crate screen knows about the free crate")
	eq(trouble(S), "", "errors or warns")
end)

test("open the crate, then round 2 starts by itself after the break, with the late kid", function()
	-- (opening the first crate opens the daily gift too, and it brings one more crate)
	local had = #data.garage
	S.send(kid, "Garage", "open")
	S.advance(1, BEAT)
	eq(#data.garage, had + 1, "a new car")
	eq(#S.got(kid, "StarsEvent", "daily"), 1, "the daily gift came after the first crate")
	while data.crates > 0 and #data.garage < had + 4 do
		S.send(kid, "Garage", "open")
		S.advance(1, BEAT)
	end
	eq(data.crates, 0, "crates all opened")
	local took = waitFor(function()
		return (S.workspace:GetAttribute("MatchRound") or 0) >= 2
			and kid:GetAttribute("InMatch") == true
	end, 20)
	truthy(took, "round 2 started with the kid in it")
	eq(late:GetAttribute("InMatch"), true, "the late kid is in round 2")
	eq(kid:GetAttribute("Health"), 100, "fresh health")
	eq(kid:GetAttribute("Smashes"), 0, "fresh score")
	eq(trouble(S), "", "errors or warns")
end)

test("round 2 over: paid again, no second free crate", function()
	local took = waitFor(function()
		return #S.got(kid, "MatchResult") >= 2
	end, ROUND + 20)
	truthy(took, "2nd MatchResult")
	eq(data.crates, 0, "no 2nd free crate")
	truthy(#S.got(late, "MatchResult") >= 1, "the late kid got a result")
	eq(trouble(S), "", "errors or warns")
end)

test("leave mid-round 3 and rejoin on another server: coins and cars come back", function()
	waitFor(function()
		return kid:GetAttribute("InMatch") == true
			and (S.workspace:GetAttribute("MatchRound") or 0) >= 3
	end, 20)
	local want = { coins = data.coins, cars = carIds(data), crates = data.crates }
	S.leave(kid)
	S.advance(5, BEAT)
	eq(#MR.karts() <= 8, true, "the round goes on")
	eq(trouble(S), "", "server A errors or warns")
	local S2 = boot(store, "smash-B")
	local kid2 = S2.join(KID)
	S2.advance(3, BEAT)
	local d2 = S2.require("PlayerData").get(kid2)
	truthy(d2, "loaded")
	truthy(
		d2.coins >= want.coins and d2.coins <= want.coins + 5,
		`coins {d2.coins} vs {want.coins}`
	)
	eq(carIds(d2), want.cars, "cars")
	eq(d2.crates, want.crates, "crates")
	eq(trouble(S2), "", "server B errors or warns")
end)
