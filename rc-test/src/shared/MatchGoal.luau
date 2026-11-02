--!strict
-- ONE tiny goal in a match (carter 10-31 "addicting" pick 3): "SMASH 3", then "SMASH 5" ...
-- It always shows the NEXT step above your smashes this match; when the last step is done it says
-- "NICE!" and stays calm. Pure numbers and words (Lune tests it); looks only, no reward of its own.
local MatchGoal = {}

-- Where the pill sits: left edge, x px from the safe area's left, its top at TOP of the safe height
-- (176 of the 390 design px: just under the scoreboard / kill list and above the stick, which
-- starts at 250). Phone check: tests/match_goal.test.
MatchGoal.PILL = { x = 10, top = 176 / 390, w = 112, h = 34 }

MatchGoal.STEPS = { 1, 3, 5, 8 } -- smashes (a 2:00 match with 8 karts: 1 and 3 are easy, 8 is a lot)

export type View = {
	words: string, -- "SMASH 3"
	have: number, -- smashes counted toward this step
	need: number, -- this step's size
	f: number, -- bar fill 0..1
	done: boolean, -- every step is done
}

-- Is the player still in a running match? The server leaves InMatch on through the between-rounds
-- break (and the player's MatchEndsAt as it was), so the end time has to be checked too, or the
-- pill, the SPECIAL button and the edge arrows would stay up over the end screen. A second of
-- grace after the clock (the same as the match HUD).
function MatchGoal.live(inMatch: any, endsAt: any, now: number): boolean
	return inMatch == true and type(endsAt) == "number" and endsAt > now - 1
end

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
