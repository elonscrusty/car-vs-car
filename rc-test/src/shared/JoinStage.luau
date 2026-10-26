--!strict
-- What a player's screen shows at each stage of their first minutes (carter 10-25: "the game is
-- overwhelming and confusing when joining"). One new thing at a time:
--   0 new      your car on your pad and GO. Drive one lap.
--   1 lapped   +20 coins, the coins number, BUILD in the break, and the server race.
--   2 raced    GO SHOP (and QUICK RACE, the friends switch).
--   3 shopped  everything else: daily gift, jobs, looks, top 3, 2X, rivals, the visit goal.
-- The stage is the player's "Stage" attribute (saved; PlayerData.raiseStage moves it up). Pure,
-- so Lune can test it; each screen asks JoinStage.shows(stage, "<its name>").

local JoinStage = {}

JoinStage.NEW, JoinStage.LAPPED, JoinStage.RACED, JoinStage.SHOPPED = 0, 1, 2, 3

-- The first stage each thing shows at. A name that isn't here always shows (nothing hides by
-- accident).
JoinStage.FROM = {
	go = 0, -- DRIVE / GO on your own pad, WALK while driving
	arrows = 0, -- the road arrows on the track
	coins = 1, -- the coins number (top of the screen)
	build = 1, -- BUILD in the break
	race = 1, -- the server race chip and sign, RACE IN 3:00
	goal = 1, -- the NEXT goal bar
	shop = 2, -- GO SHOP and the arrows to the car shop
	quick = 2, -- QUICK RACE
	friends = 2, -- the open / shut switch for your plot
	gift = 3, -- the daily gift strip
	jobs = 3, -- daily jobs
	looks = 3, -- plot looks
	top3 = 3, -- the boards' top 3
	boost = 3, -- the 2X weekend banner
	rivals = 3,
	visit = 3, -- WIN STARS AT SAM'S and the arrows to that plot
	gumball = 3,
	pads = 2, -- the spawn's DRIFT NOW / RACE NOW pads (drive someone's plot)
}

-- A Stage attribute (or anything) -> a stage 0..3. Not set yet (the save is still loading) = new.
function JoinStage.of(v: any): number
	if type(v) ~= "number" or v ~= v then
		return JoinStage.NEW
	end
	return math.clamp(math.floor(v), JoinStage.NEW, JoinStage.SHOPPED)
end

function JoinStage.shows(stage: any, what: string): boolean
	local from = JoinStage.FROM[what]
	return from == nil or JoinStage.of(stage) >= from
end

return JoinStage
