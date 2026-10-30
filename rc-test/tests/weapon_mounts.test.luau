--!strict
-- Click-on weapons (shared/WeaponMounts, shared/WeaponLooks, client/WeaponPart): the mounts fit any
-- car by fractions of its body, every weapon look is a small part list that sits on its mount and
-- stays on the car, and the gun's bullets leave from its barrel tip whatever the look.
local fs = require("@lune/fs")
local H = require("./harness")
local Mounts = require("../src/shared/WeaponMounts")
local Looks = require("../src/shared/WeaponLooks")
local Gun = require("../src/server/weapons/Gun")
local Weapons = require("../src/shared/Weapons")
local TrackData = require("../src/shared/TrackData")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("Weapon mounts")

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

-- the box a part fills (its corners turned, then moved to its spot): min and max on each axis
local function bounds(p: Looks.Part): (V, V)
	local lo, hi = { 1e9, 1e9, 1e9 }, { -1e9, -1e9, -1e9 }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local c =
					turn({ sx * p.size[1] / 2, sy * p.size[2] / 2, sz * p.size[3] / 2 }, p.rot)
				for i = 1, 3 do
					local v = c[i] + p.at[i]
					lo[i] = math.min(lo[i], v)
					hi[i] = math.max(hi[i], v)
				end
			end
		end
	end
	return lo, hi
end

test("weapon mounts: a roof and a front, as fractions of any body", function()
	eq(#Mounts.NAMES, 2, "two mounts")
	for _, name in Mounts.NAMES do
		truthy(Mounts.isMount(name), name)
		local p = Mounts.PLACE[name]
		truthy(math.abs(p.x) < 0.1, name .. " in the middle across")
		truthy(math.abs(p.z) < 0.5 and math.abs(p.y) <= 0.5, name .. " inside the body")
	end
	truthy(not Mounts.isMount("Trunk"), "no such mount")
	truthy(not Mounts.isMount(nil), "junk")
	eq(Mounts.PLACE.Roof.y, 0.5, "the roof mount sits on the top")
	truthy(Mounts.PLACE.Front.z > 0.2, "the front mount is toward the nose")
	truthy(Mounts.PLACE.Roof.z < Mounts.PLACE.Front.z, "roof behind the hood")
end)

test("weapon mounts: the spot follows the body's size and which way its nose faces", function()
	local a = Mounts.offset("Front", 4.9, 2.64, 9.9, 1)
	local b = Mounts.offset("Front", 4.9, 2.64, 9.9, -1)
	local small = Mounts.offset("Front", 2.45, 1.32, 4.95, 1)
	truthy(a and b and small, "offsets")
	if a and b and small then
		near(a.z, -b.z, 1e-9, "a turned-round body flips z")
		near(a.z, 3.2, 1e-6, "the preview car's hood spot")
		near(small.z, a.z / 2, 1e-9, "half the car, half the distance")
	end
	eq(Mounts.offset("Wing", 1, 1, 1, 1), nil, "not a mount")
	near(Mounts.scale(9.9), 1, 1e-9, "the preview car is full size")
	near(Mounts.scale(4.95), 0.5, 1e-9, "a half-size car carries a half-size weapon")
	eq(Mounts.scale(0), 1, "junk length")
end)

test("weapon looks: small part lists that sit on their mount and stay on the car", function()
	local n = 0
	for id, look in Looks.LOOKS do
		n += 1
		eq(look.id, id, "id")
		truthy(Mounts.isMount(look.mount), id .. " mount")
		truthy(
			#look.parts >= 10 and #look.parts <= 34,
			`{id}: {#look.parts} parts (phones move every one)`
		)
		truthy(#look.muzzles >= 1, id .. " has a muzzle")
		local maxZ, minZ = -1e9, 1e9
		for _, p in look.parts do
			truthy(Looks.COLORS[p.mat] ~= nil, `{id}: colour {p.mat}`)
			for i = 1, 3 do
				truthy(p.size[i] > 0 and p.size[i] < 4.5, `{id}: size of {p.name}`)
			end
			local lo, hi = bounds(p)
			truthy(lo[2] > -0.05, `{id}: {p.name} sinks into the car`)
			truthy(hi[2] < 3, `{id}: {p.name} too tall`)
			truthy(lo[1] > -2.45 and hi[1] < 2.45, `{id}: {p.name} wider than the car`)
			truthy(lo[3] > -3 and hi[3] < 5, `{id}: {p.name} hangs off the car`)
			maxZ = math.max(maxZ, hi[3])
			minZ = math.min(minZ, lo[3])
		end
		for _, m in look.muzzles do
			-- (the Mine Dropper throws its mines out of the back end)
			truthy(
				m[3] >= maxZ - 0.6 or m[3] <= minZ + 0.6,
				id .. " the shots leave from the weapon's end"
			)
		end
	end
	-- carter 10-29 22:43: the 3 gun looks; 23:02: Missile Rack, Flame Nozzle, Mine Dropper too
	eq(n, 6, "six looks to pick from")
end)

test("weapon looks: a weapon's own look is the default, a skin id swaps it", function()
	local own = Looks.forWeapon("Gun", nil)
	truthy(own ~= nil, "the Gun has a look")
	eq(own and own.id, "gatling", "the starter is the Roof Gatling")
	local skin = Looks.forWeapon("Gun", "nose")
	eq(skin and skin.mount, "Front", "a skin can sit on the other mount")
	eq(Looks.forWeapon("Gun", "nonsense") == own, true, "junk skin: the weapon's own look")
	eq(Looks.forWeapon("Nope", nil), nil, "a weapon with no look")
	eq(Looks.forWeapon(nil, nil), nil, "junk weapon")
end)

test("weapon looks: every weapon that has a part wears its own look by default", function()
	local want = { Gun = "gatling", Rockets = "rack", Flame = "flame", Mine = "dropper" }
	for weapon, id in want do
		local look = Looks.forWeapon(weapon, nil)
		eq(look and look.id, id, weapon .. " look")
		truthy(Weapons.isName(weapon), weapon .. " is a weapon")
	end
	eq(Looks.LOOKS.rack.mount, "Roof", "the rack rides the roof")
	eq(Looks.LOOKS.flame.mount, "Front", "the nozzle sits on the hood")
	eq(Looks.LOOKS.dropper.mount, "Roof", "the dropper rides the roof")
	-- the arm's parts are one rigid piece in the game: only the preview swings them
	local arms = 0
	for _, p in Looks.LOOKS.dropper.parts do
		if p.arm then
			arms += 1
		end
	end
	truthy(arms >= 4, "the throwing arm is marked")
end)

test("gun: bullets leave the barrel tip, the same for every look (looks only)", function()
	local kartLen = 5.5 * TrackData.RC_SCALE
	local look = Looks.forWeapon("Gun", nil)
	truthy(look ~= nil, "look")
	if look then
		local ahead, up = Mounts.muzzle(look.mount, look.muzzles[1])
		near(Gun.MUZZLE, ahead * kartLen, 1e-9, "muzzle ahead")
		near(Gun.HEIGHT, up * kartLen, 1e-9, "muzzle height")
		-- the Roof Gatling's barrel ends about a third of a kart ahead of the middle, above the roof
		truthy(ahead > 0.25 and ahead < 0.5, `ahead {ahead}`)
		truthy(up > 0.2 and up < 0.4, `up {up}`)
	end
end)

test(
	"weapon part: CarSkin readies every model with the starter weapon, welded on the body",
	function()
		local skin = fs.readFile("src/client/CarSkin.luau")
		truthy(skin:find("WeaponPart.addTo", 1, true), "CarSkin.prepare adds the weapon")
		truthy(skin:find('CarSkin.STARTER = "Gun"', 1, true), "the starter weapon")
		truthy(
			skin:find('GetAttribute("WeaponMount")', 1, true),
			"the skin carries the weapon parts"
		)
		local part = fs.readFile("src/client/WeaponPart.luau")
		truthy(part:find("WeaponMounts.offset", 1, true), "the spot comes from the body's size")
		truthy(part:find("FireDrake.noseSign", 1, true), "the nose is read from the wheels")
		truthy(part:find("WeldConstraint", 1, true), "the weapon is welded on")
		truthy(part:find("WeaponMount_", 1, true), "an attachment marks the saddle")
	end
)
