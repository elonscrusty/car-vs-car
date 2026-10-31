--!strict
-- ONE tiny goal in a match (carter 10-31 "addicting" pick 3): "SMASH 3", then "SMASH 5" ...
-- It always shows the NEXT step above your smashes this match; when the last step is done it says
-- "NICE!" and stays calm. Pure numbers and words (Lune tests it); looks only, no reward of its own.
local MatchGoal = {}

MatchGoal.STEPS = { 1, 3, 5, 8 } -- smashes (a 2:00 match with 8 karts: 1 and 3 are easy, 8 is a lot)

export type View = {
	words: string, -- "SMASH 3"
	have: number, -- smashes counted toward this step
	need: number, -- this step's size
	f: number, -- bar fill 0..1
	done: boolean, -- every step is done
}

-- smashes: your smashes this match (junk -> 0)
function MatchGoal.read(smashes: any): View
	local n = 0
	if type(smashes) == "number" and smashes == smashes then
		n = math.max(0, math.floor(smashes))
	end
	local last = MatchGoal.STEPS[#MatchGoal.STEPS]
	if n >= last then
		return { words = "NICE!", have = last, need = last, f = 1, done = true }
	end
	for _, step in MatchGoal.STEPS do
		if n < step then
			return { words = `SMASH {step}`, have = n, need = step, f = n / step, done = false }
		end
	end
	return { words = "NICE!", have = last, need = last, f = 1, done = true }
end

return MatchGoal
