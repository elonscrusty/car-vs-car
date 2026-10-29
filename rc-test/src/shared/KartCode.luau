--!strict
-- Reads KartMeshData's compact numbers (assets/karts/to_luau.py writes them): base-64 characters,
-- two per vertex coordinate (hundredths of a toy unit, offset by 2048) and w per vertex number.

local KartCode = {}

local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VAL: { [number]: number } = {}
for i = 1, #A do
	VAL[string.byte(A, i)] = i - 1
end

-- The vertex coordinates, x, y, z, x, y, z, ... in toy units.
function KartCode.verts(s: string): { number }
	local out: { number } = table.create(#s // 2)
	for i = 1, #s, 2 do
		local a, b = string.byte(s, i, i + 1)
		table.insert(out, (VAL[a] * 64 + VAL[b] - 2048) / 100)
	end
	return out
end

-- The triangles' vertex numbers (1-based), three per triangle.
function KartCode.tris(s: string, w: number): { number }
	local out: { number } = table.create(#s // w)
	for i = 1, #s, w do
		if w == 1 then
			table.insert(out, VAL[string.byte(s, i)] + 1)
		else
			local a, b = string.byte(s, i, i + 1)
			table.insert(out, VAL[a] * 64 + VAL[b] + 1)
		end
	end
	return out
end

return KartCode
