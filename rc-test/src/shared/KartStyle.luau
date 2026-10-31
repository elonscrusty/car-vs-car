--!strict
-- Style A, "Kart Party" (carter's pick, 10-26): the big-word font (UiFonts.TITLE), bright red /
-- yellow / blue / green,
-- thick dark ink outlines, glossy pushable buttons. Every screen and sign takes its colours and
-- font from here, so the whole game looks like one game. KartSkin.client puts the look on the
-- screens; 3D signs (PadWords) use these too.
local KartStyle = {}

KartStyle.FONT = Enum.Font.Oswald

KartStyle.RED = Color3.fromRGB(232, 53, 46) -- #E8352E
KartStyle.YELLOW = Color3.fromRGB(255, 199, 44) -- #FFC72C
KartStyle.BLUE = Color3.fromRGB(30, 111, 217) -- #1E6FD9 panels
KartStyle.SKY = Color3.fromRGB(61, 155, 255) -- #3D9BFF panel tops, light blue
KartStyle.GREEN = Color3.fromRGB(45, 190, 78) -- #2DBE4E GO / DRIVE / BUY
KartStyle.PINK = Color3.fromRGB(255, 111, 181) -- confetti
KartStyle.INK = Color3.fromRGB(27, 27, 47) -- #1B1B2F every outline
KartStyle.WHITE = Color3.new(1, 1, 1)

-- outline widths in pixels
KartStyle.BUTTON_RIM = 3
KartStyle.PANEL_RIM = 4
KartStyle.TEXT_RIM = 2

-- confetti and burst colours
KartStyle.PARTY = {
	KartStyle.YELLOW,
	KartStyle.RED,
	KartStyle.SKY,
	KartStyle.GREEN,
	KartStyle.PINK,
	KartStyle.WHITE,
}

return KartStyle
