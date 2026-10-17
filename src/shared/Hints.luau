--!strict
-- First-time hints (pure). Which hints exist, their order, text, and the "seen" rules.
-- `seen` is the player's saved table (profile.hintsSeen): id -> true.

export type Seen = { [string]: boolean }

local Hints = {}

-- Order = the order a new player meets them: lobby pads, first aim phase, claw machine.
Hints.Order = { "pad", "aim", "claw" }

Hints.Text = {
	pad = "Step on a green pad to fight",
	aim = "Drag back from your car, then let go to launch!",
	claw = "Open the claw machine to win new cars",
} :: { [string]: string }

-- What the client points an arrow at: "pad" = the match pads, "claw" = the claw machine.
Hints.Target = {
	pad = "pad",
	claw = "claw",
} :: { [string]: string }

Hints.ShowSeconds = 12

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
