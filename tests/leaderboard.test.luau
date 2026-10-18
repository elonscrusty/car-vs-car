--!strict
local H = require("./harness")
local Leaderboard = require("../src/shared/Leaderboard")
local Inventory = require("../src/shared/Inventory")

print("Leaderboard")

H.test("score comes from wins or best streak, never negative or NaN", function()
	local p = Inventory.default()
	p.wins = 7
	p.progress.bestStreak = 4
	H.eq(Leaderboard.scoreFor("wins", p), 7)
	H.eq(Leaderboard.scoreFor("streak", p), 4)
	p.wins = -3
	H.eq(Leaderboard.scoreFor("wins", p), 0)
	p.progress.bestStreak = 0 / 0
	H.eq(Leaderboard.scoreFor("streak", p), 0)
end)

H.test("submit only better scores, not too often", function()
	H.eq(Leaderboard.shouldSubmit(0, nil, nil, 100, 20), false)
	H.eq(Leaderboard.shouldSubmit(1, nil, nil, 100, 20), true)
	H.eq(Leaderboard.shouldSubmit(5, 5, 0, 100, 20), false)
	H.eq(Leaderboard.shouldSubmit(4, 5, 0, 100, 20), false)
	H.eq(Leaderboard.shouldSubmit(6, 5, 90, 100, 20), false)
	H.eq(Leaderboard.shouldSubmit(6, 5, 70, 100, 20), true)
end)

H.test("rows skip junk, rank from 1 and stop at the limit", function()
	local rows = Leaderboard.rows({
		{ key = "11", value = 50 },
		{ key = "bad", value = 40 },
		{ key = "12", value = 0 },
		{ key = "13", value = 30.9 },
		{ key = "14", value = 20 },
		"junk",
	}, 2)
	H.eq(#rows, 2)
	H.eq(rows[1].userId, 11)
	H.eq(rows[1].rank, 1)
	H.eq(rows[2].userId, 13)
	H.eq(rows[2].rank, 2)
	H.eq(rows[2].score, 30)
	H.eq(#Leaderboard.rows("nope", 5), 0)
end)

H.test("line text uses a fallback and cuts long names", function()
	H.eq(Leaderboard.line({ rank = 1, userId = 1, score = 9 }, "Ann"), "1. Ann   9")
	H.eq(Leaderboard.line({ rank = 2, userId = 1, score = 9 }, nil), "2. Player   9")
	H.eq(#Leaderboard.line({ rank = 3, userId = 1, score = 9 }, string.rep("x", 40)), 3 + 16 + 4)
end)
