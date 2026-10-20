--!strict
-- Pure text/logic helpers for the lobby UI (no Roblox APIs, so Lune can test them).

local LobbyText = {}

-- Text keys the server sends instead of words (the client shows the text for a key).
-- claw = a random car, store = the car you pick.
LobbyText.Keys = {
	clawSurprise = "SPIN BOX",
	storeChoose = "CHOOSE YOUR CAR",
} :: { [string]: string }

function LobbyText.keyText(key: any): string
	if type(key) ~= "string" then
		return ""
	end
	return LobbyText.Keys[key] or ""
end

function LobbyText.formatNumber(n: number): string
	local s = tostring(math.floor(math.max(0, n)))
	local out = s
	repeat
		s = out
		out = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
	until out == s
	return out
end

function LobbyText.coinsText(n: number): string
	return `{LobbyText.formatNumber(n)} COINS`
end

function LobbyText.winsText(n: number): string
	return `{LobbyText.formatNumber(n)} WINS`
end

function LobbyText.percentText(percent: number): string
	if percent == math.floor(percent) then
		return `{math.floor(percent)}%`
	end
	return string.format("%.1f%%", percent)
end

-- "Common  60%  -  HEAVY, LIGHT"
function LobbyText.oddsLine(rarity: string, percent: number, carNames: { string }): string
	local names = if #carNames > 0 then table.concat(carNames, ", ") else "-"
	return `{rarity}  {LobbyText.percentText(percent)}  -  {names}`
end

-- "Duplicate = 25 coins back" for the gumball odds list.
function LobbyText.refundText(refund: number): string
	if refund <= 0 then
		return "Duplicate = nothing"
	end
	return `Duplicate = {LobbyText.formatNumber(refund)} coins back`
end

-- "Epic or better in 4 pulls" (0 left = the next pull).
function LobbyText.pityText(left: number, minRarity: string): string
	if left <= 1 then
		return `Next pull: {minRarity} or better!`
	end
	return `{minRarity} or better in {math.floor(left)} pulls`
end

function LobbyText.priceText(price: number, freeAvailable: boolean): string
	if freeAvailable then
		return "FIRST PULL FREE!"
	end
	return `PRICE: {LobbyText.formatNumber(price)} COINS`
end

function LobbyText.canAfford(coins: number, price: number, freeAvailable: boolean): boolean
	return freeAvailable or coins >= price
end

function LobbyText.buyButtonText(coins: number, price: number, freeAvailable: boolean): string
	if freeAvailable then
		return "OPEN FREE"
	end
	if coins < price then
		return `NEED {LobbyText.formatNumber(price - coins)} MORE`
	end
	return `OPEN  ({LobbyText.formatNumber(price)})`
end

function LobbyText.timerText(seconds: number): string
	return tostring(math.max(0, math.ceil(seconds)))
end

function LobbyText.resultText(isNew: boolean, refund: number): string
	if isNew then
		return "NEW!"
	end
	if refund <= 0 then
		return "DUPLICATE"
	end
	return `DUPLICATE  +{LobbyText.formatNumber(refund)} COINS`
end

function LobbyText.countdownText(seconds: number): string?
	if seconds <= 0 then
		return nil
	end
	return `Starting in {math.ceil(seconds)}...`
end

-- Small line under the pad countdown while nobody else is on the pad.
function LobbyText.padAloneText(alone: boolean): string?
	return if alone then "A bot will join you" else nil
end

function LobbyText.rewardText(coinsEarned: number, won: boolean): string
	local sign = if coinsEarned > 0 then "+" else ""
	return `{if won then "YOU WIN" else "YOU LOSE"}   {sign}{LobbyText.formatNumber(coinsEarned)} COINS`
end

function LobbyText.gachaErrorText(reason: string): string
	if reason == "coins" then
		return "Not enough coins"
	end
	return "Try again in a moment"
end

-- Store row label on the right: OWNED, or the price on a BUY button.
function LobbyText.storeButtonText(isOwned: boolean, price: number): string
	if isOwned then
		return "OWNED"
	end
	return `BUY  {LobbyText.formatNumber(price)}`
end

function LobbyText.storeErrorText(reason: string): string
	if reason == "coins" then
		return "Not enough coins"
	elseif reason == "owned" then
		return "Already yours"
	elseif reason == "busy" then
		return "Finish your match first"
	end
	return "Can't buy that"
end

return LobbyText
