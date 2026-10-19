--!strict
-- The 30-second tutorial of a player's very first fight (pure, no Roblox calls). Steps run in
-- order: SMASH a car first, then BOOST, then the ABILITY, then "knock everyone out". A step ends
-- when the player does the thing, or when its time runs out so nobody gets stuck. The server
-- (GroupMatch) sends the line of the current step to that player; the UI shows it.

local Tutorial = {}

export type Step = {
	id: string, -- also the TutorialStep attribute value the UI can read
	text: string,
	doneBy: string?, -- the event that finishes it ("hit" | "boost" | "special"); nil = timed only
	maxSeconds: number, -- the step ends by itself after this long
}

Tutorial.Steps = {
	{ id = "smash", text = "SMASH into a car!", doneBy = "hit", maxSeconds = 12 },
	{ id = "boost", text = "Tap BOOST to go fast!", doneBy = "boost", maxSeconds = 9 },
	{ id = "ability", text = "Use your ABILITY!", doneBy = "special", maxSeconds = 9 },
	{ id = "fight", text = "Knock out everyone! Last car wins!", doneBy = nil, maxSeconds = 4 },
} :: { Step }

export type State = { step: number, since: number } -- step 0 = not started, > #Steps = finished

function Tutorial.new(): State
	return { step = 0, since = 0 }
end

function Tutorial.total(): number
	local t = 0
	for _, s in Tutorial.Steps do
		t += s.maxSeconds
	end
	return t
end

function Tutorial.current(s: State): Step?
	return Tutorial.Steps[s.step]
end

local function advance(s: State, now: number): Step?
	s.step += 1
	s.since = now
	return Tutorial.Steps[s.step]
end

-- Call every so often with the time the fight has run. Returns the step to SHOW when it changed
-- (the first step at the start, the next one after a timeout), else nil. After the last step: nil.
function Tutorial.tick(s: State, now: number): Step?
	if s.step == 0 then
		return advance(s, now)
	end
	local cur = Tutorial.Steps[s.step]
	if cur and now - s.since >= cur.maxSeconds then
		return advance(s, now)
	end
	return nil
end

-- The player did `event`. Returns the next step to show when it finished the current one.
function Tutorial.event(s: State, event: string, now: number): Step?
	local cur = Tutorial.Steps[s.step]
	if cur and cur.doneBy == event then
		return advance(s, now)
	end
	return nil
end

function Tutorial.finished(s: State): boolean
	return s.step > #Tutorial.Steps
end

return Tutorial
