--!strict
-- Pure schedule for the car soccer "chaos moments" (no Roblox calls): every few seconds of play
-- something shakes the match up so no stretch of 20 seconds is quiet. The server (GroupMatch)
-- does the effect; this only says WHEN and WHICH. Numbers: ModesConfig.Soccer.Chaos. Unit tested.

local SoccerChaos = {}

export type State = { nextAt: number, count: number }

export type Config = {
	firstSeconds: number,
	everySeconds: number,
	kinds: { string },
}

function SoccerChaos.new(cfg: Config): State
	return { nextAt = cfg.firstSeconds, count = 0 }
end

-- `playSeconds` = match seconds spent in play (not countdowns). Returns the event kind that
-- fires now, or nil. Kinds take turns in the order of `cfg.kinds`.
function SoccerChaos.step(s: State, cfg: Config, playSeconds: number): string?
	if #cfg.kinds == 0 or playSeconds < s.nextAt then
		return nil
	end
	local kind = cfg.kinds[s.count % #cfg.kinds + 1]
	s.count += 1
	s.nextAt = playSeconds + cfg.everySeconds
	return kind
end

return SoccerChaos
