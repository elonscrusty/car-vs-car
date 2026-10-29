--!strict
-- Toy kart looks (carter 10-28 "use all of it"): every car has its own low-poly shape and accent
-- in the look rule's palette and no weapon on it (an icon above it shows that), stays the grey race body's length and the
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

test("every car: 16 parts at most, four wheels one per corner, no weapon plate", function()
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
			-- Body: the one part the race paints the car's colour (carter 10-28: no weapon plate)
			eq(named.Body, 1)
			eq(named.WeaponMount, nil)
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
	"glow (rare and up): the accent bits light up, no extra parts; rims take the car's colour",
	function()
		for _, shape in ToyCars.SHAPES do
			local plain, glow = pieces(shape .. "/sky"), pieces(shape .. "/sky/glow")
			eq(#glow, #plain)
			local lit = 0
			for _, p in glow do
				if p.material == "Neon" and p.color == ToyCars.PALETTE.sky then
					lit += 1
				elseif p.name == "Hub" then
					eq(p.color[1], 200) -- carter's picture: rims in the car's own colour
				end
			end
			truthy(lit >= 1, `{shape}: nothing glows`)
		end
		eq(ToyCars.rim("muscle/navy"), ToyCars.PALETTE.white) -- navy rims would vanish
		eq(ToyCars.rim("muscle/red", { 27, 27, 47 }), ToyCars.PALETTE.white)
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

test("every car is an open kart with a Roblox kid driving, cap top on the hat spot", function()
	for _, shape in ToyCars.SHAPES do
		local named: { [string]: Garage.Piece } = {}
		for _, p in pieces(shape .. "/white") do
			named[p.name] = p
		end
		truthy(named.Driver and named.Head and named.Cap, `{shape}: no driver`)
		eq(named.Cap.shape, "Ball") -- (a ball: as tall as it is wide)
		eq(named.Cap.pos.y + named.Cap.size.x / 2, ToyCars.HEAD_TOP)
		eq(named.Head.mesh, "Head") -- the round Roblox head, not a Lego cube
		eq(table.concat(named.Head.color, ","), "245,205,48")
		truthy(named.Head.face, `{shape}: the driver has no face`)
		eq(table.concat(named.Cap.color, ","), "200,40,40")
		-- a yellow car's kid wears the accent, so he doesn't blend into the car (Studio 10-29)
		local yellow: { [string]: Garage.Piece } = {}
		local out = {}
		Garage.toyCar(
			Garage.adder(out),
			"Car",
			{ x = 0, y = 0, z = 0 },
			0,
			{ 255, 199, 44 },
			1,
			shape .. "/navy"
		)
		for _, p in out do
			yellow[p.name] = p
		end
		eq(table.concat(yellow.Cap.color, ","), "27,27,47")
		eq(yellow.Driver.material, "SmoothPlastic")
		eq(named.Cab, nil)
	end
end)

test("every car has a hat spot", function()
	local fs = require("@lune/fs")
	local builder = fs.readFile("src/server/CarBuilder.luau")
	truthy(string.find(builder, 'topper.Name = "Topper"', 1, true), "no Topper attachment")
end)

test("6 kart models dress all 24 cars, each car its own colours", function()
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
			{
				"Trim",
				"Driver",
				"Head",
				"Cap",
				"Metal",
				"Eyes",
				"Seat",
				"RimFL",
				"WheelFL",
				"WheelFR",
				"WheelRL",
				"WheelRR",
			}
		do
			truthy(ToyCars.kartPaint(name, red, "muscle") ~= nil, `{name} not painted`)
		end
		-- carter's picture: the shirt, cap and rims are the kart's own colour
		eq(
			table.concat(ToyCars.kartPaint("Driver", red, "muscle") :: { number }, ","),
			table.concat(red, ",")
		)
		eq(
			table.concat(ToyCars.kartPaint("Cap", red, "muscle") :: { number }, ","),
			table.concat(red, ",")
		)
		eq(ToyCars.kartRim(red, "muscle"), red)
		-- two-tone (auditor round 12): trim a dark tone of the body, a bright seat and stripe
		eq(table.concat(ToyCars.kartPaint("Trim", red, "muscle") :: { number }, ","), "116,26,23")
		eq(ToyCars.kartPaint("Seat", red, "formula/white"), ToyCars.PALETTE.white)
		eq(ToyCars.kartPaint("Stripe", red, "formula/white"), ToyCars.PALETTE.white)
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

test("a new kid with no racer yet drives the starter's kart, not the red grey body", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/GarageServer.luau")
	truthy(
		string.find(src, 'if racer then racer.id else CarCatalog.starter("race").id', 1, true),
		"no racer = no look"
	)
	local starter = CarCatalog.starter("race")
	truthy(CarCatalog.get(starter.id) ~= nil and starter.price == 0, "the starter is a free car")
end)

test(
	"the karts (carter's picture + his Meshy one): built in game from mesh data, painted by name",
	function()
		local KartMeshData = require("../src/shared/KartMeshData")
		local KartCode = require("../src/shared/KartCode")
		local names: { [string]: boolean } = {}
		for _, name in ToyCars.KARTS do
			names[name] = true
		end
		for name in names do
			local kart = KartMeshData[name]
			truthy(kart ~= nil, `{name}: no mesh data`)
			local tris = 0
			for g, mesh in kart do
				local v, t = KartCode.verts(mesh.v), KartCode.tris(mesh.t, mesh.w)
				eq(#v % 3, 0)
				eq(#t % 3, 0)
				for _, i in t do
					truthy(i >= 1 and i <= #v / 3, `{name}.{g}: vertex {i} out of range`)
				end
				tris += #t / 3
				-- every part gets its colour from the car (no weapon plate: carter 10-28)
				truthy(ToyCars.kartPaint(g, { 1, 2, 3 }, "muscle") ~= nil, `{name}.{g} not painted`)
				truthy(g ~= "WeaponMount", `{name} has a weapon plate`)
				if g == "Headlights" then
					-- nose at +Z, as the skins expect
					local z = 0
					for k = 3, #v, 3 do
						z += v[k]
					end
					truthy(z > 0, `{name}: headlights at the back`)
				end
			end
			truthy(tris <= 5500, `{name}: {tris} triangles (phones)`)
			for _, part in
				{ "Body", "Head", "Cap", "WheelFL", "WheelFR", "WheelRL", "WheelRR", "RimFL" }
			do
				truthy(kart[part] ~= nil, `{name} has no {part}`)
			end
		end
		-- carter's own kart (10-28): the racers wear it, its face rebuilt with two eyes and a smile
		eq(ToyCars.KARTS.formula, "Kart_Carter1")
		local face = KartMeshData.Kart_Carter1.Eyes
		truthy(
			face ~= nil and #KartCode.tris(face.t, face.w) // 3 == 5 * 12,
			"carter's driver has no clean face"
		)
		local fs = require("@lune/fs")
		local km = fs.readFile("src/client/KartMesh.luau")
		truthy(
			string.find(km, "pcall(build", 1, true),
			"a failed build must fall back to the toy car"
		)
		truthy(
			string.find(km, 'p:SetAttribute("Baked", true)', 1, true),
			"wheels keep their own colours"
		)
		local skin = fs.readFile("src/client/CarSkin.luau")
		truthy(
			string.find(skin, "return KartMesh.get(name, ToyCars.kartRim(", 1, true),
			"karts not used"
		)
		truthy(string.find(skin, 'p:GetAttribute("Baked") ~= true', 1, true), "wheels repainted")
		local others = fs.readFile("src/client/OtherCars.luau")
		truthy(string.find(others, "o.toy = shell", 1, true), "other cars never get their kart")
	end
)

test("toxic rod: rim pieces ride on their wheel and the car's files are all there", function()
	local fs = require("@lune/fs")
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(string.find(skin, "isRimOf(rim, wheelEnd)", 1, true), "every Rim<..>FL piece rides")
	-- the parts CarSkin needs: Body, the 4 wheels, and Headlights (it finds the nose by them)
	for _, part in { "Body", "WheelFL", "WheelFR", "WheelRL", "WheelRR", "Headlights" } do
		local file = `assets/toxic_rod/obj/ToxicRod__{part}.obj`
		truthy(fs.isFile(file), `{file} missing: run node assets/toxic_rod/export.js`)
	end
end)

test(
	"kart mesh numbers: compact base-64 reads back exactly (Studio paste, phone download)",
	function()
		local KartCode = require("../src/shared/KartCode")
		local v = KartCode.verts("gAgBf/")
		eq(#v, 3)
		eq(v[1], 0)
		eq(v[2], 0.01)
		eq(v[3], -0.01)
		local one, two = KartCode.tris("AB/", 1), KartCode.tris("AAAB//", 2)
		eq(one[1], 1)
		eq(one[3], 64)
		eq(two[2], 2)
		eq(two[3], 4096)
		local fs = require("@lune/fs")
		truthy(
			#fs.readFile("src/shared/KartMeshData.luau") < 200000,
			"kart data too big to paste into Studio"
		)
	end
)
