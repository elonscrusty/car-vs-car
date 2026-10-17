--!strict
-- Pure pad state machine (no Roblox instances). The server's LobbyService drives it.
-- A pad is idle -> countdown (first player joined) -> locked (countdown done, bot filled).
-- Keys are any value that identifies a player (a Player on the server, a string in tests).

export type PadPhase = "idle" | "countdown" | "locked"

export type Pad = {
	phase: PadPhase,
	players: { any },
	seconds: number, -- countdown seconds left (only meaningful in "countdown")
}

export type State = {
	pads: { Pad },
	playerPad: { [any]: number },
	maxPlayers: number,
	countdownSeconds: number,
}

export type TickResult = "none" | "counting" | "ready"

local PadLogic = {}

function PadLogic.new(padCount: number, maxPlayers: number, countdownSeconds: number): State
	local pads: { Pad } = {}
	for i = 1, padCount do
		pads[i] = { phase = "idle", players = {}, seconds = 0 }
	end
	return {
		pads = pads,
		playerPad = {},
		maxPlayers = maxPlayers,
		countdownSeconds = countdownSeconds,
	}
end

local function removeKey(list: { any }, key: any)
	local i = table.find(list, key)
	if i then
		table.remove(list, i)
	end
end

-- Join a pad. First player starts the countdown. Returns ok, reason.
function PadLogic.join(state: State, padIndex: any, key: any): (boolean, string?)
	if type(padIndex) ~= "number" or padIndex % 1 ~= 0 then
		return false, "badPad"
	end
	local pad = state.pads[padIndex]
	if pad == nil then
		return false, "badPad"
	end
	if state.playerPad[key] ~= nil then
		return false, "alreadyOnPad"
	end
	if pad.phase == "locked" then
		return false, "started"
	end
	if #pad.players >= state.maxPlayers then
		return false, "full"
	end
	table.insert(pad.players, key)
	state.playerPad[key] = padIndex
	if pad.phase == "idle" then
		pad.phase = "countdown"
		pad.seconds = state.countdownSeconds
	end
	return true, nil
end

-- Remove a player from whatever pad they are on. Returns the pad index (nil if on none)
-- and whether the pad went back to idle (empty).
function PadLogic.leave(state: State, key: any): (number?, boolean)
	local padIndex = state.playerPad[key]
	if padIndex == nil then
		return nil, false
	end
	state.playerPad[key] = nil
	local pad = state.pads[padIndex]
	removeKey(pad.players, key)
	if #pad.players == 0 then
		pad.phase = "idle"
		pad.seconds = 0
		return padIndex, true
	end
	return padIndex, false
end

-- One-second tick of a pad countdown. "ready" means it hit zero and the pad is now locked.
function PadLogic.tick(state: State, padIndex: number): (TickResult, number)
	local pad = state.pads[padIndex]
	if pad == nil or pad.phase ~= "countdown" then
		return "none", 0
	end
	pad.seconds = math.max(0, pad.seconds - 1)
	if pad.seconds <= 0 then
		pad.phase = "locked"
		return "ready", 0
	end
	return "counting", pad.seconds
end

-- Cancel a pad: everyone is removed, pad goes idle. Returns who was on it.
function PadLogic.cancel(state: State, padIndex: number): { any }
	local pad = state.pads[padIndex]
	if pad == nil then
		return {}
	end
	local removed = table.clone(pad.players)
	for _, key in removed do
		state.playerPad[key] = nil
	end
	table.clear(pad.players)
	pad.phase = "idle"
	pad.seconds = 0
	return removed
end

-- Number of players shown on the sign. Bots fill empty slots once the pad is locked.
function PadLogic.shown(state: State, padIndex: number): number
	local pad = state.pads[padIndex]
	if pad == nil then
		return 0
	end
	if pad.phase == "locked" then
		return state.maxPlayers
	end
	return #pad.players
end

-- True when there is at least one player and every one of them has picked a car.
function PadLogic.allPicked(keys: { any }, picks: { [any]: string }): boolean
	if #keys == 0 then
		return false
	end
	for _, key in keys do
		if picks[key] == nil then
			return false
		end
	end
	return true
end

-- A pick is valid only if it is one of the offered cars. Returns the car id or nil.
function PadLogic.validatePick(offered: { string }, carId: any): string?
	if type(carId) ~= "string" then
		return nil
	end
	if table.find(offered, carId) then
		return carId
	end
	return nil
end

-- Timeout auto-pick: a random offered car (rng returns [0,1)).
function PadLogic.autoPick(offered: { string }, rng: () -> number): string?
	if #offered == 0 then
		return nil
	end
	local i = math.clamp(math.floor(rng() * #offered) + 1, 1, #offered)
	return offered[i]
end

return PadLogic
