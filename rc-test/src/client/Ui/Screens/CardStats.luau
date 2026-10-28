--!strict
-- The 3 stats on a car card (garage card, crate reveal): a white panel with ink words, a bar in
-- each stat's colour and ink numbers, so they read on every rarity colour (blue numbers vanished
-- on a RARE card, Studio pr850 4c).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))

local CardStats = {}

CardStats.HEIGHT = 66

-- "39/82" fills a bar to 39 of 82; a plain number shows a full bar; anything else an empty one.
function CardStats.fraction(words: string): number
	local have, most = string.match(words, "^(%d+)%s*/%s*(%d+)$")
	local hv, mv = tonumber(have), tonumber(most)
	if hv and mv and mv > 0 then
		return math.clamp(hv / mv, 0, 1)
	end
	return if tonumber(words) then 1 else 0
end

-- stats = { power, air, speed } as words ("39/82" or "12")
function CardStats.draw(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	stats: { [string]: any }?
): Frame
	local box = Base.fill(parent, "Stats", x, y, w, CardStats.HEIGHT, Base.WHITE, 4)
	Base.corner(box, 12)
	Base.outline(box, UiTheme.OUTLINE.normal)
	local ink = Base.color("ink")
	for j, stat in UiTheme.STATS do
		local ry = 4 + (j - 1) * 20
		local words = tostring((stats or {})[stat.key] or "")
		Base.text(box, stat.word, 8, ry + 1, 50, 16, stat.word, { color = ink, align = "l", z = 5 })
		local bar = Kit.bar(box, stat.word .. "Bar", 62, ry + 4, w - 124, 11, stat.tone, {
			track = "barEmpty",
			still = true,
			z = 5,
		})
		Kit.setBar(bar, CardStats.fraction(words), true)
		Base.text(
			box,
			stat.word .. "Value",
			w - 58,
			ry + 1,
			52,
			16,
			words,
			{ color = ink, align = "r", z = 5 }
		)
	end
	return box
end

return CardStats
