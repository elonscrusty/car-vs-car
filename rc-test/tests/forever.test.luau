--!strict
-- A loop that must never stop keeps going after an error, and reports it once a minute at most.
local H = require("./harness")
local Forever = require("../src/shared/Forever")

local test, eq = H.test, H.eq

print("Forever")

test("an error in one round doesn't stop the next one", function()
	Forever.reset()
	local rounds = 0
	for i = 1, 3 do
		local ok = Forever.step("t1", function()
			rounds += 1
			if i == 2 then
				error("boom")
			end
		end, i)
		eq(ok, i ~= 2)
	end
	eq(rounds, 3)
end)
