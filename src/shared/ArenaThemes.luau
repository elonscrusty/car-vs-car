--!strict
-- Weekly bowl look: 4 palettes that rotate by week number. Looks only (rim stripe colors and a
-- ground tint); sizes, radii and physics never change. Pure data + a pick rule, unit tested.
-- Colors are {r, g, b} 0-255 so tests can load this without Roblox.

export type Rgb = { number }
export type Theme = { name: string, rimA: Rgb, rimB: Rgb, ground: Rgb }

local ArenaThemes = {}

-- Placeholder palettes (pure looks). Index 1 is the steel blue + yellow garage look.
ArenaThemes.List = {
	{
		name = "Classic",
		rimA = { 55, 95, 150 },
		rimB = { 250, 205, 60 },
		ground = { 125, 190, 120 },
	},
	{
		name = "Ocean",
		rimA = { 40, 130, 200 },
		rimB = { 235, 248, 255 },
		ground = { 110, 190, 175 },
	},
	{
		name = "Sunset",
		rimA = { 225, 140, 50 },
		rimB = { 255, 235, 190 },
		ground = { 190, 190, 120 },
	},
	{
		name = "Night",
		rimA = { 50, 70, 120 },
		rimB = { 200, 215, 240 },
		ground = { 100, 145, 125 },
	},
} :: { Theme }

-- Theme for a week number (see Leaderboard.weekIndex). Bad input gives the first theme.
function ArenaThemes.forWeek(week: number): Theme
	local n = #ArenaThemes.List
	if type(week) ~= "number" or week ~= week or week < 0 or week == math.huge then
		return ArenaThemes.List[1]
	end
	return ArenaThemes.List[math.floor(week) % n + 1]
end

return ArenaThemes
