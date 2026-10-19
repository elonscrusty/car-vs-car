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
	eq(Modes.pick(1), ModesConfig.Order[1 % n + 1])
	eq(Modes.pick(n), ModesConfig.Order[1])
	eq(Modes.pick(-3), ModesConfig.Order[1])
	eq(Modes.pick(1.9), ModesConfig.Order[1 % n + 1])
	truthy(table.find(ModesConfig.Order, "lastStanding") ~= nil, "the fight is in the rotation")
end)

test(
	"launch rotation: soccer first, then tag, duel, hill, ice; last standing only with its flag",
	function()
		-- Launch: only the 4-car fight (soccer / tag / race are hidden behind flags).
		eq(table.concat(ModesConfig.Order, ","), "lastStanding")
		eq(table.concat(ModesConfig.orderFor({}), ","), "duel")
		eq(table.concat(ModesConfig.orderFor({ tagMode = true }), ","), "tag,duel")
		eq(
			table.concat(ModesConfig.orderFor({ hillMode = true, iceMode = true }), ","),
			"duel,hill,ice"
		)
		eq(
			table.concat(
				ModesConfig.orderFor({
					soccerMode = true,
					lastStandingMode = true,
					tagMode = true,
					raceMode = true,
					hillMode = true,
					iceMode = true,
				}),
				","
			),
			"soccer,tag,race,hill,ice,lastStanding"
		)
	end
)

test("car counts and bots", function()
	eq(Modes.carCount("duel"), 2)
	eq(Modes.carCount("hill"), 2)
	eq(Modes.carCount("ice"), 2)
	eq(Modes.carCount("lastStanding"), 4)
	eq(Modes.carCount("soccer"), ModesConfig.Soccer.teamSize * 2)
	truthy(Modes.isGroup("soccer") and Modes.isGroup("lastStanding"))
	truthy(not Modes.isGroup("hill"))
	eq(Modes.botsNeeded("lastStanding", 1), 3)
	eq(Modes.botsNeeded("lastStanding", 2), 2)
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

test("player mode pick: cycle and choose", function()
	local order = ModesConfig.Order
	eq(Modes.nextPick(nil), "auto")
	eq(Modes.nextPick("auto"), order[1])
	eq(Modes.nextPick(order[#order]), "auto")
	eq(Modes.nextPick("junk"), "auto")
	eq(Modes.isPick("lastStanding"), true)
	eq(Modes.isPick("auto"), true)
	eq(Modes.isPick("nope"), false)
	eq(Modes.isPick(5), false)
	eq(Modes.choose({ "auto", "lastStanding" }, 0), "lastStanding")
	eq(Modes.choose({ "auto" }, 1), Modes.pick(1))
	eq(Modes.choose({}, 2), Modes.pick(2))
	eq(Modes.choose({ "bogus" }, 0), Modes.pick(0))
end)

test("mode pick: odd remote values are rejected", function()
	eq(Modes.isPick(nil), false)
	eq(Modes.isPick({}), false)
	eq(Modes.isPick(string.rep("x", 100000)), false)
	eq(Modes.isPick(true), false)
	eq(Modes.isPick(""), false)
	eq(Modes.choose({ {}, 5, "x" }, 1), Modes.pick(1))
end)

print("Modes: car tag")

test("tag is a group mode with its own car count", function()
	truthy(Modes.isMode("tag") and Modes.isGroup("tag"))
	eq(Modes.carCount("tag"), ModesConfig.Tag.cars)
	eq(Modes.botsNeeded("tag", 2), ModesConfig.Tag.cars - 2)
end)

test("fuse shrinks each round and stops at the minimum", function()
	local c = ModesConfig.Tag
	eq(Modes.tagFuse(1, c.startFuse, c.fuseStep, c.minFuse), c.startFuse)
	truthy(Modes.tagFuse(2, c.startFuse, c.fuseStep, c.minFuse) < c.startFuse)
	eq(Modes.tagFuse(99, c.startFuse, c.fuseStep, c.minFuse), c.minFuse)
	eq(Modes.tagFuse(0, c.startFuse, c.fuseStep, c.minFuse), c.startFuse)
end)

test("only IT can pass IT, and not straight back", function()
	local t = Modes.tagNew(1, 10)
	truthy(not Modes.tagPass(t, 2, 3, 0, 1.5), "a car that is not IT cannot pass it")
	truthy(not Modes.tagPass(t, 1, 1, 0, 1.5))
	truthy(Modes.tagPass(t, 1, 2, 0, 1.5))
	eq(t.it, 2)
	truthy(not Modes.tagPass(t, 2, 1, 1.0, 1.5), "car 1 is immune for 1.5 s")
	eq(t.it, 2)
	truthy(Modes.tagPass(t, 2, 1, 1.6, 1.5), "immunity ended")
	eq(t.it, 1)
end)

test("fuse runs out and the IT car blows up", function()
	local t = Modes.tagNew(3, 1)
	truthy(not Modes.tagTick(t, 0.4))
	truthy(not Modes.tagTick(t, 0.4))
	truthy(Modes.tagTick(t, 0.4))
end)

test("next IT is an alive car and the next round resets the immunity", function()
	local l = Modes.lastNew(4)
	Modes.lastEliminate(l, 2)
	Modes.lastEliminate(l, 3)
	eq(Modes.tagNextIt(l, 0), 1)
	eq(Modes.tagNextIt(l, 0.99), 4)
	eq(Modes.tagNextIt(l, 5), 4, "r is clamped")
	for i = 1, 4 do
		Modes.lastEliminate(l, i)
	end
	eq(Modes.tagNextIt(l, 0.5), 0)
	local t = Modes.tagNew(1, 10)
	Modes.tagPass(t, 1, 2, 0, 5)
	Modes.tagNextRound(t, 4, 7)
	eq(t.it, 4)
	eq(t.fuse, 7)
	eq(t.round, 2)
	truthy(next(t.immuneUntil) == nil)
end)

test("signed angle: left is positive", function()
	near(Modes.signedAngle(0, -1, -1, 0), math.pi / 2, 1e-6) -- car faces -Z, target to -X
	near(Modes.signedAngle(0, -1, 0, -1), 0, 1e-6)
	near(math.abs(Modes.signedAngle(0, -1, 0, 1)), math.pi, 1e-6)
end)

test("flee direction: away from IT, bent to the middle near a wall", function()
	local d = Modes.tagFleeDir(0, 0, -10, 0, 60, 35)
	near(d.x, 1, 1e-6)
	near(d.z, 0, 1e-6)
	local edge = Modes.tagFleeDir(55, 0, 40, 0, 60, 35) -- IT is inside, car is by the wall
	near(math.sqrt(edge.x ^ 2 + edge.z ^ 2), 1, 1e-6)
	truthy(edge.x < 1, "bent back toward the middle")
	local same = Modes.tagFleeDir(5, 5, 5, 5, 60, 35)
	near(math.sqrt(same.x ^ 2 + same.z ^ 2), 1, 1e-6)
end)

test("rematch repeats the mode; a real pick wins; auto rotates", function()
	eq(Modes.choose({ "auto" }, 5, "lastStanding"), "lastStanding")
	eq(Modes.choose({ "lastStanding" }, 5, "tag"), "lastStanding")
	eq(Modes.choose({ "auto" }, 0, nil), ModesConfig.Order[1])
	eq(Modes.choose({ "auto" }, 0, "junk"), ModesConfig.Order[1])
	eq(Modes.choose({ "auto" }, 0, "auto"), ModesConfig.Order[1])
end)

test(
	"new players start in soccer only while it is in the rotation, others keep their pick",
	function()
		-- soccer is hidden at launch: nobody is forced into it
		eq(Modes.defaultPick(0, "auto"), "auto")
		eq(Modes.defaultPick(2, nil), nil)
		eq(Modes.defaultPick(3, "auto"), "auto")
		eq(Modes.defaultPick(3, nil), nil)
		eq(Modes.defaultPick(0, "tag"), "tag")
	end
)
