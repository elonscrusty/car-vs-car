--!strict
-- Tiny test helper. Run all tests with:  lune run tests/run

local process = require("@lune/process")

local Harness = {}

local passed, failed = 0, 0

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function Harness.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "eq"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Harness.near(actual: number, expected: number, eps: number?, msg: string?)
	if math.abs(actual - expected) > (eps or 1e-6) then
		error(`{msg or "near"}: expected {expected}, got {actual}`, 2)
	end
end

function Harness.truthy(v: any, msg: string?)
	if not v then
		error(msg or "expected truthy", 2)
	end
end

-- Runs `fn` with the training game's save fields kept (Profile.KEEP_TRAINING = true), then puts
-- the flag back. For tests that round-trip the old training-era fields (stations, plot level,
-- track, per-car training); the smash game drops them on load (tests/smash_save checks that).
function Harness.withTraining(profile: any, fn: () -> ())
	local was = profile.KEEP_TRAINING
	profile.KEEP_TRAINING = true
	local ok, err = pcall(fn)
	profile.KEEP_TRAINING = was
	if not ok then
		error(err, 0)
	end
end

function Harness.summary()
	print(`\n{passed} passed, {failed} failed`)
	if failed > 0 then
		process.exit(1)
	end
end

return Harness
