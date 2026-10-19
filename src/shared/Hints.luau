--!strict
-- First-time hints (pure). Which hints exist, their order, text, and the "seen" rules.
-- `seen` is the player's saved table (profile.hintsSeen): id -> true.

export type Seen = { [string]: boolean }

local Hints = {}

-- Order = the order a new player meets them: lobby pads, first aim phase, claw machine, then the
-- first time in each group mode (controls) and the "new menu buttons" notice. Every id here is saved
-- in profile.hintsSeen, so each shows once per player.
Hints.Order = { "pad", "aim", "claw", "soccer", "tag", "race", "unlock" }

Hints.Text = {
	pad = "Step on a blue pad to play",
	aim = "Drag back from your car and let go",
	claw = "Try the claw, first try is free",
	-- First time in a group mode: what the controls do (keep each under 40 characters).
	soccer = "Ball into the goal! BOOST = go fast",
	tag = "You are IT? Bump a car to pass it on",
	race = "Drive through the gates in order",
	-- Shown when QUESTS and GARAGE appear in the menu (MenuRules.unlockNotice).
	unlock = "New buttons: QUESTS and GARAGE",
} :: { [string]: string }

-- Mode name -> hint id shown the first time the player plays that mode (client asks, server saves).
Hints.ModeHint = { soccer = "soccer", tag = "tag", race = "race" } :: { [string]: string }

-- What the client points an arrow at: "pad" = the match pads, "claw" = the claw machine.
Hints.Target = {
	pad = "pad",
	claw = "claw",
} :: { [string]: string }

Hints.ShowSeconds = 12

-- Aim phase: no drag after this many seconds shows a pulsing arrow on the car.
Hints.AimNudgeSeconds = 3

function Hints.aimNudgeDue(secondsSinceAimStart: number, hasDragged: boolean): boolean
	return not hasDragged and secondsSinceAimStart >= Hints.AimNudgeSeconds
end

-- The first-time hint id for a mode (nil = that mode has no hint).
function Hints.forMode(mode: any): string?
	if type(mode) ~= "string" then
		return nil
	end
	return Hints.ModeHint[mode]
end

function Hints.isKnown(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	return table.find(Hints.Order, id) ~= nil
end

function Hints.text(id: string): string
	return Hints.Text[id] or ""
end

function Hints.target(id: string): string?
	return Hints.Target[id]
end

function Hints.shouldShow(seen: Seen, id: string): boolean
	return Hints.isKnown(id) and seen[id] ~= true
end

-- Returns true when the flag was new (so the caller knows to save). Unknown ids are ignored.
function Hints.markSeen(seen: Seen, id: any): boolean
	if not Hints.isKnown(id) or seen[id] == true then
		return false
	end
	seen[id] = true
	return true
end

-- Clean anything (old saves have no field): only known ids set to true survive.
function Hints.clean(raw: any): Seen
	local out: Seen = {}
	if type(raw) == "table" then
		for _, id in Hints.Order do
			if raw[id] == true then
				out[id] = true
			end
		end
	end
	return out
end

-- Ids as a list (for sending to the client), in Order.
function Hints.seenList(seen: Seen): { string }
	local list = {}
	for _, id in Hints.Order do
		if seen[id] == true then
			table.insert(list, id)
		end
	end
	return list
end

return Hints
