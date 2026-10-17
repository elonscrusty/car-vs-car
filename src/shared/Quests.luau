--!strict
-- Quests ("win 3 with Tank"). Pure rules so Lune can test them. Owned by the quests worker.
-- LobbyService calls `onMatchEnd` once per finished match, right where it pays the coin reward.

local Quests = {}

export type MatchInfo = { won: boolean, carId: string, opponentIsBot: boolean }

-- Updates quest progress inside `profile` (a Profile table). Returns true if anything changed.
function Quests.onMatchEnd(_profile: any, _info: MatchInfo): boolean
	return false -- stub
end

return Quests
