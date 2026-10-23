--!strict
-- Race start lights: after the car is put on the start, three red lamps on the start arch light
-- one by one with a beep, then all turn green: GO, and the lap clock starts. Pure maths.
-- Timing only: the car drives the same the whole time (going over the line early = no timed lap).

export type State = {
	t: number, -- seconds since the countdown began
	shown: number, -- lamps lit so far (4 = green, done)
}

local RaceStart = {}

RaceStart.WAIT = 0.6 -- a moment after landing on the start before the first lamp
RaceStart.STEP = 0.8 -- seconds between lamps
RaceStart.GO = 4 -- the step that turns them green

function RaceStart.new(): State
	return { t = 0, shown = 0 }
end

-- Call every frame. Returns 1, 2 or 3 when that red lamp lights, RaceStart.GO for green, else nil.
function RaceStart.update(s: State, dt: number): number?
	if s.shown >= RaceStart.GO then
		return nil
	end
	s.t += dt
	local due = math.floor((s.t - RaceStart.WAIT) / RaceStart.STEP) + 1
	if due > s.shown then
		s.shown += 1
		return s.shown
	end
	return nil
end

-- What the big text says for a step: 3, 2, 1, GO!
function RaceStart.label(step: number): string
	return if step >= RaceStart.GO then "GO!" else tostring(RaceStart.GO - step)
end

return RaceStart
