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

test("the big race throws a too-fast racer out and checks every gate", function()
	local src = fs.readFile("src/server/ServerRaceRunner.luau")
	truthy(string.find(src, "RunCheck.legOk(leg.x, leg.z, leg.t, lx, lz, clock)", 1, true) ~= nil)
	truthy(string.find(src, "r.out = true\n\t\t\t\t\t\t\t\tev = nil", 1, true) ~= nil)
end)

test("JOIN then walk off: no try pay; tried and didn't finish: the try pay", function()
	local data = Profile.new()
	data.stage = Profile.STAGE.RACED -- (not the first race: no crate either way)
	local before = data.coins
	eq(CvcRules.raceDone(data, 0, 100, false).coins, 0)
	eq(data.coins, before)
	eq(CvcRules.raceDone(data, 0, 200, true).coins, League.prize(data.league, 0))
	-- (old callers with no flag: as before)
	eq(CvcRules.raceDone(data, 0, 300).coins, League.prize(data.league, 0))
	-- a finisher always gets the place pay
	eq(CvcRules.raceDone(data, 2, 400, false).coins, League.prize(data.league, 2))
	truthy(has("src/server/ServerRaceRunner.luau", "raceDone(p, at, done or tried[p.UserId])"))
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

test("a race that throws walks everyone off the stand", function()
	truthy(
		has("src/server/ServerRaceRunner.luau", "local function rescue(hooks: Hooks, slot: number)")
	)
	truthy(has("src/server/ServerRaceRunner.luau", "rescue(hooks, slot)\n"))
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
