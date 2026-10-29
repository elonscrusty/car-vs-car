--!nocheck
-- Car VS Car SMASH: no join-in-progress (carter 22:12). A kid who leaves a running round and taps
-- in again waits for the next round (queued, in the yard): never straight back into this one.
local H = require("./harness")
local Fake = require("./fakeroblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: leave and join again mid-round")

test("leave mid-round, join again: queued for the next round, not InMatch in this one", function()
	local S = Fake.server(Fake.store(), { jobId = "rejoin" })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	MR.MATCH_SECS = 60
	local kid, other = S.join(801), S.join(802)
	S.advance(3, 0.1)
	MR.join(kid)
	MR.join(other) -- (stays and plays: the round goes on)
	for _ = 1, 40 do
		if kid:GetAttribute("InMatch") == true then
			break
		end
		S.advance(0.5, 0.1)
	end
	eq(kid:GetAttribute("InMatch"), true, "in round 1")
	local round = S.workspace:GetAttribute("MatchRound")
	S.advance(10, 0.1)
	S.send(kid, "LeaveMatch")
	S.advance(2, 0.1)
	eq(kid:GetAttribute("InMatch"), nil, "left")
	MR.join(kid)
	for _ = 1, 200 do
		S.advance(0.5, 0.1)
		if S.workspace:GetAttribute("MatchRound") ~= round then
			break
		end
		eq(kid:GetAttribute("InMatch"), nil, "not back in the running round")
		eq(kid:GetAttribute("MatchQueued"), true, "queued for the next one")
	end
	truthy(S.workspace:GetAttribute("MatchRound") ~= round, "the round ran to its end")
	eq(kid:GetAttribute("InMatch"), true, "in the next round")
	eq(#S.errors, 0, "errors")
end)

test("alone: leaving stops the round; joining again starts a fresh one after the wait", function()
	local S = Fake.server(Fake.store(), { jobId = "rejoin-solo" })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local kid = S.join(811)
	S.advance(3, 0.1)
	MR.join(kid)
	for _ = 1, 40 do
		if kid:GetAttribute("InMatch") == true then
			break
		end
		S.advance(0.5, 0.1)
	end
	local round = S.workspace:GetAttribute("MatchRound")
	S.advance(10, 0.1)
	S.send(kid, "LeaveMatch")
	S.advance(2, 0.1)
	eq(S.workspace:GetAttribute("MatchEndsAt"), nil, "no round runs for bots alone")
	S.advance(20, 0.1) -- (the crate, the daily gift...)
	MR.join(kid)
	local t0 = S.now()
	for _ = 1, 150 do
		if kid:GetAttribute("InMatch") == true then
			break
		end
		S.advance(0.1, 0.1)
	end
	eq(kid:GetAttribute("InMatch"), true, "in")
	truthy(S.now() - t0 >= MR.START_SECS - 0.2, "waited for the start like anyone")
	truthy(S.workspace:GetAttribute("MatchRound") ~= round, "a fresh round")
	eq(#S.errors, 0, "errors")
end)
