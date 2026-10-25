--!strict
-- The car show at each plot (PlotStands.luau): which cars show where, and the show fits the
-- plot's front area clear of the driver stand, the canopy and the gate.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local PlotDecor = require("../src/shared/PlotDecor")
local P = require("../src/shared/PlotStands")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot stands (car show)")

-- every car there is, as a "CarIds" list
local function everyCar(): string
	local ids = {}
	for _, c in P.ALL do
		table.insert(ids, c.id)
	end
	return table.concat(ids, ",")
end

test("the owner's cars: known ones only, no repeats, best first", function()
	local cars = P.parse("race_bolt, drift_ghost,race_bolt,boat_x,,race_comet, gb_gold,gb_lime")
	eq(#cars, 5)
	eq(cars[1].id, "gb_gold") -- 5% gumball: 2000
	eq(cars[2].id, "race_comet") -- 1500
	eq(cars[3].id, "gb_lime") -- 22% gumball: about 455
	eq(cars[4].id, "drift_ghost")
	eq(cars[5].id, "race_bolt")
	eq(#P.parse(nil), 0)
	eq(#P.parse(""), 0)
end)

test("rarer gumball cars are worth more", function()
	local cars = P.parse("gb_lime,gb_gold,gb_night")
	eq(cars[1].id, "gb_gold")
	eq(cars[2].id, "gb_night")
	eq(cars[3].id, "gb_lime")
end)

test("a spot for every car but the podium one, best row in front", function()
	eq(#P.SLOTS, #P.ALL - 1)
	local front = P.SLOTS[1]
	local back = P.SLOTS[#P.SLOTS]
	truthy(front.z > back.z, "front row nearest the road")
	truthy(front.y < back.y, "back row highest")
end)

test("the show fits the front area, clear of the stand, canopy, gate and street wall", function()
	local s = 0.25
	local front = Kit.FRONT_Z * s
	local edge = Kit.DEPTH / 2 * s - 0.6 -- the street wall
	local standLeft = (Kit.STAND.x - 14) * s
	local canopyRight = PlotDecor.CANOPY.x + 3.5
	for _, p in P.pieces(P.parse(everyCar())) do
		local sx, sz = p.size.x, p.size.z
		if p.shape == "Cylinder" then
			sx, sz = p.size.y, p.size.z -- turned onto its end
		end
		local name = p.group .. "/" .. p.name
		truthy(p.pos.z - sz / 2 >= front + 0.2, name .. " in front of the low wall")
		truthy(p.pos.z + sz / 2 <= edge, name .. " behind the street wall")
		truthy(p.pos.x - sx / 2 >= canopyRight - 0.01, name .. " right of the canopy")
		truthy(p.pos.x + sx / 2 <= math.min(standLeft, -10), name .. " left of the gate and stand")
	end
end)

test("every car stands on its spot or the podium, not floating or sunk", function()
	local pieces = P.pieces(P.parse(everyCar()))
	local wheels = { Hero = 0, Shelf = 0 }
	for _, p in pieces do
		if p.name == "Wheel" then
			local bottom = p.pos.y - p.size.y / 2
			wheels[p.group] += 1
			if p.group == "Hero" then
				truthy(math.abs(bottom - P.HERO.top) < 0.05, "hero wheel on the podium")
			else
				local ok = false
				for _, s in P.SLOTS do
					if math.abs(p.pos.x - s.x) < 1.2 and math.abs(p.pos.z - s.z) < 1.2 then
						ok = math.abs(bottom - (s.y + 0.06)) < 0.05
					end
				end
				truthy(ok, "shelf wheel on its plate")
			end
		end
	end
	eq(wheels.Hero, 4)
	eq(wheels.Shelf, 4 * (#P.ALL - 1))
	-- no owner: the show only, no cars
	for _, p in P.pieces({}) do
		eq(p.group, "Show")
	end
end)

test("shelf cars fit their spots side by side", function()
	local row1 = P.ROWS[1]
	local gap = (P.X1 - P.X0) / row1
	-- the widest toy car (rock) is about 3.5 studs at size 1
	truthy(3.5 * P.SHELF_CAR < gap - 0.2, "a gap between cars")
	-- the hero turns inside its podium (car about 4 x 3.6 at size 1)
	local half = math.sqrt(2 ^ 2 + 1.8 ^ 2) * P.HERO_CAR
	truthy(half <= P.HERO.r + 0.1, "hero stays over the podium as it turns")
end)

test("the board hangs over the shelf cars, not through them", function()
	local b = P.BOARD
	for _, p in P.pieces(P.parse(everyCar())) do
		if p.group == "Shelf" and math.abs(p.pos.z - b.z) < p.size.z / 2 + 0.3 then
			truthy(p.pos.y + p.size.y / 2 < b.y - b.h / 2, p.name .. " under the board")
		end
	end
end)

test("the board says whose cars and how many", function()
	local top, bottom = P.words("Carter", 12)
	eq(top, "CARTER'S CARS")
	eq(bottom, "12 / " .. #P.ALL)
end)
