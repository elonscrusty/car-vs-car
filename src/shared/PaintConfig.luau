--!strict
-- Paint shop catalog: body colors and stickers. All paint numbers live here (placeholder prices).
-- Order is the display order, cheapest first.

export type Color = { id: string, name: string, rgb: { number }, price: number }
export type Sticker = { id: string, name: string, text: string, price: number }

local PaintConfig = {}

PaintConfig.Colors = {
	{ id = "white", name = "SNOW", rgb = { 240, 240, 245 }, price = 80 },
	{ id = "black", name = "NIGHT", rgb = { 30, 30, 36 }, price = 80 },
	{ id = "blue", name = "OCEAN", rgb = { 40, 110, 230 }, price = 100 },
	{ id = "green", name = "LIME", rgb = { 70, 210, 80 }, price = 100 },
	{ id = "yellow", name = "SUN", rgb = { 255, 210, 40 }, price = 120 },
	{ id = "orange", name = "BLAZE", rgb = { 255, 125, 30 }, price = 140 },
	{ id = "purple", name = "GRAPE", rgb = { 150, 70, 220 }, price = 160 },
	{ id = "pink", name = "BUBBLE", rgb = { 255, 100, 190 }, price = 180 },
	{ id = "gold", name = "GOLD", rgb = { 225, 180, 60 }, price = 220 },
	{ id = "cyan", name = "NEON", rgb = { 0, 235, 235 }, price = 250 },
} :: { Color }

PaintConfig.Stickers = {
	{ id = "gg", name = "GG", text = "GG", price = 120 },
	{ id = "seven", name = "LUCKY 7", text = "7", price = 140 },
	{ id = "star", name = "STAR", text = "★", price = 180 },
	{ id = "bolt", name = "BOLT", text = "⚡", price = 220 },
	{ id = "skull", name = "SKULL", text = "☠", price = 260 },
	{ id = "fire", name = "FIRE", text = "🔥", price = 300 },
} :: { Sticker }

function PaintConfig.color(id: any): Color?
	for _, c in PaintConfig.Colors do
		if c.id == id then
			return c
		end
	end
	return nil
end

function PaintConfig.sticker(id: any): Sticker?
	for _, s in PaintConfig.Stickers do
		if s.id == id then
			return s
		end
	end
	return nil
end

return PaintConfig
