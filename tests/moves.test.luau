--!strict
local Harness = require("./harness")
local Moves = require("../src/shared/Moves")
local MovesConfig = require("../src/shared/MovesConfig")

local test, eq, near = Harness.test, Harness.eq, Harness.near

print("Moves")

test("only known move names pass", function()
	eq(Moves.isMove("boost", MovesConfig.Names), true)
	eq(Moves.isMove("jump", MovesConfig.Names), true)
	eq(Moves.isMove("special", MovesConfig.Names), true)
	eq(Moves.isMove("fly", MovesConfig.Names), false)
	eq(Moves.isMove(1, MovesConfig.Names), false)
	eq(Moves.isMove(nil, MovesConfig.Names), false)
end)

test("cooldown math", function()
	near(Moves.cooldownLeft(10, 6, 12), 4)
	near(Moves.cooldownLeft(10, 6, 16), 0)
	near(Moves.cooldownLeft(10, 6, 99), 0)
	eq(Moves.ready(-math.huge, 6, 0), true)
	eq(Moves.ready(10, 6, 15.9), false)
	eq(Moves.ready(10, 6, 16), true)
end)

test("boost timeline: full, fade, over", function()
	local b = MovesConfig.Boost
	near(Moves.boostSpeedMult(0, MovesConfig.Boost), 1 + b.speedBonus)
	near(Moves.boostSpeedMult(b.duration - b.fade, MovesConfig.Boost), 1 + b.speedBonus)
	near(Moves.boostSpeedMult(b.duration - b.fade / 2, MovesConfig.Boost), 1 + b.speedBonus / 2)
	near(Moves.boostSpeedMult(b.duration, MovesConfig.Boost), 1)
	near(Moves.boostSpeedMult(-1, MovesConfig.Boost), 1)
	near(Moves.boostAccelMult(0, MovesConfig.Boost), 1 + b.accelBonus)
	near(Moves.boostAccelMult(99, MovesConfig.Boost), 1)
end)

test("drift starts after holding a full steer, then lingers", function()
	local d = MovesConfig.Drift
	local s = Moves.newDrift()
	local grip = 1
	for _ = 1, 3 do -- 0.3 s: not yet
		grip = Moves.driftStep(s, 1, 40, 0.1, d)
	end
	eq(grip, 1)
	grip = Moves.driftStep(s, 1, 40, 0.15, d)
	near(grip, d.gripFactor)
	local _, turn = Moves.driftStep(s, 1, 40, 0.1, d)
	near(turn, d.turnBonus)
	-- release: still sliding for the linger time, then normal
	grip = Moves.driftStep(s, 0, 40, d.lingerSeconds / 2, d)
	near(grip, d.gripFactor)
	grip = Moves.driftStep(s, 0, 40, d.lingerSeconds, d)
	eq(grip, 1)
end)

test("no drift when slow, half steer, or switching sides", function()
	local d = MovesConfig.Drift
	local s = Moves.newDrift()
	for _ = 1, 20 do
		eq((Moves.driftStep(s, 1, 5, 0.1, d)), 1)
	end
	for _ = 1, 20 do
		eq((Moves.driftStep(s, 0.5, 40, 0.1, d)), 1)
	end
	local s2 = Moves.newDrift()
	for i = 1, 20 do
		eq((Moves.driftStep(s2, if i % 2 == 0 then 1 else -1, 40, 0.1, d)), 1)
	end
end)
