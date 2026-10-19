--!strict
-- "Is this the player's very first win?" (pure). Uses the saved win count from BEFORE the
-- match is counted, so no extra saved counter is needed (old saves already have `wins`).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("FirstWinConfig")

local FirstWin = {}

function FirstWin.isFirstWin(winsBefore: any, won: boolean): boolean
	return won and type(winsBefore) == "number" and winsBefore <= 0
end

function FirstWin.headline(): string
	return Config.headline
end

-- Reward toast, e.g. "FIRST WIN!   +25 COINS".
function FirstWin.toastText(coinsEarned: number): string
	local n = math.max(0, math.floor(coinsEarned))
	return `{Config.toastText}   +{n} COINS`
end

return FirstWin
