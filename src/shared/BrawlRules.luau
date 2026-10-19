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

return BrawlRules
