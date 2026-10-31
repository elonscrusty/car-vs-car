--!strict
-- Smash between-rounds screen data (plans/smash/VIDEO-STUDY.md, carter GO 22:13): ROUND OVER,
-- "<name> WINS" with the winner's kart, the top 3 with smashes, your coins and XP, then "NEW ROUND
-- STARTING IN 12" (the next round starts by itself; LEAVE goes back to the lobby).
-- The server (MatchRunner) fires ReplicatedStorage.MatchResult to each player:
--   FireClient(player, places, coins, nextAt, xp?)
--   places = { { name, smashes, userId? (nil = bot), carId? } } best first, every kart;
--   coins / xp = what this player earned; nextAt = workspace:GetServerTimeNow() at the next round.
-- MatchEnd.args builds those (server), MatchEnd.read checks them (client: junk never errors).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent:WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end
local Xp = sibling("Xp")
local Match = sibling("Match")

local MatchEnd = {}

MatchEnd.AUTO = 8 -- the break between rounds when the server sends no nextAt
MatchEnd.MAX_ROWS = 12 -- a match has at most 12 karts
MatchEnd.MAX_NAME = 20

export type Row = { name: string, smashes: number, userId: number?, carId: string? }
export type View = {
	place: number, -- this player's place (0 = not in the list)
	total: number, -- karts in the match
	top: { Row & { me: boolean } }, -- 1st, 2nd, 3rd (fewer if fewer karts)
	winner: (Row & { me: boolean })?,
	coins: number,
	xp: number,
	smashes: number, -- this player's smashes
	nextAt: number?,
}

local function count(v: unknown, most: number): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, most)
end

local function words(v: unknown): string
	if type(v) ~= "string" then
		return "?"
	end
	local s = string.gsub(v, "[%c]", "")
	if utf8.len(s) == nil then
		return "?" -- not real text
	end
	-- cut by letters, not bytes (a cut through an accent or emoji shows as junk)
	local cut = utf8.offset(s, MatchEnd.MAX_NAME + 1)
	if cut then
		s = string.sub(s, 1, cut - 1)
	end
	return if s == "" then "?" else s
end

-- Server: the MatchResult arguments for one player (places best first).
function MatchEnd.args(
	places: { Row },
	coins: number,
	nextAt: number?,
	xp: number?
): ({ Row }, number, number?, number?)
	local rows = {}
	for i, r in places do
		if i > MatchEnd.MAX_ROWS then
			break
		end
		table.insert(
			rows,
			{ name = r.name, smashes = r.smashes, userId = r.userId, carId = r.carId }
		)
	end
	return rows, coins, nextAt, xp
end

-- Client: what the end screen shows for player `myId`, from MatchResult's arguments. Anything
-- odd is dropped, never an error.
function MatchEnd.read(
	places: unknown,
	coins: unknown,
	nextAt: unknown,
	xp: unknown,
	myId: number
): View
	local view: View = {
		place = 0,
		total = 0,
		top = {},
		winner = nil,
		coins = 0,
		xp = 0,
		smashes = 0,
		nextAt = nil,
	}
	view.coins = count(coins, 1e9)
	view.xp = count(xp, 1e9)
	if type(nextAt) == "number" and nextAt == nextAt then
		view.nextAt = nextAt
	end
	if type(places) ~= "table" then
		return view
	end
	local n = 0
	local scored = 0 -- rows with a smash
	local found = false -- your row is in the list
	for i = 1, MatchEnd.MAX_ROWS do
		local r = (places :: { unknown })[i]
		if type(r) ~= "table" then
			break
		end
		n = i
		local row = r :: { [string]: unknown }
		local uid = if type(row.userId) == "number" then row.userId :: number else nil
		local me = uid ~= nil and uid == myId
		local smashes = count(row.smashes, 9999)
		if smashes > 0 then
			scored += 1
		end
		if me then
			found = true
			-- the server's shared place (ties share it; 0 = no smashes), else the row's number
			local pl = row.place
			view.place = if type(pl) == "number"
					and pl == math.floor(pl)
					and pl >= 0
					and pl <= MatchEnd.MAX_ROWS
				then pl
				else i
			view.smashes = smashes
		end
		if i <= 3 then
			table.insert(view.top, {
				name = words(row.name),
				smashes = smashes,
				userId = uid,
				carId = if type(row.carId) == "string" then row.carId :: string else nil,
				me = me,
			})
		end
	end
	view.total = n
	-- no smashes (the server's 0): the place every kart on 0 shares, after the ones who scored and
	-- never on the podium, as the round pays it (Match.payPlace); never "- / 8" (auditor round 12b)
	if found and view.place == 0 then
		view.place = math.min(n, math.max(scored + 1, #Match.PLACE_COINS + 1))
	end
	view.winner = view.top[1]
	return view
end

-- "3RD / 5"
function MatchEnd.placeWords(place: number, total: number): string
	if place < 1 then
		return if total >= 1 then `- / {total}` else "" -- (no smashes: no place, like the chip)
	end
	local tail = "TH"
	local t, h = place % 10, place % 100
	if h < 11 or h > 13 then
		tail = if t == 1 then "ST" elseif t == 2 then "ND" elseif t == 3 then "RD" else "TH"
	end
	return `{place}{tail} / {total}`
end

-- "1 SMASH" / "4 SMASHES"
function MatchEnd.smashWords(n: number): string
	return if n == 1 then "1 SMASH" else `{n} SMASHES`
end

-- "PEPPER WINS!" / "YOU WIN!" ("" with nobody in the list)
function MatchEnd.winWords(view: View): string
	local w = view.winner
	if not w then
		return ""
	end
	return if w.me then "YOU WIN!" else `{string.upper(w.name)} WINS!`
end

-- Seconds until the next round: from the server's nextAt, else MatchEnd.AUTO after the screen
-- opened. Never below 0, never above a minute (a junk nextAt can't hold the screen up).
function MatchEnd.left(view: View, openedAt: number, now: number): number
	local shown = now - openedAt
	local s = if view.nextAt then math.min(view.nextAt - now, 60 - shown) else MatchEnd.AUTO - shown
	return math.clamp(math.ceil(s), 0, 60)
end

export type XpBar = {
	fromLevel: number,
	fromF: number, -- where the bar starts (0..1 of fromLevel's need)
	toLevel: number,
	toF: number, -- where it ends (0..1 of toLevel's need)
	into: number, -- XP into toLevel and what it needs: "60 / 100"
	need: number,
	levelUp: boolean,
}

-- The ROUND OVER XP bar (auditor "Road to 9/10" item 7): from the XP you had before this round to
-- now. `now` = the player's Xp attribute (the server sets it before MatchResult), `gained` = the
-- round's XP. nil when there's nothing to show (junk, or no XP).
function MatchEnd.xpBar(now: unknown, gained: unknown): XpBar?
	if type(now) ~= "number" or type(gained) ~= "number" or now ~= now or gained ~= gained then
		return nil
	end
	if gained <= 0 then
		return nil
	end
	local after = math.max(0, math.floor(now))
	local before = math.max(0, after - math.floor(gained))
	local l1, i1, n1 = Xp.levelOf(before)
	local l2, i2, n2 = Xp.levelOf(after)
	return {
		fromLevel = l1,
		fromF = if n1 > 0 then i1 / n1 else 0,
		toLevel = l2,
		toF = if n2 > 0 then i2 / n2 else 0,
		into = i2,
		need = n2,
		levelUp = l2 > l1,
	}
end

-- "NEXT ROUND 12"

function MatchEnd.countWords(left: number): string
	return if left > 0 then `PLAY AGAIN {left}` else "GO!"
end

return MatchEnd
