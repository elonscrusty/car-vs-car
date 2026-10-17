--!strict
-- Pure rematch rules. The end screen opens a window; each human taps REMATCH inside it.
-- When the window closes: everyone tapped -> "start", otherwise -> "lobby".
-- While it is still open and not everyone tapped the answer is "wait".

export type Decision = "start" | "lobby" | "wait"
export type State = {
	players: { any }, -- the humans of the match
	tapped: { [any]: boolean },
	open: boolean,
	broken: boolean, -- somebody left: no rematch any more
}

local Rematch = {}

function Rematch.new(players: { any }): State
	return { players = table.clone(players), tapped = {}, open = false, broken = false }
end

function Rematch.isMember(state: State, key: any): boolean
	return table.find(state.players, key) ~= nil
end

function Rematch.openWindow(state: State)
	state.open = true
end

function Rematch.closeWindow(state: State)
	state.open = false
end

-- True when this tap counted (window open, member, not tapped yet, nobody left).
function Rematch.tap(state: State, key: any): boolean
	if not state.open or state.broken or state.tapped[key] or not Rematch.isMember(state, key) then
		return false
	end
	state.tapped[key] = true
	return true
end

function Rematch.hasTapped(state: State, key: any): boolean
	return state.tapped[key] == true
end

-- A human left: the rematch is off.
function Rematch.playerLeft(state: State, key: any)
	if Rematch.isMember(state, key) then
		state.broken = true
	end
end

function Rematch.allTapped(state: State): boolean
	if #state.players == 0 then
		return false
	end
	for _, key in state.players do
		if not state.tapped[key] then
			return false
		end
	end
	return true
end

function Rematch.decide(state: State): Decision
	if state.broken then
		return "lobby"
	end
	if Rematch.allTapped(state) then
		return "start"
	end
	if state.open then
		return "wait"
	end
	return "lobby"
end

return Rematch
