--!strict
-- The game's three type jobs (carter 10-29, "Steel Shop" set): a tall tough face for big words,
-- a plain narrow face for numbers, a quiet face for small words. All three are Roblox's own
-- fonts, so there is nothing to upload. Big words keep the ink stroke; small words sit on a
-- dark plate with little or no stroke.
local UiFonts = {}

UiFonts.TITLE = Enum.Font.Oswald -- 1ST, NEW CAR!, buttons, signs
UiFonts.NUM = Enum.Font.RobotoCondensed -- timer, x7, 72/100, ammo, prices
UiFonts.SMALL = Enum.Font.Roboto -- kill feed, name tags, odds, tips

-- Which job a bit of words does: digits and their signs are numbers, short low boxes with a
-- light stroke are small words, the rest are big words.
function UiFonts.role(words: string, boxH: number?, stroke: number?): string
	if string.match(words, "^[%d%s%p%+x]+$") ~= nil and string.find(words, "%d") ~= nil then
		return "num"
	end
	if boxH ~= nil and boxH <= 20 and (stroke or 0) <= 3.5 then
		return "small"
	end
	return "title"
end

function UiFonts.forRole(role: string): Enum.Font
	if role == "num" then
		return UiFonts.NUM
	elseif role == "small" then
		return UiFonts.SMALL
	end
	return UiFonts.TITLE
end

return UiFonts
