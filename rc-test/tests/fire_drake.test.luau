--!strict
-- The Fire Drake heads (shared/FireDrakeData, client/FireDrake): carter's pick "Fender Heads".
-- Checks the part list is small, stays on the car, the spikes point the way they should, and that
-- the car skins call it.
local fs = require("@lune/fs")
local H = require("./harness")
local D = require("../src/shared/FireDrakeData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Fire Drake")

type V = { number }
-- a vector turned like CFrame.Angles(x, y, z): Z first, then Y, then X
local function turn(v: V, rot: V): V
	local x, y, z = v[1], v[2], v[3]
	local c, s = math.cos(math.rad(rot[3])), math.sin(math.rad(rot[3]))
	x, y = x * c - y * s, x * s + y * c
	c, s = math.cos(math.rad(rot[2])), math.sin(math.rad(rot[2]))
	x, z = x * c + z * s, -x * s + z * c
	c, s = math.cos(math.rad(rot[1])), math.sin(math.rad(rot[1]))
	y, z = y * c - z * s, y * s + z * c
	return { x, y, z }
end

-- a wedge's point is the top of its tall edge, at (0, +h/2, +len/2) (see ArenaBuilder)
local function point(s: D.Spec): V
	local p = turn({ 0, s.size[2] / 2, s.size[3] / 2 }, s.rot)
	local mid = turn({ 0, -s.size[2] / 2, 0 }, s.rot)
	return { p[1] + s.at[1], p[2] + s.at[2], p[3] + s.at[3], mid[1], mid[2], mid[3] }
end

local function find(name: string): D.Spec
	for _, s in D.pod() do
		if s.name == name then
			return s
		end
	end
	error("no part " .. name)
end

test("fire drake: a small part list (phones move every part every frame)", function()
	local n = #D.pod()
	truthy(n >= 25 and n <= 36, `{n} parts a head`)
	local seen: { [string]: boolean } = {}
	for _, s in D.pod() do
		truthy(not seen[s.name], "twice: " .. s.name)
		seen[s.name] = true
		truthy(D.COLORS[s.mat] ~= nil, "colour " .. s.mat)
		for i = 1, 3 do
			truthy(s.size[i] > 0 and s.size[i] < 3, "size of " .. s.name)
		end
	end
end)

test("fire drake: the heads stay on the car's front half and don't grow past its nose", function()
	local k = D.SCALE
	local podZ = D.PLACE.z * D.DESIGN_LENGTH
	local half = D.DESIGN_LENGTH / 2
	local front, back = -1e9, 1e9
	for _, s in D.pod() do
		local reach = math.max(s.size[1], s.size[2], s.size[3]) / 2
		front =
			math.max(front, podZ + s.at[3] + (if s.name:find("Muzzle") then s.size[3] / 2 else 0))
		back = math.min(back, podZ + s.at[3] - reach * 0.5)
		truthy(s.at[2] < 3.2 * k * 2, "not sky high: " .. s.name)
	end
	truthy(front <= half, `the muzzle reaches z={front}, past the nose at {half}`)
	truthy(back > -half * 0.6, "the heads stay on the front half")
end)

test("fire drake: horns sweep to the tail, fangs hang down, teeth stand up", function()
	local horn = find("HornR")
	local p = point(horn)
	truthy(p[5] < 0, "the horn's base is below its point") -- (mid is the base's middle, offset down)
	-- the point is behind the base's middle (toward -Z) and above it
	truthy(p[3] - horn.at[3] < 0 and p[2] > horn.at[2], "horn: up and back")
	truthy(p[1] - horn.at[1] > 0, "the +X head's horn leans out, not across the car")
	local fang = point(find("FangR1"))
	truthy(fang[2] < find("FangR1").at[2], "the fang's point is at the bottom")
	local tooth = point(find("ToothR1"))
	truthy(tooth[2] > find("ToothR1").at[2], "the tooth's point is at the top")
	local frill = find("Frill")
	truthy(point(frill)[3] < frill.at[3], "the fin's point is toward the tail")
end)

test("fire drake: the other head is the first one's mirror", function()
	for _, s in D.pod() do
		local m = D.mirror(s)
		eq(m.at[1], -s.at[1])
		eq(m.at[2], s.at[2])
		eq(m.at[3], s.at[3])
		eq(m.rot[1], s.rot[1])
		eq(m.rot[2], -s.rot[2])
		eq(m.rot[3], -s.rot[3])
		-- horns that lean out lean out the other way too
		if s.name == "HornR" then
			truthy(point(m)[1] - m.at[1] < 0, "the mirrored horn leans to -X")
		end
	end
	eq(D.mirror(D.mirror(find("Frill"))).rot[2], find("Frill").rot[2])
end)

test("fire drake: it has two tubes (the weapon is in the head) and glowing eyes", function()
	local tubes, eyes = 0, 0
	for _, s in D.pod() do
		if s.shape == "Cylinder" then
			tubes += 1
		end
		if s.name:sub(1, 3) == "Eye" and s.neon == true then
			eyes += 1
		end
	end
	eq(tubes, 2) -- (a head holds two)
	eq(eyes, 2)
end)

test("fire drake: CarSkin and OtherCars both ready the model first", function()
	local skin = fs.readFile("src/client/CarSkin.luau")
	local others = fs.readFile("src/client/OtherCars.luau")
	truthy(skin:find("FireDrake.addTo", 1, true), "CarSkin adds the heads")
	truthy(skin:find("CarSkin.prepare(m)", 1, true), "template() readies the model")
	truthy(others:find("CarSkin.prepare(own)", 1, true), "other cars ready it too")
	local drake = fs.readFile("src/client/FireDrake.luau")
	truthy(drake:find("race_bolt", 1, true), "it is on the black+red car")
	-- race_bolt's body is turned round (front wheels at its local -Z): the heads follow the wheels
	truthy(drake:find("function FireDrake.noseSign", 1, true), "the nose is read from the wheels")
	truthy(drake:find("nose * place.z", 1, true), "the head sits toward the nose")
end)

test("fire drake: the tailpipes are at the car's tail, either side of the middle", function()
	local e = D.EXHAUST
	truthy(e.x > 0.1 and e.x < 0.4, "pipes either side of the middle, inside the body")
	truthy(e.z <= -0.45 and e.z >= -0.55, "at the tail")
	truthy(e.y > -0.5 and e.y < 0, "low on the body")
end)

test("fire drake: the exhaust jets follow boost, on whatever car skin is shown", function()
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(skin:find("car.telemetry.boost > 0", 1, true), "boost drives the jets")
	truthy(skin:find("if cur then cur.body else nil", 1, true), "any car skin, not only Fire Drake")
	local fx = fs.readFile("src/client/ExhaustFx.luau")
	truthy(fx:find("Enum.NormalId.Back", 1, true), "flames go out the tail, either way round")
	truthy(fx:find("FireDrake.noseSign", 1, true), "the tail is found from the wheels")
end)
