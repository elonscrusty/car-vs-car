--!strict
-- Car abilities (pure): look one up, scale it by the car's rarity. No Roblox calls so Lune can
-- test it. The server applies the result (src/server/Specials); clients only press the button.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local AbilitiesConfig = sibling("AbilitiesConfig")

-- Same shape as AbilitiesConfig.Ability (the sibling loader types the config as `any`).
export type Ability = {
	id: string,
	name: string,
	kind: string,
	blurb: string,
	cooldown: number,
	radius: number,
	push: number,
	lift: number,
	dashForward: number,
	jumpSpeed: number,
	seconds: number,
	damageMult: number,
}

local Abilities = {}

-- The base (Common) ability for an id, or nil. Takes `any` because ids can come from data.
function Abilities.get(id: any): Ability?
	if type(id) ~= "string" then
		return nil
	end
	return AbilitiesConfig.Abilities[id]
end

function Abilities.isRarity(rarity: any): boolean
	return type(rarity) == "string" and AbilitiesConfig.Rarity[rarity] ~= nil
end

-- The ability as this rarity gets it: reach, push, lift, speed, jump and seconds grow with the
-- rarity's power, ram's damage bonus grows with it, and the cooldown shrinks. nil for a bad id or
-- rarity. Returns a new table (the config stays unchanged).
function Abilities.resolve(id: any, rarity: any): Ability?
	local base = Abilities.get(id)
	if base == nil or not Abilities.isRarity(rarity) then
		return nil
	end
	local scale = AbilitiesConfig.Rarity[rarity :: string]
	local power = scale.power
	local out = table.clone(base)
	out.cooldown = base.cooldown * scale.cooldown
	out.radius = base.radius * power
	out.push = base.push * power
	out.lift = base.lift * power
	out.dashForward = base.dashForward * power
	out.jumpSpeed = base.jumpSpeed * power
	out.seconds = base.seconds * power
	out.damageMult = 1 + (base.damageMult - 1) * power
	return out
end

-- The ability of a car (anything with `ability` and `rarity`, e.g. CarConfig stats).
function Abilities.forCar(stats: { ability: string?, rarity: string? }): Ability?
	return Abilities.resolve(stats.ability, stats.rarity)
end

-- What an ability does in a mode (AbilitiesConfig.ModeUse), or nil for an unknown mode/ability
-- (nil = old behaviour). `mode` is the GameMode attribute value, any case.
function Abilities.modeUse(id: any, mode: any): { text: string, ball: string?, tagImmune: number? }?
	if type(id) ~= "string" or type(mode) ~= "string" then
		return nil
	end
	local row = AbilitiesConfig.ModeUse[string.lower(mode)]
	return if row then row[id] else nil
end

-- Fraction of the cooldown still left, 0 (ready) .. 1 (just used). For a cooldown ring.
-- readyAt and now must use the same clock (the server sets both attributes in server time).
function Abilities.cooldownFraction(readyAt: number, cooldown: number, now: number): number
	if cooldown <= 0 or now >= readyAt then
		return 0
	end
	return math.clamp((readyAt - now) / cooldown, 0, 1)
end

return Abilities
