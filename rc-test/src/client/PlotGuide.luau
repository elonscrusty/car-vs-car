--!strict
-- Always shows what to do next, on this player's screen only (carter's pick #2): one goal from
-- NextGoal (drive your track, go shop when the next unlock is yours, build in the break) as 1-2
-- words at the bottom, and glowing arrows on the road to where that goal is (your plot's pad or
-- the spawn lobby shops; a wave of light runs along them). Hidden while driving or building.
-- The shop goal comes from the NEXT box (Stars.client sets the local GoalReady attribute).
-- Looks only (no collide, query or touch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CvcGoal = require(ReplicatedStorage.Shared.CvcGoal)
local Features = require(ReplicatedStorage.Shared.Features)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local JoinStage = require(ReplicatedStorage.Shared.JoinStage)
local StageGate = require(script.Parent.StageGate)
local CvcState = require(script.Parent.CvcState)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local NextGoal = require(ReplicatedStorage.Shared.NextGoal)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local SpawnLobby = require(ReplicatedStorage.Shared.SpawnLobby)

export type PlotGuide = {
	setSlot: (slot: number) -> (),
	setDriving: (on: boolean) -> (),
	hold: (seconds: number) -> (),
}

local PlotGuide = {}

local COLOR = Color3.fromRGB(255, 220, 60)
local STEP = 8 -- road studs between arrows
local ARM = 2.2
local NEAR = 14 -- this close to the pad: the arrows have done their job

-- one ">" on the floor at (x, z) pointing along (dx, dz)
local function chevron(parent: Instance, x: number, z: number, dx: number, dz: number): { BasePart }
	local yaw = math.atan2(-dx, -dz) -- CFrame look direction
	local base = CFrame.new(x, 0.17, z) * CFrame.Angles(0, yaw, 0)
	local arms: { BasePart } = {}
	for _, side in { -1, 1 } do
		local p = Instance.new("Part")
		p.Name = "GuideArrow"
		p.Size = Vector3.new(0.5, 0.05, ARM)
		-- each arm leans back from the tip (local -z is forward)
		p.CFrame = base
			* CFrame.new(side * 0.7, 0, 0.75)
			* CFrame.Angles(0, side * math.rad(-40), 0)
		p.Color = COLOR
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = parent
		table.insert(arms, p)
	end
	return arms
end

function PlotGuide.new(): PlotGuide
	local player = Players.LocalPlayer
	local slot: number? = nil
	local driving = false
	local driven = false -- drove their own plot once: the guide is done
	local paths: { [string]: { model: Model, rows: { { BasePart } } } } = {} -- target -> arrows

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlotGuide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = HudLayout.HUD
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local line = Instance.new("TextLabel")
	line.Name = "Goal"
	HudLayout.place(line, "Goal")
	line.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	line.BackgroundTransparency = 0.25
	line.TextColor3 = COLOR
	line.Font = Enum.Font.LuckiestGuy
	line.TextScaled = true
	line.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = line
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = line
	-- a brand new player follows the road arrows: no words until the first lap (JoinStage)
	StageGate.hold(line, "help")

	-- arrows to your pad: down the middle of the road from the top, then across to the pad
	local function padPath(m: Model, s: LobbyLayout.Slot): { { BasePart } }
		local rows = {}
		local road = LobbyLayout.road()
		local z = road.minZ + 4
		while z < s.padZ - 6 do
			table.insert(rows, chevron(m, 0, z, 0, 1))
			z += STEP
		end
		local dir = if s.padX < 0 then -1 else 1
		local x = dir * 3
		while math.abs(x) < math.abs(s.padX) - 3 do
			table.insert(rows, chevron(m, x, s.padZ, dir, 0))
			x += dir * 3
		end
		return rows
	end
	-- arrows to the shops: from your pad across to the road, then up it to the spawn lobby
	local function shopPath(m: Model, s: LobbyLayout.Slot): { { BasePart } }
		local rows = {}
		local dir = if s.padX < 0 then 1 else -1 -- toward the road's middle
		local x = s.padX + dir * 3
		while math.abs(x) > 3 do
			table.insert(rows, chevron(m, x, s.padZ, dir, 0))
			x += dir * 3
		end
		local road = LobbyLayout.road()
		local z = s.padZ - 4
		while z > road.minZ - 6 do
			table.insert(rows, chevron(m, 0, z, 0, -1))
			z -= STEP
		end
		return rows
	end

	-- arrows out of each shop to the street (SpawnLobby.exitPath), where the pad path starts:
	-- after a buy, home is shown from the shop's own door, round the play pads
	local shopZ = LobbyLayout.PLAZA.maxZ - 36 -- the spawn lobby's origin (LobbyBuilder)
	local doors: { { model: Model, rows: { { BasePart } }, x: number, z: number } } = {}
	for i, d in SpawnLobby.DOORS do
		local m = Instance.new("Model")
		m.Name = "PlotGuideArrows"
		local rows = {}
		local pts = SpawnLobby.exitPath(i)
		for k = 1, #pts - 1 do
			local ax, az = pts[k][1], pts[k][2] + shopZ
			local bx, bz = pts[k + 1][1], pts[k + 1][2] + shopZ
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local dx, dz = (bx - ax) / len, (bz - az) / len
			local at = 0
			while at < len do
				table.insert(rows, chevron(m, ax + dx * at, az + dz * at, dx, dz))
				at += 3
			end
		end
		table.insert(doors, { model = m, rows = rows, x = d.x, z = d.z + shopZ })
	end

	-- Car VS Car: the same walk the other way, from the street in to the crate shop (it stands
	-- where the race shop was, DOORS[2]); gone once you've been there this visit
	local CRATE_DOOR = 2
	local crateDoor: { model: Model, rows: { { BasePart } } }? = nil
	local crateShopSeen = false
	if Features.CVC then
		local m = Instance.new("Model")
		m.Name = "PlotGuideArrows"
		local rows = {}
		local pts = SpawnLobby.exitPath(CRATE_DOOR)
		for k = #pts, 2, -1 do
			local ax, az = pts[k][1], pts[k][2] + shopZ
			local bx, bz = pts[k - 1][1], pts[k - 1][2] + shopZ
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local dx, dz = (bx - ax) / len, (bz - az) / len
			local at = 0
			while at < len do
				table.insert(rows, chevron(m, ax + dx * at, az + dz * at, dx, dz))
				at += 3
			end
		end
		crateDoor = { model = m, rows = rows }
	end

	local visitSlot: number? = nil -- whose pad paths.visit leads to
	local function build(s: LobbyLayout.Slot)
		for _, p in paths do
			p.model:Destroy()
		end
		paths = {}
		visitSlot = nil
		for name, make in { pad = padPath, shop = shopPath } do
			local m = Instance.new("Model")
			m.Name = "PlotGuideArrows"
			paths[name] = { model = m, rows = make(m, s) }
		end
	end

	-- the nearest plot with stars still to win for me (StarsAt from Stars.server, nearest first):
	-- its slot and owner's name, from stage 3 on (one new thing at a time)
	local function visitTarget(): (number?, string?)
		if not JoinStage.shows(player:GetAttribute("Stage"), "visit") then
			return nil, nil
		end
		local list = player:GetAttribute("StarsAt")
		local first = if type(list) == "string" then tonumber(string.match(list, "^%d+")) else nil
		local info = first and LobbyLayout.slots()[first]
		local plots = workspace:FindFirstChild("Plots")
		local m = info and plots and plots:FindFirstChild(first .. "_" .. info.id)
		local name = m and m:GetAttribute("OwnerName")
		if not (first and info and type(name) == "string" and name ~= "") or first == slot then
			return nil, nil
		end
		if first ~= visitSlot then
			visitSlot = first
			local old = paths.visit
			if old then
				old.model:Destroy()
			end
			local vm = Instance.new("Model")
			vm.Name = "PlotGuideArrows"
			paths.visit = { model = vm, rows = padPath(vm, info) }
		end
		return first, name
	end

	local function padDistance(): number
		local s = slot and LobbyLayout.slots()[slot]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (s and root and root:IsA("BasePart")) then
			return math.huge
		end
		local p = root.Position
		return math.sqrt((p.X - s.padX) ^ 2 + (p.Z - s.padZ) ^ 2)
	end

	local function inShops(): boolean
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return false
		end
		local p, b = root.Position, LobbyLayout.PLAZA
		return p.X >= b.minX and p.X <= b.maxX and p.Z >= b.minZ and p.Z <= b.maxZ
	end

	local function inBreak(): boolean
		local ends = workspace:GetAttribute("BuildEndsAt")
		return workspace:GetAttribute("BuildOpen") == true
			and type(ends) == "number"
			and ends > workspace:GetServerTimeNow()
	end

	-- A returning player already has stars (only driving gives them), so they skip FOLLOW THE
	-- ARROWS, like after a first drive this visit.
	local function returning()
		local stars = player:GetAttribute("Stars")
		if not driven and type(stars) == "number" and stars > 0 then
			driven = true
			player:SetAttribute("HasDriven", true)
		end
	end
	player:GetAttributeChangedSignal("Stars"):Connect(returning)
	returning()

	-- the tycoon plan: plots are garages, races are on the maps (JOIN RACE pad at the spawn)
	local tycoonOn = true
	local seenGarage = false

	-- the goal is picked 10 times a second (new tables each pick); the arrows glow every frame
	local goal: NextGoal.Goal? = nil
	local nextPick = 0
	local holdUntil = 0
	local wasOnFoot = false
	RunService.RenderStepped:Connect(function()
		local ends = workspace:GetAttribute("BuildEndsAt")
		local clock = os.clock()
		local onFoot = not driving and clock >= holdUntil
		local root0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if clock >= nextPick or onFoot ~= wasOnFoot then
			nextPick, wasOnFoot = clock + 0.1, onFoot
			local _, visitName = visitTarget()
			local near = padDistance() < NEAR
			if near then
				seenGarage = true
			end
			local pile = player:GetAttribute("PlotCoins")
			local raceSlot = workspace:GetAttribute("RaceSlot")
			-- Car VS Car: JOIN and the crate button get CvcHowTo's arrow on the button; the walk to
			-- the crate shop gets road arrows here
			if goal and goal.target == "crateshop" and root0 and root0:IsA("BasePart") then
				local d = SpawnLobby.DOORS[CRATE_DOOR]
				local far = (root0.Position.X - d.x) ^ 2 + (root0.Position.Z - (d.z + shopZ)) ^ 2
				crateShopSeen = far < 10 * 10
			end
			local coins = player:GetAttribute("Coins")
			goal = if onFoot and Features.CVC
				then CvcGoal.pick({
					picked = player:GetAttribute("Picked") == true,
					stage = player:GetAttribute("Stage") :: any,
					crates = CvcState.crates,
					coins = if type(coins) == "number" then coins else 0,
					shopSeen = crateShopSeen,
				})
				elseif onFoot then NextGoal.pick({
					hasPlot = slot ~= nil,
					driven = driven or player:GetAttribute("HasDriven") == true,
					nearPad = near,
					inShops = inShops(),
					inBreak = inBreak(),
					canBuy = player:GetAttribute("GoalReady") == true,
					built = false,
					-- (building closes CALL s before the start: count to the start, like the
					-- NEXT RACE chip)
					raceIn = if type(ends) == "number"
						then ends + ServerRace.CALL - workspace:GetServerTimeNow()
						else nil,
					visit = visitName,
					tycoon = tycoonOn,
					seenGarage = seenGarage,
					pile = if type(pile) == "number" then pile else 0,
					joinOpen = #RaceMaps.NAMES > 0 and (raceSlot == nil or raceSlot == 0),
					joined = player:GetAttribute("RaceJoined") == true,
				})
				else nil
			-- (the JOIN and crate words are already by their buttons: CvcHowTo)
			gui.Enabled = goal ~= nil and goal.target ~= "join" and goal.target ~= "crate"
			if goal then
				line.Text = goal.text
			end
		end
		local t = clock * 5
		-- in the shops with home to go to: the way out from the nearest shop door first
		local door: number? = nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if goal and goal.target == "pad" and root and root:IsA("BasePart") and inShops() then
			local best = math.huge
			for i, d in doors do
				local far = (root.Position.X - d.x) ^ 2 + (root.Position.Z - d.z) ^ 2
				if far < best then
					best, door = far, i
				end
			end
		end
		for i, d in doors do
			local want: Instance? = if i == door then workspace else nil
			if d.model.Parent ~= want then
				d.model.Parent = want
			end
			if i == door then
				for k, arms in d.rows do
					local glow = 0.5 + 0.5 * math.sin(t - k * 0.7)
					for _, p in arms do
						p.Transparency = 0.55 - glow * 0.5
					end
				end
			end
		end
		-- to the crate shop: up the road to the spawn, then in at its door
		local toCrates = goal ~= nil and goal.target == "crateshop"
		if crateDoor then
			local want: Instance? = if toCrates then workspace else nil
			if crateDoor.model.Parent ~= want then
				crateDoor.model.Parent = want
			end
			if toCrates then
				for k, arms in crateDoor.rows do
					local glow = 0.5 + 0.5 * math.sin(t - k * 0.7)
					for _, p in arms do
						p.Transparency = 0.55 - glow * 0.5
					end
				end
			end
		end
		for name, path in paths do
			local show = goal ~= nil
				and (goal.target == name or (toCrates and name == "shop" and not inShops()))
			local want: Instance? = if show then workspace else nil
			if path.model.Parent ~= want then
				path.model.Parent = want
			end
			if show then
				-- a wave of light running toward the goal
				for i, arms in path.rows do
					local glow = 0.5 + 0.5 * math.sin(t - i * 0.7)
					for _, p in arms do
						p.Transparency = 0.55 - glow * 0.5
					end
				end
			end
		end
	end)

	local guide = {} :: PlotGuide
	function guide.setSlot(s: number)
		if s ~= slot then
			slot = s
			local info = LobbyLayout.slots()[s]
			if info then
				build(info)
			end
		end
	end
	-- a drive is starting: no goal line for a moment (it sat over the road in the first frames)
	function guide.hold(seconds: number)
		holdUntil = os.clock() + seconds
	end
	function guide.setDriving(on: boolean)
		driving = on
		if on and padDistance() < NEAR * 2 then
			driven = true -- drove from their own pad
			player:SetAttribute("HasDriven", true)
		end
	end
	return guide
end

return PlotGuide
