--!strict
-- Weekly bowl look: 4 palettes that rotate by week number. Looks only (rim stripe colors and a
-- ground tint); sizes, radii and physics never change. Pure data + a pick rule, unit tested.
-- Colors are {r, g, b} 0-255 so tests can load this without Roblox.

export type Rgb = { number }
export type Theme = { name: string, rimA: Rgb, rimB: Rgb, ground: Rgb }

local ArenaThemes = {}

-- Placeholder palettes (pure looks). Index 1 matches the original red/white + green look.
ArenaThemes.List = {
	{
		name = "Classic",
		rimA = { 230, 55, 55 },
		rimB = { 250, 250, 250 },
		ground = { 110, 200, 90 },
	},
	{
		name = "Ocean",
		rimA = { 40, 130, 230 },
		rimB = { 235, 248, 255 },
		ground = { 90, 200, 190 },
	},
	{
		name = "Sunset",
		rimA = { 255, 140, 40 },
		rimB = { 255, 235, 190 },
		ground = { 215, 185, 100 },
	},
	{
		name = "Night",
		rimA = { 150, 80, 230 },
		rimB = { 215, 205, 245 },
		ground = { 80, 120, 110 },
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
