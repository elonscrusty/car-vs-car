--!strict
-- Lobby button "BOT: EASY / MEDIUM / HARD". Tap cycles the level; the server decides and the
-- label follows the profile update.

local BotLevels = require(game:GetService("ReplicatedStorage").Shared.BotLevels)
local MenuBar = require(script.Parent.MenuBar)

local BotLevelUi = {}

local COLORS: { [string]: Color3 } = {
	easy = Color3.fromRGB(60, 170, 80),
	medium = Color3.fromRGB(210, 170, 40),
	hard = Color3.fromRGB(200, 55, 55),
}

export type BotLevelUi = {
	-- Call with the `botLevel` of each profile update.
	handleProfile: (level: string?) -> (),
}

function BotLevelUi.new(menu: MenuBar.MenuBar, send: (level: string) -> ()): BotLevelUi
	local current = BotLevels.get(nil).name

	local function refresh()
		menu.add("botLevel", `BOT: {string.upper(current)}`, 90, function()
			send(BotLevels.next(current))
		end)
		menu.setColor("botLevel", COLORS[current])
	end
	refresh()

	return {
		handleProfile = function(level: string?)
			if level ~= nil and BotLevels.isValid(level) and level ~= current then
				current = level
				refresh()
			end
		end,
	}
end

return BotLevelUi
