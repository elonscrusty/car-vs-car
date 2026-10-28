--!strict
-- Smash game screens owned by WINDOWS (plans/smash, FINISH-JOBS): where each piece sits, in the
-- same design px and Piece shape as UiScreens (756 x 390 canvas inside the phone's safe area), so
-- client/Ui/Screens/Smash places from here and tests/smash_screens.test.luau checks the same rules
-- (safe area, move-stick corner free while driving, tap sizes, short ALL CAPS button words).
--   matchEnd: the 12 s break between rounds (VIDEO-STUDY.md). ROUND OVER, "<name> WINS" with the
--     winner's kart, the top 3 with smashes, your coins and XP popping in, "NEW ROUND STARTING IN
--     12" (the next round starts by itself), and a small LEAVE back to the lobby.
--   howTo: the 3-step tip over a match (drive, grab a "?", fire), one card at a time.
-- (the same shapes as UiScreens.Piece / UiScreens.Screen; no require, so Lune tests load it)
export type Piece = {
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	anchor: string?,
	tone: string?,
	text: string?,
	tap: boolean?,
	main: boolean?,
	world: boolean?,
	instead: string?,
	inner: { Piece }?,
}
export type Screen = {
	id: string,
	n: number,
	title: string,
	kind: string,
	gameplay: boolean,
	pieces: { Piece },
}

local function p(name: string, x: number, y: number, w: number, h: number, more: any?): Piece
	local out: any = { name = name, x = x, y = y, w = w, h = h }
	if more then
		for k, v in more do
			out[k] = v
		end
	end
	return out :: Piece
end

local SmashScreens = {}

local LIST: { Screen } = {
	{
		id = "matchEnd",
		n = 101,
		title = "Round over",
		kind = "full",
		gameplay = false,
		pieces = {
			p("Shout", 178, 4, 400, 58, { anchor = "t" }),
			p("Wins", 178, 62, 400, 34, { anchor = "t" }),
			-- the winner's kart on show in the middle, rays behind it
			p("Winner", 258, 100, 240, 170, { anchor = "c" }),
			-- 1st, 2nd, 3rd with smashes
			p("Top3", 0, 104, 230, 168, { anchor = "l" }),
			-- what you got: coins, XP, your place
			p("Rewards", 526, 104, 230, 168, { anchor = "r" }),
			p("Count", 128, 292, 500, 40, { anchor = "b" }),
			p("Leave", 646, 334, 110, 48, { anchor = "br", tone = "white", text = "LEAVE" }),
		},
	},
	{
		id = "howTo",
		n = 102,
		title = "How to smash",
		kind = "hud",
		gameplay = true,
		pieces = {
			-- under the health bar and clock (top middle), over the empty middle of the arena
			p("Tip", 238, 92, 280, 92, { anchor = "t", tap = true }),
			-- the arrow for each step: just right of the stick corner pointing left at it (the
			-- scoreboard sits above the corner), and just above FIRE pointing down
			p("ArrowDrive", 148, 290, 56, 56, { anchor = "bl" }),
			p("ArrowFire", 650, 180, 56, 56, { anchor = "br" }),
		},
	},
}

SmashScreens.LIST = LIST

local byId: { [string]: Screen } = {}
for _, s in LIST do
	byId[s.id] = s
end

function SmashScreens.get(id: string): Screen
	local s = byId[id]
	assert(s, "no smash screen " .. id)
	return s
end

-- One piece; "Rewards.Coins" reaches into a window's own pieces.
function SmashScreens.piece(id: string, path: string): Piece
	local s = SmashScreens.get(id)
	local function find(list: { Piece }, name: string): Piece?
		for _, piece in list do
			if piece.name == name then
				return piece
			end
		end
		return nil
	end
	local dot = path:find(".", 1, true)
	local got: Piece?
	if dot then
		local outer = find(s.pieces, path:sub(1, dot - 1))
		got = outer and outer.inner and find(outer.inner, path:sub(dot + 1))
	else
		got = find(s.pieces, path)
	end
	assert(got, `no piece {path} on {id}`)
	return got
end

-- The how-to's 3 steps, in order: the big words, one small line, and the arrow piece (if any).
SmashScreens.STEPS = {
	-- (rot: the arrow drawing points right; 180 = left, 90 = down)
	{
		id = "drive",
		words = "DRIVE!",
		help = "Move the stick to drive.",
		arrow = "ArrowDrive",
		rot = 180,
	},
	{ id = "grab", words = "GRAB A ?", help = "Drive into a red ? box.", arrow = nil, rot = 0 },
	{
		id = "fire",
		words = "TAP FIRE!",
		help = "Smash the other cars!",
		arrow = "ArrowFire",
		rot = 90,
	},
}
SmashScreens.DRIVE_STUDS = 12 -- driven this far = the drive step is done

-- Which how-to step shows now (4 = all done), from the one showing and what the kid has done:
-- moved (studs from where the tip started), weapon ("" = none), fired (ammo went down).
-- Doing a later thing first skips ahead: a kid who grabs a box before the tip says so never
-- sees GRAB A ?.
function SmashScreens.step(
	at: number,
	did: { moved: number, weapon: string, fired: boolean }
): number
	local s = math.clamp(at, 1, 4)
	if did.fired then
		return 4
	end
	if s <= 2 and did.weapon ~= "" then
		s = 3
	end
	if s == 1 and did.moved >= SmashScreens.DRIVE_STUDS then
		s = 2
	end
	return s
end

return SmashScreens
