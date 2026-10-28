--!strict
-- Race looks: sparks only on a real hit, never on braking or a bump.
local H = require("./harness")
local RaceLooks = require("../src/shared/RaceLooks")

local test, truthy = H.test, H.truthy

print("Race looks")

test("sparks: a wall stops the car in a frame; brakes and bumps don't", function()
	local s = 0.25 -- RC size
	truthy(RaceLooks.slammed(40, 8, s), "into a wall at speed")
	truthy(not RaceLooks.slammed(40, 39, s), "braking hard: about 1 stud/s a frame")
	truthy(not RaceLooks.slammed(4, 0, s), "a slow nudge is too small")
	truthy(not RaceLooks.slammed(40, 45, s), "speeding up")
end)

test("Car VS Car (playtest u01): the race car is your racer's toy car, not the grey box", function()
	local fs = require("@lune/fs")
	local Garage = require("../src/shared/Garage")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(string.find(main, "skin.update(car, skinName())", 1, true), "skin not used")
	truthy(string.find(main, "CarSkin.TOY .. id", 1, true), "no toy car for the racer")
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(string.find(skin, "Garage.toyCar(", 1, true), "not the plot's toy car")
	-- the toy car's four wheels sit one at each corner, so each gets its own name
	local pieces = {}
	Garage.toyCar(Garage.adder(pieces), "Car", { x = 0, y = 0, z = 0 }, 180, { 1, 2, 3 }, 1, "race")
	local corners: { [string]: number } = {}
	for _, p in pieces :: { any } do
		if p.name == "Wheel" then
			local k = (if p.pos.z > 0 then "F" else "R") .. (if p.pos.x < 0 then "R" else "L")
			corners[k] = (corners[k] or 0) + 1
		end
	end
	for _, k in { "FL", "FR", "RL", "RR" } do
		truthy(corners[k] == 1, `wheel {k}`)
	end
end)

test("skid marks (playtest u30, u12): one smooth fading ribbon, none on water", function()
	local fs = require("@lune/fs")
	local fx = fs.readFile("src/client/Effects.luau")
	truthy(string.find(fx, 'Instance.new("Trail")', 1, true), "marks are not a ribbon")
	truthy(not string.find(fx, 'p.Name = "Skid"', 1, true), "the old box marks are back")
	truthy(string.find(fx, "[Enum.Material.Water] = true", 1, true), "marks on water")
	truthy(string.find(fx, "[Enum.Material.Glass] = true", 1, true), "marks on puddles")
	local car = fs.readFile("src/client/RCCar.luau")
	truthy(
		string.find(car, "w.info.material = hit.Material", 1, true),
		"no material under the tyre"
	)
end)

test("boost pads (playtest u02): no glowing yellow pad that hides the car", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/RaceMapBuilder.luau")
	truthy(
		string.find(
			src,
			"boost = { color = rgb(225, 150, 40), mat = Enum.Material.SmoothPlastic }",
			1,
			true
		),
		"the pad glows again"
	)
end)

test("Car VS Car (phone 10-28 t096-t100): over the line, the car brakes to a stop", function()
	local fs = require("@lune/fs")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(
		string.find(main, "elseif grid and (raceDone ~= nil or raceOver) then", 1, true),
		"drives on"
	)
	truthy(
		string.find(main, "local rolling = car.telemetry.vLong > 3", 1, true),
		"backs up at a stop"
	)
end)

test("Car VS Car (playtest u01): race bots and other players wear toy cars, varied", function()
	local fs = require("@lune/fs")
	local CarCatalog = require("../src/shared/CarCatalog")
	local ids = CarCatalog.raceIds()
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		local c = CarCatalog.get(id)
		truthy(c and c.mode == "race", `{id} is a race car`)
		truthy(not seen[id], `{id} twice`)
		seen[id] = true
	end
	truthy(#ids >= 7, "enough looks for 7 bots")
	local bots = fs.readFile("src/server/RaceBotCars.luau")
	truthy(string.find(bots, 'model:SetAttribute("ToyCar", look)', 1, true), "bots wear no car")
	local others = fs.readFile("src/client/OtherCars.luau")
	truthy(string.find(others, "workspace:BulkMoveTo(toy.parts, at", 1, true), "no toy shell drawn")
	truthy(string.find(others, 'p.Name ~= "Wheel" and p.Name ~= "Hub"', 1, true), "parts per car")
end)

test(
	"Car VS Car (Studio after-818): a put-back lands on top of a jump ramp, not inside it",
	function()
		local fs = require("@lune/fs")
		local main = fs.readFile("src/client/Main.client.luau")
		truthy(
			string.find(main, "if hit and hit.Position.Y + clear > y then", 1, true),
			"no ramp check"
		)
		truthy(
			string.find(main, "probe.RespectCanCollide = true", 1, true),
			"lands on looks-only parts"
		)
	end
)

test("Car VS Car (Studio pr816 04b): the toy car is the grey body's size, within 10%", function()
	local fs = require("@lune/fs")
	local Garage = require("../src/shared/Garage")
	local bodyX, bodyY, bodyZ = 3, 1, 5.5 -- Tuning's big-size grey body
	local pieces = {}
	Garage.toyCar(
		Garage.adder(pieces),
		"Car",
		{ x = 0, y = 0, z = 0 },
		0,
		{ 1, 2, 3 },
		Garage.toyFit(bodyZ),
		"race"
	)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local body: any = nil
	for _, p in pieces :: { any } do
		if p.name ~= "Wheel" and p.name ~= "Hub" then
			minX, maxX =
				math.min(minX, p.pos.x - p.size.x / 2), math.max(maxX, p.pos.x + p.size.x / 2)
			minZ, maxZ =
				math.min(minZ, p.pos.z - p.size.z / 2), math.max(maxZ, p.pos.z + p.size.z / 2)
		end
		if p.name == "Body" then
			body = p
		end
	end
	local function near(a: number, b: number, what: string)
		truthy(math.abs(a - b) <= 0.1 * b, `{what}: {a} vs {b}`)
	end
	near(maxZ - minZ, bodyZ, "length")
	near(maxX - minX, bodyX, "width")
	near(body.size.x, bodyX, "body width")
	near(body.size.y, bodyY, "body height")
	-- both the own car's skin and other cars use that size
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(string.find(skin, "Garage.toyFit(Tuning.bodyZ)", 1, true), "own car sized by its wheels")
	local others = fs.readFile("src/client/OtherCars.luau")
	truthy(
		string.find(others, 'Garage.toyFit(base("bodyZ"))', 1, true),
		"other cars sized by wheels"
	)
end)

test("carter's own car model (CarSkins, named the car id) wins over the toy look", function()
	local fs = require("@lune/fs")
	local main = fs.readFile("src/client/Main.client.luau")
	truthy(
		string.find(main, "skins:FindFirstChild(id) then id else CarSkin.TOY .. id", 1, true),
		"own car"
	)
	local others = fs.readFile("src/client/OtherCars.luau")
	truthy(string.find(others, "modelShell(f, own, s) else nil", 1, true), "other cars")
	truthy(string.find(others, "toy or if id then toyShell", 1, true), "toy when no model")
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(string.find(skin, "HOW TO ADD A CAR MODEL", 1, true), "how-to line")
end)

test("Studio pr839: name tags that would sit on each other show only the nearest", function()
	local fs = require("@lune/fs")
	local others = fs.readFile("src/client/OtherCars.luau")
	truthy(
		string.find(others, "math.abs(p.X - q.X) < TAG_W and math.abs(p.Y - q.Y) < TAG_H", 1, true)
	)
	truthy(string.find(others, "while k > 1 and tagFar[k - 1] > far do", 1, true), "nearest first")
	truthy(string.find(others, "unstack(cam)", 1, true), "not wired")
	truthy(string.find(others, "UDim2.fromOffset(TAG_W, TAG_H)", 1, true))
end)
