--!nocheck
-- Car VS Car SMASH: more players than seats. 9 kids, 8 karts a round: at the next round the one
-- who doesn't fit waits at the front of the queue, out of the round for real (no InMatch, no
-- match HUD numbers, out of the arena), and gets in the round after.
local H = require("./harness")
local Fake = require("./fakeroblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: a full round")

test(
	"9 kids: the one left over is off the round (no InMatch, out of the arena) and queued first",
	function()
		local S = Fake.server(Fake.store(), { jobId = "overflow" })
		S.require("Shared.Features").SMASH = true
		S.run("Main")
		S.run("Stars")
		S.run("CarShop")
		local MR = S.require("MatchRunner")
		local Match = S.require("Shared.Match")
		local LobbyPlots = S.require("LobbyPlots")
		MR.MATCH_SECS = 20
		local kids = {}
		for i = 1, Match.MAX + 1 do
			kids[i] = S.join(700 + i)
		end
		S.advance(3, 0.1)
		for _, k in kids do
			MR.join(k)
		end
		local function count(attr: string): number
			local n = 0
			for _, k in kids do
				if k:GetAttribute(attr) == true then
					n += 1
				end
			end
			return n
		end
		for _ = 1, 40 do
			if count("InMatch") > 0 then
				break
			end
			S.advance(0.5, 0.1)
		end
		eq(count("InMatch"), Match.MAX, "round 1: 8 in")
		eq(count("MatchQueued"), 1, "round 1: 1 waits")
		local round1 = S.workspace:GetAttribute("MatchRound")
		-- the kid who won't fit next round (the highest id of the stayers) is smashed in the last
		-- seconds: its kart must not stay frozen for the round it waits out
		local last = kids[Match.MAX]
		S.advance(MR.MATCH_SECS - 2, 0.1) -- (round 1 is a few tenths in: ~1.5 s to go)
		for _ = 1, 3 do
			MR.damage(last.UserId, kids[1].UserId, Match.HIT, "rocket")
		end
		eq(last:GetAttribute("Health"), 0, "smashed at the end")
		for _ = 1, 120 do
			if (S.workspace:GetAttribute("MatchRound") or 0) > round1 then
				break
			end
			S.advance(0.5, 0.1)
		end
		truthy((S.workspace:GetAttribute("MatchRound") or 0) > round1, "round 2 started")
		S.advance(1, 0.1)
		eq(count("InMatch"), Match.MAX, "round 2: 8 in")
		local out = {}
		for _, k in kids do
			if k:GetAttribute("InMatch") ~= true then
				table.insert(out, k)
			end
		end
		eq(#out, 1, "one left over")
		local o = out[1]
		eq(o:GetAttribute("MatchQueued"), true, "queued")
		eq(o:GetAttribute("Health"), nil, "no match health")
		eq(o:GetAttribute("Place"), nil, "no place")
		-- (out of the arena: walking, or waiting in the warm-up yard)
		truthy(
			LobbyPlots.drivingOf(o) ~= S.require("Shared.LobbyLayout").arenaIndex(),
			"not in the arena"
		)
		eq(o, last, "the one left over is the late-smashed kid")
		local car = S.workspace:FindFirstChild("Car_" .. o.UserId)
		truthy(car and car.PrimaryPart and not car.PrimaryPart.Anchored, "its kart isn't frozen")
		eq(car and car:GetAttribute("Smashed"), nil, "nor shown smashed")
		eq(#S.errors, 0, "errors")
	end
)
