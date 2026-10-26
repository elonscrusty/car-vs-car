--!strict
-- The spawn lobby for a brand new player (carter 10-25: joining was overwhelming): only the way
-- to their own pad. The spawn's pads, shops, gumball and LOOKS door wait for their stage.
local H = require("./harness")
local JoinStage = require("../src/shared/JoinStage")

local test, eq = H.test, H.eq

print("JoinSpawn")

test("join spawn: the spawn's extras wait for their stage", function()
	for _, name in { "pads", "build", "shop", "gumball", "looks" } do
		eq(JoinStage.shows(0, name), false)
	end
	eq(JoinStage.shows(1, "build"), true)
	eq(JoinStage.shows(1, "pads"), false)
	eq(JoinStage.shows(2, "pads"), true)
	eq(JoinStage.shows(2, "shop"), true)
	eq(JoinStage.shows(2, "gumball"), false)
	eq(JoinStage.shows(3, "gumball"), true)
	eq(JoinStage.shows(3, "looks"), true)
end)
