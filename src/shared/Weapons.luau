--!strict
-- Weapon ownership rules (pure): what a player owns, which one is worn, and the claw roll.
-- Profile field: weapons = { owned = { [id] = true }, equipped = id }

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local WeaponsConfig = sibling("WeaponsConfig")

export type WeaponData = { owned: { [string]: boolean }, equipped: string }
type Profile = { weapons: WeaponData }

local Weapons = {}

function Weapons.default(): WeaponData
	return {
		owned = { [WeaponsConfig.Starter] = true },
		equipped = WeaponsConfig.Starter,
	}
end

-- Never errors. Accepts anything (old saves have no weapons), returns clean WeaponData.
function Weapons.clean(raw: any): WeaponData
	local out = Weapons.default()
	if type(raw) ~= "table" then
		return out
	end
	if type(raw.owned) == "table" then
		for id, v in raw.owned do
			if v == true and WeaponsConfig.get(id) then
				out.owned[id] = true
			end
		end
	end
	if type(raw.equipped) == "string" and out.owned[raw.equipped] then
		out.equipped = raw.equipped
	end
	return out
end

function Weapons.copy(d: WeaponData): WeaponData
	return { owned = table.clone(d.owned), equipped = d.equipped }
end

-- Owned ids, menu order.
function Weapons.ownedList(d: WeaponData): { string }
	local list = {}
	for _, id in WeaponsConfig.Order do
		if d.owned[id] then
			table.insert(list, id)
		end
	end
	return list
end

-- Returns true if the weapon was new. Unknown ids are ignored (false).
function Weapons.grant(p: Profile, id: any): boolean
	if not WeaponsConfig.get(id) or p.weapons.owned[id] then
		return false
	end
	p.weapons.owned[id] = true
	return true
end

-- reason: "unknown" or "notowned". Mutates p only on success.
function Weapons.equip(p: Profile, id: any): (boolean, string?)
	if not WeaponsConfig.get(id) then
		return false, "unknown"
	end
	if not p.weapons.owned[id] then
		return false, "notowned"
	end
	p.weapons.equipped = id
	return true, nil
end

-- A claw win: pick a rarity by the claw odds (skipping rarities with no weapons), then a weapon.
-- `odds` is { Common = 60, ... } (LobbyConfig.Gacha.odds); rng returns 0..1.
function Weapons.roll(odds: { [string]: number }, rng: () -> number): string
	local rows: { { rarity: string, percent: number, ids: { string } } } = {}
	local total = 0
	for _, rarity in { "Common", "Rare", "Epic" } do
		local ids = {}
		for _, id in WeaponsConfig.Order do
			if WeaponsConfig.Weapons[id].rarity == rarity then
				table.insert(ids, id)
			end
		end
		local percent = odds[rarity] or 0
		if #ids > 0 and percent > 0 then
			table.insert(rows, { rarity = rarity, percent = percent, ids = ids })
			total += percent
		end
	end
	if #rows == 0 then
		return WeaponsConfig.Starter
	end
	local roll = rng() * total
	local chosen = rows[#rows]
	local acc = 0
	for _, row in rows do
		acc += row.percent
		if roll < acc then
			chosen = row
			break
		end
	end
	local index = math.clamp(math.floor(rng() * #chosen.ids) + 1, 1, #chosen.ids)
	return chosen.ids[index]
end

return Weapons
