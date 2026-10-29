--!strict
-- Name tags over karts that would sit on or right next to each other on screen (auditor round
-- 13: "Zippy" drawn over "Lil Smasher" when two karts touch). Given the tags' screen spots,
-- nearest first, it says which ones show: the nearest of each bunch keeps its tag, a farther one
-- is hidden while it sits inside a kept tag's box plus a gap of one tag height above and below.
-- A tag hidden last frame needs a little more room before it comes back, so it doesn't blink.
-- Pure, so Lune can test it.

local TagStack = {}

-- on: on screen at all. hid: this tag was hidden last frame. w, h: its size in pixels (else the
-- call's w, h).
export type Spot = { x: number, y: number, on: boolean, hid: boolean?, w: number?, h: number? }

TagStack.GAP = 1 -- tag heights of empty room kept between two tags, up and down
TagStack.BACK = 1.25 -- a hidden tag shows again once it is this much further out

-- spots: nearest first. w, h: a tag's size in pixels.
-- Writes into `out` (shown per spot) and returns it.
function TagStack.pick(spots: { Spot }, w: number, h: number, out: { boolean }?): { boolean }
	local shown = out or {}
	table.clear(shown)
	for i, s in spots do
		local show = true
		if s.on then
			local grow = if s.hid then TagStack.BACK else 1
			local sw, sh = s.w or w, s.h or h
			for j = 1, i - 1 do
				local k = spots[j]
				-- (two tags of different sizes: half of each, plus the gap of the taller one)
				local bw = (sw + (k.w or w)) / 2 * grow
				local th = (sh + (k.h or h)) / 2
				local bh = (th + math.max(sh, k.h or h) * TagStack.GAP) * grow
				if shown[j] and k.on and math.abs(s.x - k.x) < bw and math.abs(s.y - k.y) < bh then
					show = false
					break
				end
			end
		end
		shown[i] = show
	end
	return shown
end

return TagStack
