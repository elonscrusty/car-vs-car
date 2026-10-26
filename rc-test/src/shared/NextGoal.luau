--!strict
-- What a player on foot should do next: one goal at a time, shown as the glowing arrows on the
-- road and 1-2 words at the bottom (carter's pick #2: "the glowing arrow always shows what to do
-- next"). Pure, so Lune can test it; PlotGuide draws it.

export type State = {
	hasPlot: boolean, -- owns a plot on the street
	driven: boolean, -- drove their own plot at least once
	nearPad: boolean, -- standing on their plot's pad
	inShops: boolean, -- inside the spawn lobby (the shops)
	inBreak: boolean, -- the build break is on (BUILD! works anywhere)
	canBuy: boolean, -- has the coins / stars for the next unlock
	built: boolean?, -- already opened the build screen in this break
	raceIn: number?, -- seconds until building closes and the race is called
	visit: string?, -- whose plot nearby still has stars to win (from stage 3 on), its owner's name
	-- the tycoon plan (carter 10-26): the plot is a garage, races are on the maps
	tycoon: boolean?,
	seenGarage: boolean?, -- been to their own plot this visit
	pile: number?, -- coins waiting in their plot
	joinOpen: boolean?, -- the JOIN RACE pad takes them now
	joined: boolean?, -- already in the next race
}
-- target: where the arrows lead ("pad" = your plot's pad, "shop" = the spawn lobby, "visit" =
-- that plot's pad, nil = none)
export type Goal = { text: string, target: string? }

local NextGoal = {}

NextGoal.COLLECT_AT = 20 -- coins in the pile worth walking back for

-- The tycoon loop, one thing at a time: see your garage (your free car is earning there), join
-- the race, buy the next car, collect the pile.
local function tycoon(s: State): Goal?
	if s.hasPlot and not s.seenGarage then
		return if s.nearPad then nil else { text = "YOUR GARAGE", target = "pad" }
	end
	if s.canBuy then
		return if s.inShops
			then { text = "BUY IT!", target = nil }
			else { text = "GO SHOP!", target = "shop" }
	end
	if s.joined then
		return { text = "RACE SOON!", target = nil }
	end
	if s.hasPlot and (s.pile or 0) >= NextGoal.COLLECT_AT then
		return if s.nearPad
			then { text = "TAP TO COLLECT", target = nil }
			else { text = "COLLECT COINS", target = "pad" }
	end
	if s.joinOpen then
		return if s.inShops
			then { text = "JOIN THE RACE", target = nil }
			else { text = "JOIN THE RACE", target = "shop" }
	end
	return nil
end

-- WIN ⭐ AT SAM'S: one short line on a phone (a long name is cut)
local function visitGoal(name: string): Goal
	return { text = `WIN ⭐ AT {string.upper(string.sub(name, 1, 10))}'S`, target = "visit" }
end

function NextGoal.pick(s: State): Goal?
	if s.tycoon then
		return tycoon(s)
	end
	if not s.hasPlot then
		return if s.canBuy and not s.inShops then { text = "GO SHOP!", target = "shop" } else nil
	end
	-- first thing ever: drive your own track
	if not s.driven then
		return if s.nearPad
			then { text = "TAP DRIVE!", target = nil }
			else { text = "FOLLOW THE ARROWS", target = "pad" }
	end
	-- the next car or tile is yours to buy
	if s.canBuy then
		return if s.inShops
			then { text = "BUY IT!", target = nil }
			else { text = "GO SHOP!", target = "shop" }
	end
	-- the break: make your track better (the BUILD! button is right there)
	if s.inBreak then
		-- built already: the next thing is the race, so count it down
		if s.built and s.visit then
			-- built already, and the wait is best spent winning stars on someone's plot
			return visitGoal(s.visit)
		end
		if s.built and s.raceIn then
			local t = math.max(0, math.ceil(s.raceIn))
			return { text = string.format("RACE IN %d:%02d", t // 60, t % 60), target = nil }
		end
		return { text = "TAP BUILD!", target = nil }
	end
	-- stars only come from other people's plots: go and win some
	if s.visit then
		return visitGoal(s.visit)
	end
	return if s.nearPad
		then { text = "TAP DRIVE!", target = nil }
		else { text = "DRIVE YOUR TRACK", target = "pad" }
end

return NextGoal
