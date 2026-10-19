--!strict
local H = require("./harness")
local Abilities = require("../src/shared/Abilities")
local AbilitiesConfig = require("../src/shared/AbilitiesConfig")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Abilities")

local RARITIES = { "Common", "Rare", "Epic", "Legendary" }
-- The one number that matters most for each kind of ability.
local MAIN: { [string]: string } = {
	dash = "dashForward",
	shield = "seconds",
	slam = "push",
	ram = "damageMult",
	magnet = "push",
	jump = "jumpSpeed",
}

test("the six abilities exist and every one is listed in Order", function()
	eq(#AbilitiesConfig.Order, 6)
	for _, id in { "Dash", "Shield", "Slam", "Ram", "Magnet", "Jump" } do
		truthy(table.find(AbilitiesConfig.Order, id), id)
		local a = Abilities.get(id)
		truthy(a ~= nil, id)
		eq((a :: any).id, id)
	end
end)

test("get and resolve reject bad ids and rarities", function()
	eq(Abilities.get("Nope"), nil)
	eq(Abilities.get(5), nil)
	eq(Abilities.get(nil), nil)
	eq(Abilities.resolve("Dash", "Mythic"), nil)
	eq(Abilities.resolve("Dash", nil), nil)
	eq(Abilities.resolve("Nope", "Common"), nil)
	eq(Abilities.forCar({ ability = "Dash" }), nil)
end)

test("Common is the plain config; resolve returns a copy", function()
	local base = AbilitiesConfig.Abilities.Slam
	local r = Abilities.resolve("Slam", "Common") :: any
	eq(r.push, base.push)
	eq(r.cooldown, base.cooldown)
	r.push = 1
	eq(AbilitiesConfig.Abilities.Slam.push, base.push)
end)

test("better rarity means stronger and ready sooner, for every ability", function()
	for _, id in AbilitiesConfig.Order do
		local key = MAIN[AbilitiesConfig.Abilities[id].kind]
		local prev: any = nil
		for _, rarity in RARITIES do
			local r = Abilities.resolve(id, rarity) :: any
			truthy(r ~= nil, id .. " " .. rarity)
			if prev then
				truthy(r[key] > prev[key], `{id} {rarity} {key}`)
				truthy(r.cooldown < prev.cooldown, `{id} {rarity} cooldown`)
			end
			prev = r
		end
	end
end)

test("ram bonus stays above 1 and grows only by its extra", function()
	local c = Abilities.resolve("Ram", "Common") :: any
	local l = Abilities.resolve("Ram", "Legendary") :: any
	local extra = AbilitiesConfig.Abilities.Ram.damageMult - 1
	H.near(c.damageMult, 1 + extra)
	H.near(l.damageMult, 1 + extra * AbilitiesConfig.Rarity.Legendary.power)
end)

test("every ability has sane numbers at every rarity", function()
	for _, id in AbilitiesConfig.Order do
		for _, rarity in RARITIES do
			local r = Abilities.resolve(id, rarity) :: any
			truthy(r.cooldown >= 2 and r.cooldown <= 20, `{id} {rarity} cooldown {r.cooldown}`)
			truthy(r.damageMult >= 1)
			truthy(r[MAIN[r.kind]] > 0, `{id} {rarity} main number`)
		end
	end
end)

test("forCar reads ability and rarity from car stats", function()
	local r = Abilities.forCar({ ability = "Jump", rarity = "Epic" }) :: any
	eq(r.kind, "jump")
	H.near(
		r.jumpSpeed,
		AbilitiesConfig.Abilities.Jump.jumpSpeed * AbilitiesConfig.Rarity.Epic.power
	)
end)
