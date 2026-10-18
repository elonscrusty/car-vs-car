--!strict
local H = require("./harness")
local Inventory = require("../src/shared/Inventory")
local QuestsConfig = require("../src/shared/QuestsConfig")
local Spin = require("../src/shared/Spin")
local SpinConfig = require("../src/shared/SpinConfig")

print("Spin")

local DAY = SpinConfig.dayLength

H.test("segments are valid and the odds sum to about 100", function()
	local rows = Spin.oddsTable()
	H.eq(#rows, #SpinConfig.Segments)
	local sum = 0
	for i, seg in SpinConfig.Segments do
		H.truthy(seg.weight > 0)
		H.truthy(seg.coins > 0 or seg.freePulls > 0)
		H.eq(rows[i].label, seg.label)
		sum += rows[i].percent
	end
	H.near(sum, 100, 0.5)
end)

H.test("pick follows the weights from both ends", function()
	H.eq(Spin.pick(0), 1)
	H.eq(Spin.pick(1), #SpinConfig.Segments)
	H.eq(Spin.pick(0.999999), #SpinConfig.Segments)
	H.eq(Spin.pick(-5), 1)
	local total = 0
	for _, seg in SpinConfig.Segments do
		total += seg.weight
	end
	local first = SpinConfig.Segments[1].weight / total
	H.eq(Spin.pick(first - 0.001), 1)
	H.eq(Spin.pick(first + 0.001), 2)
end)

H.test("one spin per UTC day, pays once", function()
	local d = Spin.default()
	local coins, tries = 0, 0
	local function pay(n: number)
		coins += n
	end
	local function addTry(n: number)
		tries += n
	end
	local t = 100 * DAY + 5
	H.truthy(Spin.canSpin(d, t))
	local r = Spin.spin(d, t, function()
		return 0
	end, pay, addTry)
	H.truthy(r ~= nil)
	H.eq(coins, SpinConfig.Segments[1].coins)
	H.eq(Spin.canSpin(d, t + 3000), false)
	H.eq(
		Spin.spin(d, t + 3000, function()
			return 0
		end, pay, addTry),
		nil
	)
	H.eq(coins, SpinConfig.Segments[1].coins) -- repeat paid nothing
	H.truthy(Spin.canSpin(d, t + DAY))
end)

H.test("free claw try segment adds a try, capped", function()
	local d = Spin.default()
	local daily = { freePulls = QuestsConfig.Daily.maxFreePulls }
	local r = Spin.spin(d, DAY * 3, function()
		return 0.9 -- lands on the free claw try row
	end, function() end, function(n)
		Spin.addFreePulls(daily, n)
	end)
	H.truthy(r ~= nil and r.freePulls == 1)
	H.eq(daily.freePulls, QuestsConfig.Daily.maxFreePulls)
end)

H.test("saves: spin defaults, cleans bad data", function()
	H.eq(Inventory.default().spin.lastDay, 0)
	H.eq(Inventory.migrate({}).spin.lastDay, 0)
	H.eq(Inventory.migrate({ spin = { lastDay = 77.9 } }).spin.lastDay, 77)
	H.eq(Inventory.migrate({ spin = { lastDay = -3 } }).spin.lastDay, 0)
	H.eq(Inventory.migrate({ spin = "x" }).spin.lastDay, 0)
end)
