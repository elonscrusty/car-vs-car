--!strict
-- Who owns which plot on a full server (PlotOwners.luau): 8 joins get the 8 plots (race plots
-- first, the drift plot last), a 9th waits, and a plot someone leaves is clean for the next one.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local O = require("../src/shared/PlotOwners")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot owners (full server)")

test("8 joins get 8 plots, race plots first and the drift plot last; a 9th waits", function()
	local o = O.new(L.claimOrder())
	local slots = L.slots()
	local seen = {}
	for p = 1, #slots do
		local slot = O.add(o, p)
		truthy(slot ~= nil, `player {p} got a plot`)
		truthy(not seen[slot :: number], "one plot each")
		seen[slot :: number] = true
	end
	eq(slots[O.add(o, 8) :: number].id, "drift") -- the 8th (asking again) still has the drift plot
	eq(O.add(o, 9), nil)
	eq(#o.waiting, 1)
	eq(O.add(o, 9), nil) -- asking twice doesn't queue twice
	eq(#o.waiting, 1)
end)

test(
	"a plot someone leaves goes to the first one waiting, else is free for the next joiner",
	function()
		local o = O.new(L.claimOrder())
		for p = 1, 8 do
			O.add(o, p)
		end
		O.add(o, 9)
		O.add(o, 10)
		local mine = o.ownSlot[3]
		local freed, to = O.remove(o, 3)
		eq(freed, mine)
		eq(to, 9) -- first in line
		eq(o.ownSlot[9], mine)
		eq(o.owners[mine], 9)
		eq(o.ownSlot[3], nil)
		-- 10 leaves while waiting: no plot changes, the line is empty
		local f2, t2 = O.remove(o, 10)
		eq(f2, nil)
		eq(t2, nil)
		eq(#o.waiting, 0)
		-- the next leaver's plot stays free, and the next joiner claims it
		local free = o.ownSlot[5]
		local f3, t3 = O.remove(o, 5)
		eq(f3, free)
		eq(t3, nil)
		eq(o.owners[free], nil)
		eq(O.add(o, 11), free)
	end
)

test("leaving twice or without a plot changes nothing", function()
	local o = O.new(L.claimOrder())
	O.add(o, 1)
	O.remove(o, 1)
	local f, t = O.remove(o, 1)
	eq(f, nil)
	eq(t, nil)
	local f2 = O.remove(o, 42)
	eq(f2, nil)
end)
