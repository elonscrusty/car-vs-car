--!strict
local H = require("./harness")
local PadSlots = require("../src/shared/PadSlots")
local eq, truthy = H.eq, H.truthy

print("PadSlots")

local function kinds(events: { PadSlots.Event }): string
	local out = {}
	for _, e in events do
		table.insert(out, `{e.kind}{if e.id then e.id else ""}@{e.pad}`)
	end
	return table.concat(out, " ")
end

H.test("one player waits forever, nothing starts", function()
	local s = PadSlots.new(4, 2)
	eq(kinds(PadSlots.update(s, { [11] = 2 })), "joined11@2")
	for _ = 1, 50 do
		eq(#PadSlots.update(s, { [11] = 2 }), 0)
	end
	eq(PadSlots.counts(s)[2], 1)
end)

H.test("two on one pad make a fight and leave the pad", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 3 })
	local ev = PadSlots.update(s, { [11] = 3, [12] = 3 })
	eq(kinds(ev), "joined12@3 ready@3")
	eq(ev[2].ids[1], 11)
	eq(ev[2].ids[2], 12)
	eq(PadSlots.counts(s)[3], 0)
end)

H.test("two on different pads do not fight", function()
	local s = PadSlots.new(4, 2)
	eq(kinds(PadSlots.update(s, { [11] = 1, [12] = 2 })), "joined11@1 joined12@2")
end)

H.test("two strangers on different pads meet after the wait", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1 }, nil, 100)
	PadSlots.update(s, { [11] = 1, [12] = 3 }, nil, 102)
	eq(#PadSlots.update(s, { [11] = 1, [12] = 3 }, nil, 104), 0) -- 12 has waited only 2 s
	local ev = PadSlots.update(s, { [11] = 1, [12] = 3 }, nil, 108.5)
	eq(kinds(ev), "ready@1")
	eq(ev[1].ids[1], 11)
	eq(ev[1].ids[2], 12)
	eq(PadSlots.counts(s)[1] + PadSlots.counts(s)[3], 0)
end)

H.test("a friend pair is not split: two on one pad still fight at once", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1, [13] = 2 }, nil, 100)
	local ev = PadSlots.update(s, { [11] = 1, [12] = 1, [13] = 2 }, nil, 101)
	eq(kinds(ev), "joined12@1 ready@1")
	eq(PadSlots.counts(s)[2], 1)
end)

H.test("three singles: the two longest waiting meet, the third keeps waiting", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1 }, nil, 100)
	PadSlots.update(s, { [11] = 1, [12] = 2 }, nil, 101)
	PadSlots.update(s, { [11] = 1, [12] = 2, [13] = 3 }, nil, 102)
	local ev = PadSlots.update(s, { [11] = 1, [12] = 2, [13] = 3 }, nil, 120)
	eq(ev[1].ids[1], 11)
	eq(ev[1].ids[2], 12)
	eq(PadSlots.counts(s)[3], 1)
end)

H.test("walking off leaves the pad", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1 })
	eq(kinds(PadSlots.update(s, {})), "left11@1")
	eq(PadSlots.counts(s)[1], 0)
end)

H.test("moving to another pad is a leave and a join", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1 })
	eq(kinds(PadSlots.update(s, { [11] = 4 })), "left11@1 joined11@4")
end)

H.test("a third player on a full pad is not counted", function()
	local s = PadSlots.new(4, 3)
	local cap3 = PadSlots.new(4, 2)
	PadSlots.update(s, { [1] = 1, [2] = 1 })
	eq(PadSlots.counts(s)[1], 2)
	-- with cap 2 the pad is taken off right away, so test "full" with three arriving at once
	eq(
		kinds(PadSlots.update(cap3, { [5] = 1, [6] = 1, [7] = 1 })),
		"joined5@1 joined6@1 full7@1 ready@1"
	)
end)

H.test("ignored ids (in a fight) never count, and are taken off", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 1 })
	eq(kinds(PadSlots.update(s, { [11] = 1 }, { [11] = true })), "left11@1")
	eq(#PadSlots.update(s, { [11] = 1 }, { [11] = true }), 0)
end)

H.test("suggest: a waiting pad first, then an empty one, nil when full", function()
	local s = PadSlots.new(2, 2)
	eq(PadSlots.suggest(s), 1)
	PadSlots.update(s, { [11] = 2 })
	eq(PadSlots.suggest(s), 2)
	local full = PadSlots.new(1, 2)
	full.pads[1] = { 1, 2 }
	full.at[1], full.at[2] = 1, 1
	eq(PadSlots.suggest(full), nil)
end)

H.test("suggest: friends pull you to their pad", function()
	local s = PadSlots.new(4, 2)
	PadSlots.update(s, { [11] = 3 })
	PadSlots.update(s, { [21] = 1 })
	eq(PadSlots.suggest(s, { 21 }), 1)
	eq(PadSlots.suggest(s, { 99 }), 1) -- both have one waiting: the first pad
end)

H.test("leave is safe for strangers", function()
	local s = PadSlots.new(4, 2)
	truthy(not PadSlots.leave(s, 5))
end)

H.test("suggestFromCounts matches suggest", function()
	eq(PadSlots.suggestFromCounts({ 0, 0, 0, 0 }, 2), 1)
	eq(PadSlots.suggestFromCounts({ 0, 1, 0, 0 }, 2), 2)
	eq(PadSlots.suggestFromCounts({ 2, 2, 2, 2 }, 2), nil)
	eq(PadSlots.suggestFromCounts({ 2, 0, 1, 1 }, 2), 3)
end)
