--!strict
-- Which lobby menu buttons a player sees (pure, unit tested).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local MenuConfig = sibling("MenuConfig")

export type Visible = { gift: boolean, quests: boolean, garage: boolean }

local MenuRules = {}

-- `profile` only needs a `matches` field (finished matches); anything else counts as 0.
function MenuRules.visible(profile: any, cfg: any?): Visible
	local c = cfg or MenuConfig
	local matches = 0
	if type(profile) == "table" then
		local m = profile.matches
		if type(m) == "number" and m == m then
			matches = m
		end
	end
	local full = matches >= c.matchesForFullMenu
	return { gift = true, quests = full, garage = full }
end

return MenuRules
