--!strict
local H = require("./harness")
local Rules = require("../src/shared/CarSanityRules")

print("CarSanityRules")

local CAP = 100
local function run(st: Rules.State, x: number, y: number, dt: number?): Rules.Result
	return Rules.step(st, { x = x, y = y, z = 0 }, 0, CAP, dt or 1 / 60)
end

H.test("normal driving stays ok", function()
	local st = Rules.newState()
	for i = 1, 120 do
		H.eq(run(st, i * (CAP / 60), 5).verdict, "ok")
	end
	H.eq(st.resets, 0)
end)

H.test("a teleport is reset to the last good spot", function()
	local st = Rules.newState()
	run(st, 0, 5)
	run(st, 1, 5)
	local r = run(st, 500, 5)
	H.eq(r.verdict, "reset")
	H.eq(r.resetTo and r.resetTo.x, 1)
	H.eq(st.resets, 1)
	H.eq(run(st, 2, 5).verdict, "ok")
end)

H.test("a lag spike is not a teleport", function()
	local st = Rules.newState()
	run(st, 0, 5)
	-- 0.2 s frame at top speed = 20 studs
	H.eq(run(st, 20, 5, 0.2).verdict, "ok")
end)

H.test("a huge dt is capped, so waiting does not buy a long jump", function()
	local st = Rules.newState()
	run(st, 0, 5)
	H.eq(run(st, 400, 5, 30).verdict, "reset")
end)

H.test("flying above the limit resets after the grace time", function()
	local st = Rules.newState()
	run(st, 0, 5)
	local verdict = "ok"
	for _ = 1, 120 do
		verdict = run(st, 0, 200).verdict
		if verdict ~= "ok" then
			break
		end
	end
	H.eq(verdict, "reset")
end)

H.test("a short hop over the limit is forgiven", function()
	local st = Rules.newState()
	run(st, 0, 69)
	for _ = 1, 10 do
		H.eq(run(st, 0, 71).verdict, "ok")
	end
	for _ = 1, 120 do
		H.eq(run(st, 0, 69).verdict, "ok")
	end
	H.truthy(st.badTime < 0.01)
end)

H.test("sustained speeding resets", function()
	local st = Rules.newState()
	run(st, 0, 5)
	local x, verdict = 0, "ok"
	for _ = 1, 120 do
		x += CAP * 2.2 / 60 -- 2.2x the cap but under the teleport limit
		verdict = run(st, x, 5).verdict
		if verdict ~= "ok" then
			break
		end
	end
	H.eq(verdict, "reset")
end)

H.test("too many resets forfeit", function()
	local st = Rules.newState()
	run(st, 0, 5)
	H.eq(run(st, 900, 5).verdict, "reset")
	H.eq(run(st, 900, 5).verdict, "reset")
	H.eq(run(st, 900, 5).verdict, "forfeit")
end)

H.test("NaN position or a bad first frame forfeits", function()
	local st = Rules.newState()
	H.eq(run(st, 0 / 0, 5).verdict, "forfeit")
	local st2 = Rules.newState()
	run(st2, 0, 5)
	H.eq(Rules.step(st2, { x = math.huge, y = 0, z = 0 }, 0, CAP, 1 / 60).verdict, "reset")
end)
