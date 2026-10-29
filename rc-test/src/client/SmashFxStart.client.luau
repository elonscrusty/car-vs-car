--!strict
-- Starts the smash juice (client/SmashFx): words, streaks, shake, confetti and the killer camera.
-- It waits for the match server's SmashFeed remote by itself, so starting early is fine.
local SmashFx = require(script.Parent:WaitForChild("SmashFx"))

SmashFx.start()
require(script.Parent:WaitForChild("SmashSparks")).start()
require(script.Parent:WaitForChild("MatchStart")).start()
