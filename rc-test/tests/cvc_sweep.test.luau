--!nocheck
-- Car VS Car red-error sweep on the real server scripts (Lead's FINISH-JOBS row LOOPTEST), on the
-- pretend server (tests/fakeroblox.luau): junk from a hacked or buggy screen on every remote, a
-- full server of 8 kids racing while some leave (mid-race, while loading), and the DataStore down
-- at join. None of it may hit an error (red in Studio's output).
local H = require("./harness")
local Fake = require("./fakeroblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car: red-error sweep on the real server scripts")

local BEAT = 0.1

local function boot(store: Fake.Store, jobId: string)
	local S = Fake.server(store, { jobId = jobId })
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	return S
end

-- remote name -> the words its server script compares the first argument with
local function kindsByRemote(): { [string]: { string } }
	local fs = require("@lune/fs")
	local out = {}
	for _, f in fs.readDir("src/server") do
		local path = "src/server/" .. f
		if not fs.isFile(path) then
			path = path .. "/init.luau"
			if not fs.isFile(path) then
				continue
			end
		end
		local src = fs.readFile(path)
		local words, seen = {}, {}
		for w in string.gmatch(src, '[%w_]+%s*==%s*"([%w_]+)"') do
			if not seen[w] then
				seen[w] = true
				table.insert(words, w)
			end
		end
		for name in string.gmatch(src, '%.Name%s*=%s*"([%w_]+)"') do
			out[name] = out[name] or {}
			for _, w in words do
				table.insert(out[name], w)
			end
		end
	end
	return out
end

local function errors(S): string
	return table.concat(S.errors, "\n")
end

-- the warns that aren't what the test itself set up
local function warnsBut(S, ok: { string }): string
	local out = {}
	for _, w in S.warns do
		local fine = false
		for _, pat in ok do
			fine = fine or string.find(w, pat, 1, true) ~= nil
		end
		if not fine then
			table.insert(out, w)
		end
	end
	return table.concat(out, "\n")
end

test("junk on every remote (wrong types, NaN, huge, other players) never errors", function()
	local S = boot(Fake.store(), "fuzz")
	local a = S.join(201)
	local b = S.join(202)
	S.advance(3, BEAT)
	S.send(b, "Garage", "pick", "race_bolt")
	S.advance(1, BEAT)
	local part = S.Instance.new("Part")
	-- (and nil: one past the end)
	local junk = {
		0,
		-1,
		1.5,
		1e308,
		-1e308,
		math.huge,
		0 / 0,
		"",
		"x",
		"race_bolt",
		string.rep("A", 5000),
		{},
		{ 1, 2, 3 },
		{ uid = "1" },
		true,
		false,
		a,
		part,
	}
	-- every remote the server made, and the words its script checks for (kind == "x"), found
	-- in the source, so a new remote is swept the day it's added
	local kinds = kindsByRemote()
	local n = 0
	local RS = S.game:GetService("ReplicatedStorage")
	local swept = {}
	for _, r in RS:GetDescendants() do
		local isEvent = r.ClassName == "RemoteEvent" or r.ClassName == "UnreliableRemoteEvent"
		if not (isEvent or r.ClassName == "RemoteFunction") then
			continue
		end
		local list = table.clone(kinds[r.Name] or {})
		table.insert(list, "nope")
		table.insert(swept, r.Name)
		local function ask(who, ...)
			if isEvent then
				(getmetatable(r) :: any).p.OnServerEvent._fire(who, ...)
			else
				truthy(type(r.OnServerInvoke) == "function", r.Name .. " has no OnServerInvoke")
				S.task.spawn(r.OnServerInvoke, who, ...)
			end
			n += 1
			S.advance(0.6, BEAT) -- (past every rate limit, so the junk reaches the checks)
		end
		for _, kind in list do
			for _, who in { a, b } do
				for i = 1, #junk + 1 do
					ask(who, kind, junk[i], junk[(i * 7) % #junk + 1])
				end
			end
		end
		-- (and junk where the kind goes)
		for i = 1, #junk do
			ask(a, junk[i], junk[(i * 3) % #junk + 1])
		end
	end
	print("       swept " .. table.concat(swept, ", "))
	for _, name in { "Garage", "RCControl", "CarShop", "LeaveMatch", "SmashFeed", "MatchResult" } do
		truthy(table.find(swept, name), name .. " swept")
	end
	truthy(n > 400, "sent " .. n)
	eq(errors(S), "", "errors")
	eq(warnsBut(S, {}), "", "warns")
end)

test(
	"6 kids in a smash round; one leaves mid-round, one while loading: the rest get results",
	function()
		local S = boot(Fake.store(), "full")
		local MR = S.require("MatchRunner")
		MR.MATCH_SECS = 40
		local kids = {}
		for i = 1, 6 do
			kids[i] = S.join(300 + i)
		end
		S.advance(3, BEAT)
		for i, k in kids do
			S.send(
				k,
				"Garage",
				"pick",
				({ "race_bolt", "race_dart", "race_rocket" })[(i - 1) % 3 + 1]
			)
			MR.join(k)
		end
		local waited = 0
		while not kids[1]:GetAttribute("InMatch") and waited < 30 do
			S.advance(1, BEAT)
			waited += 1
		end
		for i, k in kids do
			eq(k:GetAttribute("InMatch"), true, `kid {i} in the round`)
		end
		eq(#MR.karts(), 6, "6 karts, no bots needed")
		S.advance(8, BEAT)
		S.leave(kids[6]) -- leaves mid-round
		local late = S.join(399)
		S.leave(late) -- left before the save loaded
		S.advance(45, BEAT)
		for i = 1, 5 do
			truthy(#S.got(kids[i], "MatchResult") >= 1, `kid {i} got a result`)
		end
		eq(#S.got(kids[6], "MatchResult"), 0, "the kid who left gets nothing")
		-- the next round runs too: the runner isn't stuck
		S.advance(60, BEAT)
		for i = 1, 5 do
			truthy(#S.got(kids[i], "MatchResult") >= 2, `kid {i} played twice`)
		end
		eq(errors(S), "", "errors")
		eq(warnsBut(S, {}), "", "warns")
	end
)

test("DataStore down at join: plays unsaved, then the visit reaches the save", function()
	local store = Fake.store()
	local S = boot(store, "down")
	S.storeDown = true
	local k = S.join(401)
	S.advance(60, BEAT)
	S.send(k, "Garage", "pick", "race_bolt")
	S.advance(2, BEAT)
	local PlayerData = S.require("PlayerData")
	truthy(PlayerData.isRetrying(k), "still trying")
	S.storeDown = false
	S.advance(120, BEAT)
	eq(PlayerData.isRetrying(k), false, "reached the save")
	truthy(#S.got(k, "StarsEvent", "saving") >= 2, "the screen heard saving is back")
	S.leave(k)
	S.advance(5, BEAT)
	truthy(store["RCPlayerData_v1/p_401"] ~= nil, "saved")
	eq(errors(S), "", "errors")
	-- (the outage itself warns: that's the point)
	eq(warnsBut(S, { "pretend outage", "DataStore is down" }), "", "other warns")
end)
