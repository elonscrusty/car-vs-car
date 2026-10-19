--!strict
-- A short factual recap shown between rounds (pure, unit tested): what each weapon did.

export type Stats = {
	shots: number, -- shells fired
	shotHits: number, -- shells that hit
	charges: number, -- ram charges finished (hit or miss)
	ramHits: number,
	sawHits: number, -- saw damage ticks
}

local BattleRecap = {}

function BattleRecap.newStats(): Stats
	return { shots = 0, shotHits = 0, charges = 0, ramHits = 0, sawHits = 0 }
end

local function times(n: number, word: string): string
	return `{n} {word}{if n == 1 then "" else "s"}`
end

-- Up to three lines for one player: their own weapon first, then what the foe did to them.
function BattleRecap.lines(fighterId: string, mine: Stats, foe: Stats): { string }
	local out: { string } = {}
	if fighterId == "CannonVan" then
		table.insert(out, `Your cannon landed {mine.shotHits} of {times(mine.shots, "shot")}`)
	elseif fighterId == "RamTruck" then
		table.insert(out, `Your ram landed {mine.ramHits} of {times(mine.charges, "charge")}`)
	elseif fighterId == "SawBuggy" then
		table.insert(out, `Your saw landed {times(mine.sawHits, "hit")}`)
	end
	local taken: { string } = {}
	if foe.shotHits > 0 then
		table.insert(taken, times(foe.shotHits, "cannon hit"))
	end
	if foe.ramHits > 0 then
		table.insert(taken, times(foe.ramHits, "ram hit"))
	end
	if foe.sawHits > 0 then
		table.insert(taken, times(foe.sawHits, "saw hit"))
	end
	if #taken > 0 then
		table.insert(out, "You took " .. table.concat(taken, ", "))
	else
		table.insert(out, "You took no hits")
	end
	return out
end

return BattleRecap
