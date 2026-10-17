--!strict
-- Player profile data (pure). Everything coming from a DataStore goes through migrate.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local BotLevels = sibling("BotLevels")
local Hints = sibling("Hints")
local LobbyConfig = sibling("LobbyConfig")
local Progress = sibling("Progress")
local Daily = sibling("Daily")
local Quests = sibling("Quests")
local Paint = sibling("Paint")
local Weapons = sibling("Weapons")

export type Profile = {
	version: number,
	coins: number,
	wins: number,
	owned: { [string]: boolean },
	freePullUsed: boolean,
	hintsSeen: { [string]: boolean }, -- first-time hints already shown (see Hints)
	progress: Progress.Data, -- car XP and win streak (see Progress)
	botLevel: string, -- bot difficulty: "easy" | "medium" | "hard"
	quests: { { id: string, progress: number } }, -- active quests (see Quests)
	daily: { lastDay: number, freePulls: number }, -- daily gift state (see Daily)
	paint: Paint.PaintData, -- owned colors/stickers and what each car wears (see Paint)
	weapons: Weapons.WeaponData, -- owned weapons and the one worn (see Weapons)
}

local Inventory = {}

local VERSION = 1
local MAX_NUMBER = 1e9

local function cleanNumber(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, MAX_NUMBER)
end

local function grantStarters(owned: { [string]: boolean })
	for _, id in LobbyConfig.StarterCars do
		if CarConfig.get(id) then
			owned[id] = true
		end
	end
end

function Inventory.default(): Profile
	local owned: { [string]: boolean } = {}
	grantStarters(owned)
	return {
		version = VERSION,
		coins = 0,
		wins = 0,
		owned = owned,
		freePullUsed = false,
		hintsSeen = {},
		progress = Progress.default(),
		botLevel = "medium",
		quests = {},
		daily = Daily.default(),
		paint = Paint.default(),
		weapons = Weapons.default(),
	}
end

-- Never errors. Accepts anything, returns a clean Profile.
function Inventory.migrate(raw: any): Profile
	if type(raw) ~= "table" then
		return Inventory.default()
	end
	local owned: { [string]: boolean } = {}
	local rawOwned = raw.owned
	if type(rawOwned) == "table" then
		for _, id in CarConfig.Order do
			if rawOwned[id] == true then
				owned[id] = true
			end
		end
	end
	if next(owned) == nil then
		grantStarters(owned)
	end
	return {
		version = VERSION,
		coins = cleanNumber(raw.coins),
		wins = cleanNumber(raw.wins),
		owned = owned,
		freePullUsed = raw.freePullUsed == true,
		hintsSeen = Hints.clean(raw.hintsSeen),
		progress = Progress.clean(raw.progress),
		botLevel = if BotLevels.isValid(raw.botLevel) then raw.botLevel else "medium",
		quests = Quests.clean(raw.quests),
		daily = Daily.clean(raw.daily),
		paint = Paint.clean(raw.paint),
		weapons = Weapons.clean(raw.weapons),
	}
end

function Inventory.ownedList(p: Profile): { string }
	local list = {}
	for _, id in CarConfig.Order do
		if p.owned[id] then
			table.insert(list, id)
		end
	end
	return list
end

function Inventory.owns(p: Profile, id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	return p.owned[id] == true
end

function Inventory.addCoins(p: Profile, n: number)
	p.coins = math.clamp(p.coins + n, 0, MAX_NUMBER)
end

-- Returns true if the car was new. Unknown ids are ignored (false).
function Inventory.grantCar(p: Profile, id: string): boolean
	if not CarConfig.get(id) or p.owned[id] then
		return false
	end
	p.owned[id] = true
	return true
end

return Inventory
