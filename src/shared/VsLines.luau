--!strict
-- The funny line each car says on the VS screen before a fight (pure, unit tested). These are
-- PLACEHOLDERS: the fight thread / carter send the real lines, and a line that comes with the
-- prep message (`me.line` / `opp.line`) always wins over this table.

local VsLines = {}

local LINES: { [string]: { string } } = {
	RamTruck = { "Knock knock. It is me, the wall.", "I brake for nobody." },
	CannonVan = { "I came to deliver pain. Signature please.", "Pew pew, the roof says hi." },
	SawBuggy = { "Hold still, this tickles.", "I am a very small, very angry lawnmower." },
}

local GENERIC = { "Ready when you are.", "Let us make some noise." }

local function pick(list: { string }, seed: number): string
	return list[(seed % #list) + 1]
end

-- A small stable number from a name, so a player sees the same line for the same opponent.
function VsLines.seedOf(name: string): number
	local n = 0
	for i = 1, #name do
		n = (n * 31 + string.byte(name, i)) % 1000003
	end
	return n
end

-- `override` is a line the server sent (used if it is a non-empty string).
function VsLines.lineFor(carId: string, seed: number?, override: any?): string
	if type(override) == "string" and override ~= "" then
		return override
	end
	return pick(LINES[carId] or GENERIC, seed or 0)
end

return VsLines
