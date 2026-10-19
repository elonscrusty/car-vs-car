--!strict
local H = require("./harness")
local ArenaThemes = require("../src/shared/ArenaThemes")

print("ArenaThemes")

H.test("four themes, valid colors", function()
	H.eq(#ArenaThemes.List, 4)
	for _, t in ArenaThemes.List do
		for _, c in { t.rimA, t.rimB, t.ground } do
			H.eq(#c, 3)
			for _, v in c do
				H.truthy(v >= 0 and v <= 255)
			end
		end
	end
end)

H.test("week picks a theme, rotates every week, bad input is safe", function()
	H.eq(ArenaThemes.forWeek(0).name, ArenaThemes.List[1].name)
	H.eq(ArenaThemes.forWeek(1).name, ArenaThemes.List[2].name)
	H.eq(ArenaThemes.forWeek(4).name, ArenaThemes.List[1].name)
	H.eq(ArenaThemes.forWeek(2903).name, ArenaThemes.List[4].name)
	H.eq(ArenaThemes.forWeek(-1).name, ArenaThemes.List[1].name)
	H.eq(ArenaThemes.forWeek(0 / 0).name, ArenaThemes.List[1].name)
end)
