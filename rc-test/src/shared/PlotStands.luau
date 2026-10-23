--!strict
-- Your cars on show at your plot (carter's loop: "your cars sit on stands at your plot"). Three
-- round stands on the parking spot in each plot's front area; each car the owner has stands on
-- one, nose to the road. Plain numbers (Lune tests load this); PlotStandsBuilder makes the parts.
--
-- Plot-local, RC size (studs): x across the plot, +z toward the road, y up. The cars are the
-- shop's toy cars (Garage.SHOPS), named "<kind>:<index>" (e.g. "race:2").

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		local node: any = (script :: any).Parent
		for _, part in string.split(name, "/") do
			node = node[part]
		end
		return require(node)
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local Kit = sibling("Plots/Kit")

local PlotStands = {}

local S = 0.25 -- RC size (TrackData.RC_SCALE)
PlotStands.MAX = 3
PlotStands.TOP = 0.5 -- stand top above the plot floor
PlotStands.RADIUS = 2.2
PlotStands.CAR = 0.9 -- toy car size (times a 3.6-stud car)
-- The three stands, on the parking spot's bays (TrackBuilder: x = -w/2 + 72 + i*21, z = FRONT_Z+48)
PlotStands.SPOTS = {} :: { { x: number, z: number } }
for i = -1, 1 do
	table.insert(PlotStands.SPOTS, {
		x = (-Kit.WIDTH / 2 + 72 + i * 21) * S,
		z = (Kit.FRONT_Z + 48) * S,
	})
end

export type Car = { kind: string, index: number }

-- The cars someone has, from their "Cars" attribute ("race:1,drift:2"): known cars only, no
-- repeats, at most MAX. Nothing listed yet: the first car of `starter` (the plot's kind).
function PlotStands.parse(list: string?, starter: string): { Car }
	local out: { Car } = {}
	local seen: { [string]: boolean } = {}
	for _, item in string.split(list or "", ",") do
		local kind, n = string.match(item, "^%s*(%a+):(%d+)%s*$")
		local index = tonumber(n)
		local shop = kind and Garage.SHOPS[kind]
		if shop and index and shop.cars[index] and not seen[item] and #out < PlotStands.MAX then
			seen[item] = true
			table.insert(out, { kind = kind :: string, index = index })
		end
	end
	if #out == 0 and Garage.SHOPS[starter] then
		table.insert(out, { kind = starter, index = 1 })
	end
	return out
end

-- The stands (always) and the cars on them, as Garage pieces in plot-local RC studs.
function PlotStands.pieces(cars: { Car }): { Garage.Piece }
	local out: { Garage.Piece } = {}
	local add = Garage.adder(out)
	for i, spot in PlotStands.SPOTS do
		local d = PlotStands.RADIUS * 2
		add(
			"Stands",
			"Stand",
			{ x = PlotStands.TOP, y = d, z = d },
			{ x = spot.x, y = PlotStands.TOP / 2, z = spot.z },
			{ 60, 60, 66 },
			{ shape = "Cylinder", rot = { x = 0, y = 0, z = 90 } }
		)
		add(
			"Stands",
			"Ring",
			{ x = 0.1, y = d + 0.3, z = d + 0.3 },
			{ x = spot.x, y = 0.25, z = spot.z }, -- just above the parking spot (0.2)
			{ 255, 210, 63 },
			{
				shape = "Cylinder",
				rot = { x = 0, y = 0, z = 90 },
				material = "Neon",
				collide = false,
			}
		)
		local car = cars[i]
		if car then
			local shop = Garage.SHOPS[car.kind]
			Garage.toyCar(
				add,
				"Car" .. i,
				{ x = spot.x, y = PlotStands.TOP, z = spot.z },
				180, -- nose to the road (+z)
				shop.cars[car.index],
				PlotStands.CAR,
				shop.style
			)
		end
	end
	return out
end

return PlotStands
