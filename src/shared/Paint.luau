--!strict
-- Paint shop rules (pure): owned colors/stickers, buying, and what each car wears.
-- Profile field: paint = { owned = { [id] = true }, equipped = { [carId] = { color = id?, sticker = id? } } }

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local PaintConfig = sibling("PaintConfig")

export type Equipped = { color: string?, sticker: string? }
export type PaintData = { owned: { [string]: boolean }, equipped: { [string]: Equipped } }
type Profile = { coins: number, owned: { [string]: boolean }, paint: PaintData }

local Paint = {}

local MAX_COINS = 1e9

function Paint.default(): PaintData
	return { owned = {}, equipped = {} }
end

-- "color" or "sticker" for a catalog id, nil when unknown.
function Paint.kindOf(id: any): string?
	if PaintConfig.color(id) then
		return "color"
	end
	if PaintConfig.sticker(id) then
		return "sticker"
	end
	return nil
end

function Paint.price(id: any): number?
	local c = PaintConfig.color(id)
	if c then
		return c.price
	end
	local s = PaintConfig.sticker(id)
	return if s then s.price else nil
end

-- Never errors. Accepts anything (old saves have no paint), returns clean PaintData.
function Paint.clean(raw: any): PaintData
	local out = Paint.default()
	if type(raw) ~= "table" then
		return out
	end
	if type(raw.owned) == "table" then
		for id, v in raw.owned do
			if v == true and Paint.kindOf(id) then
				out.owned[id] = true
			end
		end
	end
	if type(raw.equipped) == "table" then
		for carId, e in raw.equipped do
			if CarConfig.get(carId) and type(e) == "table" then
				local entry: Equipped = {}
				if PaintConfig.color(e.color) and out.owned[e.color] then
					entry.color = e.color
				end
				if PaintConfig.sticker(e.sticker) and out.owned[e.sticker] then
					entry.sticker = e.sticker
				end
				if entry.color or entry.sticker then
					out.equipped[carId] = entry
				end
			end
		end
	end
	return out
end

function Paint.copy(d: PaintData): PaintData
	local out = Paint.default()
	out.owned = table.clone(d.owned)
	for carId, e in d.equipped do
		out.equipped[carId] = table.clone(e)
	end
	return out
end

-- Owned ids, catalog order (colors then stickers).
function Paint.ownedList(d: PaintData): { string }
	local list = {}
	for _, c in PaintConfig.Colors do
		if d.owned[c.id] then
			table.insert(list, c.id)
		end
	end
	for _, s in PaintConfig.Stickers do
		if d.owned[s.id] then
			table.insert(list, s.id)
		end
	end
	return list
end

-- reason: "unknown", "owned" or "coins".
function Paint.canBuy(p: Profile, id: any): (boolean, string?)
	local price = Paint.price(id)
	if price == nil then
		return false, "unknown"
	end
	if p.paint.owned[id] then
		return false, "owned"
	end
	if p.coins < price then
		return false, "coins"
	end
	return true, nil
end

-- Mutates p. Returns false (and changes nothing) if canBuy says no.
function Paint.buy(p: Profile, id: any): boolean
	if not Paint.canBuy(p, id) then
		return false
	end
	p.coins = math.clamp(p.coins - (Paint.price(id) :: number), 0, MAX_COINS)
	p.paint.owned[id] = true
	return true
end

-- reason: "car" (unknown or not owned car), "kind", "unknown", "notowned".
-- id nil clears that slot. Mutates p only on success.
function Paint.equip(p: Profile, carId: any, kind: any, id: any): (boolean, string?)
	if type(carId) ~= "string" or not CarConfig.get(carId) or not p.owned[carId] then
		return false, "car"
	end
	if kind ~= "color" and kind ~= "sticker" then
		return false, "kind"
	end
	if id ~= nil then
		if type(id) ~= "string" or Paint.kindOf(id) ~= kind then
			return false, "unknown"
		end
		if not p.paint.owned[id] then
			return false, "notowned"
		end
	end
	local e: any = p.paint.equipped[carId]
	if e == nil then
		e = {}
		p.paint.equipped[carId] = e
	end
	e[kind] = id
	if e.color == nil and e.sticker == nil then
		p.paint.equipped[carId] = nil
	end
	return true, nil
end

-- What the car wears: body color rgb ({r,g,b} 0-255) and sticker id; either may be nil.
function Paint.look(d: PaintData, carId: string): ({ number }?, string?)
	local e = d.equipped[carId]
	if e == nil then
		return nil, nil
	end
	local c = PaintConfig.color(e.color)
	local s = PaintConfig.sticker(e.sticker)
	return if c then c.rgb else nil, if s then s.id else nil
end

return Paint
