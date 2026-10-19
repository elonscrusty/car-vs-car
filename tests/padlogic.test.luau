--!strict
local Harness = require("./harness")
local PadLogic = require("../src/shared/PadLogic")

local test, eq = Harness.test, Harness.eq

print("PadLogic")

local function fresh()
	return PadLogic.new(3, 2, 3)
end

test("join starts countdown, shows count", function()
	local s = fresh()
	local ok = PadLogic.join(s, 1, "a")
	eq(ok, true)
	eq(s.pads[1].phase, "countdown")
	eq(s.pads[1].seconds, 3)
	eq(PadLogic.shown(s, 1), 1)
	eq(PadLogic.shown(s, 2), 0)
end)

test("rejects bad pad index", function()
	local s = fresh()
	eq((PadLogic.join(s, 0, "a")), false)
	eq((PadLogic.join(s, 4, "a")), false)
	eq((PadLogic.join(s, 1.5, "a")), false)
	eq((PadLogic.join(s, "1", "a")), false)
	eq((PadLogic.join(s, nil, "a")), false)
end)

test("one player max one pad", function()
	local s = fresh()
	eq((PadLogic.join(s, 1, "a")), true)
	local ok, why = PadLogic.join(s, 2, "a")
	eq(ok, false)
	eq(why, "alreadyOnPad")
	local ok2 = PadLogic.join(s, 1, "a")
	eq(ok2, false)
end)

test("pad fills at max players", function()
	local s = fresh()
	eq((PadLogic.join(s, 1, "a")), true)
	eq((PadLogic.join(s, 1, "b")), true)
	local ok, why = PadLogic.join(s, 1, "c")
	eq(ok, false)
	eq(why, "full")
end)

test("countdown ticks to ready then locks", function()
	local s = fresh()
	PadLogic.join(s, 1, "a")
	local r, secs = PadLogic.tick(s, 1)
	eq(r, "counting")
	eq(secs, 2)
	r, secs = PadLogic.tick(s, 1)
	eq(r, "counting")
	eq(secs, 1)
	r = PadLogic.tick(s, 1)
	eq(r, "ready")
	eq(s.pads[1].phase, "locked")
	eq(PadLogic.shown(s, 1), 2)
	eq(PadLogic.tick(s, 1), "none")
end)

test("tick on idle pad does nothing", function()
	local s = fresh()
	eq(PadLogic.tick(s, 2), "none")
	eq(PadLogic.tick(s, 99), "none")
end)

test("locked pad refuses joins", function()
	local s = fresh()
	PadLogic.join(s, 1, "a")
	for _ = 1, 3 do
		PadLogic.tick(s, 1)
	end
	local ok, why = PadLogic.join(s, 1, "b")
	eq(ok, false)
	eq(why, "started")
end)

test("leave empties pad back to idle", function()
	local s = fresh()
	PadLogic.join(s, 2, "a")
	local idx, idle = PadLogic.leave(s, "a")
	eq(idx, 2)
	eq(idle, true)
	eq(s.pads[2].phase, "idle")
	eq(s.playerPad["a"], nil)
	local idx2 = PadLogic.leave(s, "a")
	eq(idx2, nil)
	eq((PadLogic.join(s, 3, "a")), true)
end)

test("leave with one still on pad keeps countdown", function()
	local s = fresh()
	PadLogic.join(s, 1, "a")
	PadLogic.join(s, 1, "b")
	local _, idle = PadLogic.leave(s, "a")
	eq(idle, false)
	eq(s.pads[1].phase, "countdown")
	eq(PadLogic.shown(s, 1), 1)
end)

test("leaving a locked pad frees it when empty", function()
	local s = fresh()
	PadLogic.join(s, 1, "a")
	for _ = 1, 3 do
		PadLogic.tick(s, 1)
	end
	local _, idle = PadLogic.leave(s, "a")
	eq(idle, true)
	eq((PadLogic.join(s, 1, "b")), true)
	eq(s.pads[1].seconds, 3)
end)

test("cancel removes everyone", function()
	local s = fresh()
	PadLogic.join(s, 1, "a")
	PadLogic.join(s, 1, "b")
	local removed = PadLogic.cancel(s, 1)
	eq(#removed, 2)
	eq(s.pads[1].phase, "idle")
	eq(s.playerPad["a"], nil)
	eq(s.playerPad["b"], nil)
	eq(#PadLogic.cancel(s, 1), 0)
	eq(#PadLogic.cancel(s, 9), 0)
end)

test("pick validation only accepts offered cars", function()
	local offered = { "Sedan", "Compact", "Kart" }
	eq(PadLogic.validatePick(offered, "Compact"), "Compact")
	eq(PadLogic.validatePick(offered, "Semi"), nil)
	eq(PadLogic.validatePick(offered, 5), nil)
	eq(PadLogic.validatePick(offered, nil), nil)
	eq(PadLogic.validatePick(offered, {}), nil)
	eq(PadLogic.validatePick({}, "Sedan"), nil)
end)

test("auto pick stays inside offered", function()
	local offered = { "Sedan", "Compact", "Kart" }
	eq(
		PadLogic.autoPick(offered, function()
			return 0
		end),
		"Sedan"
	)
	eq(
		PadLogic.autoPick(offered, function()
			return 0.999
		end),
		"Kart"
	)
	eq(
		PadLogic.autoPick(offered, function()
			return 1
		end),
		"Kart"
	)
	eq(
		PadLogic.autoPick({}, function()
			return 0
		end),
		nil
	)
end)

test("allPicked needs everyone on the pad", function()
	eq(PadLogic.allPicked({}, {}), false)
	eq(PadLogic.allPicked({ "a", "b" }, { a = "Sedan" }), false)
	eq(PadLogic.allPicked({ "a", "b" }, { a = "Sedan", b = "Compact" }), true)
	eq(PadLogic.allPicked({ "a" }, { a = "Sedan", b = "Compact" }), true)
end)
