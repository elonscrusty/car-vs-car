--!nocheck
-- Arena bots on a pretend server (tests/fakeroblox.luau): the real ArenaBots reads what a bot
-- holds from the real WeaponServer and fires through it, so a bot's rocket hits the match.
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")
local B = require("../src/shared/ArenaBrain")

local test, eq, truthy = H.test, H.eq, H.truthy

print("ArenaBots (pretend server)")

local v = vector.create

test("a bot with Rockets fires through WeaponServer and hits the kart ahead", function()
	local S = Fake.server(Fake.store())
	local hurt = {}
	-- bot -1 at the middle facing -z; the kid's kart 40 ahead of it
	local karts = {
		{ id = -1, cframe = { Position = v(0, 0, 0), LookVector = v(0, 0, -1) }, alive = true },
		{ id = 201, cframe = { Position = v(0, 0, -40), LookVector = v(0, 0, 1) }, alive = true },
	}
	local WS = S.require("WeaponServer")
	WS.start({
		match = {
			karts = function()
				return karts
			end,
			damage = function(victim, attacker, amount, weapon)
				table.insert(hurt, { victim, attacker, amount, weapon })
			end,
			kartOf = function(p)
				return p.UserId
			end,
			playerOf = function()
				return nil
			end,
		},
	})
	local Bots = S.require("ArenaBots")
	-- the match's side of ctx; weaponOf and fire are left to the real WeaponServer
	local fleet = Bots.new({
		karts = function()
			local out = {}
			for _, k in karts do
				local p = k.cframe.Position -- (the bots get real Vector3s, as in Roblox)
				table.insert(
					out,
					{ id = k.id, pos = roblox.Vector3.new(p.x, p.y, p.z), alive = k.alive }
				)
			end
			return out
		end,
		boxes = function()
			return {}
		end,
		place = function() end, -- (stays put: the shot is what's checked)
		toLocal = function(p)
			return p.X, p.Z
		end,
		toWorld = function(x, z)
			return roblox.Vector3.new(x, 0, z)
		end,
		world = { half = 170, solids = {}, boxes = {}, karts = {} },
	})
	Bots.add(fleet, -1, roblox.CFrame.new(0, 0, 0), { skill = 1 }) -- (facing -z)
	truthy(WS.give(-1, "Rockets"))
	local t = 0
	while t < 3 and select(2, WS.holding(-1)) == 3 do
		t += 1 / 30
		Bots.step(fleet, 1 / 30, t)
		S.advance(1 / 30, 1 / 30)
	end
	eq(select(2, WS.holding(-1)), 2) -- a shot went
	S.advance(2, 1 / 30)
	eq(#hurt, 1)
	eq(hurt[1][1], 201)
	eq(hurt[1][2], -1)
	eq(#S.errors, 0)
end)

test("a rookie (first 3 matches): bots fire at them far less often", function()
	local function run(rookie: boolean): (number, number)
		local S = Fake.server(Fake.store())
		local Bots = S.require("ArenaBots")
		local shots, close = 0, 0
		local fleet = Bots.new({
			karts = function()
				return {
					{ id = -1, pos = roblox.Vector3.new(0, 0, 0), alive = true },
					{
						id = 201,
						pos = roblox.Vector3.new(0, 0, -40),
						alive = true,
						human = true,
						rookie = rookie,
					},
				}
			end,
			weaponOf = function()
				return "Rockets", 3
			end,
			fire = function(_, aim)
				shots += 1
				if (aim - roblox.Vector3.new(0, 0, -40)).Magnitude < 6 then
					close += 1
				end
			end,
			boxes = function()
				return {}
			end,
			place = function() end,
			toLocal = function(p)
				return p.X, p.Z
			end,
			toWorld = function(x, z)
				return roblox.Vector3.new(x, 0, z)
			end,
			world = { half = 170, solids = {}, boxes = {}, karts = {} },
		}, B.rng(7))
		Bots.add(fleet, -1, roblox.CFrame.new(0, 0, 0), { skill = 1 })
		local t = 100
		while t < 160 do
			t += 1 / 30
			Bots.step(fleet, 1 / 30, t)
		end
		eq(#S.errors, 0)
		return shots, close
	end
	local vetShots, vetClose = run(false)
	local kidShots, kidClose = run(true)
	print(
		`       60 s at a kart ahead: a veteran gets {vetShots} shots ({vetClose} on target), a rookie {kidShots} ({kidClose})`
	)
	truthy(kidShots < vetShots * 0.5, "far fewer shots at a rookie")
	eq(vetClose, vetShots, "a sharp bot hits a veteran sitting still")
end)
