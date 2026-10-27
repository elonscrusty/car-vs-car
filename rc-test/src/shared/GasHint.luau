--!strict
-- The first race's "the car just sits there" hint (Studio check: a new kid didn't know what to
-- press at GO). Look only: it never touches how the car drives.

local GasHint = {}

GasHint.WAIT = 2 -- seconds after GO with the car still on the line before the hint shows

-- Show the hint? `sinceGo` = seconds since this car's GO (nil = no GO yet), `moved` = the car has
-- moved or the gas was pressed since GO, `over` = finished or the results are in.
function GasHint.shows(sinceGo: number?, moved: boolean, over: boolean): boolean
	return sinceGo ~= nil and sinceGo >= GasHint.WAIT and not moved and not over
end

-- What it says: a phone has the GAS button, a computer the keys.
function GasHint.words(touch: boolean): string
	return if touch then "HOLD GAS!" else "HOLD W TO GO!"
end

return GasHint
