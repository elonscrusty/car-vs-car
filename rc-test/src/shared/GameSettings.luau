--!strict
-- A player's settings (the Smash SETTINGS window, WINDOWS): music and sound volume (0..1), the
-- world's shadows, other players' name tags and the match camera (follow or fixed). Pure (Lune
-- tests it): the defaults and the one check every saved or sent table goes through. SettingsServer keeps them, the client applies them.
local GameSettings = {}

export type Settings = {
	music: number,
	sfx: number,
	shadows: boolean,
	names: boolean,
	camera: string,
	buttons: string, -- the phone's FIRE button size: "small" | "medium" | "large"
	buzz: boolean, -- a controller's rumble
}

GameSettings.DEFAULTS = {
	music = 1,
	sfx = 1,
	shadows = true,
	names = true,
	camera = "follow",
	buttons = "medium",
	buzz = true,
} :: Settings
GameSettings.BUTTON_SCALE = { small = 0.8, medium = 1, large = 1.25 }
GameSettings.SAVE_GAP = 2 -- seconds between saves taken from one player

local function volume(v: any, default: number): number
	if type(v) ~= "number" or v ~= v then
		return default
	end
	-- (0.05 steps: a slider can't send a long tail of digits into the save)
	return math.clamp(math.floor(v * 20 + 0.5) / 20, 0, 1)
end

-- Any table (a save, a client's ask) as good settings: unknown keys dropped, bad values default.
function GameSettings.clean(t: any): Settings
	local d = GameSettings.DEFAULTS
	local src = if type(t) == "table" then t else {}
	return {
		music = volume(src.music, d.music),
		sfx = volume(src.sfx, d.sfx),
		shadows = if type(src.shadows) == "boolean" then src.shadows else d.shadows,
		names = if type(src.names) == "boolean" then src.names else d.names,
		camera = if src.camera == "fixed" then "fixed" else "follow",
		buttons = if src.buttons == "small" or src.buttons == "large"
			then src.buttons
			else "medium",
		buzz = if type(src.buzz) == "boolean" then src.buzz else d.buzz,
	}
end

function GameSettings.same(a: Settings, b: Settings): boolean
	return a.music == b.music
		and a.sfx == b.sfx
		and a.shadows == b.shadows
		and a.names == b.names
		and a.camera == b.camera
		and a.buttons == b.buttons
		and a.buzz == b.buzz
end

return GameSettings
