--!strict
-- The big race maps' names, vote-card icons and colours (carter's tycoon plan, 10-26). The maps
-- themselves are this module's children (Backyard, Kitchen; RaceMaps lists them in vote order).
-- Light on purpose: the vote card reads this without loading a whole map.

export type Info = { id: string, name: string, icon: string, color: { number } }

local Maps = {}

Maps.INFO = {
	backyard = { name = "BACKYARD", icon = "🌳", color = { 86, 150, 70 } },
	kitchen = { name = "KITCHEN", icon = "🍳", color = { 224, 138, 58 } },
} :: { [string]: { name: string, icon: string, color: { number } } }

-- What the vote card shows for a map id (nil = not a map).
function Maps.get(id: string): Info?
	local i = Maps.INFO[id]
	if not i then
		return nil
	end
	return { id = id, name = i.name, icon = i.icon, color = i.color }
end

return Maps
