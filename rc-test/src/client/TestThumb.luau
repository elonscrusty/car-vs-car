--!strict
-- Studio-only "test thumb" (shared/ThumbBrain has the rules): when on, it takes over the stick
-- in Main's input step (the same RCCar.Input the touch stick gives) and presses the same FIRE
-- the button does (MatchHud's fire, through TestThumb.onFire). Off unless BOTH this is Studio
-- AND workspace attribute TestThumb = true, so it can never run in a live game.
-- Studio: workspace:SetAttribute("TestThumb", true)   (false or nil = your own thumbs again)
-- It writes to the Output: "[TestThumb] match start", "first smash at N s", each hit taken, and at
-- each ROUND OVER "round over: smashes N, place P/T, ..." plus two lines of counters.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchEnd = require(ReplicatedStorage.Shared.MatchEnd)
local ThumbBrain = require(ReplicatedStorage.Shared.ThumbBrain)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local TestThumb = {}

local player = Players.LocalPlayer
local brain: ThumbBrain.State? = nil
local fireFns: { () -> () } = {}
-- the gun's and freeze ray's aim help (server/weapons/Gun: AIM_DEG, RANGE = 160 * 0.25)
local GUN_LOCK_DEG = 25
local GUN_RANGE = 40
local SETTLE = 2.5 -- s after a round start or respawn before the stuck/speed counters run

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

-- the other live karts, as Weapons targets (id, pos)
local function kartList(): { { id: number, pos: Vector3 } }
	local out = {}
	local mine = "Car_" .. player.UserId
	for _, m in workspace:GetChildren() do
		local id = string.match(m.Name, "^Car_(%-?%d+)$")
		if id and m.Name ~= mine and m:IsA("Model") and m.PrimaryPart and alive(id) then
			table.insert(out, { id = tonumber(id) :: number, pos = m.PrimaryPart.Position })
		end
	end
	return out
end

-- ===== the Output log (Studio copies it for the auditor) =====
-- Each round: "match start" when it starts, then at ROUND OVER (MatchResult) the round's report
-- (ThumbBrain.report: place from the end screen's own list, boxes, shots, lock-ons, hits, speed,
-- stuck and flipped time). Leaving mid round prints the report so far.
local myId = player.UserId
local log = { startAt = nil :: number?, firstAt = nil :: number?, smashes = 0 }
local tally = ThumbBrain.tally()
local nextAt: number? = nil -- the server time the next round starts (from MatchResult)
local lastHealth: number? = nil
local lastPlace: number? = nil
local lastAmmo: number? = nil
local held: string? = nil -- the weapon in hand (the server blanks Weapon before the last shot's Ammo)
local pickedAt = -math.huge -- (a pickup sets Weapon and Ammo: count it once)
local settleUntil = 0 -- no driving samples until then (a round start or a respawn: frozen, then moved)
local lastPos: Vector3? = nil
local lastTarget: ThumbBrain.Point? = nil -- where the thumb was heading last frame
local catchSpot: (kind: string, body: BasePart, pos: Vector3) -> ()
local lastAt = 0
local function say(text: string)
	print("[TestThumb] " .. text)
end
-- a box: Weapon and Ammo both change on a pickup (or only one of them, for the same weapon
-- again or the same ammo count), so the two within a moment count once
local function picked(w: string)
	local now = os.clock()
	if now - pickedAt > 0.2 then
		tally.boxes += 1
		table.insert(tally.weapons, w)
	end
	pickedAt = now
end

local function startRound()
	log = { startAt = os.clock(), firstAt = nil, smashes = 0 }
	tally = ThumbBrain.tally()
	nextAt, lastHealth, lastPlace, lastAmmo, lastPos, held = nil, nil, nil, nil, nil, nil
	lastTarget = nil
	settleUntil = os.clock() + SETTLE
	if brain then
		ThumbBrain.calm(brain)
	end
	say("match start")
end
local function endRound(smashes: number, place: number, total: number)
	for _, line in ThumbBrain.report(tally, smashes, place, total, log.firstAt) do
		say(line)
	end
	log.startAt = nil
end
player:GetAttributeChangedSignal("Place"):Connect(function()
	local p = player:GetAttribute("Place")
	if type(p) == "number" then
		lastPlace = p
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if not TestThumb.on() then
		return
	end
	if player:GetAttribute("InMatch") == true then
		startRound()
	elseif log.startAt then
		say("left mid round")
		endRound(log.smashes, lastPlace or 0, 0)
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
		tally.hitsTaken += 1
		say(string.format("hit: health %d at %.1f s", hp, os.clock() - log.startAt))
	elseif lastHealth and hp > lastHealth then
		lastPos = nil -- (respawned somewhere else: not a put back)
		tally.stuckRun, tally.flipRun = 0, 0
		settleUntil = os.clock() + SETTLE
	end
	lastHealth = hp
end)
player:GetAttributeChangedSignal("Weapon"):Connect(function()
	local w = player:GetAttribute("Weapon")
	if TestThumb.on() and log.startAt and type(w) == "string" and w ~= "" then
		held = w
		picked(w)
	end
end)

local function karts(): { ThumbBrain.Point }
	local out = {}
	for _, k in kartList() do
		table.insert(out, { x = k.pos.X, z = k.pos.Z })
	end
	return out
end

-- the server took a shot (ammo down by one while alive; a round end or a smash empties it in
-- one go): was a kart in the weapon's lock cone right then? Ammo going up = a box.
player:GetAttributeChangedSignal("Ammo"):Connect(function()
	local ammo = player:GetAttribute("Ammo")
	if not (TestThumb.on() and log.startAt and type(ammo) == "number") then
		return
	end
	local was = lastAmmo
	lastAmmo = ammo
	if ammo > (was or 0) then
		local w = player:GetAttribute("Weapon")
		picked(if type(w) == "string" and w ~= "" then w else held or "?")
		return
	end
	local hp = player:GetAttribute("Health")
	if not (was and ammo == was - 1 and type(hp) == "number" and hp > 0) then
		return
	end
	tally.shots += 1
	local car = workspace:FindFirstChild("Car_" .. myId)
	local body = car and car:IsA("Model") and car.PrimaryPart
	local w = held
	if not body or w == nil or w == "Mine" then
		return -- (a mine drops behind: no aim)
	end
	local flight = Weapons.FLIGHTS[w :: any]
	local deg = if flight then flight.seekDeg else GUN_LOCK_DEG
	local range = if flight then flight.seekRange else GUN_RANGE
	local list = kartList()
	local nose = body.CFrame.LookVector
	local cam = workspace.CurrentCamera
	local aim = Weapons.aim(if cam then cam.CFrame.LookVector else nose, nose)
	if Weapons.cone(body.Position, aim, list, deg, range, myId) then
		tally.locked += 1
	end
	if Weapons.cone(body.Position, nose, list, deg, range, myId) then
		tally.lockedNose += 1
	end
end)

local function onRemote(name: string, fn: (RemoteEvent) -> ())
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		fn(r)
		return
	end
	local conn: RBXScriptConnection
	conn = ReplicatedStorage.ChildAdded:Connect(function(c)
		if c.Name == name and c:IsA("RemoteEvent") then
			conn:Disconnect()
			fn(c)
		end
	end)
end
if RunService:IsStudio() then -- (never listens in a live game)
	onRemote("MatchResult", function(r)
		r.OnClientEvent:Connect(function(places, coins, at, xp)
			if not (TestThumb.on() and log.startAt) then
				return
			end
			local view = MatchEnd.read(places, coins, at, xp, myId)
			endRound(view.smashes, view.place, view.total)
			nextAt = view.nextAt or workspace:GetServerTimeNow() + MatchEnd.AUTO
		end)
	end)
	onRemote(Weapons.FX_REMOTE, function(r)
		r.OnClientEvent:Connect(function(kind, data)
			if TestThumb.on() and log.startAt and ThumbBrain.isHit(kind, data, myId) then
				tally.hits += 1
			end
		end)
	end)
end

-- What the kart is touching: the nose first (a wall, a rock), else what's under it (a ramp).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function touching(body: BasePart): string
	local skip: { Instance } = { body }
	local car = workspace:FindFirstChild("Car_" .. myId)
	if car then
		table.insert(skip, car)
	end
	if player.Character then
		table.insert(skip, player.Character)
	end
	rayParams.FilterDescendantsInstances = skip
	local cf = body.CFrame
	local flatLook = cf.LookVector * Vector3.new(1, 0, 1)
	local tries = {
		if flatLook.Magnitude > 0.1 then flatLook.Unit * 2.5 else cf.LookVector * 2.5,
		-cf.LookVector * 2.5,
		cf.RightVector * 2,
		-cf.RightVector * 2,
		Vector3.new(0, -3, 0),
	}
	for _, dir in tries do
		local hit = workspace:Raycast(cf.Position, dir, rayParams)
		if hit then
			local inst = hit.Instance
			local parent = inst.Parent
			local where = if parent and parent ~= workspace then parent.Name .. "." else ""
			return where .. inst.Name
		end
	end
	return "nothing"
end

-- A stuck or flip moment: Output line with where, what it touched and where its target was.
catchSpot = function(kind: string, body: BasePart, pos: Vector3)
	local what = touching(body)
	local look = body.CFrame.LookVector * Vector3.new(1, 0, 1)
	local off = 0
	if lastTarget and look.Magnitude > 1e-3 then
		local u = look.Unit
		off = ThumbBrain.angle({ x = pos.X, z = pos.Z, fx = u.X, fz = u.Z }, lastTarget)
	end
	local straight = math.abs(off) <= ThumbBrain.STRAIGHT
	ThumbBrain.spot(tally, kind, pos.X, pos.Z, what, straight)
	say(
		string.format(
			"%s at (%.0f, %.0f) touching %s, target %.0f deg off the nose, %.1f s",
			kind,
			pos.X,
			pos.Z,
			what,
			math.deg(off),
			os.clock() - (log.startAt or os.clock())
		)
	)
end

-- The stick this frame: the thumb's when it's on and you're in a match, else `input` unchanged.
function TestThumb.drive(body: BasePart, input: any): any
	if player:GetAttribute("InMatch") ~= true or (player:GetAttribute("Health") or 0) <= 0 then
		lastPos = nil
		tally.stuckRun, tally.flipRun = 0, 0 -- (smashed: a new moment after the respawn)
		if brain then
			ThumbBrain.calm(brain)
		end
		return input
	end
	-- (rounds roll on with InMatch staying true; also turned on mid round)
	if not log.startAt and (nextAt == nil or workspace:GetServerTimeNow() >= nextAt) then
		startRound()
	end
	local now = os.clock()
	local pos = body.Position
	if now < settleUntil then
		lastPos = nil -- (still frozen or about to be moved to a spawn)
		tally.stuckRun, tally.flipRun = 0, 0
	elseif log.startAt and lastPos then
		local d = (pos - lastPos) * Vector3.new(1, 0, 1)
		local events = ThumbBrain.sample(tally, now - lastAt, d.Magnitude, body.CFrame.UpVector.Y)
		for _, event in events or {} do
			catchSpot(event, body, pos)
		end
	end
	lastPos, lastAt = pos, now
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
	local out = ThumbBrain.step(b, now, {
		x = body.Position.X,
		z = body.Position.Z,
		fx = look.X,
		fz = look.Z,
		-- (frozen at a round start or a respawn: no speed, so no back-up while it can't move)
		speed = if now < settleUntil
			then nil
			else (body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
	}, boxes(), karts(), armed)
	lastTarget = out.target
	if out.fire then
		for _, fn in fireFns do
			task.spawn(fn)
		end
	end
	return { steer = out.steer, throttle = out.throttle, brake = out.brake, drift = false }
end

return TestThumb
