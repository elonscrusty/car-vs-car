--!strict
-- Launch feature flags (pure data). A flag that is false = that feature is hidden / off; the
-- code stays in the game. Flip a flag to true to bring a feature back. Read via FeatureFlags.enabled.

local FeatureFlags = {}

FeatureFlags.Flags = {
	dailySpin = false, -- daily spin wheel button and server action
	rankBadges = false, -- Bronze/Silver/Gold rank label in the progress panel
	paintShop = false, -- PAINT button and buyPaint/equipPaint server actions
	perCarQuests = false, -- "Win 3 with <car>" quests (off = only win3, play5, bot2)
	botLevelButton = false, -- BOT: EASY/MEDIUM/HARD button (off = bot level auto-scales by wins)
	soccerMode = false, -- car soccer: hidden for now (carter: fights are the only mode); the code stays
	raceMode = false, -- Crazy Race: hidden for now
	tagMode = false, -- car tag: hidden for now
	hillMode = false, -- king of the hill (1v1 bowl): out of the rotation until soccer/tag/race are proven
	iceMode = false, -- ice bowl (1v1): same
	lastStandingMode = true, -- the car fight: 4 cars on a flat floor with ramps, last car alive wins
} :: { [string]: boolean }

-- Unknown flag names count as off.
function FeatureFlags.enabled(name: string, flags: { [string]: boolean }?): boolean
	return (flags or FeatureFlags.Flags)[name] == true
end

return FeatureFlags
