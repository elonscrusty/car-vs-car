--!strict
-- Pure rules for the SUPER KICK orbs of car soccer (no Roblox calls): where they sit, who takes
-- one, when it comes back, and what the kick does to the ball. The server (GroupMatch) draws the
-- orbs and moves the ball. Numbers: ModesConfig.Soccer.Orbs. Unit tested.

local SoccerOrbs = {}

export type Cfg = {
	spots: { { x: number, z: number } },
	radius: number,
	respawn: number,
	holdSeconds: number,
	kickSpeed: number,
	kickLift: number,
}

export type State = { readyAt: { number } }

function SoccerOrbs.new(cfg: Cfg): State
	local r: { number } = {}
	for i = 1, #cfg.spots do
		r[i] = 0
	end
	return { readyAt = r }
end

function SoccerOrbs.lit(s: State, i: number, now: number): boolean
	return now >= s.readyAt[i]
end

-- A car at flat (x, z) takes the orb it stands on (0 = none). The orb goes dark for `respawn`.
function SoccerOrbs.take(s: State, cfg: Cfg, x: number, z: number, now: number): number
	for i, spot in cfg.spots do
		if now >= s.readyAt[i] and (x - spot.x) ^ 2 + (z - spot.z) ^ 2 <= cfg.radius ^ 2 then
			s.readyAt[i] = now + cfg.respawn
			return i
		end
	end
	return 0
end

-- Ball velocity after a super kick: flat direction from the car to the ball, `kickSpeed` fast,
-- with a little lift. Returns (vx, vy, vz). A car right on top of the ball kicks along +X.
function SoccerOrbs.kick(cfg: Cfg, dx: number, dz: number): (number, number, number)
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-3 then
		return cfg.kickSpeed, cfg.kickLift, 0
	end
	return dx / len * cfg.kickSpeed, cfg.kickLift, dz / len * cfg.kickSpeed
end

return SoccerOrbs
