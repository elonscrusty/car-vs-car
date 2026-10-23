--!strict
-- Timing gates for the race lap and the rock climb. Pure maths (plain tables).
-- "loop": gate 1 is the start/finish line, cross the others in order, then gate 1 again = a lap.
-- "oneway": cross gate 1 to start, the LAST gate stops the clock.

export type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number, -- unit direction of travel
	dz: number,
	halfWidth: number,
	depth: number, -- half thickness along the travel direction
}

export type State = {
	gates: { Gate },
	mode: string,
	next: number,
	running: boolean,
	startTime: number,
	laps: number,
	last: number?,
	best: number?,
	finished: boolean,
}

local HEIGHT_SLACK = 14

local LapTimer = {}

function LapTimer.new(gates: { Gate }, mode: string): State
	return {
		gates = gates,
		mode = mode,
		next = 1,
		running = false,
		startTime = 0,
		laps = 0,
		last = nil,
		best = nil,
		finished = false,
	}
end

-- Forget the run (keeps the best time).
function LapTimer.reset(s: State)
	s.next = 1
	s.running = false
	s.finished = false
	s.laps = 0
end

-- Start the clock now (a standing start, when the start lights go green): the line just ahead
-- doesn't restart it, the next gate is gate 2.
function LapTimer.go(s: State, now: number)
	s.running = true
	s.finished = false
	s.startTime = now
	s.next = 2
end

function LapTimer.inside(g: Gate, x: number, y: number, z: number): boolean
	local rx, rz = x - g.x, z - g.z
	local along = rx * g.dx + rz * g.dz
	local across = rx * -g.dz + rz * g.dx
	return math.abs(along) <= g.depth
		and math.abs(across) <= g.halfWidth
		and math.abs(y - g.y) <= HEIGHT_SLACK
end

local function record(s: State, t: number)
	s.last = t
	local best = s.best
	if best == nil or t < best then
		s.best = t
	end
end

-- Call every frame. Returns "start", "checkpoint", "lap", "finish" or nil.
function LapTimer.update(s: State, now: number, x: number, y: number, z: number): string?
	local count = #s.gates
	if count == 0 then
		return nil
	end
	if not s.running then
		if LapTimer.inside(s.gates[1], x, y, z) then
			s.running = true
			s.finished = false
			s.startTime = now
			s.next = 2
			return "start"
		end
		return nil
	end
	local gate = s.gates[((s.next - 1) % count) + 1]
	if not LapTimer.inside(gate, x, y, z) then
		return nil
	end
	if s.mode == "oneway" and s.next == count then
		record(s, now - s.startTime)
		s.running = false
		s.finished = true
		s.next = 1
		return "finish"
	end
	if s.mode == "loop" and s.next == count + 1 then
		record(s, now - s.startTime)
		s.laps += 1
		s.startTime = now
		s.next = 2
		return "lap"
	end
	s.next += 1
	return "checkpoint"
end

return LapTimer
