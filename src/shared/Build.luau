--!strict
-- Build-and-watch rules (pure): which car and parts a player wears, buying and upgrading parts,
-- and the final car stats. The server decides everything; clients only ask.
-- Profile field: build = { carId, parts = { [slot] = partId }, owned = { [partId] = true }, levels = { [slot] = n } }

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BuildConfig = sibling("BuildConfig")
local CarConfig = sibling("CarConfig")

export type BuildData = {
	carId: string,
	parts: { [string]: string },
	owned: { [string]: boolean },
	levels: { [string]: number },
}
-- Only what the rules need from a profile.
type Profile = { coins: number, owned: { [string]: boolean }, build: BuildData }

local Build = {}

function Build.default(): BuildData
	local owned: { [string]: boolean } = {}
	local parts: { [string]: string } = {}
	local levels: { [string]: number } = {}
	for _, slot in BuildConfig.Slots do
		local starter = BuildConfig.Starter[slot]
		owned[starter] = true
		parts[slot] = starter
		levels[slot] = 1
	end
	return { carId = "Compact", parts = parts, owned = owned, levels = levels }
end

-- Never errors. Accepts anything (old saves have no build), returns a clean BuildData.
function Build.clean(raw: any): BuildData
	local out = Build.default()
	if type(raw) ~= "table" then
		return out
	end
	if CarConfig.get(raw.carId) then
		out.carId = raw.carId
	end
	if type(raw.owned) == "table" then
		for id, v in raw.owned do
			if v == true and BuildConfig.slotOf(id) then
				out.owned[id] = true
			end
		end
	end
	if type(raw.parts) == "table" then
		for _, slot in BuildConfig.Slots do
			local id = raw.parts[slot]
			if BuildConfig.slotOf(id) == slot and out.owned[id] then
				out.parts[slot] = id
			end
		end
	end
	if type(raw.levels) == "table" then
		for _, slot in BuildConfig.Slots do
			local n = raw.levels[slot]
			if type(n) == "number" and n == n then
				out.levels[slot] = math.clamp(math.floor(n), 1, BuildConfig.MaxLevel)
			end
		end
	end
	return out
end

function Build.copy(b: BuildData): BuildData
	return {
		carId = b.carId,
		parts = table.clone(b.parts),
		owned = table.clone(b.owned),
		levels = table.clone(b.levels),
	}
end

-- The car this build uses: the chosen one if the player still owns it, else the first car they own.
function Build.carFor(b: BuildData, ownedCars: { [string]: boolean }): string
	if ownedCars[b.carId] then
		return b.carId
	end
	for _, id in CarConfig.Order do
		if ownedCars[id] then
			return id
		end
	end
	return b.carId
end

-- reason: "unknown" or "notowned". Mutates p only on success.
function Build.setCar(p: Profile, carId: any): (boolean, string?)
	if not CarConfig.get(carId) then
		return false, "unknown"
	end
	if not p.owned[carId] then
		return false, "notowned"
	end
	p.build.carId = carId
	return true, nil
end

-- reason: "unknown", "owned" or "coins".
function Build.canBuyPart(p: Profile, id: any): (boolean, string?)
	local slot = BuildConfig.slotOf(id)
	if slot == nil then
		return false, "unknown"
	end
	if p.build.owned[id] then
		return false, "owned"
	end
	if p.coins < BuildConfig.Parts[id].cost then
		return false, "coins"
	end
	return true, nil
end

function Build.buyPart(p: Profile, id: any): (boolean, string?)
	local ok, reason = Build.canBuyPart(p, id)
	if not ok then
		return false, reason
	end
	p.coins -= BuildConfig.Parts[id].cost
	p.build.owned[id] = true
	return true, nil
end

-- Wear a part you own (it goes in its own slot). reason: "unknown" or "notowned".
function Build.equipPart(p: Profile, id: any): (boolean, string?)
	local slot = BuildConfig.slotOf(id)
	if slot == nil then
		return false, "unknown"
	end
	if not p.build.owned[id] then
		return false, "notowned"
	end
	p.build.parts[slot] = id
	return true, nil
end

-- Coins to raise `slot` one level, or nil at the top level.
function Build.upgradeCost(b: BuildData, slot: any): number?
	if not BuildConfig.isSlot(slot) then
		return nil
	end
	local level = b.levels[slot]
	if level >= BuildConfig.MaxLevel then
		return nil
	end
	return BuildConfig.LevelCost[level]
end

-- reason: "unknown", "max" or "coins".
function Build.upgrade(p: Profile, slot: any): (boolean, string?)
	if not BuildConfig.isSlot(slot) then
		return false, "unknown"
	end
	local cost = Build.upgradeCost(p.build, slot)
	if cost == nil then
		return false, "max"
	end
	if p.coins < cost then
		return false, "coins"
	end
	p.coins -= cost
	p.build.levels[slot] += 1
	return true, nil
end

local MULTIPLIED = { "hp", "mass", "maxSpeed", "accel", "turnRate", "damageMult" }

-- The car's final stats: the base car, then each worn part, then each slot's level bonus.
-- Returns a new table (the base stays unchanged).
function Build.stats(base: any, b: BuildData): any
	local out = table.clone(base)
	for _, slot in BuildConfig.Slots do
		local part = BuildConfig.Parts[b.parts[slot]]
		local mods = if part then part.mods else {}
		local bonus = BuildConfig.LevelBonus[slot]
		local extra = b.levels[slot] - 1
		for _, key in MULTIPLIED do
			local mult = mods[key] or 1
			local lv = bonus[key]
			if lv then
				mult *= 1 + lv * extra
			end
			out[key] *= mult
		end
		if mods.hitLift then
			out.hitLift += mods.hitLift
		end
	end
	out.hp = math.max(1, math.floor(out.hp + 0.5))
	return out
end

-- A bot's build: random parts, levels close to `level` (the player's). rng returns 0..1.
function Build.botBuild(rng: () -> number, level: number): BuildData
	local b = Build.default()
	for _, slot in BuildConfig.Slots do
		local list = BuildConfig.Order[slot]
		local id = list[math.clamp(math.floor(rng() * #list) + 1, 1, #list)]
		b.owned[id] = true
		b.parts[slot] = id
		local roll = rng()
		local shift = if roll < 0.25 then -1 elseif roll > 0.75 then 1 else 0
		b.levels[slot] = math.clamp(level + shift, 1, BuildConfig.MaxLevel)
	end
	return b
end

-- The average part level, rounded (what a bot of your strength gets).
function Build.averageLevel(b: BuildData): number
	local total = 0
	for _, slot in BuildConfig.Slots do
		total += b.levels[slot]
	end
	return math.clamp(math.floor(total / #BuildConfig.Slots + 0.5), 1, BuildConfig.MaxLevel)
end

-- A short "power" number for the garage screen: bigger = a stronger car.
function Build.power(base: any, b: BuildData): number
	local s = Build.stats(base, b)
	local score = s.hp * s.damageMult * 0.5 + s.maxSpeed * 0.6 + s.accel * 0.2 + s.mass * 0.3
	return math.floor(score + 0.5)
end

return Build
