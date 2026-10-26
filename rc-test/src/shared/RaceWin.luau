--!strict
-- Car VS Car win moment from the stand (code-only round, 10-26): when a big race ends, the winner
-- of your league's race gets confetti and a trophy over their avatar on the driver stand, everyone
-- cheers, and the winner's 10 min coin boost shows. Pure (which row won, the words), so Lune
-- tests it; RaceWin.client draws it.

local RaceWin = {}

RaceWin.SHOW = 6 -- seconds the trophy and confetti stay (the result shows ServerRace.SHOW = 7)
RaceWin.BOOST_MIN = 10 -- the win's coin boost (CvcRules.WIN_BOOST_SECS = 600)

export type Winner = { uid: number, name: string, mine: boolean }

-- The person who won this result (rows = the "result" rows, best first), or nil when a bot won,
-- nobody finished, or the rows are odd. `me` = this screen's UserId.
function RaceWin.winner(rows: any, me: number): Winner?
	if type(rows) ~= "table" then
		return nil
	end
	local first = rows[1]
	if type(first) ~= "table" or first.bot == true or type(first.uid) ~= "number" then
		return nil
	end
	if type(first.time) ~= "number" then
		return nil -- (a race nobody finished has no winner)
	end
	local name = if type(first.name) == "string" then first.name else "?"
	return { uid = first.uid, name = name, mine = first.uid == me }
end

-- The two lines over the winner's head.
function RaceWin.words(w: Winner): (string, string)
	local top = if w.mine then "YOU WIN!" else string.upper(w.name) .. " WINS!"
	return top, `2X COINS {RaceWin.BOOST_MIN} MIN!`
end

return RaceWin
