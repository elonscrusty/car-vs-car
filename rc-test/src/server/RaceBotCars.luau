--!strict
-- The bot cars of a map race (RaceBots has their pace): little RC cars the server drives round the
-- map's centre line so a lone player still has a race. Each is a Car_<negative number> model, so
-- every screen draws its wheels and a name tag like another player's car (client OtherCars). The
-- body is moved by the server's own physics (align constraints), so screens see it move smoothly.
-- Bots never push anyone: nothing about them is solid. The player's car and its feel are not
-- touched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local RaceBots = require(ReplicatedStorage.Shared.RaceBots)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)

type Car = {
	bot: RaceBots.Bot,
	model: Model,
	body: BasePart,
	pos: Vector3,
	move: AlignPosition,
	turn: AlignOrientation,
}

export type Fleet = {
	track: TrackData.Track,
	route: RaceBots.Route,
	cars: { Car },
	hover: number, -- body height over the road (the players' spawn height over the road)
	ground: RaycastParams,
	last: number?, -- clock of the last step
	easy: boolean, -- a first race: no catch-up, and the bots wait for the kid (RaceBots.holds)
}

local RaceBotCars = {}

local random = Random.new()

local function worldCF(t: TrackData.Track, x: number, y: number, z: number, dx: number, dz: number)
	local wx, wy, wz = TrackData.toWorld(t, true, x, y, z)
	local ddx, ddz = TrackData.dirToWorld(t, true, dx, dz)
	local pos = Vector3.new(wx, wy, wz)
	return pos, CFrame.lookAt(pos, pos + Vector3.new(ddx, 0, ddz))
end

-- Car VS Car (Features.CVC): `league` (1..4) sets how good the bots are, `easy` = a new player's
-- first race (slow bots that wake up late), and the race is filled up to the whole grid.
export type Options = { league: number?, easy: boolean?, laps: number? }

-- Fill a map race: `humans` players are on grid spots 1..humans; the bots take the next spots up
-- to RaceBots.MIN_CARS cars (the whole grid in Car VS Car). nil when no bots are needed (or the
-- map has no road for them).
function RaceBotCars.spawn(
	t: TrackData.Track,
	humans: number,
	mapModel: Instance?,
	options: Options?
): Fleet?
	local map = if t.map then RaceMaps.get(t.map) else nil
	local opt: Options = options or {}
	local count =
		RaceBots.count(humans, ServerRace.MAX, if Features.CVC then ServerRace.MAX else nil)
	local easy = Features.CVC and opt.easy == true
	local lo, hi = RaceBots.skillRange(if Features.CVC then opt.league else nil, easy)
	if not map or count == 0 then
		return nil
	end
	local ok, route = pcall(function()
		return RaceBots.route(map.loop(), map.lineSample(), t.gates)
	end)
	if not ok then
		warn("race bots: " .. tostring(route))
		return nil
	end
	route.laps = opt.laps

	local ground = RaycastParams.new()
	ground.FilterType = Enum.RaycastFilterType.Include
	ground.FilterDescendantsInstances = if mapModel then { mapModel } else {}

	-- how high a car body rides over the road: as high as the players' spawn spot does
	local hover = 0
	if mapModel then
		local sx, sy, sz = TrackData.toWorld(t, true, t.spawn.x, t.spawn.y, t.spawn.z)
		local hit = workspace:Raycast(Vector3.new(sx, sy + 4, sz), Vector3.new(0, -40, 0), ground)
		hover = if hit then sy - hit.Position.Y else 0
	end

	local fleet: Fleet = {
		track = t,
		route = route,
		cars = {},
		hover = hover,
		ground = ground,
		last = nil,
		easy = easy,
	}
	local names = table.clone(RaceBots.NAMES)
	for i = 1, count do
		local k = humans + i
		local g = ServerRace.gridOn(map, k, t.spawn.y)
		local row = (k - 1) // 2
		local side = if k % 2 == 1 then -1 else 1
		local nm = table.remove(names, random:NextInteger(1, #names)) or `Bot {i}`
		local colors = RaceBots.COLORS
		local bot = RaceBots.new(
			route,
			`{nm} (bot)`,
			RaceBots.skillFor(i, count, random:NextNumber(), lo, hi),
			RaceBots.laneFor(i),
			side * ServerRace.GRID_SIDE,
			random:NextNumber() * 6.28,
			random:NextNumber() * 0.35 + (if easy then RaceBots.EASY_DELAY else 0),
			ServerRace.BACK + row * ServerRace.GRID_ROW,
			colors[random:NextInteger(1, #colors)]
		)
		local pos, cf = worldCF(t, g.x, g.y, g.z, g.dx, g.dz)
		local model = CarBuilder.build(`Car_-{i}`, cf, TrackData.RC_SCALE)
		model:SetAttribute("BotName", bot.name)
		local body = model.PrimaryPart :: BasePart
		body.Color = Color3.fromRGB(bot.color[1], bot.color[2], bot.color[3])
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		local att = Instance.new("Attachment")
		att.Name = "BotAttachment"
		att.Parent = body
		local move = Instance.new("AlignPosition")
		move.Mode = Enum.PositionAlignmentMode.OneAttachment
		move.Attachment0 = att
		move.ApplyAtCenterOfMass = true
		move.MaxForce = math.huge
		move.MaxVelocity = math.huge
		move.Responsiveness = 100
		move.Position = pos
		move.Parent = body
		local turn = Instance.new("AlignOrientation")
		turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
		turn.Attachment0 = att
		turn.MaxTorque = math.huge
		turn.MaxAngularVelocity = math.huge
		turn.Responsiveness = 100
		turn.CFrame = cf.Rotation
		turn.Parent = body
		model.Parent = workspace
		pcall(function()
			body:SetNetworkOwner(nil) -- the server drives it
		end)
		table.insert(fleet.cars, {
			bot = bot,
			model = model,
			body = body,
			pos = pos,
			move = move,
			turn = turn,
		})
	end
	return fleet
end

-- One frame. `clock` = os.clock(), `goAt` = the clock at GO, `lead` = the leading player's
-- ServerRace.progress (nil = none racing: no catch-up). Returns the number of bots that finished
-- on this step, so the caller can start the finish countdown.
function RaceBotCars.step(fleet: Fleet, clock: number, goAt: number, lead: number?): number
	local dt = math.clamp(clock - (fleet.last or clock), 0, 0.1)
	fleet.last = clock
	local since = clock - goAt
	local done = 0
	local t = fleet.track
	for _, car in fleet.cars do
		local bot = car.bot
		local catchUp = 0
		if lead and not fleet.easy then
			catchUp =
				math.clamp((RaceBots.progress(fleet.route, bot) - lead) / RaceBots.CATCH_GAP, -1, 1)
		end
		local had = bot.time
		local hold = fleet.easy and bot.time == nil and RaceBots.holds(fleet.route, bot, lead)
		RaceBots.step(fleet.route, bot, dt, since, catchUp, hold)
		if had == nil and bot.time ~= nil then
			done += 1
		end
		local pose = RaceBots.pose(fleet.route, bot)
		-- the road under it
		local y = t.spawn.y
		local wx, wy, wz = TrackData.toWorld(t, true, pose.x, y, pose.z)
		local at = Vector3.new(wx, wy, wz)
		local hit =
			workspace:Raycast(Vector3.new(wx, wy + 4, wz), Vector3.new(0, -40, 0), fleet.ground)
		if hit then
			at = Vector3.new(wx, hit.Position.Y + fleet.hover, wz)
		end
		local ddx, ddz = TrackData.dirToWorld(t, true, pose.dx, pose.dz)
		local look = Vector3.new(ddx, 0, ddz)
		local cf = CFrame.lookAt(at, at + look)
		-- (speed is big units/s; the world is a quarter size)
		local vel = look * (bot.speed * TrackData.RC_SCALE)
		car.move.Position = at
		car.turn.CFrame = cf.Rotation
		car.body.AssemblyLinearVelocity = vel
		car.body.AssemblyAngularVelocity = Vector3.new(0, pose.yaw, 0)
		car.pos = at
	end
	return done
end

function RaceBotCars.clear(fleet: Fleet?)
	if not fleet then
		return
	end
	for _, car in fleet.cars do
		car.model:Destroy()
	end
	fleet.cars = {}
end

return RaceBotCars
