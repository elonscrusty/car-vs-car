--!strict
-- Car VS Car Smash: builds the WARM-UP YARD (WarmupYard) where kids waiting for the next round
-- drive, and runs its own set of "?" boxes (BoxServer "WarmupBoxes", the weapon through
-- WeaponServer.give). Only with Features.SMASH on. No score and no coins here. Target dummies
-- (BOTS) join once they're in the game; MatchRunner moves waiting players in and out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local WarmupYard = require(ReplicatedStorage.Shared.WarmupYard)

if not (Features.CVC and Features.SMASH) then
	return
end

WarmupYard.build(workspace)

-- a module next to this script, or nil while it isn't in the game yet
local function optional(name: string): any
	local m = script.Parent:FindFirstChild(name)
	return if m and m:IsA("ModuleScript") then require(m) :: any else nil
end

local BoxServer = optional("BoxServer")
local WeaponServer = optional("WeaponServer")
local Weapons = ReplicatedStorage.Shared:FindFirstChild("Weapons")
local weaponList: any = if Weapons and Weapons:IsA("ModuleScript") then require(Weapons) else nil

-- the karts driving in the yard: players whose car (workspace Car_<UserId>) is inside it
local function karts(): { { id: any, position: Vector3, alive: boolean } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and (car :: Model).PrimaryPart
		if body then
			local p = body.Position
			if WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z }) then
				table.insert(out, { id = player.UserId, position = p, alive = true })
			end
		end
	end
	return out
end

if BoxServer and WeaponServer then
	local spots = {}
	for _, s in WarmupYard.BOXES do
		local w = WarmupYard.world(s)
		table.insert(spots, Vector3.new(w.x, w.y, w.z))
	end
	BoxServer.start({
		name = "WarmupBoxes",
		spots = spots,
		karts = karts,
		give = WeaponServer.give,
		has = if weaponList and weaponList.get
			then function(name: string): boolean
				return weaponList.get(name) ~= nil
			end
			else nil,
		parent = workspace,
	})
else
	warn("[WarmupYard] no BoxServer / WeaponServer yet: the yard has no boxes")
end
