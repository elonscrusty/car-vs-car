--!strict
-- Lobby button "MODE: AUTO / DUEL / HILL / ICE / SOCCER". Tap goes to the next one; the server
-- checks it and the label follows the profile update. AUTO = the usual rotation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage.Shared.Modes)
local MenuBar = require(script.Parent.MenuBar)

local ModeUi = {}

-- Short names: the menu button is narrow.
local SHORT: { [string]: string } = {
	duel = "DUEL",
	hill = "HILL",
	ice = "ICE",
	soccer = "SOCCER",
	tag = "TAG",
	race = "RACE",
	lastStanding = "8 CARS",
}

local AUTO_COLOR = Color3.fromRGB(90, 100, 120)
local PICK_COLOR = Color3.fromRGB(230, 130, 40)

export type ModeUi = {
	-- Call with the `mode` of each profile update.
	handleProfile: (mode: string?) -> (),
}

function ModeUi.new(menu: MenuBar.MenuBar, send: (mode: string) -> ()): ModeUi
	local current = "auto"

	local function refresh()
		local name = if current == "auto" then "AUTO" else (SHORT[current] or current)
		menu.add("mode", `MODE: {string.upper(name)}`, 85, function()
			send(Modes.nextPick(current))
		end)
		menu.setColor("mode", if current == "auto" then AUTO_COLOR else PICK_COLOR)
	end
	refresh()

	return {
		handleProfile = function(mode: string?)
			if mode ~= nil and Modes.isPick(mode) and mode ~= current then
				current = mode
				refresh()
			end
		end,
	}
end

return ModeUi
