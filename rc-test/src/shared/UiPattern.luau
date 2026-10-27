--!strict
-- The sliding pattern's tile (spec section 7): 44 x 44, a 4-point sparkle at (11, 11) and a
-- diamond with a diamond hole at (33, 33), both about 15 px across. This draws it as how
-- covered each pixel is (0..1), so the screens can make the picture in the game (EditableImage)
-- and Lune can check its shape. The picture is plain white; the screens tint it (white 26% on
-- colors, ink 8% on white).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local UiTheme = sibling("UiTheme")

local UiPattern = {}

local P = UiTheme.PATTERN
UiPattern.SIZE = P.tile

-- Is the point (x, y) (tile px, may be fractional) inside a shape?
function UiPattern.inside(x: number, y: number): boolean
	-- the sparkle: a 4-point star with curved sides (|dx|^p + |dy|^p <= r^p, p < 1)
	local r = P.sparkle.size / 2
	local dx, dy = math.abs(x - P.sparkle.x), math.abs(y - P.sparkle.y)
	if dx <= r and dy <= r then
		local p = 0.55
		if (dx / r) ^ p + (dy / r) ^ p <= 1 then
			return true
		end
	end
	-- the diamond with a diamond hole
	local d = math.abs(x - P.diamond.x) + math.abs(y - P.diamond.y)
	return d <= P.diamond.size / 2 and d > P.diamond.hole / 2
end

-- Coverage of every pixel, row by row (index y * SIZE + x + 1), 4 x 4 samples per pixel.
function UiPattern.mask(): { number }
	local n = UiPattern.SIZE
	local out = table.create(n * n, 0)
	local ss = 4
	for py = 0, n - 1 do
		for px = 0, n - 1 do
			local hit = 0
			for sy = 0, ss - 1 do
				for sx = 0, ss - 1 do
					if UiPattern.inside(px + (sx + 0.5) / ss, py + (sy + 0.5) / ss) then
						hit += 1
					end
				end
			end
			out[py * n + px + 1] = hit / (ss * ss)
		end
	end
	return out
end

-- RGBA bytes (white, the coverage as alpha) into a buffer of SIZE * SIZE * 4.
function UiPattern.fill(buf: buffer)
	local m = UiPattern.mask()
	for i, a in m do
		local o = (i - 1) * 4
		buffer.writeu8(buf, o, 255)
		buffer.writeu8(buf, o + 1, 255)
		buffer.writeu8(buf, o + 2, 255)
		buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
	end
end

return UiPattern
