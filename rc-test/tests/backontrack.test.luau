--!strict
-- Car VS Car big race: falling off or getting stuck puts the car back on the road at the last
-- gate, facing the way to go (a small loss, not the grid).
local H = require("./harness")
local BackOnTrack = require("../src/shared/BackOnTrack")
local LapTimer = require("../src/shared/LapTimer")
local RaceMaps = require("../src/shared/RaceMaps")
local LobbyLayout = require("../src/shared/LobbyLayout")
local Tuning = require("../src/shared/Tuning")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Back on track")

test("back on track: the gate just passed, round the lap", function()
	eq(BackOnTrack.lastGate(6, 2), 1) -- just over the line: the line
	eq(BackOnTrack.lastGate(6, 4), 3)
	eq(BackOnTrack.lastGate(6, 7), 6) -- after the last gate, before the line
	eq(BackOnTrack.lastGate(6, 8), 1) -- (LapTimer counts on: next 8 = gate 2 of the next lap)
end)

test("back on track: on every map, on the road and facing the next gate", function()
	for k, m in RaceMaps.list() do
		local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
		local timer = LapTimer.new(t.gates, t.mode)
		LapTimer.go(timer, 0)
		for next = 2, #t.gates + 1 do
			timer.next = next
			local sp = BackOnTrack.spot(t, timer.gates, timer.next) :: BackOnTrack.Spot
			local x, y, z, dx, dz = sp.x, sp.y, sp.z, sp.dx, sp.dz
			local g = t.gates[BackOnTrack.lastGate(#t.gates, next)]
			-- on the gate (the road), standing at least as high as the start
			truthy(LapTimer.inside(g, x, g.y, z), `{m.id} gate {next}: on the road`)
			truthy(y >= t.spawn.y)
			-- facing the next gate: it is ahead
			local n = t.gates[((next - 1) % #t.gates) + 1]
			truthy((n.x - x) * dx + (n.z - z) * dz > 0, `{m.id} gate {next}: faces the way to go`)
		end
		eq(BackOnTrack.spot(t, {}, 2), nil)
	end
end)

test("back on track: fell off the world, or stuck too long (not on the rocks)", function()
	local s = TrackData.RC_SCALE
	truthy(BackOnTrack.fell(-9, s)) -- (RC size: 8 studs under the floor)
	truthy(not BackOnTrack.fell(0, s))
	truthy(not BackOnTrack.fell(-1.5, s), "a dip in the road is not a fall")
	truthy(BackOnTrack.stuck(Tuning.stuckWait + 0.1, Tuning.stuckWait, "backyard"))
	truthy(not BackOnTrack.stuck(Tuning.stuckWait - 0.1, Tuning.stuckWait, "backyard"))
	truthy(not BackOnTrack.stuck(99, Tuning.stuckWait, "rock"))
end)
