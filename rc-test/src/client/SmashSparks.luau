--!strict
-- Gold Burst (carter's pick A, 10-29): when YOU smash someone, hot gold sparks blast out of the
-- "SMASHED!" words in a ring, then fall like embers. Preview: match-screen/smashed/.
-- Looks only. A pool of small frames is made once; a smash only sets properties.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SmashJuice = require(Shared:WaitForChild("SmashJuice"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local player = Players.LocalPlayer

local SmashSparks = {}

local POOL = 120
local BURST = 70 -- fast streaks, thrown at once
local EMBERS = 40 -- slow dots, thrown 0.12 s later
local REDUCED = 24
local GRAVITY = 0.9 -- screen heights per second squared
local COLORS = {
	Color3.fromRGB(255, 251, 224),
	Color3.fromRGB(255, 233, 90),
	Color3.fromRGB(255, 196, 0),
	Color3.fromRGB(255, 154, 0),
	Color3.fromRGB(255, 106, 0),
}

type Spark = {
	frame: Frame,
	x: number,
	y: number,
	vx: number,
	vy: number,
	life: number,
	max: number,
	streak: boolean,
}

local started = false

function SmashSparks.start()
	if started then
		return
	end
	started = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "SmashSparks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19 -- under the words (SmashFx is 20)
	gui.Parent = player:WaitForChild("PlayerGui")

	local rng = Random.new()
	local sparks: { Spark } = {}
	for i = 1, POOL do
		local f = Instance.new("Frame")
		f.Name = "Spark" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = COLORS[(i - 1) % #COLORS + 1]
		f.Visible = false
		f.Parent = gui
		table.insert(
			sparks,
			{ frame = f, x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, streak = false }
		)
	end

	local live = 0
	local conn: RBXScriptConnection? = nil

	local function step(dt: number)
		local aspect = gui.AbsoluteSize.X / math.max(gui.AbsoluteSize.Y, 1)
		for _, s in sparks do
			if s.life > 0 then
				s.life -= dt
				if s.life <= 0 then
					s.frame.Visible = false
					live -= 1
				else
					s.vy += GRAVITY * dt
					s.x += s.vx * dt / aspect
					s.y += s.vy * dt
					s.frame.Position = UDim2.fromScale(s.x, s.y)
					if s.streak then
						s.frame.Rotation = math.deg(math.atan2(s.vy, s.vx * aspect))
					end
					s.frame.BackgroundTransparency = 1 - math.min(1, (s.life / s.max) * 1.6)
				end
			end
		end
		if live <= 0 and conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function throw(
		n: number,
		x: number,
		y: number,
		speed: { number },
		size: { number },
		streak: boolean
	)
		local thrown = 0
		for _, s in sparks do
			if thrown >= n then
				break
			end
			if s.life <= 0 then
				thrown += 1
				local a = rng:NextNumber(0, math.pi * 2)
				local v = rng:NextNumber(speed[1], speed[2])
				s.x, s.y = x, y
				s.vx, s.vy = math.cos(a) * v, math.sin(a) * v
				s.max = rng:NextNumber(0.8, 1.5)
				s.life = s.max
				s.streak = streak
				local px = rng:NextInteger(size[1], size[2])
				s.frame.Size = if streak
					then UDim2.fromOffset(px * 4, math.max(2, px))
					else UDim2.fromOffset(px, px)
				s.frame.Rotation = 0
				s.frame.BackgroundTransparency = 0
				s.frame.Position = UDim2.fromScale(x, y)
				s.frame.Visible = true
				live += 1
			end
		end
		if not conn then
			conn = RunService.RenderStepped:Connect(step)
		end
	end

	local spot = if Base.phone() then SmashJuice.WORDS_TOUCH else SmashJuice.WORDS

	local function burst()
		local y = spot.you.y
		if Base.reduced() then
			throw(REDUCED, 0.5, y, { 0.3, 0.7 }, { 2, 4 }, false)
			return
		end
		throw(BURST, 0.5, y, { 0.5, 1.2 }, { 2, 4 }, true)
		task.delay(0.12, function()
			throw(EMBERS, 0.5, y, { 0.2, 0.7 }, { 2, 4 }, false)
		end)
	end

	local function hook(remote: Instance)
		if remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(
				function(attacker: unknown, victim: unknown, weapon: unknown)
					local f = SmashJuice.read(attacker, victim, weapon, player.UserId)
					if f and f.attacker and f.attacker.me and not f.victim.me then
						burst()
					end
				end
			)
		end
	end
	local feed = ReplicatedStorage:FindFirstChild("SmashFeed")
	if feed then
		hook(feed)
	else
		local c: RBXScriptConnection
		c = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
			if child.Name == "SmashFeed" and child:IsA("RemoteEvent") then
				c:Disconnect()
				hook(child)
			end
		end)
	end
end

return SmashSparks
