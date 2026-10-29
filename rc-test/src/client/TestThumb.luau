--!strict
-- Studio-only "test thumb" (shared/ThumbBrain has the rules): when on, it takes over the stick
-- in Main's input step (the same RCCar.Input the touch stick gives) and presses the same FIRE
-- the button does (MatchHud's fire, through TestThumb.onFire). Off unless BOTH this is Studio
-- AND workspace attribute TestThumb = true, so it can never run in a live game.
-- Studio: workspace:SetAttribute("TestThumb", true)   (false or nil = your own thumbs again)
-- It writes to the Output: "[TestThumb] first smash at N s", each hit taken, and at the end of a
-- match "[TestThumb] match over: smashes N, place P, hits taken H, first smash N s".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ThumbBrain = require(ReplicatedStorage.Shared.ThumbBrain)

local TestThumb = {}

local player = Players.LocalPlayer
local brain: ThumbBrain.State? = nil
local fireFns: { () -> () } = {}

-- On right now? (checked every frame: the attribute can be flipped in a running test)
function TestThumb.on(): boolean
	return ThumbBrain.allowed(RunService:IsStudio(), workspace:GetAttribute(ThumbBrain.ATTR))
end

-- MatchHud hands over its FIRE (the button's own function, so the same checks run).
function TestThumb.onFire(fn: () -> ())
	table.insert(fireFns, fn)
end

local function alive(id: string): boolean
	local board = ReplicatedStorage:FindFirstChild("MatchBoard")
	local row = board and board:FindFirstChild(id)
	local hp = row and row:GetAttribute("Health")
	return type(hp) ~= "number" or hp > 0
end

local function boxes(): { ThumbBrain.Point }
	local out = {}
	for _, m in CollectionService:GetTagged("SmashBox") do
		local home = m:GetAttribute("Home")
		if m:GetAttribute("Up") == true and typeof(home) == "CFrame" then
			table.insert(out, { x = home.Position.X, z = home.Position.Z })
		end
	end
	return out
end

local function karts(): { ThumbBrain.Point }
	local out = {}
	local mine = "Car_" .. player.UserId
	for _, m in workspace:GetChildren() do
		local id = string.match(m.Name, "^Car_(%-?%d+)$")
		if id and m.Name ~= mine and m:IsA("Model") and m.PrimaryPart and alive(id) then
			local p = m.PrimaryPart.Position
			table.insert(out, { x = p.X, z = p.Z })
		end
	end
	return out
end

-- ===== the Output log (Studio copies it for the auditor) =====
local log = { startAt = nil :: number?, firstAt = nil :: number?, hits = 0, smashes = 0 }
local lastHealth: number? = nil
local lastPlace: number? = nil -- (the server clears Place before InMatch at the end)
player:GetAttributeChangedSignal("Place"):Connect(function()
	local p = player:GetAttribute("Place")
	if type(p) == "number" then
		lastPlace = p
	end
end)
local function say(text: string)
	print("[TestThumb] " .. text)
end
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if not TestThumb.on() then
		return
	end
	if player:GetAttribute("InMatch") == true then
		log = { startAt = os.clock(), firstAt = nil, hits = 0, smashes = 0 }
		lastHealth, lastPlace = nil, nil
		say("match start")
	elseif log.startAt then
		local place = lastPlace
		say(
			`match over: smashes {log.smashes}, place {tostring(place)}, hits taken {log.hits}, first smash {if log.firstAt
				then string.format("%.1f s", log.firstAt)
				else "none"}`
		)
		log.startAt = nil
	end
end)
player:GetAttributeChangedSignal("Smashes"):Connect(function()
	local n = player:GetAttribute("Smashes")
	if not (TestThumb.on() and log.startAt and type(n) == "number" and n > log.smashes) then
		return
	end
	log.smashes = n
	local at = os.clock() - log.startAt
	if not log.firstAt then
		log.firstAt = at
		say(string.format("first smash at %.1f s", at))
	end
	say(string.format("smashes %d at %.1f s", n, at))
end)
player:GetAttributeChangedSignal("Health"):Connect(function()
	local hp = player:GetAttribute("Health")
	if not (TestThumb.on() and log.startAt and type(hp) == "number") then
		return
	end
	if lastHealth and hp < lastHealth then
		log.hits += 1
		say(string.format("hit: health %d at %.1f s", hp, os.clock() - log.startAt))
	end
	lastHealth = hp
end)

-- The stick this frame: the thumb's when it's on and you're in a match, else `input` unchanged.
function TestThumb.drive(body: BasePart, input: any): any
	if player:GetAttribute("InMatch") ~= true or (player:GetAttribute("Health") or 0) <= 0 then
		return input
	end
	local b = brain
	if not b then
		b = ThumbBrain.new(Random.new())
		brain = b
	end
	local look = body.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		return input
	end
	look = look.Unit
	local ammo = player:GetAttribute("Ammo")
	local armed = type(player:GetAttribute("Weapon")) == "string"
		and type(ammo) == "number"
		and ammo > 0
	local out = ThumbBrain.step(b, os.clock(), {
		x = body.Position.X,
		z = body.Position.Z,
		fx = look.X,
		fz = look.Z,
	}, boxes(), karts(), armed)
	if out.fire then
		for _, fn in fireFns do
			task.spawn(fn)
		end
	end
	return { steer = out.steer, throttle = out.throttle, brake = 0, drift = false }
end

return TestThumb
