--!strict
-- The build screen: everything fits, nothing overlaps, grid squares are big enough to tap.
local H = require("./harness")
local BuildLayout = require("../src/shared/BuildLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("BuildLayout")

local SCREENS =
	{ { 667, 375 }, { 844, 390 }, { 932, 430 }, { 1024, 768 }, { 1366, 768 }, { 1920, 1080 } }

local function parts(l: BuildLayout.Layout): { [string]: BuildLayout.Rect }
	return {
		grid = l.grid,
		timer = l.timer,
		status = l.status,
		why = l.why,
		tray = l.tray,
		erase = l.erase,
		done = l.done,
	}
end

test("all parts on screen, under the top bar, apart", function()
	for _, s in SCREENS do
		local sw, sh = s[1], s[2]
		local l = BuildLayout.fit(sw, sh, 8, 8)
		local list = {}
		for name, r in parts(l) do
			truthy(
				r.x >= 0 and r.y >= 58 and r.x + r.w <= sw and r.y + r.h <= sh,
				`{name} on {sw}x{sh}`
			)
			truthy(r.w > 0 and r.h > 0, `{name} has size on {sw}x{sh}`)
			table.insert(list, { name, r })
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i][2], list[j][2]
				local hit = a.x < b.x + b.w
					and b.x < a.x + a.w
					and a.y < b.y + b.h
					and b.y < a.y + a.h
				truthy(not hit, `{list[i][1]} / {list[j][1]} on {sw}x{sh}`)
			end
		end
	end
end)

test("a 4x5 grid and a tall top bar still fit, apart", function()
	for _, s in SCREENS do
		local sw, sh = s[1], s[2]
		for _, top in { 64, 100 } do
			local l = BuildLayout.fit(sw, sh, 4, 5, top)
			truthy(l.grid.y >= top and l.timer.y >= top, `under a {top} px top bar on {sw}x{sh}`)
			truthy(l.grid.y + l.grid.h <= sh and l.grid.w == l.cell * 4, `4x5 grid on {sw}x{sh}`)
			truthy(l.grid.x + l.grid.w < l.tray.x, `grid left of the tray on {sw}x{sh}`)
			truthy(l.cell >= BuildLayout.MIN_TAP, `cell {l.cell} on {sw}x{sh}`)
		end
	end
end)

test("8x8 squares are thumb size on the smallest phone; tray fits a card", function()
	for _, s in SCREENS do
		local l = BuildLayout.fit(s[1], s[2], 8, 8)
		truthy(l.cell >= BuildLayout.MIN_TAP, `cell {l.cell} on {s[1]}x{s[2]}`)
		truthy(
			l.tray.h >= BuildLayout.CARD and l.tray.w >= BuildLayout.CARD * 2,
			`tray on {s[1]}x{s[2]}`
		)
		truthy(l.erase.w >= 44 and l.done.h >= 44, "big buttons")
	end
end)

test("tap finds the right square (row 1 = front = bottom)", function()
	local l = BuildLayout.fit(844, 390, 8, 6)
	local c, r = BuildLayout.cellAt(l, l.grid.x + 1, l.grid.y + 1, 8, 6)
	eq(c, 1)
	eq(r, 6)
	c, r = BuildLayout.cellAt(l, l.grid.x + l.cell * 2.5, l.grid.y + l.cell * 5.5, 8, 6)
	eq(c, 3)
	eq(r, 1)
	for _, cr in { { 1, 1 }, { 8, 6 }, { 4, 3 } } do
		local x, y = BuildLayout.cellPos(l, cr[1], cr[2], 6)
		local c2, r2 = BuildLayout.cellAt(l, l.grid.x + x + 1, l.grid.y + y + 1, 8, 6)
		eq(c2, cr[1])
		eq(r2, cr[2])
	end
	c = BuildLayout.cellAt(l, l.grid.x - 2, l.grid.y + 5, 8, 6)
	eq(c, nil)
	c = BuildLayout.cellAt(l, l.grid.x + l.grid.w + 1, l.grid.y + 5, 8, 6)
	eq(c, nil)
end)

test("turning a tile turns its road ends clockwise", function()
	local corner = { N = true, E = true, S = false, W = false }
	local t1 = BuildLayout.turn(corner, 1)
	truthy(t1.E and t1.S and not t1.N and not t1.W, "N+E -> E+S")
	local t4 = BuildLayout.turn(corner, 4)
	truthy(t4.N and t4.E and not t4.S and not t4.W, "four turns = back")
	local straight = BuildLayout.turn({ N = true, E = false, S = true, W = false }, 3)
	truthy(straight.E and straight.W and not straight.N, "straight on its side")
end)

test("countdown and status words", function()
	eq(BuildLayout.clock(300), "5:00")
	eq(BuildLayout.clock(272.2), "4:33")
	eq(BuildLayout.clock(-3), "0:00")
	eq(BuildLayout.statusText(true), "✓ READY")
	eq(BuildLayout.statusText(false), "GAP!")
	eq(BuildLayout.hint(false, false, false), "DRAG A TILE")
	eq(BuildLayout.hint(false, true, false), "FIX THE GAP")
	eq(BuildLayout.hint(true, false, false), "TAP DONE!")
	eq(BuildLayout.hint(true, false, true), "TAP TO ERASE")
	eq(BuildLayout.hint(false, true, false, true), "TAP TO TURN")
	eq(BuildLayout.hint(true, false, true, true), "TAP TO ERASE")
	for _, w in { BuildLayout.hint(false, false, false), BuildLayout.hint(false, true, false) } do
		truthy(#string.split(w, " ") <= 3, "hint is 3 words or less")
	end
end)

test("the right road tile for each pair of sides", function()
	local function E(n: boolean, e: boolean, s: boolean, w: boolean): BuildLayout.Ends
		return { N = n, E = e, S = s, W = w }
	end
	local piece, rot = BuildLayout.roadFor(E(true, false, true, false))
	eq(piece, "straight")
	eq(rot % 2, 0)
	piece, rot = BuildLayout.roadFor(E(false, true, false, true))
	eq(piece, "straight")
	eq(rot % 2, 1)
	for _, case in
		{
			{ E(true, true, false, false), 0 },
			{ E(false, true, true, false), 1 },
			{ E(false, false, true, true), 2 },
			{ E(true, false, false, true), 3 },
		}
	do
		piece, rot = BuildLayout.roadFor(case[1] :: BuildLayout.Ends)
		eq(piece, "turn")
		eq(rot, case[2])
	end
	piece = BuildLayout.roadFor(E(true, true, true, false))
	eq(piece, nil)
	eq(BuildLayout.side({ c = 2, r = 2 }, { c = 2, r = 3 }), "N")
	eq(BuildLayout.side({ c = 2, r = 2 }, { c = 1, r = 2 }), "W")
	eq(BuildLayout.side({ c = 2, r = 2 }, { c = 3, r = 3 }), nil)
end)
