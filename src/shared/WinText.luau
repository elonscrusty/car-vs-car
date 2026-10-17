--!strict
-- Pure helpers for the end-of-match screen (no Roblox APIs, so Lune can test them).

local WinText = {}

export type Rewards = { winCoins: number, loseCoins: number }

export type Coin = {
	startX: number, -- 0..1 of screen width, at the bottom edge
	peakX: number, -- where it is at the top of the flight
	peakY: number, -- 0..1 of screen height (smaller = higher)
	endX: number,
	size: number, -- fraction of screen height
	delay: number, -- seconds before it launches
}

WinText.MaxCoins = 30
WinText.DefaultCoins = 24

function WinText.headline(won: boolean): string
	return if won then "YOU WIN!" else "YOU LOSE"
end

function WinText.coinsFor(won: boolean, rewards: Rewards): number
	return if won then rewards.winCoins else rewards.loseCoins
end

function WinText.subtitle(won: boolean, rewards: Rewards): string
	return `+{WinText.coinsFor(won, rewards)} coins`
end

-- Deterministic coin burst: same seed, same coins.
function WinText.coinParticles(seed: number, count: number): { Coin }
	local n = math.clamp(math.floor(count), 0, WinText.MaxCoins)
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	local function next01(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local out: { Coin } = {}
	for _ = 1, n do
		local startX = 0.1 + next01() * 0.8
		local peakX = math.clamp(startX + (next01() - 0.5) * 0.3, 0.02, 0.98)
		out[#out + 1] = {
			startX = startX,
			peakX = peakX,
			peakY = 0.15 + next01() * 0.35,
			endX = math.clamp(peakX + (next01() - 0.5) * 0.2, 0.02, 0.98),
			size = 0.05 + next01() * 0.03,
			delay = next01() * 0.5,
		}
	end
	return out
end

return WinText
