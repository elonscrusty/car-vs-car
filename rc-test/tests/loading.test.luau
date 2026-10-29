--!nocheck
-- The loading screen (carter's UI kit v41, Loading.png): it runs from ReplicatedFirst, ends as soon
-- as the lobby is ready (the game in, your save's Coins set) and never holds a kid past 15 s.
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local test, truthy = H.test, H.truthy

print("Loading screen")

local src = fs.readFile("src/first/Loading.client.luau")

test("Loading runs from ReplicatedFirst and drops Roblox's own screen", function()
	local project = serde.decode("json", fs.readFile("default.project.json"))
	local rf = project.tree.ReplicatedFirst
	truthy(
		rf and rf.Loading and rf.Loading["$path"] == "src/first/Loading.client.luau",
		"not mapped"
	)
	truthy(string.find(src, "RemoveDefaultLoadingScreen", 1, true) ~= nil, "Roblox's screen stays")
end)

test("Loading ends when the lobby is ready, 15 s at most, and cleans up", function()
	local max = tonumber(string.match(src, "local MAX_WAIT = (%d+)"))
	truthy(max and max <= 15, "MAX_WAIT " .. tostring(max))
	truthy(
		string.find(
			src,
			'game:IsLoaded() and type(player:GetAttribute("Coins")) == "number"',
			1,
			true
		) ~= nil,
		"ready rule"
	)
	truthy(string.find(src, "gui:Destroy()", 1, true) ~= nil, "the screen is never removed")
	truthy(string.find(src, "conn:Disconnect()", 1, true) ~= nil, "its frame loop keeps running")
end)
