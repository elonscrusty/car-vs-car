--!nocheck
-- GarageServer on the pretend server (tests/fakeroblox.luau) with Features.SMASH on, as phase 3
-- runs it: no training, a new kid owns a starter kart from the first second, the plot shows the
-- karts (Garage / RacerCar for the showroom), and picks, crates and leftover training asks
-- from old screens never error.
local H = require("./harness")
local Fake = require("./fakeroblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Garage server (Smash on)")

local BEAT = 0.1

local store = Fake.store()
local S = Fake.server(store, { jobId = "garage" })
do -- Features.SMASH on for this server only
	local f = S.Shared:FindFirstChild("Features")
	local p = (getmetatable(f) :: any).p
	local src, n = string.gsub(p._source, "Features%.SMASH = false", "Features.SMASH = true")
	assert(n == 1 or string.find(p._source, "Features%.SMASH = true"), "Features.SMASH line")
	p._source = src
end
S.run("Main")
S.run("Stars")
S.run("CarShop")
local PlayerData = S.require("PlayerData")
local CarStats = S.require("Shared.CarStats")
local kid = S.join(9301)
S.advance(5, BEAT)
local data = PlayerData.get(kid)

local function plot(): any
	for _, m in S.workspace.Plots:GetChildren() do
		if m:GetAttribute("OwnerId") == kid.UserId then
			return m
		end
	end
	return nil
end

test("a new kid owns the starter kart from the first second", function()
	truthy(data, "save")
	eq(data.picked, true, "picked for them")
	eq(#data.garage, 1, "one kart")
	eq(data.garage[1].id, CarStats.STARTERS[1])
	eq(data.racer, data.garage[1].uid, "it's the one they play with")
	eq(kid:GetAttribute("RacerCar"), CarStats.STARTERS[1])
	local cars = S.got(kid, "Garage", "cars")
	truthy(#cars >= 1 and #cars[#cars][3].garage == 1, "the screens got the kart")
end)

test("the plot shows the karts for the showroom", function()
	local m = plot()
	truthy(m, "the kid has a plot")
	eq(m:GetAttribute("Garage"), CarStats.STARTERS[1])
	eq(m:GetAttribute("RacerCar"), CarStats.STARTERS[1])
	eq(m:GetAttribute("Stations"), nil, "no training on the plot")
end)

test("a crate adds a kart; PICK THIS KART swaps the turntable", function()
	data.coins = 100000
	S.send(kid, "Garage", "buy", "basic")
	S.advance(1, BEAT)
	eq(#data.garage, 2, "the crate gave a kart")
	local second = data.garage[2]
	S.send(kid, "Garage", "racer", second.uid)
	S.advance(1, BEAT)
	eq(data.racer, second.uid)
	local m = plot()
	eq(m:GetAttribute("RacerCar"), second.id)
	eq(#string.split(m:GetAttribute("Garage"), ","), 2)
end)

test("leftover training asks and junk change nothing and never error", function()
	local before = data.racer
	for _, kind in { "coach", "station", "upgrade", "level", "nope", 5, nil } do
		S.send(kid, "Garage", kind, 1, "x")
		S.advance(0.3, BEAT)
	end
	S.send(kid, "Garage", "racer", "not-a-uid")
	S.advance(0.5, BEAT)
	eq(data.racer, before)
	eq(kid:GetAttribute("CoachAt"), nil, "no COACH without training")
	eq(table.concat(S.errors, "\n"), "", "errors")
end)
