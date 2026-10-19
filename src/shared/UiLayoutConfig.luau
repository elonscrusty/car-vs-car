--!strict
-- Numbers for the phone HUD layout (see UiLayout). Tweak freely; tests/uilayout.test.luau checks
-- that every screen size still fits. All values are PLACEHOLDERS until tried on a real phone.

local UiLayoutConfig = {}

UiLayoutConfig.topInset = 56 -- px kept free under the Roblox top bar (menu, chat, player list)
UiLayoutConfig.edge = 16 -- px from the left/right/bottom screen edge
UiLayoutConfig.gap = 8 -- px between neighbouring HUD pieces
UiLayoutConfig.minText = 14 -- smallest readable text in px (at 360 px screen height)
UiLayoutConfig.maxTextBanner = 26
UiLayoutConfig.maxTextMsg = 40
UiLayoutConfig.textPad = 4 -- px above/below text inside its label
UiLayoutConfig.centerShare = 0.4 -- middle 40% (width and height) stays empty during a fight
UiLayoutConfig.thumbShare = 0.4 -- joystick/buttons stay inside this share of the width, per side
UiLayoutConfig.thumbLowShare = 0.5 -- ...and in the bottom half of the screen

-- Top row (under the top bar): "YOU vs BOT" and the mode line side by side.
UiLayoutConfig.topRow = {
	heightShare = 0.09,
	minH = 32,
	maxH = 48,
	vsShare = 0.3,
	vsMinW = 190,
	vsMaxW = 420,
	modeShare = 0.4,
	modeMinW = 200,
	modeMaxW = 640,
}

-- Bottom centre lane (between the two thumb clusters), top to bottom: message, hint, power bar.
UiLayoutConfig.lane = {
	msgY = 0.71,
	msgH = 0.09,
	msgMinH = 30,
	msgMaxH = 64,
	hintY = 0.805,
	hintH = 0.07,
	hintMinH = 24,
	hintMaxH = 40,
	powerY = 0.885,
	powerH = 0.045,
	powerMinH = 14,
	powerMaxH = 28,
	widthShare = 0.4,
	minW = 160,
	maxW = 520,
}

-- End screen (shares of the screen height).
UiLayoutConfig.endScreen = {
	bannerY = 0.12,
	bannerH = 0.44,
	bannerW = 0.9,
	rematchY = 0.6,
	rematchH = 0.16,
	rematchW = 0.34,
	rematchMinW = 140,
	rematchMaxW = 320,
	inviteY = 0.79,
	inviteH = 0.13,
	inviteW = 0.3,
	inviteMinW = 140,
	inviteMaxW = 300,
	-- headline and sub line inside the banner (x, y, w, h as shares of the banner)
	head = { 0, 0, 1, 0.6 },
	sub = { 0.1, 0.66, 0.8, 0.34 },
}

-- Lobby menu column (left edge). Wraps into a second column when it runs out of height.
UiLayoutConfig.menu = {
	buttonW = 104,
	buttonH = 52,
	gap = 6,
	top = 84, -- under the coins box
	topStudio = 160, -- under the Studio-only DEV button
	bottomMargin = 8,
}

return UiLayoutConfig
