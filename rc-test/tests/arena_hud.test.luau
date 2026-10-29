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
	-- (it checks the gui itself: a HUD opened while it shouldn't show stayed up, Studio final)
	truthy(
		has("src/client/CvcScreens.client.luau", "h.gui.gui.Enabled ~= shows"),
		"the switch only watches its own flag"
	)
end)

test("in Smash, driving the lobby kart keeps the lobby HUD (only the arena hides it)", function()
	local src = fs.readFile("src/client/CvcScreens.client.luau")
	local want = string.match(src, "local want = CvcState%.loaded(.-)not anyOpen%(FULL%)") or ""
	truthy(string.find(want, "SMASH or (", 1, true) ~= nil, "driving hides the Smash lobby HUD")
end)

test("the other lobby screens step away in the arena too", function()
	truthy(has("src/client/UiGallery.client.luau", "InMatch"), "SCREENS pill in the arena")
	truthy(has("src/client/Hud.luau", "InMatch"), "race timer in the arena")
end)

test("the match HUD is the one that shows while InMatch", function()
	truthy(has("src/client/MatchHud.client.luau", 'attr("InMatch") == true'), "no match HUD")
end)

test("the Lucky Spin tile leaves in the arena (InMatch) and goes with the lobby HUD", function()
	local src = fs.readFile("src/client/LuckySpin.client.luau")
	local fn = string.match(src, "local function showTile%(%)(.-)\nend") or ""
	truthy(string.find(fn, "not inMatch()", 1, true) ~= nil, "SPIN tile shows in the arena")
	truthy(
		string.find(fn, "lobbyHudUp()", 1, true) ~= nil,
		"SPIN tile doesn't follow the lobby HUD"
	)
	truthy(
		string.find(src, 'GetAttribute("InMatch") == true', 1, true) ~= nil,
		"inMatch reads InMatch"
	)
	truthy(string.find(src, 'FindFirstChild("Ui_plot")', 1, true) ~= nil, "lobby HUD is Ui_plot")
end)

test(
	"a match starting closes the daily gift and the spin window; the gift comes back later",
	function()
		local stars = fs.readFile("src/client/Stars.client.luau")
		truthy(
			string.find(stars, 'GetAttributeChangedSignal("InMatch")', 1, true) ~= nil,
			"daily ignores InMatch"
		)
		truthy(
			string.find(stars, "task.spawn(showDaily, coins, streak, boost, crate)", 1, true) ~= nil,
			"daily not re-queued"
		)
		local spin = fs.readFile("src/client/LuckySpin.client.luau")
		truthy(
			string.find(spin, 'Screen.isOpen("spin") and handle', 1, true) ~= nil,
			"spin window stays in the match"
		)
	end
)

test("LEVEL UP waits for the garage: never in a match, the yard or under another screen", function()
	local src = fs.readFile("src/client/LuckySpin.client.luau")
	local calm = string.match(src, "local function levelsCalm%(%)(.-)\nend") or ""
	truthy(string.find(calm, "not inMatch()", 1, true) ~= nil, "level card in the match")
	truthy(string.find(calm, '"MatchQueued"', 1, true) ~= nil, "level card in the yard countdown")
	truthy(string.find(calm, "Screen.anyOver()", 1, true) ~= nil, "level card over the match end")
	truthy(string.find(calm, "lobbyHudUp()", 1, true) ~= nil, "level card away from the garage")
	-- a card already up when a round starts goes, and its levels wait for later
	local away = string.match(src, "local function levelsStepAway%(%)(.-)\nend") or ""
	truthy(string.find(away, "card.close()", 1, true) ~= nil, "level card stays over the round")
	truthy(
		string.find(away, "table.insert(pending, l)", 1, true) ~= nil,
		"levels lost when it goes"
	)
	-- the server's LevelUp only queues it (no card the moment it lands)
	local onLevel = string.match(src, "levelUp%.OnClientEvent:Connect%(function(.-)\nend%)") or ""
	truthy(string.find(onLevel, "showLevels", 1, true) == nil, "LevelUp shows the card at once")
end)
