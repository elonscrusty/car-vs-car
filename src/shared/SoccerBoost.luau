--!strict
-- Pure boost pad rules for car soccer (no Roblox calls): which spots exist, who is on one, and when
-- a taken pad is lit again. The server (GroupMatch) makes the car's BOOST ready; SoccerArena draws
-- the glowing spots. Numbers: SoccerFieldConfig.boostPads. Unit tested.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("SoccerFieldConfig")

local SoccerBoost = {}

export type Pads = { readyAt: { number } } -- per pad: the time it is lit again (0 = lit now)

function SoccerBoost.count(): number
	return #Config.boostPads
end

-- Pad `i` as flat (x, z) relative to the field middle.
function SoccerBoost.spot(i: number): (number, number)
	local p = Config.boostPads[i]
	return p.x, p.z
end

function SoccerBoost.new(): Pads
	local ready: { number } = {}
	for i = 1, #Config.boostPads do
		ready[i] = 0
	end
	return { readyAt = ready }
end

function SoccerBoost.lit(p: Pads, i: number, now: number): boolean
	return now >= p.readyAt[i]
end

-- A car at flat (x, z): returns the pad it takes (0 = none). The pad goes dark for the respawn time.
function SoccerBoost.take(p: Pads, x: number, z: number, now: number): number
	local r2 = Config.boostPadRadius ^ 2
	for i, spot in Config.boostPads do
		if now >= p.readyAt[i] and (x - spot.x) ^ 2 + (z - spot.z) ^ 2 <= r2 then
			p.readyAt[i] = now + Config.boostPadRespawn
			return i
		end
	end
	return 0
end

-- Everything lit again (new kickoff does NOT call this: pads keep their own timers).
function SoccerBoost.reset(p: Pads)
	for i = 1, #p.readyAt do
		p.readyAt[i] = 0
	end
end

return SoccerBoost
