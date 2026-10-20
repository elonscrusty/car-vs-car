--!strict
-- The lobby's PLAY pads (pure, unit tested). A player waits by standing on a pad; two on the same
-- pad make a fight. Nobody waits for a timer and nobody is filled in by a bot: a pad with one
-- player just waits. A key is a user id.

export type Event = { kind: string, id: number?, pad: number, ids: { number }? }

export type State = {
	pads: { { number } }, -- per pad, the ids standing there, in arrival order
	at: { [number]: number }, -- id -> pad
	cap: number,
}

local PadSlots = {}

function PadSlots.new(count: number, cap: number): State
	local pads = {}
	for _ = 1, count do
		table.insert(pads, {})
	end
	return { pads = pads, at = {}, cap = cap }
end

function PadSlots.counts(s: State): { number }
	local out = {}
	for i, list in s.pads do
		out[i] = #list
	end
	return out
end

function PadSlots.padOf(s: State, id: number): number?
	return s.at[id]
end

-- Take an id off its pad (walked off, left the game, started a fight). False when not on one.
function PadSlots.leave(s: State, id: number): boolean
	local i = s.at[id]
	if i == nil then
		return false
	end
	local list = s.pads[i]
	local k = table.find(list, id)
	if k then
		table.remove(list, k)
	end
	s.at[id] = nil
	return true
end

-- `observed` maps id -> the pad that id physically stands on right now (ids not on a pad are left
-- out). `ignore` lists ids to skip (in a fight). Returns what changed, in order:
--   left  (id, pad)          the id is no longer on that pad
--   joined(id, pad)          the id now waits on that pad
--   full  (id, pad)          the id stands on a pad that already has `cap` waiting: not counted
--   ready (pad, ids)         the pad is full: these ids fight now (they are taken off the pad)
function PadSlots.update(
	s: State,
	observed: { [number]: number },
	ignore: { [number]: boolean }?
): { Event }
	local events: { Event } = {}
	local skip = ignore or {}
	local tracked: { number } = {}
	for id in s.at do
		table.insert(tracked, id)
	end
	table.sort(tracked)
	for _, id in tracked do
		if observed[id] ~= s.at[id] or skip[id] then
			local pad = s.at[id]
			PadSlots.leave(s, id)
			table.insert(events, { kind = "left", id = id, pad = pad })
		end
	end
	local arrivals: { number } = {}
	for id in observed do
		if s.at[id] == nil and not skip[id] then
			table.insert(arrivals, id)
		end
	end
	table.sort(arrivals)
	for _, id in arrivals do
		local pad = observed[id]
		local list = s.pads[pad]
		if list ~= nil then
			if #list < s.cap then
				table.insert(list, id)
				s.at[id] = pad
				table.insert(events, { kind = "joined", id = id, pad = pad })
			else
				table.insert(events, { kind = "full", id = id, pad = pad })
			end
		end
	end
	for pad, list in s.pads do
		if #list >= s.cap then
			local ids = table.clone(list)
			for _, id in ids do
				PadSlots.leave(s, id)
			end
			table.insert(events, { kind = "ready", pad = pad, ids = ids })
		end
	end
	return events
end

-- The pad the PLAY button should send someone to: a pad with someone waiting first (most waiting
-- that is not full), then an empty pad. `friends` (ids) pull their pad to the front. nil = all full.
function PadSlots.suggest(s: State, friends: { number }?): number?
	if friends then
		for _, f in friends do
			local i = s.at[f]
			if i and #s.pads[i] < s.cap then
				return i
			end
		end
	end
	local best: number? = nil
	for i, list in s.pads do
		if #list > 0 and #list < s.cap and (best == nil or #list > #s.pads[best]) then
			best = i
		end
	end
	if best then
		return best
	end
	for i, list in s.pads do
		if #list == 0 then
			return i
		end
	end
	return nil
end

-- The same choice from plain counts (the lobby only knows how many wait on each pad).
function PadSlots.suggestFromCounts(counts: { number }, cap: number): number?
	local best: number? = nil
	for i, n in counts do
		if n > 0 and n < cap and (best == nil or n > counts[best]) then
			best = i
		end
	end
	if best then
		return best
	end
	for i, n in counts do
		if n == 0 then
			return i
		end
	end
	return nil
end

return PadSlots
