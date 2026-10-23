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
}
-- target: where the arrows lead ("pad" = your plot's pad, "shop" = the spawn lobby, nil = none)
export type Goal = { text: string, target: string? }

local NextGoal = {}

function NextGoal.pick(s: State): Goal?
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
		return { text = "TAP BUILD!", target = nil }
	end
	return if s.nearPad
		then { text = "TAP DRIVE!", target = nil }
		else { text = "DRIVE YOUR TRACK", target = "pad" }
end

return NextGoal
