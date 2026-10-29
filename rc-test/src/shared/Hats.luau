--!strict
-- Kart hats (Smash plan, REWARDS row): low-poly toppers won on the Lucky Spin. Each hat is a few
-- flat SmoothPlastic / Neon parts (no text, no logos, no studs), placed from the kart's "Topper"
-- attachment (+Y up). Pure data, so Lune can check the look rules; SpinServer builds them.

export type Bit = {
	shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	size: { number }, -- x, y, z studs (a Cylinder's length is x; it is turned to stand up)
	at: { number }, -- x, y, z studs above the topper
	rot: { number }?, -- degrees x, y, z
	rgb: { number },
	neon: boolean?,
}
export type Hat = { id: string, name: string, rarity: string, bits: { Bit } }

local Hats = {}

Hats.MAX_BITS = 6

-- the palette (FINISH-JOBS look rule): grass green, sky blue, sunny yellow, cherry red,
-- hot pink, dark navy, plus white
local GREEN, BLUE, YELLOW = { 92, 196, 74 }, { 86, 180, 245 }, { 255, 205, 50 }
local RED, PINK, NAVY, WHITE = { 230, 57, 70 }, { 255, 92, 170 }, { 34, 40, 74 }, { 245, 245, 250 }

Hats.LIST = {
	{
		id = "cherry",
		name = "Cherry",
		rarity = "common",
		bits = {
			{ shape = "Ball", size = { 1.2, 1.2, 1.2 }, at = { -0.35, 0.6, 0 }, rgb = RED },
			{ shape = "Ball", size = { 1.2, 1.2, 1.2 }, at = { 0.45, 0.6, 0.1 }, rgb = RED },
			{
				shape = "Block",
				size = { 0.15, 1, 0.15 },
				at = { 0.05, 1.5, 0 },
				rot = { 0, 0, 15 },
				rgb = GREEN,
			},
			{ shape = "Wedge", size = { 0.15, 0.4, 0.6 }, at = { 0.25, 1.9, 0 }, rgb = GREEN },
		},
	},
	{
		id = "cone",
		name = "Party Cone",
		rarity = "rare",
		bits = {
			{ shape = "Cylinder", size = { 0.5, 1.6, 1.6 }, at = { 0, 0.25, 0 }, rgb = PINK },
			{ shape = "Cylinder", size = { 0.5, 1.1, 1.1 }, at = { 0, 0.75, 0 }, rgb = YELLOW },
			{ shape = "Cylinder", size = { 0.5, 0.6, 0.6 }, at = { 0, 1.25, 0 }, rgb = PINK },
			{
				shape = "Ball",
				size = { 0.5, 0.5, 0.5 },
				at = { 0, 1.65, 0 },
				rgb = WHITE,
				neon = true,
			},
		},
	},
	{
		id = "tophat",
		name = "Top Hat",
		rarity = "rare",
		bits = {
			{ shape = "Cylinder", size = { 0.15, 2.2, 2.2 }, at = { 0, 0.08, 0 }, rgb = NAVY },
			{ shape = "Cylinder", size = { 1.4, 1.4, 1.4 }, at = { 0, 0.85, 0 }, rgb = NAVY },
			{ shape = "Cylinder", size = { 0.3, 1.45, 1.45 }, at = { 0, 0.4, 0 }, rgb = RED },
		},
	},
	{
		id = "propeller",
		name = "Propeller Cap",
		rarity = "epic",
		bits = {
			{ shape = "Ball", size = { 1.8, 1.2, 1.8 }, at = { 0, 0.3, 0 }, rgb = BLUE },
			{ shape = "Cylinder", size = { 0.5, 0.15, 0.15 }, at = { 0, 1.05, 0 }, rgb = NAVY },
			{ shape = "Block", size = { 2.2, 0.08, 0.35 }, at = { 0, 1.32, 0 }, rgb = YELLOW },
			{ shape = "Block", size = { 0.35, 0.08, 2.2 }, at = { 0, 1.32, 0 }, rgb = RED },
		},
	},
	{
		id = "crown",
		name = "Crown",
		rarity = "epic",
		bits = {
			{ shape = "Cylinder", size = { 0.5, 1.7, 1.7 }, at = { 0, 0.25, 0 }, rgb = YELLOW },
			{ shape = "Wedge", size = { 0.3, 0.7, 0.4 }, at = { 0, 0.85, 0.65 }, rgb = YELLOW },
			{
				shape = "Wedge",
				size = { 0.3, 0.7, 0.4 },
				at = { 0, 0.85, -0.65 },
				rot = { 0, 180, 0 },
				rgb = YELLOW,
			},
			{
				shape = "Wedge",
				size = { 0.3, 0.7, 0.4 },
				at = { 0.65, 0.85, 0 },
				rot = { 0, 90, 0 },
				rgb = YELLOW,
			},
			{
				shape = "Wedge",
				size = { 0.3, 0.7, 0.4 },
				at = { -0.65, 0.85, 0 },
				rot = { 0, -90, 0 },
				rgb = YELLOW,
			},
			{
				shape = "Ball",
				size = { 0.4, 0.4, 0.4 },
				at = { 0, 0.55, 0.85 },
				rgb = PINK,
				neon = true,
			},
		},
	},
	{
		id = "star",
		name = "Star Topper",
		rarity = "legendary",
		bits = {
			{ shape = "Cylinder", size = { 0.6, 0.2, 0.2 }, at = { 0, 0.3, 0 }, rgb = NAVY },
			{
				shape = "Block",
				size = { 0.3, 1.6, 0.5 },
				at = { 0, 1.3, 0 },
				rot = { 0, 0, 36 },
				rgb = YELLOW,
				neon = true,
			},
			{
				shape = "Block",
				size = { 0.3, 1.6, 0.5 },
				at = { 0, 1.3, 0 },
				rot = { 0, 0, -36 },
				rgb = YELLOW,
				neon = true,
			},
			{
				shape = "Block",
				size = { 0.3, 1.6, 0.5 },
				at = { 0, 1.3, 0 },
				rot = { 0, 0, 90 },
				rgb = YELLOW,
				neon = true,
			},
		},
	},
} :: { Hat }

local byId: { [string]: Hat } = {}
for _, h in Hats.LIST do
	byId[h.id] = h
end

function Hats.get(id: any): Hat?
	return if type(id) == "string" then byId[id] else nil
end

return Hats
