--!strict
-- Toy car looks (carter 10-28 "use all of it"): every car has its own low-poly shape and accent,
-- each stays the grey race body's size and the phone part budget, and the wheels sit where the
-- race car's springs put them.
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local Garage = require("../src/shared/Garage")
local ToyCars = require("../src/shared/ToyCars")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Toy cars")

local function allCars(): { CarCatalog.Car }
	local out = {}
	for _, list in CarCatalog.SHOP do
		for _, c in list do
			table.insert(out, c)
		end
	end
	for _, g in CarCatalog.GUMBALL do
		table.insert(out, g.car)
	end
	return out
end

local function pieces(style: string?): { Garage.Piece }
	local out = {}
	Garage.toyCar(Garage.adder(out), "Car", { x = 0, y = 0, z = 0 }, 0, { 200, 40, 40 }, 1, style)
	return out
end

test("all 24 cars have their own look: a real shape and accent, no two the same", function()
	local seen: { [string]: string } = {}
	local cars = allCars()
	eq(#cars, 24)
	for _, c in cars do
		local look = CarCatalog.LOOKS[c.id]
		truthy(look ~= nil, `{c.id} has no look`)
		eq(c.style, look)
		local bits = string.split(look, "/")
		truthy(ToyCars.WHEELS[bits[1]] ~= nil, `{c.id}: no shape {bits[1]}`)
		truthy(ToyCars.ACCENTS[bits[2] or ""] ~= nil, `{c.id}: no accent {bits[2]}`)
		truthy(bits[3] == nil or bits[3] == "glow", `{c.id}: {look}`)
		truthy(seen[look] == nil, `{c.id} looks like {seen[look]}`)
		seen[look] = c.id
	end
	-- every shape is used, so no kind of car is left out
	local used: { [string]: boolean } = {}
	for _, c in cars do
		used[ToyCars.parse(c.style).shape] = true
	end
	for _, shape in ToyCars.SHAPES do
		truthy(used[shape], `no car is a {shape}`)
	end
end)

test("the old looks and unknown ones still draw a car", function()
	eq(ToyCars.parse("race").shape, "muscle")
	eq(ToyCars.parse("drift").shape, "coupe")
	eq(ToyCars.parse("rock").shape, "crawler")
	eq(ToyCars.parse(nil).shape, "muscle")
	eq(ToyCars.parse("nope/nope").accent, ToyCars.ACCENTS.dark)
	truthy(ToyCars.parse("truck/purple/glow").glow)
end)

test("every look: 16 parts at most, four wheels one per corner, the grey body's size", function()
	for _, shape in ToyCars.SHAPES do
		for _, style in { shape .. "/white", shape .. "/white/glow" } do
			local ps = pieces(style)
			truthy(#ps <= 16, `{style}: {#ps} parts`)
			local corners: { [string]: number } = {}
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			local body = 0
			for _, p in ps do
				if p.name == "Wheel" then
					local k = (if p.pos.z < 0 then "F" else "R")
						.. (if p.pos.x < 0 then "L" else "R")
					corners[k] = (corners[k] or 0) + 1
					eq(math.abs(p.pos.z), ToyCars.WHEEL_Z)
				elseif p.name ~= "Hub" then
					minX = math.min(minX, p.pos.x - p.size.x / 2)
					maxX = math.max(maxX, p.pos.x + p.size.x / 2)
					minZ = math.min(minZ, p.pos.z - p.size.z / 2)
					maxZ = math.max(maxZ, p.pos.z + p.size.z / 2)
					if p.name == "Body" then
						body += 1
					end
				end
				truthy(p.collide == false, `{style}: {p.name} is solid`)
			end
			for _, k in { "FL", "FR", "RL", "RR" } do
				eq(corners[k], 1)
			end
			eq(body, 1) -- the one part the race paints the car's colour
			local len, wide = maxZ - minZ, maxX - minX
			truthy(
				math.abs(len - Garage.TOY_LENGTH) <= 0.1 * Garage.TOY_LENGTH,
				`{style} {len} long`
			)
			truthy(math.abs(wide - 2) <= 0.2, `{style} {wide} wide`)
		end
	end
end)

test("glow lights up the accent bits and adds no parts", function()
	for _, shape in ToyCars.SHAPES do
		local plain, glow = pieces(shape .. "/cyan"), pieces(shape .. "/cyan/glow")
		eq(#glow, #plain)
		local lit = 0
		for _, p in glow do
			if p.material == "Neon" and p.color == ToyCars.ACCENTS.cyan then
				lit += 1
			end
		end
		truthy(lit >= 1, `{shape}: nothing glows`)
	end
end)

test("wheels stay near the race car's own (springs hold them: big tyres would sink)", function()
	-- the race car's wheel is 0.8 of a 5.5 body: about 1.05 across at toy size 1
	local own = 2 * 0.8 * Garage.TOY_LENGTH / 5.5
	for shape, w in ToyCars.WHEELS do
		truthy(w.wd >= own - 0.15 and w.wd <= own + 0.2, `{shape} wheels {w.wd}`)
	end
end)
