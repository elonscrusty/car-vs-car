--!strict
-- The launch audit's safety list (10-28): cheaters can't win races or set fake laps, a Reset on
-- the stand doesn't leave you stuck, a race that throws lets everyone go, saves keep trying, one
-- odd save can't stop the server's training, the old car shop stays shut, and no coins for JOIN
-- then walk off.
local fs = require("@lune/fs")
local H = require("./harness")
local CvcRules = require("../src/shared/CvcRules")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")
local RunCheck = require("../src/shared/RunCheck")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Launch safety")

local function has(path: string, text: string): boolean
	return string.find(fs.readFile(path), text, 1, true) ~= nil
end

test("a gate leg driven at race speed is fine; a jump across the map is not", function()
	-- 1 s at the top race speed (+ slack) is allowed
	truthy(RunCheck.legOk(0, 0, 10, RunCheck.MAX_SPEED.race, 0, 11))
	-- same frame, short hop (two gates close together)
	truthy(RunCheck.legOk(0, 0, 10, 20, 0, 10))
	-- 600 units in 1 s: a teleport
	truthy(not RunCheck.legOk(0, 0, 10, 600, 0, 11))
	-- 2x the top speed for 5 s: a speed hack
	truthy(not RunCheck.legOk(0, 0, 0, RunCheck.MAX_SPEED.race * 10, 0, 5))
end)

test("Reset on the stand: walking back makes a new body", function()
	truthy(has("src/server/Main.server.luau", "if not root or not hum or hum.Health <= 0 then"))
	truthy(
		has(
			"src/server/Main.server.luau",
			"if was == nil or wasHum == nil or wasHum.Health <= 0 then"
		)
	)
end)

test("saves: the lock waits ~45 s; a failed leave-save is tried again", function()
	truthy(has("src/server/PlayerData.luau", "local TAKE_TRIES = 6"))
	truthy(has("src/server/PlayerData.luau", "round < LEAVE_RETRIES"))
end)

test("training: one player per step", function()
	local src = fs.readFile("src/server/TrainingServer.luau")
	local a = string.find(src, "for _, p in Players:GetPlayers() do", 1, true)
	local b = string.find(src, 'Forever.step("Training"', 1, true)
	truthy(a ~= nil and b ~= nil and a < b)
end)

test("the old car shop's buy and spin are shut in Car VS Car", function()
	truthy(has("src/server/CarShop.server.luau", "elseif Features.CVC then"))
end)

test("INVITE is on the plot screen (after the first crate, where Roblox allows it)", function()
	truthy(has("src/shared/UiScreens.luau", 'p("Invite", 522, 228, 112, 44'))
	truthy(has("src/client/Ui/Screens/Hud.luau", "holders.Invite = inviteHolder"))
	local src = fs.readFile("src/client/CvcScreens.client.luau")
	truthy(string.find(src, "SocialService:PromptGameInvite(player, options)", 1, true) ~= nil)
	truthy(string.find(src, 'api.setShown("Invite", shopped and canInvite)', 1, true) ~= nil)
	truthy(string.find(src, "CanSendGameInviteAsync", 1, true) ~= nil)
end)
