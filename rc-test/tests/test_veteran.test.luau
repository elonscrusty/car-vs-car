--!nocheck
-- The Studio-only veteran switch (shared/TestVeteran, MatchRunner's round start): never on in a
-- live game, and in Studio with workspace TestVeteran = true a fresh save is not a rookie.
local H = require("./harness")
local Fake = require("./fakeroblox")
local TestVeteran = require("../src/shared/TestVeteran")

local test, eq = H.test, H.eq

print("Test veteran (Studio only)")

test("the gate: only Studio AND workspace TestVeteran == true", function()
	eq(TestVeteran.allowed(false, true), false, "live game, attribute on")
	eq(TestVeteran.allowed(true, nil), false, "Studio, off (the default)")
	eq(TestVeteran.allowed(true, "true"), false, "a string is not true")
	eq(TestVeteran.allowed(true, true), true, "Studio + on")
	eq(TestVeteran.allowed(true, 11), true, "Studio + a number")
	eq(TestVeteran.allowed(false, 11), false, "live game, a number")
	eq(TestVeteran.wanted(true, true), 5, "true = 5")
	eq(TestVeteran.wanted(true, 11), 11, "a number = that many")
	eq(TestVeteran.wanted(true, 10.7), 10, "whole matches")
	eq(TestVeteran.wanted(true, 0), 0, "0 = a brand-new player on purpose")
	eq(TestVeteran.wanted(true, -1), nil, "negative: off")
	eq(TestVeteran.wanted(true, 0 / 0), nil, "NaN: off")
	eq(TestVeteran.wanted(true, math.huge), nil, "huge: off")
	eq(TestVeteran.wanted(true, 1e9), 1000, "capped")
	eq(TestVeteran.wanted(false, true), nil, "live: off")
	eq(TestVeteran.matches(0, 5), 5, "a fresh save counts 5")
	eq(TestVeteran.matches(nil, 11), 11, "no save yet counts 11")
	eq(TestVeteran.matches(0, nil), 0, "off: as saved")
	eq(TestVeteran.matches(nil, nil), nil, "off: no save stays no save")
end)

local function firstRound(studio: boolean, attr: any): boolean
	local S = Fake.server(Fake.store(), { jobId = "vet" })
	S.require("Shared.Features").SMASH = true
	if studio then
		(getmetatable(S.game:GetService("RunService")) :: any).p.IsStudio = function()
			return true
		end
	end
	S.workspace:SetAttribute("TestVeteran", attr)
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local p = S.join(701)
	S.advance(3, 0.1)
	S.send(p, "Garage", "pick", "race_bolt")
	S.advance(1, 0.1)
	MR.join(p)
	local waited = 0
	while not p:GetAttribute("InMatch") and waited < 30 do
		S.advance(1, 0.1)
		waited += 1
	end
	eq(p:GetAttribute("InMatch"), true, "in the round")
	local rookie = MR.isRookie(701)
	eq(table.concat(S.errors, "\n"), "", "errors")
	S.close()
	return rookie
end

test("a fresh save: a rookie, unless Studio with TestVeteran on", function()
	eq(firstRound(false, nil), true, "live, off")
	eq(firstRound(false, true), true, "live, attribute on: still a rookie")
	eq(firstRound(true, nil), true, "Studio, off")
	eq(firstRound(true, true), false, "Studio, on: a veteran")
	eq(firstRound(true, 11), false, "Studio, 11: a veteran")
	eq(firstRound(true, 1), true, "Studio, 1: still a rookie (under 3)")
end)
