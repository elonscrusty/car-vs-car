--!strict
local Harness = require("./harness")
local Modes = require("../src/shared/Modes")
local ModesConfig = require("../src/shared/ModesConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("Modes")

test("every mode has a name and a blurb, and the rotation goes round", function()
	for _, m in ModesConfig.Order do
		truthy(Modes.isMode(m))
		truthy(ModesConfig.Names[m] ~= nil and ModesConfig.Blurbs[m] ~= nil)
	end
	truthy(not Modes.isMode("nope"))
	truthy(not Modes.isMode(5))
	local n = #ModesConfig.Order
	eq(Modes.pick(0), ModesConfig.Order[1])
	eq(Modes.pick(1), ModesConfig.Order[2])
	eq(Modes.pick(n), ModesConfig.Order[1])
	eq(Modes.pick(-3), ModesConfig.Order[1])
	eq(Modes.pick(1.9), ModesConfig.Order[2])
	for _, m in { "hill", "ice", "lastStanding", "soccer" } do
		truthy(table.find(ModesConfig.Order, m) ~= nil, m .. " is in the rotation")
	end
end)

test("car counts and bots", function()
	eq(Modes.carCount("duel"), 2)
	eq(Modes.carCount("hill"), 2)
	eq(Modes.carCount("ice"), 2)
	eq(Modes.carCount("lastStanding"), 8)
	eq(Modes.carCount("soccer"), ModesConfig.Soccer.teamSize * 2)
	truthy(Modes.isGroup("soccer") and Modes.isGroup("lastStanding"))
	truthy(not Modes.isGroup("hill"))
	eq(Modes.botsNeeded("lastStanding", 1), 7)
	eq(Modes.botsNeeded("lastStanding", 2), 6)
	eq(Modes.botsNeeded("lastStanding", 20), 0)
end)

test("ring spots are evenly spaced and face the middle", function()
	local spots = Modes.ringSpots(8, 90)
	eq(#spots, 8)
	for _, s in spots do
		near(math.sqrt(s.x ^ 2 + s.z ^ 2), 90, 0.001)
		-- CFrame.Angles(0, yaw, 0) faces (-sin yaw, -cos yaw): toward the middle
		local fx, fz = -math.sin(s.yaw), -math.cos(s.yaw)
		near(fx * s.x + fz * s.z, -90, 0.001)
	end
	near(spots[1].x * spots[5].x + spots[1].z * spots[5].z, -8100, 0.001) -- opposite
end)

test("hill: alone scores, two cars cancel, empty does nothing", function()
	local h = Modes.hillNew(2)
	eq(Modes.hillStep(h, { true, false }, 0.5), 1)
	near(h.scores[1], 0.5)
	eq(Modes.hillStep(h, { true, true }, 0.5), 0)
	near(h.scores[1], 0.5)
	near(h.scores[2], 0)
	eq(h.holder, 0)
	eq(Modes.hillStep(h, { false, false }, 0.5), 0)
	eq(Modes.hillStep(h, { false, true }, 1), 2)
	eq(h.holder, 2)
	near(h.scores[2], 1)
end)

test("hill: winner after the hold time, leader on time up", function()
	local h = Modes.hillNew(3)
	eq(Modes.hillLeader(h), 0)
	Modes.hillStep(h, { false, true, false }, 5)
	Modes.hillStep(h, { true, false, false }, 3)
	eq(Modes.hillLeader(h), 2)
	eq(Modes.hillWinner(h, 20), 0)
	Modes.hillStep(h, { false, true, false }, 15)
	eq(Modes.hillWinner(h, 20), 2)
	local t = Modes.hillNew(2)
	Modes.hillStep(t, { true, false }, 4)
	Modes.hillStep(t, { false, true }, 4)
	eq(Modes.hillLeader(t), 0) -- tie
end)

test("hill circle test", function()
	truthy(Modes.onHill(3, 4, 5))
	truthy(not Modes.onHill(4, 4, 5))
end)

test("ice is never grippier than normal", function()
	near(Modes.iceFriction(0.4, 0.02), 0.02)
	near(Modes.iceFriction(0.01, 0.02), 0.01)
	near(Modes.iceGrip(1, 0.12), 0.12)
	truthy(ModesConfig.Ice.gripScale < 1)
end)

test("last standing: eliminate, winner, draw", function()
	local l = Modes.lastNew(4)
	eq(Modes.lastWinner(l), 0)
	truthy(Modes.lastEliminate(l, 2))
	truthy(not Modes.lastEliminate(l, 2))
	truthy(not Modes.lastEliminate(l, 9))
	eq(Modes.lastAliveCount(l), 3)
	Modes.lastEliminate(l, 4)
	Modes.lastEliminate(l, 1)
	eq(Modes.lastWinner(l), 3)
	Modes.lastEliminate(l, 3)
	eq(Modes.lastWinner(l), -1)
end)

test("last standing: places and timeout", function()
	local l = Modes.lastNew(4)
	Modes.lastEliminate(l, 2) -- first out = last place
	Modes.lastEliminate(l, 4)
	Modes.lastEliminate(l, 1)
	eq(Modes.lastPlace(l, 3), 1)
	eq(Modes.lastPlace(l, 1), 2)
	eq(Modes.lastPlace(l, 4), 3)
	eq(Modes.lastPlace(l, 2), 4)
	local t = Modes.lastNew(3)
	Modes.lastEliminate(t, 1)
	eq(Modes.lastTimeoutWinner(t, { 99, 40, 70 }), 3) -- dead car 1 does not count
	eq(Modes.lastTimeoutWinner(t, { 99, 50, 50 }), 0)
end)

test("nearest alive car", function()
	local l = Modes.lastNew(3)
	local xs, zs = { 0, 10, 30 }, { 0, 0, 0 }
	eq(Modes.nearestAlive(l, xs, zs, 1), 2)
	Modes.lastEliminate(l, 2)
	eq(Modes.nearestAlive(l, xs, zs, 1), 3)
	Modes.lastEliminate(l, 3)
	eq(Modes.nearestAlive(l, xs, zs, 1), 0)
end)

test("soccer: teams and goals", function()
	eq(Modes.teamOf(1, 3), 1)
	eq(Modes.teamOf(3, 3), 1)
	eq(Modes.teamOf(4, 3), 2)
	local cfg = ModesConfig.Soccer
	-- Ball at the -X goal (team 1's): team 1 conceded.
	eq(Modes.goalConceded(-cfg.goalRadius - 1, 0, cfg.goalRadius, cfg.goalHalfAngle), 1)
	eq(Modes.goalConceded(cfg.goalRadius + 1, 0, cfg.goalRadius, cfg.goalHalfAngle), 2)
	-- Not far enough out, or outside the goal arc.
	eq(Modes.goalConceded(-10, 0, cfg.goalRadius, cfg.goalHalfAngle), 0)
	eq(Modes.goalConceded(0, cfg.goalRadius + 5, cfg.goalRadius, cfg.goalHalfAngle), 0)
	local s = Modes.soccerNew()
	eq(Modes.soccerGoal(s, 1), 2)
	eq(s.goals[2], 1)
	eq(s.last, 2)
end)

test("soccer: winner and timeout", function()
	local s = Modes.soccerNew()
	eq(Modes.soccerWinner(s, 3), 0)
	eq(Modes.soccerTimeoutWinner(s), 0)
	Modes.soccerGoal(s, 2)
	eq(Modes.soccerTimeoutWinner(s), 1)
	Modes.soccerGoal(s, 2)
	Modes.soccerGoal(s, 2)
	eq(Modes.soccerWinner(s, 3), 1)
	Modes.soccerGoal(s, 1)
	eq(Modes.soccerTimeoutWinner(s), 1)
end)

test("soccer: ball lost past the rim", function()
	truthy(Modes.ballLost(120, 0, 112, 6))
	truthy(not Modes.ballLost(100, 20, 112, 6))
end)

test("soccer spots: teams start at their own goal, facing the middle", function()
	local spots = Modes.soccerSpots(3, 90, 0.3)
	eq(#spots, 6)
	for i = 1, 3 do
		truthy(spots[i].x < 0, "team 1 on the -X side")
		truthy(spots[i + 3].x > 0, "team 2 on the +X side")
		near(math.sqrt(spots[i].x ^ 2 + spots[i].z ^ 2), 90, 0.001)
	end
	near(spots[2].z, 0, 0.001) -- the middle car of 3 sits on the axis
end)

test("bot aims behind the ball, away from the goal it attacks", function()
	-- Team 1 attacks team 2's goal at +X, so it waits at -X of the ball.
	local t = Modes.botTarget(10, 0, 1, 14)
	near(t.x, -4, 0.001)
	near(t.z, 0, 0.001)
	local t2 = Modes.botTarget(10, 0, 2, 14)
	near(t2.x, 24, 0.001)
end)
