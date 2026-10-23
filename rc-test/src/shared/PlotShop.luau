--!strict
-- The plot looks shop (carter's new loop, 2026-10-23): coins buy looks for your plot. The themes
-- (night, snow, party) are also free once you have their stars (PlotLooks.TIERS); the decor is
-- coins only. A look you have shows on your plot until you turn it off. Pure tables, so Lune can
-- test it; server/PlotShop does the remote and the save, PlotLooksBuilder shows the looks.

export type Item = {
	id: string,
	kind: string, -- "theme" or "decor"
	icon: string,
	name: string,
	price: number, -- coins
	stars: number?, -- free from this many stars
}
-- the part of a save the shop uses (Profile.Data has these)
export type Wallet = {
	coins: number,
	stars: number,
	looks: { [string]: boolean }, -- bought
	lookOff: { [string]: boolean }, -- had but turned off
}

local PlotShop = {}

PlotShop.ITEMS = {
	{ id = "night", kind = "theme", icon = "🌙", name = "Night", price = 150, stars = 10 },
	{ id = "snow", kind = "theme", icon = "❄️", name = "Snow", price = 400, stars = 25 },
	{ id = "party", kind = "theme", icon = "🎉", name = "Party", price = 800, stars = 50 },
	{ id = "balloons", kind = "decor", icon = "🎈", name = "Balloons", price = 100 },
	{ id = "neon", kind = "decor", icon = "💡", name = "Glow walls", price = 200 },
	{ id = "confetti", kind = "decor", icon = "🎊", name = "Confetti", price = 300 },
} :: { Item }

function PlotShop.item(id: any): Item?
	for _, it in PlotShop.ITEMS do
		if it.id == id then
			return it
		end
	end
	return nil
end

function PlotShop.has(w: Wallet, id: string): boolean
	local it = PlotShop.item(id)
	if not it then
		return false
	end
	return w.looks[id] == true or (it.stars ~= nil and w.stars >= it.stars)
end

-- The looks this wallet's plot shows, in shop order.
function PlotShop.shown(w: Wallet): { string }
	local out = {}
	for _, it in PlotShop.ITEMS do
		if PlotShop.has(w, it.id) and not w.lookOff[it.id] then
			table.insert(out, it.id)
		end
	end
	return out
end

-- Buy look `id`: (true) or (false, why) with why = "unknown", "have" or "coins".
function PlotShop.buy(w: Wallet, id: any): (boolean, string?)
	local it = PlotShop.item(id)
	if not it then
		return false, "unknown"
	end
	if PlotShop.has(w, it.id) then
		return false, "have"
	end
	if w.coins < it.price then
		return false, "coins"
	end
	w.coins -= it.price
	w.looks[it.id] = true
	w.lookOff[it.id] = nil
	return true
end

-- Turn a look you have on or off: the new state (true = on), or nil when you don't have it.
function PlotShop.toggle(w: Wallet, id: any): boolean?
	local it = PlotShop.item(id)
	if not it or not PlotShop.has(w, it.id) then
		return nil
	end
	if w.lookOff[it.id] then
		w.lookOff[it.id] = nil
		return true
	end
	w.lookOff[it.id] = true
	return false
end

-- A saved set of look ids (old, broken or missing) -> only real ids set to true.
function PlotShop.clean(raw: any): { [string]: boolean }
	local out = {}
	if type(raw) == "table" then
		for id, yes in raw do
			if yes == true and PlotShop.item(id) then
				out[id] = true
			end
		end
	end
	return out
end

-- Looks <-> the plot attribute OwnerLooks ("night,balloons").
function PlotShop.encode(ids: { string }): string
	return table.concat(ids, ",")
end

function PlotShop.decode(s: any): { string }
	local out = {}
	if type(s) == "string" then
		for id in string.gmatch(s, "[^,]+") do
			if PlotShop.item(id) then
				table.insert(out, id)
			end
		end
	end
	return out
end

return PlotShop
