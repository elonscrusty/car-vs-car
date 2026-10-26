--!strict
-- Car VS Car: the one thing a player on foot should do next, for the guide arrow (PlotGuide).
-- One at a time, gone the moment it's done:
--   not picked a car yet  -> nothing (the pick screen is up)
--   never raced           -> "join": the JOIN RACE button
--   a crate to open       -> "crate": the crate button
--   coins for a crate     -> "crateshop": the crate shop, once per join (till you get there)
--   otherwise             -> nothing
-- Pure, so Lune can test it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end
local Crates = sibling("Crates")
local Profile = sibling("Profile")

export type State = {
	picked: boolean, -- chose a first car
	stage: number?, -- the Stage attribute (Profile.STAGE)
	crates: number, -- crates to open (CvcState.crates)
	coins: number,
	shopSeen: boolean, -- got to the crate shop this visit
}
export type Goal = { text: string, target: string }

local CvcGoal = {}

-- the cheapest crate in the shop
function CvcGoal.cheapest(): number
	local best = math.huge
	for _, id in Crates.SHOP do
		local p = Crates.price(id)
		if p and p < best then
			best = p
		end
	end
	return best
end

function CvcGoal.pick(s: State): Goal?
	if not s.picked then
		return nil
	end
	local stage = if type(s.stage) == "number" then s.stage else Profile.STAGE.NEW
	if stage < Profile.STAGE.RACED then
		return { text = "JOIN THE BIG RACE!", target = "join" }
	end
	if s.crates > 0 then
		return { text = "OPEN YOUR CRATE!", target = "crate" }
	end
	if not s.shopSeen and s.coins >= CvcGoal.cheapest() then
		return { text = "GO GET A CRATE!", target = "crateshop" }
	end
	return nil
end

return CvcGoal
