--!strict
local Harness = require("./harness")
local Retry = require("../src/shared/Retry")
local SessionLock = require("../src/shared/SessionLock")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("Retry")

test("delay doubles and caps", function()
	eq(Retry.delay(1, 1, 16), 1)
	eq(Retry.delay(2, 1, 16), 2)
	eq(Retry.delay(4, 1, 16), 8)
	eq(Retry.delay(9, 1, 16), 16)
end)

test("schedule has attempts-1 sleeps", function()
	local s = Retry.schedule(5, 1, 3)
	eq(#s, 4)
	eq(s[1], 1)
	eq(s[2], 2)
	eq(s[3], 3)
	eq(s[4], 3)
	eq(#Retry.schedule(1, 1, 3), 0)
end)

test("run returns on first success without waiting", function()
	local waits = {}
	local ok, res = Retry.run(function()
		return 42
	end, {
		attempts = 3,
		baseDelay = 1,
		maxDelay = 8,
		wait = function(s)
			table.insert(waits, s)
		end,
	})
	truthy(ok)
	eq(res, 42)
	eq(#waits, 0)
end)

test("run retries with backoff then succeeds", function()
	local waits, calls, fails = {}, 0, {}
	local ok, res = Retry.run(function()
		calls += 1
		if calls < 3 then
			error("boom" .. calls)
		end
		return "fine"
	end, {
		attempts = 5,
		baseDelay = 1,
		maxDelay = 8,
		wait = function(s)
			table.insert(waits, s)
		end,
		onFail = function(a)
			table.insert(fails, a)
		end,
	})
	truthy(ok)
	eq(res, "fine")
	eq(calls, 3)
	eq(#waits, 2)
	eq(waits[1], 1)
	eq(waits[2], 2)
	eq(#fails, 2)
end)

test("run gives up after attempts and returns last error", function()
	local waits, calls = {}, 0
	local ok, err = Retry.run(function()
		calls += 1
		error("nope" .. calls, 0)
	end, {
		attempts = 3,
		baseDelay = 2,
		maxDelay = 3,
		wait = function(s)
			table.insert(waits, s)
		end,
	})
	eq(ok, false)
	eq(err, "nope3")
	eq(calls, 3)
	eq(#waits, 2) -- no sleep after the final failure
	eq(waits[2], 3)
end)

print("SessionLock")

local NOW = 1000

test("no record or no lock can be claimed", function()
	truthy(SessionLock.canClaim(nil, "A", NOW))
	truthy(SessionLock.canClaim({ data = {} }, "A", NOW))
end)

test("fresh lock by another job blocks", function()
	local ok, why =
		SessionLock.canClaim({ lock = { jobId = "B", t = NOW - 10 }, data = {} }, "A", NOW)
	eq(ok, false)
	eq(why, "locked")
end)

test("own lock can be reclaimed (same server rejoin)", function()
	truthy(SessionLock.canClaim({ lock = { jobId = "A", t = NOW - 10 }, data = {} }, "A", NOW))
end)

test("stale lock is taken over, boundary at TTL", function()
	local ttl = SessionLock.TTL
	local fresh = { lock = { jobId = "B", t = NOW - (ttl - 1) }, data = {} }
	local stale = { lock = { jobId = "B", t = NOW - ttl }, data = {} }
	eq((SessionLock.canClaim(fresh, "A", NOW)), false)
	eq((SessionLock.canClaim(stale, "A", NOW)), true)
	eq((SessionLock.canClaim(fresh, "A", NOW, 10)), true) -- custom ttl
end)

test("far-future lock is treated as stale", function()
	eq(
		(SessionLock.canClaim({ lock = { jobId = "B", t = NOW + 100000 }, data = {} }, "A", NOW)),
		true
	)
	eq((SessionLock.canClaim({ lock = { jobId = "B", t = NOW + 5 }, data = {} }, "A", NOW)), false)
end)

test("claim stamps lock and keeps data", function()
	local data = { coins = 5 }
	local r = SessionLock.claim(nil, "A", NOW, data)
	eq((r.lock :: any).jobId, "A")
	eq((r.lock :: any).t, NOW)
	eq(r.data, data)
end)

test("save refreshes timestamp only if we own the lock", function()
	local rec = { lock = { jobId = "A", t = NOW - 60 }, data = { coins = 1 } }
	local out = SessionLock.save(rec, "A", NOW, { coins = 9 })
	truthy(out ~= nil)
	eq(((out :: any).lock).t, NOW)
	eq((out :: any).data.coins, 9)
	eq(SessionLock.save({ lock = { jobId = "B", t = NOW }, data = {} }, "A", NOW, {}), nil)
	eq(SessionLock.save({ data = {} }, "A", NOW, {}), nil)
	eq(SessionLock.save(nil, "A", NOW, {}), nil)
end)

test("release clears the lock only if we own it", function()
	local out = SessionLock.release(
		{ lock = { jobId = "A", t = NOW }, data = {} },
		"A",
		{ coins = 3 }
	)
	truthy(out ~= nil)
	eq((out :: any).lock, nil)
	eq((out :: any).data.coins, 3)
	eq(SessionLock.release({ lock = { jobId = "B", t = NOW }, data = {} }, "A", {}), nil)
end)
