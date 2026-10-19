--!strict
-- Which fighters a player may pick for the 1v1 auto-battle (pure, unit tested).
-- The server runs every check; the client only shows the states.
--   "owned"  : in the player's collection
--   "loaner" : free Ram Truck for a player with no usable car (never saved)
--   "test"   : Studio-only unlock (never saved)
--   "locked" : not usable now

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

export type Context = {
	owned: { [string]: boolean }, -- the saved collection
	testUnlock: boolean, -- already checked by the server: Studio and the test setting is on
}
export type Choice = { id: string, state: string, selectable: boolean }

local BattleSelect = {}

local LOANER_ID = "RamTruck"

-- True when the player owns at least one switched-on fighter.
function BattleSelect.ownsAny(owned: { [string]: boolean }): boolean
	for _, id in BattleConfig.activeOrder() do
		if owned[id] == true then
			return true
		end
	end
	return false
end

-- How the player may use this fighter: "owned" | "loaner" | "test" | nil.
function BattleSelect.access(id: any, ctx: Context): string?
	local f = BattleConfig.fighter(id)
	if f == nil or not f.enabled then
		return nil
	end
	if ctx.owned[f.id] == true then
		return "owned"
	end
	if ctx.testUnlock then
		return "test"
	end
	if f.id == LOANER_ID and not BattleSelect.ownsAny(ctx.owned) then
		return "loaner"
	end
	return nil
end

-- All three cards, in catalog order. A fighter that is switched off is "locked" and not selectable.
function BattleSelect.choices(ctx: Context): { Choice }
	local list: { Choice } = {}
	for _, id in BattleConfig.Order do
		local access = BattleSelect.access(id, ctx)
		table.insert(list, {
			id = id,
			state = access or "locked",
			selectable = access ~= nil,
		})
	end
	return list
end

function BattleSelect.isEligible(id: any, ctx: Context): boolean
	return BattleSelect.access(id, ctx) ~= nil
end

-- What the player fights with when the clock runs out: the last valid pick, else the first
-- owned fighter in catalog order, else the loaner. nil only if nothing at all is allowed.
function BattleSelect.resolve(last: any, ctx: Context): string?
	if last ~= nil and BattleSelect.isEligible(last, ctx) then
		return last :: string
	end
	for _, id in BattleConfig.activeOrder() do
		if ctx.owned[id] == true then
			return id
		end
	end
	if BattleSelect.access(LOANER_ID, ctx) ~= nil then
		return LOANER_ID
	end
	return nil
end

-- The label for a fighter that is actually going to fight: "" for a normal owned car.
function BattleSelect.label(access: string?): string
	if access == "loaner" then
		return "Loaner"
	elseif access == "test" then
		return "Test"
	end
	return ""
end

return BattleSelect
