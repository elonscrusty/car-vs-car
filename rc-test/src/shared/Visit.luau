--!strict
-- Why drive someone else's plot (carter 10-25: "make it make sense to visit other people's
-- plots"): what each plot's sign says to ME. Stars still to win there (a medal per kind of plot,
-- bronze 1 + silver 1 + gold 1 = 3 from each owner), else the record to beat for coins, and the
-- visit gift when today's isn't taken. My own plot gives no stars. Stars.server works it out per
-- player and sends it; Stars.client draws it over each plot's gate. Pure, so Lune can test it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Medals = sibling("Medals")
local Profile = sibling("Profile")

local Visit = {}

-- The bits of my save this needs (Profile.Data has them).
export type Save = {
	starsFrom: { [string]: { [string]: number } },
	visited: { [string]: number },
}
export type Record = { value: number, name: string, userId: number }

-- One plot, as seen by me. Sent to the client as is.
export type Sign = {
	slot: number,
	own: boolean, -- my plot
	stars: number, -- stars I can still win here (0..3)
	beat: string?, -- "SAM 0:21": the record to beat (when I have all its stars)
	coins: number, -- what beating that record pays
	gift: number, -- the visit gift still there today (0 = taken, or not a visit)
}

-- What `ownerId`'s `mode` plot holds for me (`me` = my user id). ownerId nil = nobody's plot:
-- nothing to win there.
function Visit.sign(
	d: Save,
	me: number,
	slot: number,
	ownerId: number?,
	mode: string,
	record: Record?,
	day: number,
	boost: number
): Sign
	local s: Sign = { slot = slot, own = ownerId == me, stars = 0, coins = 0, gift = 0 }
	if ownerId == nil or s.own or Medals.target(mode) == nil then
		return s
	end
	local from = d.starsFrom[tostring(ownerId)]
	local had = if from then from[mode] or 0 else 0
	s.stars = math.max(3 - had, 0)
	if s.stars == 0 and record and record.userId ~= me then
		s.beat = `{string.upper(record.name)} {Medals.format(mode, record.value)}`
		s.coins = Profile.WIN_COINS * boost
	end
	if d.visited[tostring(ownerId)] ~= day then
		s.gift = Profile.VISIT_COINS * boost
	end
	return s
end

-- The words on the sign, one line each ("" = nothing to say: hide it).
function Visit.lines(s: Sign): { string }
	if s.own then
		return { "NO ⭐ HERE" }
	end
	local out = {}
	if s.stars > 0 then
		table.insert(out, `⭐ {s.stars} HERE`)
	elseif s.beat then
		table.insert(out, `BEAT {s.beat} = {s.coins} COINS`)
	end
	if s.gift > 0 then
		table.insert(out, `+{s.gift} VISIT GIFT`)
	end
	return out
end

-- "3,5": the plots that still have stars for me, nearest first (`dist` = how far each slot is).
function Visit.starsAt(signs: { Sign }, dist: { [number]: number }): string
	local list: { Sign } = {}
	for _, s in signs do
		if s.stars > 0 then
			table.insert(list, s)
		end
	end
	table.sort(list, function(a, b)
		local da, db = dist[a.slot] or math.huge, dist[b.slot] or math.huge
		if da ~= db then
			return da < db
		end
		return a.slot < b.slot
	end)
	local parts = {}
	for _, s in list do
		table.insert(parts, tostring(s.slot))
	end
	return table.concat(parts, ",")
end

return Visit
