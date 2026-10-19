--!strict
-- Friendly random names for bot drivers (pure). A bot is never just "BOT".

local BotNames = {}

BotNames.List = {
	"Sparky",
	"Turbo Tim",
	"Zippy",
	"Bumper Bob",
	"Captain Crash",
	"Wheelie Will",
	"Rusty",
	"Speedy Sue",
	"Mighty Max",
	"Dizzy Dan",
	"Pixel",
	"Nitro Nina",
	"Boomer",
	"Gizmo",
	"Beep Beep",
	"Rocket Ruby",
	"Crash Test Carl",
	"Donut",
	"Vroom Vroom",
	"Bolt",
	"Wobbly Walt",
	"Lucky",
	"Tumble",
	"Skids",
	"Honk",
	"Pancake",
	"Ziggy",
	"Buzz",
	"Clunky Clara",
	"Jumpy Jo",
} :: { string }

-- Turns any seed into a well-mixed non-negative integer (simple LCG steps, no Random needed).
local function mix(seed: number): number
	local x = math.floor(math.abs(seed)) % 2147483647
	for _ = 1, 3 do
		x = (x * 48271 + 11) % 2147483647
	end
	return x
end

-- Same seed -> same name. `taken` (optional) names to avoid while any free name is left.
function BotNames.pick(seed: number, taken: { string }?): string
	local list = BotNames.List
	local start = mix(seed) % #list
	for step = 0, #list - 1 do
		local name = list[(start + step) % #list + 1]
		if taken == nil or table.find(taken, name) == nil then
			return name
		end
	end
	return list[start + 1]
end

-- Same seed -> same car id from `roster` (the live cars). Nil when the roster is empty.
function BotNames.pickCar(seed: number, roster: { string }): string?
	if #roster == 0 then
		return nil
	end
	return roster[mix(seed + 7919) % #roster + 1]
end

return BotNames
