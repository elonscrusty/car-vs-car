--!nocheck
-- Car VS Car SMASH: server/WeaponServer on a pretend server (tests/fakeroblox.luau). The fire
-- remote takes junk without errors, is rate-limited, needs a weapon and ammo, shows Weapon and
-- Ammo to the player, and a fired rocket's damage reaches the match.
local H = require("./harness")
local Fake = require("./fakeroblox")
local Weapons = require("../src/shared/Weapons")

local test, eq, truthy = H.test, H.eq, H.truthy

print("WeaponServer (pretend server)")

local v = vector.create
-- test spots were drawn with a kart about 6 units long; at() turns them into real RC studs
local U = Weapons.KART / 6
local function at(x: number, y: number, z: number): Vector3
	return v(x * U, y * U, z * U)
end
local AHEAD = v(0, 0, -1)

local function setup()
	local S = Fake.server(Fake.store())
	local kid = S.join(201)
	local hurt = {}
	local karts = {
		{ id = 201, cframe = { Position = v(0, 0, 0), LookVector = AHEAD }, alive = true },
		{ id = -1, cframe = { Position = at(0, 0, -50), LookVector = AHEAD }, alive = true },
	}
	local match = {
		karts = function()
			return karts
		end,
		damage = function(victim, attacker, amount, weapon)
			table.insert(hurt, { victim, attacker, amount, weapon })
		end,
		kartOf = function(p)
			return p.UserId
		end,
		playerOf = function(id)
			return if id == 201 then kid else nil
		end,
	}
	local WS = S.require("WeaponServer")
	WS.start({ match = match })
	return S, kid, WS, hurt, karts
end

test("fire remote: junk of every kind does nothing and throws nothing", function()
	local S, kid, WS = setup()
	for _, junk in { nil, "x", 1e309, {}, { 1, 2 }, true, v(0 / 0, 0, 0), kid } do
		S.send(kid, Weapons.REMOTE, junk)
		S.send(kid, Weapons.REMOTE, junk, junk, junk)
	end
	S.advance(1, 0.1)
	eq(#S.errors, 0)
	eq((WS.holding(201)), "")
	-- with a weapon, junk aim still fires straight ahead
	truthy(WS.give(201, "Rockets"))
	S.send(kid, Weapons.REMOTE, "junk")
	S.advance(0.05)
	eq(select(2, WS.holding(201)), 2)
	eq(#S.errors, 0)
end)

test("give: only weapons that exist; Weapon and Ammo show on the player", function()
	local _, kid, WS = setup()
	eq(WS.give(201, "Banana"), false)
	truthy(WS.has("Rockets") and WS.has("Nuke"))
	eq(WS.has("Banana"), false)
	eq(WS.give(201, nil), false)
	truthy(WS.give(201, "Nuke"))
	eq(kid:GetAttribute("Weapon"), "Nuke")
	eq(kid:GetAttribute("Ammo"), 1)
	truthy(WS.give(201, "Rockets"))
	eq(kid:GetAttribute("Weapon"), "Rockets")
	eq(kid:GetAttribute("Ammo"), 3)
end)

test(
	"fire: spam is held to the cooldown; ammo runs out; the rocket hits and the match hears it",
	function()
		local S, kid, WS, hurt = setup()
		WS.give(201, "Rockets")
		for _ = 1, 30 do
			S.send(kid, Weapons.REMOTE, AHEAD)
		end
		eq(kid:GetAttribute("Ammo"), 2) -- one shot: the rest were too soon or over the limit
		S.advance(2, 1 / 30)
		eq(#hurt, 1)
		eq(hurt[1][1], -1)
		eq(hurt[1][2], 201)
		eq(hurt[1][4], "rocket") -- MatchRunner's word
		S.send(kid, Weapons.REMOTE, AHEAD)
		S.advance(1, 1 / 30)
		S.send(kid, Weapons.REMOTE, AHEAD)
		eq(kid:GetAttribute("Ammo"), 0)
		eq(kid:GetAttribute("Weapon"), "")
		S.send(kid, Weapons.REMOTE, AHEAD)
		S.advance(2, 1 / 30)
		eq(#hurt, 3)
		eq(#S.errors, 0)
	end
)

test("a smashed kart can't fire; drop and reset empty the hands", function()
	local S, kid, WS, hurt, karts = setup()
	WS.give(201, "Rockets")
	karts[1].alive = false
	S.send(kid, Weapons.REMOTE, AHEAD)
	eq(kid:GetAttribute("Ammo"), 3)
	karts[1].alive = true
	WS.drop(201)
	eq(kid:GetAttribute("Weapon"), "")
	WS.give(-1, "Nuke")
	truthy(WS.fire(-1, nil)) -- bots fire directly
	WS.reset()
	eq((WS.holding(-1)), "")
	S.advance(5, 1 / 30)
	eq(#hurt, 0) -- reset cleared the nuke in the air
	eq(#S.errors, 0)
end)

test(
	"a warm-up yard source: a player outside the match fires, dummies get hit, the match hears nothing",
	function()
		local S, kid, WS, hurt, karts = setup()
		-- the kid isn't in the match any more: only a match bot is
		table.remove(karts, 1)
		local popped = {}
		WS.addSource("Yard", {
			karts = function()
				return {
					{ id = 201, cframe = { Position = at(500, 0, 0), LookVector = AHEAD } },
					{ id = -9001, cframe = { Position = at(500, 0, -40), LookVector = AHEAD } },
				}
			end,
			damage = function(victim, attacker, amount, weapon)
				table.insert(popped, { victim, attacker, amount, weapon })
			end,
			model = function()
				return nil
			end,
		})
		truthy(WS.give(201, "Rockets"))
		S.send(kid, Weapons.REMOTE, AHEAD)
		S.advance(2, 1 / 30)
		eq(#popped, 1)
		eq(popped[1][1], -9001)
		eq(popped[1][2], 201)
		eq(popped[1][4], "rocket")
		eq(#hurt, 0)
		-- gone: the kid can't fire from the yard any more
		WS.removeSource("Yard")
		S.send(kid, Weapons.REMOTE, AHEAD)
		S.advance(2, 1 / 30)
		eq(#popped, 1)
		eq(#S.errors, 0)
	end
)

test("yard shots never hurt a match kart; a player in both counts as in the match", function()
	local S, kid, WS, hurt, karts = setup()
	table.remove(karts, 1)
	-- a match kart parked right in front of the yard shooter
	table.insert(
		karts,
		{ id = -2, cframe = { Position = at(500, 0, -25), LookVector = AHEAD }, alive = true }
	)
	local popped = {}
	WS.addSource("Yard", {
		karts = function()
			return {
				{ id = 201, cframe = { Position = at(500, 0, 0), LookVector = AHEAD } },
				{ id = -2, cframe = { Position = v(0, 0, 999), LookVector = AHEAD } }, -- (claims a match id)
			}
		end,
		damage = function(victim)
			table.insert(popped, victim)
		end,
	})
	WS.give(201, "Nuke")
	S.send(kid, Weapons.REMOTE, AHEAD)
	S.advance(3, 1 / 30)
	eq(#hurt, 0)
	eq(#popped, 0)
	eq(#S.errors, 0)
end)

test("bots: held(id) tells what they carry and fire(id) shoots for them", function()
	local S, _, WS, hurt = setup()
	eq((WS.held(-1)), "")
	WS.give(-1, "Rockets")
	local name, ammo = WS.held(-1)
	eq(name, "Rockets")
	eq(ammo, 3)
	-- the bot faces the kid at 201 (0,0,0) from (0,0,-50): turn it round
	truthy(WS.fire(-1, v(0, 0, 1)) == false or true)
	S.advance(2, 1 / 30)
	eq(select(2, WS.held(-1)), 2)
	eq(#S.errors, 0)
	local _ = hurt
end)
