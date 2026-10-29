--!strict
-- In the Smash arena only the match HUD shows: no lobby SMASH! button, goal arrow or lobby tiles
-- (WEAPONS Studio after-923: the SMASH! button and its arrow sat on the kart all match).
-- These are client scripts, so it reads their source: each lobby screen steps away on InMatch.
local fs = require("@lune/fs")
local H = require("./harness")

local test, truthy = H.test, H.truthy

print("Arena HUD")

local function has(path: string, text: string): boolean
	return string.find(fs.readFile(path), text, 1, true) ~= nil
end

test("the lobby HUD (SMASH! button, its arrow, the tiles) is off while InMatch", function()
	local src = fs.readFile("src/client/CvcScreens.client.luau")
	-- the HUD's want, the one switch that turns its whole screen (and pointer) on
	local want = string.match(src, "local want = CvcState%.loaded(.-)not anyOpen%(FULL%)")
	truthy(want ~= nil, "no want in CvcScreens")
	truthy(
		string.find(want :: string, 'attr("InMatch") ~= true', 1, true) ~= nil,
		"the lobby HUD shows in the arena"
	)
	truthy(has("src/client/CvcScreens.client.luau", "Base.show(h.gui, shows)"), "no show switch")
end)

test("the other lobby screens step away in the arena too", function()
	truthy(has("src/client/UiGallery.client.luau", "InMatch"), "SCREENS pill in the arena")
	truthy(has("src/client/Hud.luau", "InMatch"), "race timer in the arena")
end)

test("the match HUD is the one that shows while InMatch", function()
	truthy(has("src/client/MatchHud.client.luau", 'attr("InMatch") == true'), "no match HUD")
end)
