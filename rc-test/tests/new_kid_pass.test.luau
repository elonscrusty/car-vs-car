--!nocheck
-- Car VS Car SMASH: a new kid's first match on the real server scripts (auditor R4-1). A pretend
-- kid with no skill at all drives to the nearest "?" box and fires whenever a kart is in the
-- cone ahead of it. Against the real bots (ArenaBots: easy on a rookie) and the real weapons,
-- it must get 2+ smashes and a top-5 place in 8 of 10 seeded first matches.
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")

local test, truthy = H.test, H.truthy

print("Car VS Car SMASH: a no-skill new kid's first match")

local KID = 601
local BEAT = 0.05
local SPEED = 14 -- studs/s: a kid who holds the stick forward (an RC kart's top is about 24)
local CONE = math.rad(30) -- fires at any kart this close to straight ahead...
local REACH = 35 -- ...and this near (studs)

local function kid(S, player)
	local TrackData = S.require("Shared.TrackData")
	local LobbyLayout = S.require("Shared.LobbyLayout")
	local Weapons = S.require("Shared.Weapons")
	local MR = S.require("MatchRunner")
	local CollectionService = S.game:GetService("CollectionService")
	local seen, look = 0, roblox.Vector3.new(0, 0, -1)
	S.game:GetService("RunService").Heartbeat:Connect(function(dt)
		local car = S.workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and car.PrimaryPart
		if not body then
			return
		end
		local drives = S.got(player, "RCControl", "drive")
		if #drives > seen then
			seen = #drives
			local g = drives[#drives][4]
			if type(g) == "table" then
				local t = LobbyLayout.track(drives[#drives][3])
				body.CFrame = roblox.CFrame.new(TrackData.toWorld(t, true, g.x, g.y, g.z))
			end
		end
		body.AssemblyLinearVelocity = roblox.Vector3.zero
		if not (player:GetAttribute("InMatch") and (player:GetAttribute("Health") or 0) > 0) then
			return
		end
		local at = body.Position
		-- drive at the nearest box that's up
		local best, bestD = nil, math.huge
		for _, m in CollectionService:GetTagged("SmashBox") do
			local home = m:GetAttribute("Home")
			if m:GetAttribute("Up") == true and home then
				local d = (home.Position - at).Magnitude
				if d < bestD then
					best, bestD = home.Position, d
				end
			end
		end
		if best then
			local dir = (best - at) * roblox.Vector3.new(1, 0, 1)
			if dir.Magnitude > 0.2 then
				look = dir.Unit
				local step = math.min(SPEED * dt, dir.Magnitude)
				body.CFrame = roblox.CFrame.lookAt(at + look * step, at + look * (step + 1))
				body.AssemblyLinearVelocity = look * SPEED
			end
		end
		-- fire at whatever is in the cone ahead
		local w = player:GetAttribute("Weapon")
		if type(w) == "string" and w ~= "" then
			for _, k in MR.karts() do
				if k.id ~= player.UserId and k.alive and k.pos then
					local to = (k.pos - body.Position) * roblox.Vector3.new(1, 0, 1)
					local d = to.Magnitude
					if
						d > 0.1
						and d < REACH
						and math.acos(math.clamp(to.Unit:Dot(look), -1, 1)) < CONE
					then
						S.send(player, Weapons.REMOTE, look)
						break
					end
				end
			end
		end
	end)
end

local function firstMatch(seed: number): (number, number)
	local S = Fake.server(Fake.store(), { seed = seed, jobId = "newkid-" .. seed })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local p = S.join(KID)
	kid(S, p)
	S.advance(3, BEAT)
	S.send(p, "Garage", "pick", "race_bolt")
	S.advance(1, BEAT)
	MR.join(p)
	local t0 = S.now()
	while #S.got(p, "MatchResult") == 0 and S.now() - t0 < MR.MATCH_SECS + 30 do
		S.advance(1, BEAT)
	end
	local smashes, place = p:GetAttribute("Smashes") or 0, p:GetAttribute("Place") or 0
	S.close()
	return smashes, place
end

test("a no-skill kid's first match: 2+ smashes and top 5 in 8 of 10 runs", function()
	local good = 0
	for seed = 1, 10 do
		local smashes, place = firstMatch(seed)
		local ok = smashes >= 2 and place >= 1 and place <= 5
		if ok then
			good += 1
		end
		print(
			string.format(
				"       seed %d: %d smashes, place %d%s",
				seed,
				smashes,
				place,
				if ok then "" else "  <- miss"
			)
		)
	end
	print(string.format("       %d of 10 first matches pass", good))
	truthy(good >= 8, `{good} of 10`)
end)
