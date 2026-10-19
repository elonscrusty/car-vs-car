--!strict
-- Pure rules for the car fight (last car standing): how hard a big hit launches the car that
-- got hit, and how many bits fly off. No Roblox calls. Numbers: ModesConfig.LastStanding.Hit.

local BrawlRules = {}

export type HitCfg = {
	from: number, -- hits at least this strong (0..1) launch the victim
	push: number, -- sideways speed away from the attacker at full strength (studs/s)
	up: number, -- upward speed at full strength (studs/s)
	spin: number, -- spin at full strength (rad/s)
	scrapMax: number, -- most bits that fly off one hit
	peelFrom: number, -- hits at least this strong tear a real part off the car
}

-- (push, up, spin) for a hit of `strength` (0..1); all 0 under `from`.
function BrawlRules.launch(strength: number, cfg: HitCfg): (number, number, number)
	if strength < cfg.from then
		return 0, 0, 0
	end
	local s = math.clamp(strength, 0, 1)
	return cfg.push * s, cfg.up * s, cfg.spin * s
end

-- Bits that fly off a hit: none under `from`, then growing with strength up to `scrapMax`.
function BrawlRules.scrapCount(strength: number, cfg: HitCfg): number
	if strength < cfg.from then
		return 0
	end
	return math.max(1, math.floor(math.clamp(strength, 0, 1) * cfg.scrapMax + 0.5))
end

function BrawlRules.peels(strength: number, cfg: HitCfg): boolean
	return strength >= cfg.peelFrom
end

export type ShrinkCfg = {
	startSeconds: number, -- the walls stay put until this many seconds into the round
	endSeconds: number, -- ...and have closed to `minRadius` by this time
	minRadius: number,
}

-- How far from the middle it is still safe, `t` seconds into the round. Linear close-in.
function BrawlRules.safeRadius(t: number, fullRadius: number, cfg: ShrinkCfg): number
	if t <= cfg.startSeconds or cfg.endSeconds <= cfg.startSeconds then
		return fullRadius
	end
	local k = math.clamp((t - cfg.startSeconds) / (cfg.endSeconds - cfg.startSeconds), 0, 1)
	return fullRadius + (math.min(cfg.minRadius, fullRadius) - fullRadius) * k
end

-- Best of N rounds: who won the match so far? `wins[i]` = rounds won by car i. Returns the car
-- index, or 0 = play another round. After `maxRounds` the most wins takes it; a tie goes to the
-- winner of the last round.
function BrawlRules.matchWinner(
	wins: { [number]: number },
	roundsPlayed: number,
	winsNeeded: number,
	maxRounds: number,
	lastRoundWinner: number
): number
	local best, bestWins, tied = 0, 0, false
	for i, w in wins do
		if w >= winsNeeded then
			return i
		end
		if w > bestWins then
			best, bestWins, tied = i, w, false
		elseif w == bestWins and w > 0 then
			tied = true
		end
	end
	if roundsPlayed < maxRounds then
		return 0
	end
	if best == 0 or tied then
		return lastRoundWinner
	end
	return best
end

return BrawlRules
