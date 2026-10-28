--!strict
-- Car VS Car big race: the win moment from the stand, and 2 leagues racing at once never mix
-- cars or pay (the runner's split: ServerRace.groups; the pay: CvcRules.raceDone by place).
local H = require("./harness")
local RaceWin = require("../src/shared/RaceWin")
local ServerRace = require("../src/shared/ServerRace")
local CvcRules = require("../src/shared/CvcRules")
local CarStats = require("../src/shared/CarStats")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Race win + leagues at once")

test("win moment: a person who finished first, never a bot or nobody", function()
	local w = RaceWin.winner({ { name = "Mia", uid = 7, time = 61.2, laps = 2 } }, 9)
	truthy(w ~= nil)
	local mia = w :: RaceWin.Winner
	eq(mia.uid, 7)
	eq(mia.mine, false)
	local top, boost = RaceWin.words(mia)
	eq(top, "MIA WINS!")
	eq(boost, "2X COINS 10 MIN!")
	eq(RaceWin.words(RaceWin.winner({ { name = "Me", uid = 9, time = 60 } }, 9) :: any), "YOU WIN!")
	eq(RaceWin.winner({ { name = "Bolt Bot", time = 58, bot = true } }, 9), nil)
	eq(RaceWin.winner({ { name = "Mia", uid = 7, laps = 1 } }, 9), nil) -- nobody finished
	eq(RaceWin.winner({}, 9), nil)
	eq(RaceWin.winner("junk", 9), nil)
	eq(RaceWin.BOOST_MIN * 60, CvcRules.WIN_BOOST_SECS)
end)

test("leagues at once: each race has one league, nobody is in two, spots restart at 1", function()
	-- 5 Bronze and 4 Gold joined, mixed up
	local leagues = { 1, 3, 1, 3, 1, 3, 1, 1, 3 }
	local groups = ServerRace.groups(leagues, ServerRace.MAX)
	eq(#groups, 2)
	local seen: { [number]: boolean } = {}
	for _, g in groups do
		for spot, i in g do
			eq(leagues[i], leagues[g[1]]) -- one league per race
			truthy(not seen[i], "racer " .. i .. " is in one race only")
			seen[i] = true
			truthy(spot >= 1 and spot <= ServerRace.MAX) -- (StandSpot / grid number)
		end
	end
	for i in leagues do
		truthy(seen[i], "racer " .. i .. " races")
	end
end)

test("leagues at once: places and pay come from your own league's race", function()
	local leagues = { 1, 3, 1, 3 } -- racers 1 and 3 Bronze, 2 and 4 Gold
	-- Gold cars are faster: in one mixed race the Bronze ones would be 3rd and 4th
	local times = { 70, 55, 72, 57 }
	local saves: { Profile.Data } = {}
	for i, lg in leagues do
		local d = Profile.new()
		CvcRules.setUp(d)
		assert(CvcRules.pick(d, CarStats.STARTERS[1]), "pick")
		d.league = lg
		d.stage = Profile.STAGE.RACED -- (not their first race: no crate in the sums)
		saves[i] = d
	end
	local paid: { [number]: number } = {}
	for _, g in ServerRace.groups(leagues, ServerRace.MAX) do
		local entries: { ServerRace.Entry } = {}
		for _, i in g do
			table.insert(
				entries,
				{ name = "R" .. i, uid = i, laps = ServerRace.LAPS, time = times[i] }
			)
		end
		for place, e in ServerRace.rank(entries) do
			local i = e.uid :: number
			local before = saves[i].coins
			CvcRules.raceDone(saves[i], place, 1000)
			paid[i] = saves[i].coins - before
		end
	end
	-- the Bronze winner won its own race (boost and win) though Gold cars were faster
	eq(paid[1], League.prize(1, 1))
	eq(saves[1].raceWins, 1)
	truthy(saves[1].boostUntil > 1000)
	eq(paid[3], League.prize(1, 2))
	-- Gold paid as Gold places, only against Gold
	eq(paid[2], League.prize(3, 1))
	eq(paid[4], League.prize(3, 2))
	eq(saves[2].raceWins, 1)
	-- two winners, everyone on a podium of their own race: 4 trophies
	local trophies = 0
	for _, d in saves do
		trophies += d.trophies
	end
	eq(trophies, 4)
end)
