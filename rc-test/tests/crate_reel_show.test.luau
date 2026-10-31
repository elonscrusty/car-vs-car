--!nocheck
-- The crate opening show on the pretend client: it builds, runs to the end for every rarity, calls
-- done() once, leaves no screen behind, and SKIP ends it early.
local Fake = require("./fakeroblox")
local H = require("./harness")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Crate reel show")

local S = Fake.server(Fake.store())
local req = S.client(1)
local CrateReel = req("Ui.Screens.CrateReel")
local CarCatalog = require("../src/shared/CarCatalog")
local Crates = require("../src/shared/Crates")

local function gui()
	local pg = S.game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	return pg
end

local function shows(): number
	local n = 0
	for _, c in gui():GetChildren() do
		if string.find(c.Name, "CrateReel", 1, true) then
			n += 1
		end
	end
	return n
end

test("it plays to the end for every rarity and then hands over", function()
	local pool = Crates.pool()
	for i, r in CarCatalog.RARITY_ORDER do
		local id = pool[r][1]
		local calls = 0
		CrateReel.play({ id = id, rarity = r, kind = "mega" }, function()
			calls += 1
		end)
		truthy(shows() > 0, "no screen while it plays")
		S.advance(30, 1 / 30)
		eq(calls, 1)
		eq(shows(), 0)
	end
end)

test("a second show while one plays goes straight to the card", function()
	local pool = Crates.pool()
	local id = pool.common[1]
	local a, b = 0, 0
	CrateReel.play({ id = id, rarity = "common", kind = "basic" }, function()
		a += 1
	end)
	CrateReel.play({ id = id, rarity = "common", kind = "basic" }, function()
		b += 1
	end)
	eq(b, 1)
	eq(a, 0)
	S.advance(30, 1 / 30)
	eq(a, 1)
end)

test("SKIP ends it at once, once", function()
	local pool = Crates.pool()
	local calls = 0
	CrateReel.play({ id = pool.rare[1], rarity = "rare", kind = "big" }, function()
		calls += 1
	end)
	S.advance(1, 1 / 30)
	local function find(node, name)
		for _, c in node:GetChildren() do
			if c.Name == name then
				return c
			end
			local deeper = find(c, name)
			if deeper then
				return deeper
			end
		end
		return nil
	end
	local skip = find(gui(), "Skip")
	truthy(skip ~= nil, "no SKIP button")
	skip.Activated._fire()
	eq(calls, 1)
	eq(shows(), 0)
	S.advance(30, 1 / 30)
	eq(calls, 1)
end)

test("it never hit an error mid-show", function()
	for _, w in S.warns do
		truthy(not string.find(w, "CrateReel:", 1, true), w)
	end
end)
