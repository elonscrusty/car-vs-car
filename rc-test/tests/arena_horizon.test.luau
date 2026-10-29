--!strict
-- The far edge of the arena's world (ArenaHorizon): ground to the haze, a haze wall, a far skyline.
local H = require("./harness")
local D = require("../src/shared/ArenaHorizon")
local A = require("../src/shared/ArenaData")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Arena horizon (no dark band, far junkyard skyline)")

local pieces = D.pieces(A.atmosphere.color)

local function count(name: string): number
	local n = 0
	for _, p in pieces do
		if p.name == name then
			n += 1
		end
	end
	return n
end

test("no part is longer than Roblox allows (2048)", function()
	for _, p in pieces do
		for _, s in p.size do
			truthy(s <= D.MAX_PART, `{p.name} side {s}`)
		end
	end
end)

test("ground ring: every tile but the middle one, reaching the far edge", function()
	eq(count("FarGround"), (2 * D.RING + 1) ^ 2 - 1)
	local far = 0
	for _, p in pieces do
		if p.name == "FarGround" then
			far = math.max(
				far,
				math.abs(p.pos[1]) + p.size[1] / 2,
				math.abs(p.pos[3]) + p.size[3] / 2
			)
		end
	end
	eq(far, D.EDGE)
end)

test("haze wall: closes all four sides, haze coloured, taller than the eye", function()
	eq(count("HazeWall"), 20)
	for _, p in pieces do
		if p.name == "HazeWall" then
			eq(p.color[1], A.atmosphere.color[1])
			eq(p.color[3], A.atmosphere.color[3])
			truthy(p.pos[2] + p.size[2] / 2 >= D.HAZE_TOP, "top above the camera height")
			truthy(p.pos[2] - p.size[2] / 2 <= 0, "reaches the ground")
		end
	end
end)

test("skyline: factories, chimneys, cranes, all outside the ground the game uses", function()
	truthy(count("FarFactory") >= 100, "a city")
	truthy(count("FarChimney") >= 10, "chimneys")
	truthy(count("FarCrane") >= 40, "cranes")
	for _, p in pieces do
		if string.sub(p.name, 1, 3) == "Far" and p.name ~= "FarGround" then
			local d = math.sqrt(p.pos[1] ^ 2 + p.pos[3] ^ 2)
			truthy(d >= 2000 and d <= D.EDGE, `{p.name} ring distance {d}`)
			truthy(p.pos[2] - p.size[2] / 2 >= -1, p.name .. " stands on the ground")
		end
	end
end)

test("lit windows, crane lamps and flares glow; the part budget stays small", function()
	truthy(count("FarWindow") >= 150, "windows")
	truthy(count("FarCraneLamp") >= 10, "crane lamps")
	truthy(count("FarFlare") >= 8, "flares")
	for _, p in pieces do
		if
			string.sub(p.name, 1, 9) == "FarWindow"
			or p.name == "FarFlare"
			or p.name == "FarCraneLamp"
		then
			truthy(p.neon == true, p.name .. " glows")
		end
	end
	truthy(#pieces <= 600, "phone budget: " .. #pieces)
end)

test("same every build", function()
	local again = D.pieces(A.atmosphere.color)
	eq(#again, #pieces)
	eq(again[#again].pos[1], pieces[#pieces].pos[1])
end)
