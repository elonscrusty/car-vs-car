--!strict
-- What the server decides about the tutorial (pure, tested): which flags a start saves, and when the
-- small coin gift may be paid. The client only asks; the server checks (docs/LOBBY_POLISH.md, L3,
-- L10, L20).

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Hints = sibling("Hints")
local Config = sibling("TutorialConfig")

local TutorialRules = {}

-- The tutorial starts. It is saved NOW, at the start, so a player who leaves half-way never sees it
-- again (L20). The old "tap PLAY" and "gumball" hint lines are marked seen too: the tutorial teaches
-- both. True when something new was saved.
function TutorialRules.markStart(seen: { [string]: boolean }): boolean
	local changed = false
	for _, id in { "tutorial", "pad", "claw" } do
		if Hints.markSeen(seen, id) then
			changed = true
		end
	end
	return changed
end

-- May the coin gift be paid now? Once per player, and only a while after the tutorial started (a
-- real run takes about a minute, so a script that asks at once gets nothing).
function TutorialRules.canGift(
	seen: { [string]: boolean },
	startedAt: number?,
	now: number
): (boolean, string?)
	if seen.tutorialDone == true then
		return false, "paid"
	end
	if startedAt == nil then
		return false, "not started"
	end
	if now - startedAt < Config.minGiftSeconds then
		return false, "too fast"
	end
	return true, nil
end

function TutorialRules.markGift(seen: { [string]: boolean })
	Hints.markSeen(seen, "tutorialDone")
end

-- May a player be sent to the practice yard now? Not while fighting, and not twice.
function TutorialRules.mayPractice(inBattle: boolean, practicing: boolean): boolean
	return not inBattle and not practicing
end

return TutorialRules
