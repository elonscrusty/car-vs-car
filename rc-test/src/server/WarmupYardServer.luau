--!strict
-- Car VS Car Smash: the WARM-UP YARD on the server (WarmupYard has the map). A player on the queue
-- for the next round (MatchQueued, set by MatchRunner.join from the SMASH! pad) with a while to wait
-- is put in the yard to drive: its own "?" boxes (BoxServer "WarmupBoxes", weapons through
-- WeaponServer.give), and target dummies (BOTS' ArenaBots.dummy) that pop when hit. No score, no
-- coins. At the round's start MatchRunner moves them into the arena (it walks them off the yard
-- first); leaving the queue walks them off here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local WarmupYard = require(ReplicatedStorage.Shared.WarmupYard)
local LobbyPlots = require(script.Parent.LobbyPlots)

local WarmupYardServer = {}

WarmupYardServer.STEP = 0.5

export type Hooks = {
	remote: RemoteEvent, -- RCControl: ("drive", slot, spot) puts a car on a spawn
	walk: (player: Player) -> (), -- off the yard, back to walking
}

-- a module next to this one, or nil while it isn't in the game yet
local function optional(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
		warn(`[WarmupYard] {name}: {mod}`)
	end
	return nil
end

local function bodyOf(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	return if car and car:IsA("Model") then car.PrimaryPart else nil
end

-- the karts driving in the yard: players whose car is inside it
local function yardKarts(): { { id: any, position: Vector3, cframe: CFrame, alive: boolean } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local body = bodyOf(player)
		if body then
			local p = body.Position
			if WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z }) then
				table.insert(
					out,
					{ id = player.UserId, position = p, cframe = body.CFrame, alive = true }
				)
			end
		end
	end
	return out
end

local function worldCFrame(at: any): CFrame
	local t = WarmupYard.track()
	local x, y, z = TrackData.toWorld(t, true, at.x, at.y, at.z)
	return CFrame.new(x, y, z)
end

function WarmupYardServer.start(hooks: Hooks)
	if not WarmupYard.on() then
		return
	end
	WarmupYard.build(workspace)
	local idx = LobbyLayout.yardIndex()

	-- "?" boxes, the weapon from WeaponServer
	local BoxServer = optional("BoxServer")
	local WeaponServer = optional("WeaponServer")
	if BoxServer and WeaponServer then
		local spots = {}
		for _, s in WarmupYard.boxSpots do
			local w = WarmupYard.world(s)
			table.insert(spots, Vector3.new(w.x, w.y, w.z))
		end
		BoxServer.start({
			name = "WarmupBoxes",
			spots = spots,
			karts = yardKarts,
			give = WeaponServer.give,
			has = WeaponServer.has,
			parent = workspace,
		})
	else
		warn("[WarmupYard] no BoxServer / WeaponServer: the yard has no boxes")
	end

	-- target dummies (BOTS), popped by weapons (WeaponServer source, WEAPONS)
	local dummies: { [any]: any } = {}
	local ArenaBots = optional("ArenaBots")
	if ArenaBots and type(ArenaBots.dummy) == "function" then
		local folder = Instance.new("Folder")
		folder.Name = "WarmupDummies"
		folder.Parent = workspace
		for _, d in WarmupYard.DUMMIES do
			local cf = worldCFrame(d.at) * CFrame.Angles(0, math.pi, 0) -- facing the spawns
			local ok, dummy = pcall(ArenaBots.dummy, folder, cf, d.mode, TrackData.RC_SCALE)
			if ok and dummy then
				dummies[dummy.id] = dummy
			else
				warn(`[WarmupYard] dummy: {dummy}`)
			end
		end
	end
	if WeaponServer and type(WeaponServer.addSource) == "function" then
		WeaponServer.addSource("WarmupYard", {
			karts = function()
				local out = {}
				for _, k in yardKarts() do
					table.insert(out, { id = k.id, cframe = k.cframe, alive = true })
				end
				for id, d in dummies do
					local m = d.model
					if m and m.Parent and not d.popped then
						table.insert(out, { id = id, cframe = m:GetPivot(), alive = true })
					end
				end
				return out
			end,
			-- practice: only the dummies take damage (no score, no coins)
			damage = function(victimId: any, _attackerId: any, amount: number, _weapon: string)
				local d = dummies[victimId]
				if d and type(amount) == "number" and amount > 0 then
					d:hit(amount)
				end
			end,
			model = function(id: any): Instance?
				local d = dummies[id]
				if d then
					return d.model
				end
				return workspace:FindFirstChild("Car_" .. tostring(id))
			end,
			playerOf = function(id: any): Player?
				return if type(id) == "number" and id > 0
					then Players:GetPlayerByUserId(id)
					else nil
			end,
		})
	end

	-- move waiting players into the yard, and off it when they leave the queue
	local spot = 0
	task.spawn(function()
		while true do
			task.wait(WarmupYardServer.STEP)
			local now = workspace:GetServerTimeNow()
			local endsAt = workspace:GetAttribute("MatchEndsAt")
			local nextAt = workspace:GetAttribute("NextMatchAt")
			for _, p in Players:GetPlayers() do
				local want = WarmupYard.wants(
					p:GetAttribute("MatchQueued") == true,
					p:GetAttribute("InMatch") == true,
					if type(endsAt) == "number" then endsAt else nil,
					if type(nextAt) == "number" then nextAt else nil,
					now
				)
				local here = LobbyPlots.drivingOf(p) == idx
				if want and not here and LobbyPlots.drivingOf(p) == nil then
					spot = spot % #WarmupYard.spawns + 1
					local s = WarmupYard.spawns[spot]
					LobbyPlots.claim(p, idx)
					task.spawn(function()
						-- (StreamingEnabled: the yard must be there before the car lands on it)
						local w = WarmupYard.world(s)
						pcall(function()
							p:RequestStreamAroundAsync(Vector3.new(w.x, w.y, w.z), 3)
						end)
						if p.Parent and LobbyPlots.drivingOf(p) == idx then
							hooks.remote:FireClient(
								p,
								"drive",
								idx,
								{ x = s.x, y = s.y, z = s.z, dx = s.dx, dz = s.dz }
							)
						end
					end)
				elseif here and not want and p:GetAttribute("InMatch") ~= true then
					hooks.walk(p)
				end
			end
		end
	end)
end

return WarmupYardServer
