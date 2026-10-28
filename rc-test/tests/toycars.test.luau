--!strict
-- Toy kart looks (carter 10-28 "use all of it"): every car has its own low-poly shape and accent
-- in the look rule's palette, a driver and a WeaponMount, stays the grey race body's length and the
-- phone part budget, and its wheels sit where the race car's springs put them.
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
		-- underglow on rare cars and up, none on commons
		eq(bits[3] == "glow", c.rarity ~= "common")
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
	eq(ToyCars.parse("nope/nope").accent, ToyCars.PALETTE.yellow)
	truthy(ToyCars.parse("truck/purple/glow").glow)
end)

test("every car: 16 parts at most, four wheels one per corner, a WeaponMount", function()
	for _, shape in ToyCars.SHAPES do
		for _, style in { shape .. "/white", shape .. "/white/glow" } do
			local ps = pieces(style)
			truthy(#ps <= 16, `{style}: {#ps} parts`)
			local corners: { [string]: number } = {}
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			local named: { [string]: number } = {}
			for _, p in ps do
				if p.name == "Wheel" then
					local k = (if p.pos.z < 0 then "F" else "R")
						.. (if p.pos.x < 0 then "L" else "R")
					corners[k] = (corners[k] or 0) + 1
					eq(math.abs(p.pos.z), ToyCars.WHEEL_Z)
				elseif p.name ~= "Hub" and p.name ~= "Head" then
					minX = math.min(minX, p.pos.x - p.size.x / 2)
					maxX = math.max(maxX, p.pos.x + p.size.x / 2)
					minZ = math.min(minZ, p.pos.z - p.size.z / 2)
					maxZ = math.max(maxZ, p.pos.z + p.size.z / 2)
					named[p.name] = (named[p.name] or 0) + 1
				end
				truthy(p.collide == false, `{style}: {p.name} is solid`)
			end
			for _, k in { "FL", "FR", "RL", "RR" } do
				eq(corners[k], 1)
			end
			-- Body: the one part the race paints the car's colour; WeaponMount: where rockets go
			for _, name in { "Body", "WeaponMount" } do
				eq(named[name], 1)
			end
			local len, wide = maxZ - minZ, maxX - minX
			truthy(
				math.abs(len - Garage.TOY_LENGTH) <= 0.1 * Garage.TOY_LENGTH,
				`{style} {len} long`
			)
			-- no wider than its wheels (the deck covers their tops)
			truthy(wide <= 2 * ToyCars.halfWidth(style) + 0.01, `{style} {wide} wide`)
		end
	end
end)

test(
	"glow (rare and up): the accent bits light up, no extra parts; rims take the accent",
	function()
		for _, shape in ToyCars.SHAPES do
			local plain, glow = pieces(shape .. "/sky"), pieces(shape .. "/sky/glow")
			eq(#glow, #plain)
			local lit = 0
			for _, p in glow do
				if p.material == "Neon" and p.color == ToyCars.PALETTE.sky then
					lit += 1
				elseif p.name == "Hub" then
					eq(p.color, ToyCars.PALETTE.sky)
				end
			end
			truthy(lit >= 1, `{shape}: nothing glows`)
		end
		eq(ToyCars.rim("muscle/navy"), ToyCars.PALETTE.white) -- navy rims would vanish
	end
)

test("every car's colour is from the look rule's palette", function()
	for _, c in allCars() do
		local found = false
		for _, col in ToyCars.PALETTE do
			if col[1] == c.color[1] and col[2] == c.color[2] and col[3] == c.color[3] then
				found = true
			end
		end
		truthy(found, `{c.id}: colour not in the palette`)
	end
end)

test("wheels stay near the race car's own (springs hold them: big tyres would sink)", function()
	-- the race car's wheel is 0.8 of a 5.5 body: about 1.05 across at toy size 1
	local own = 2 * 0.8 * Garage.TOY_LENGTH / 5.5
	for shape, w in ToyCars.WHEELS do
		truthy(w.wd >= own - 0.15 and w.wd <= own + 0.2, `{shape} wheels {w.wd}`)
	end
end)

test("every car has a hat spot, and nothing covers its WeaponMount", function()
	local fs = require("@lune/fs")
	local builder = fs.readFile("src/server/CarBuilder.luau")
	truthy(string.find(builder, 'topper.Name = "Topper"', 1, true), "no Topper attachment")
	-- nothing but the deck and floor under the WeaponMount's square (the head is above it)
	for _, shape in ToyCars.SHAPES do
		local ps = pieces(shape .. "/white")
		local mount: any
		for _, p in ps do
			if p.name == "WeaponMount" then
				mount = p
			end
		end
		for _, p in ps do
			local name = p.name
			if
				name ~= "WeaponMount"
				and name ~= "Body"
				and name ~= "Floor"
				and name ~= "Hub"
				and name ~= "Head"
			then
				local overZ = math.abs(p.pos.z - mount.pos.z) < (p.size.z + mount.size.z) / 2 - 0.02
				local overX = math.abs(p.pos.x - mount.pos.x) < (p.size.x + mount.size.x) / 2
				local overY = p.pos.y + p.size.y / 2 > mount.pos.y - mount.size.y / 2 + 0.02
				truthy(not (overZ and overX and overY), `{shape}: {name} covers the WeaponMount`)
			end
		end
	end
end)

test("6 Blender kart models dress all 24 cars, each car its own colours", function()
	local seen: { [string]: string } = {}
	local models: { [string]: boolean } = {}
	for _, shape in ToyCars.SHAPES do
		local m = ToyCars.KARTS[shape]
		truthy(m ~= nil, `{shape} wears no kart`)
		models[m] = true
	end
	local n = 0
	for _ in models do
		n += 1
	end
	eq(n, 6)
	for _, c in allCars() do
		local look = ToyCars.parse(c.style)
		local key = `{ToyCars.kartModel(c.style)} {table.concat(c.color, ",")} {table.concat(
			look.accent,
			","
		)} {look.glow}`
		truthy(seen[key] == nil, `{c.id} looks like {seen[key]}`)
		seen[key] = c.id
	end
end)

test(
	"a kart model's parts are painted by name: body the car's colour, lights and glow lit",
	function()
		local red = ToyCars.PALETTE.red
		eq(ToyCars.kartPaint("Body", red, "formula/white"), red)
		eq(ToyCars.kartPaint("Accent", red, "formula/white"), ToyCars.PALETTE.white)
		local _, lit = ToyCars.kartPaint("Accent", red, "formula/white/glow")
		truthy(lit, "glow accent not lit")
		eq(ToyCars.kartPaint("Accent", red, "wedge/navy/glow"), ToyCars.PALETTE.sky)
		for _, name in { "Headlights", "Taillights" } do
			local _, on = ToyCars.kartPaint(name, red, "muscle")
			truthy(on, `{name} not lit`)
		end
		for _, name in
			{ "Trim", "Driver", "Head", "WeaponMount", "WheelFL", "WheelFR", "WheelRL", "WheelRR" }
		do
			truthy(ToyCars.kartPaint(name, red, "muscle") ~= nil, `{name} not painted`)
		end
		-- the driver's shirt never matches a blue car
		eq(ToyCars.kartPaint("Driver", { 30, 111, 217 }, "muscle"), ToyCars.PALETTE.white) -- (a catalog colour is its own table)
		-- own car and others both wear them
		local fs = require("@lune/fs")
		local others = fs.readFile("src/client/OtherCars.luau")
		truthy(
			string.find(others, "modelShell(f, kart, s, id)", 1, true),
			"other cars wear no kart"
		)
		local skin = fs.readFile("src/client/CarSkin.luau")
		truthy(string.find(skin, "CarSkin.KART .. id", 1, true), "own car wears no kart")
	end
)
