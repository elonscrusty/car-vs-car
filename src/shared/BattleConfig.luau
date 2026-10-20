--!strict
-- Numbers for the 1v1 auto-battle mode (pure data). ALL STARTING VALUES TO PLAYTEST, not final
-- balance. Distances and speeds are in L = one car's body length, so they scale to any model.
-- New cars come ONLY from the gumball machine (rarity + gumball below); nothing is bought with coins.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local DuelArenaLayout = sibling("DuelArenaLayout")

local BattleConfig = {}

BattleConfig.Series = {
	rounds = 3, -- a match is up to three rounds
	winsNeeded = 2, -- first to two round wins finishes early
}

BattleConfig.Timing = {
	selectSeconds = 8, -- pick a car before each round
	prepSeconds = 3, -- the 3-2-1 before rounds 2 and 3
	firstPrepSeconds = 5, -- the 3-2-1 before round 1: the VS screen needs time
	fightSeconds = 60, -- longest fight; then the car with more HP (percent) wins
	koLastSeconds = 4.8, -- same, but when this knock-out ends the whole match: the wreck camera is slow
	koSeconds = 2.6, -- after a knock-out: cars stop, the loser smokes, then the result shows
	resultSeconds = 3, -- round result on screen
	rematchSeconds = 6, -- how long the YOU WIN / YOU LOSE banner stays, then everyone goes back to the lobby
	hudRate = 10, -- HUD updates per second during a fight
}

-- Everything about the arena is a rectangle on a flat floor, centered on `origin`.
-- NOTE: the real map is now "Duel Car Arena" (DuelArenaLayout / server DuelArena). halfX, halfZ and
-- obstacles below are only the OLD auto-battle AI's picture of a plain box arena (kept so its tests
-- and simulation still run); the live arena reads its size from DuelArenaLayout.
BattleConfig.Arena = {
	origin = { x = 6000, y = 40, z = 0 }, -- far from the lobby and the old fight arenas
	halfX = 80, -- floor half width (studs)
	halfZ = 55, -- floor half depth
	wallHeight = DuelArenaLayout.wallHeight,
	wallThickness = 4,
	spawnInset = 18, -- cars start this far from the short walls
	-- Broad blocks (center x, z and half sizes). Left and right are mirrored; at least
	-- `minGapL` car lengths stay open around every block so no car can wedge.
	obstacles = {
		{ x = -28, z = -22, hx = 7, hz = 5 },
		{ x = 28, z = 22, hx = 7, hz = 5 },
	} :: { { x: number, z: number, hx: number, hz: number } },
	minGapL = 1.8,
	floorColor = { 92, 98, 112 },
	wallColor = { 60, 66, 82 },
	obstacleColor = { 150, 120, 80 },
}

BattleConfig.Camera = {
	pitchDeg = 60, -- overhead three-quarter angle
	fovDeg = 50,
	padding = 1.3, -- room around the arena (used when the cars are not known yet)
	smooth = 3.5, -- how fast the camera follows the pair (higher = snappier)
	-- Follow camera: frames the middle of the two cars. The view holds at least `minHalfL` car
	-- lengths to each side and grows with the gap between the cars, plus `marginL`.
	minHalfL = 3.2,
	marginL = 1.6,
}

-- The opening choice (start spot along the car's end of the arena, and the launch aim).
BattleConfig.Setup = {
	spotStep = 0.45, -- far / near spots sit this fraction of the half depth off the middle
	aimDeg = 28, -- left / right aim turns the starting heading this far
}

-- The last stretch of a fight: announced, and every weapon recharges faster for both cars.
BattleConfig.Final = {
	startSeconds = 1e9, -- carter: nothing special in the last seconds, so this never starts
	tempo = 2, -- cooldowns run this many times faster
	text = "FINAL PHASE: weapons recharge faster!",
}

-- The "momentum" prototype: the same cars and arena, but the cars LAUNCH from the opening choice,
-- keep their speed, skid and rebound off walls and each other, and fire their weapons on their own
-- with only weak steering. Compared side by side with the steering fight (carter picks one).
BattleConfig.defaultMomentum = false -- carter: no auto-fight. Players drive; only the Studio test bot uses a brain
BattleConfig.Momentum = {
	launchL = 4.5, -- launch speed, L per second
	turnScale = 1.2, -- steering is this much of the normal turn rate
	accel = 2.2, -- cruise speeds per second gained (the car keeps moving: a sleepy playtest drifted apart)
	brake = 0.5, -- cruise speeds per second lost
	side = 2.2, -- sideways grip (normal 8): low = long skids
	elasticity = 0.85, -- bounciness of the car body
	friction = 0.05,
	knockMult = 1.4, -- hits throw cars further
	aimDeg = 24,
	lungeSeconds = 1.6, -- a car that has slowed down is thrown forward again this often
	lungeL = 3.6, -- ... at this speed (L per second) -- a gun fires when the foe is this near the heading
	rangeL = 11, -- ... and this close
}

-- Movement shared by every fighter (the AI asks, the server enforces these limits).
BattleConfig.Move = {
	accel = 3.2, -- cruise speeds per second
	brake = 5,
	reverseScale = 0.6, -- reverse is slower than forward
	skidBrake = 0.9, -- cruise speeds per second lost while skidding after a charge
	skidSide = 2, -- sideways grip while skidding (normal is 8: higher = grips harder)
	knockFriction = 2.2, -- a knocked car slides and slows by this much per second
	turnScaleAtSpeed = 0.55, -- turn rate scale while moving fast (0..1)
	flipUpDot = 0.3, -- body up vector below this = flipped
	flipSeconds = 1, -- flipped this long -> set upright in place (no heal, no cooldown reset)
	stuckWindow = 1.2, -- seconds with almost no progress = stuck
	stuckDistL = 0.45, -- less than this many L moved in the window = no progress
	recoverReverse = 0.7, -- seconds backing up
	recoverTurn = 0.6, -- seconds turning away after that
	wallMarginL = 0.9, -- start steering away from a wall this close
	blockMarginL = 0.55, -- ... and from a block
}

BattleConfig.Order = { "RamTruck", "CannonVan", "SawBuggy" } :: { string }

export type Fighter = {
	id: string, -- saved in profiles: never rename or reuse
	name: string,
	model: string, -- model name in ReplicatedStorage.BattleModels
	weaponName: string,
	blurb: string, -- one sentence, what it does
	weakness: string, -- one clear weakness
	hp: number,
	cruiseL: number, -- cruising speed, L per second
	turnDeg: number, -- turn rate, degrees per second
	rarity: string, -- gumball rarity (PLACEHOLDER): Common / Rare / Epic / Legendary
	gumball: boolean, -- true = can drop from the gumball machine; false = free starter
	enabled: boolean,
	lengthStuds: number, -- the battle clone is scaled so its body is this long (one L)
	-- Weapon points, in L from the middle of the body floor (forward = nose, up = +y). The supplied
	-- models are single meshes, so these are measured from them (see docs/BATTLE_MODELS.md).
	-- A part with the same name inside the model (Muzzle / RamHit / SawHit) overrides these.
	weaponForward: number, -- distance of the weapon point ahead of the middle
	weaponUp: number, -- height of the weapon point
	hitSize: { number }, -- hit region size in L (width, height, depth); nil use = no region
	density: number, -- body weight: a heavy car shoves a light one in a crash
}

BattleConfig.Fighters = {
	RamTruck = {
		id = "RamTruck",
		name = "Ram Truck",
		model = "RamTruck",
		weaponName = "Metal Ram",
		blurb = "Lines up, then charges and smashes with its front ram.",
		weakness = "Turns slowly and is stuck for a moment after a missed charge.",
		hp = 150,
		cruiseL = 2.6,
		turnDeg = 155, -- was 105: carter said turning was too slow (top speed is unchanged)
		rarity = "Common",
		gumball = false,
		enabled = true,
		lengthStuds = 16,
		weaponForward = 0.42,
		weaponUp = 0.17,
		hitSize = { 0.6, 0.35, 0.35 },
		density = 1.6,
	},
	CannonVan = {
		id = "CannonVan",
		name = "Cannon Van",
		model = "CannonVan",
		weaponName = "Roof Cannon",
		blurb = "Fires powerful shells from a distance.",
		weakness = "Fragile up close and slow to turn.",
		hp = 150, -- was 110: it lost every fight to Ram and Saw in the Studio playtest
		cruiseL = 2.7,
		turnDeg = 150,
		rarity = "Rare",
		gumball = true,
		enabled = true,
		lengthStuds = 15,
		weaponForward = 0.425,
		weaponUp = 0.633,
		hitSize = { 0, 0, 0 },
		density = 1,
	},
	SawBuggy = {
		id = "SawBuggy",
		name = "Saw Buggy",
		model = "SawBuggy",
		weaponName = "Spinning Saw",
		blurb = "Zooms in and grinds with its front saw.",
		weakness = "Must stay close and is open to hits while it approaches.",
		hp = 105,
		cruiseL = 3.4,
		turnDeg = 230,
		rarity = "Epic",
		gumball = true,
		enabled = true,
		lengthStuds = 17,
		weaponForward = 0.48,
		weaponUp = 0.15,
		hitSize = { 0.55, 0.3, 0.3 },
		density = 0.6,
	},
} :: { [string]: Fighter }

BattleConfig.Ram = {
	damage = 30, -- at full charge speed
	damageMin = 15, -- a slow bump deals this; it scales up with the speed of the charge
	startRangeL = 3.2, -- may start a charge this close
	startAngleDeg = 15, -- ... when facing the foe within this angle
	telegraphSeconds = 0.6,
	chargeMult = 2.2, -- charge speed, times cruise
	chargeSeconds = 1.0, -- longest charge
	homingConeDeg = 35, -- auto-aim: a charge steers toward a foe within this angle of the nose ...
	homingTurn = 0.5, -- ... with at most this much steering (1 = full)
	cooldownSeconds = 6, -- after the charge ends
	skidSeconds = 0.7, -- after a MISS the truck overshoots, sliding on
	recoilSeconds = 0.5, -- after a HIT the truck bounces back
	recoilDrive = -0.9,
	peelAngleDeg = 65, -- while the ram recharges it veers off this far from the foe, then comes back
	peelRangeL = 4.5, -- ... until this far away
	knockSpeed = 60, -- studs per second the foe is shoved away
	knockStagger = 0.55, -- seconds the foe cannot steer
	missDowntimeSeconds = 0.9, -- slow and unable to start a charge after a miss
	missDowntimeDrive = 0.35,
	frontConeDeg = 55, -- a strike only counts when the foe is in front within this angle
}

BattleConfig.Cannon = {
	damage = 26, -- was 22 (more punch for a car that must also run)
	minRangeL = 2.3, -- closer than this the van runs away from the foe (was 3: it ran more than it shot)
	maxRangeL = 5.5,
	knockSpeed = 22, -- studs per second a shell shoves the car it hits
	knockStagger = 0.3,
	aimToleranceDeg = 6, -- may start a shot when facing the foe within this angle
	telegraphSeconds = 0.5,
	cooldownSeconds = 6, -- carter: every weapon waits 6 seconds
	shellSpeedL = 4.5, -- L per second (carter: easy to follow with the eyes)
	shellLifeSeconds = 2.2,
	shellRadiusL = 0.12,
	homingDegPerSec = 80, -- auto-aim: a shell curves toward the foe this fast ...
	homingConeDeg = 45, -- ... when the foe is within this angle of its heading
	ricochets = 1, -- a shell bounces off a wall this many times
	repositionDrive = 0.8, -- when closing in
	fleeDrive = 1,
	fleeGiveUpSeconds = 1.2, -- running this long means it is cornered or outrun
	standSeconds = 2, -- then it turns and fights for this long -- when running from a close foe
}

BattleConfig.Saw = {
	buildSeconds = 3, -- steady contact this long reaches the full multiplier
	heatSeconds = 3, -- bounce fight: after this much steady contact the saw overheats ...
	stallSeconds = 2.5, -- ... and does no damage for this long
	maxMult = 1.5, -- damage per tick at full build-up (resets when contact is lost)
	loseContactSeconds = 0.35, -- contact must be gone this long to reset the build-up
	damage = 4, -- was 7, then 5: the saw beat everything in the Studio playtest
	tickSeconds = 0.5, -- least time between damage ticks on the same target
	frontConeDeg = 70,
	approachDrive = 1,
	eventSeconds = 2, -- "Saw contact" message at most this often
}

-- Player-driven cars (carter: manual driving, the weapon is the ATTACK button).
BattleConfig.Human = {
	clientDrive = true, -- the player's own device drives their car (no input delay); false = server drives
	topSpeed = 42, -- studs per second: the SAME top speed for every car (cars differ in weight and turning)
	slideMaxFrac = 0.5, -- sideways slide never goes above this share of top speed
	sawGrindSeconds = 3, -- hold ATTACK: the saw grinds this long at most ...
	sawCooldownSeconds = 6, -- ... then (or when let go) it waits this long
	camDistL = 3.0, -- chase camera: this far behind the car (in car lengths) ...
	camHeightL = 2.8, -- ... and this high (carter: a high camera behind the car) ...
	camLookL = 1.4, -- ... looking at a point this far ahead of the car
	camFov = 70,
	camSmooth = 16,
	camCloseL = 6, -- an enemy closer than this many car lengths pulls the camera back and wider ...
	camCloseExtraL = 1.6, -- ... by this many car lengths ...
	camCloseFov = 12, -- ... and this many degrees of field of view -- how fast the camera swings round behind the car
	-- driving feel
	accelMult = 2, -- quicker getaway than the auto-pilot cars (cruise speeds per second x this)
	brakeMult = 1.6,
	turnMinScale = 1, -- turn rate while crawling (full: a tight turn from a standstill)
	driftSteer = 0.8, -- a little slide only when steering this hard ...
	driftSpeed = 0.8, -- ... at this share of cruise speed or more
	driftSide = 4.5, -- sideways grip while sliding (normal 8: lower = longer slide)
	driftYawBoost = 1.1, -- the nose swings round a bit faster while sliding
	chargeSteerScale = 1, -- how much of the turn rate a ram charge keeps (it only steers by auto-aim)
	airYawScale = 0.35, -- a little steering in the air
	groundRayL = 0.12, -- grounded when something is this far (in car lengths) below the BOTTOM of the body
}

-- Crashes between the two cars (a plain crash, no weapon): damage grows with the speed the OTHER car
-- hits at, so the faster car wins the shove. Walls only bounce and never hurt.
BattleConfig.Crash = {
	hitsToKill = 5, -- five full-speed crashes empty a car's HP
	minSpeedFrac = 0.3, -- slower than this share of cruise speed: just a bump, no damage
	cooldownSeconds = 0.6, -- one crash counts once, even while the cars stay in contact
	touchPadL = 0.06, -- cars count as touching when their bodies are this close (L)
}

-- The Studio / DEV bot: a medium opponent (turns slower than a player so it can be outdriven).
BattleConfig.Bot = {
	turnMult = 0.75,
}

BattleConfig.Rewards = {
	botMatchesPay = false, -- Studio test matches against a bot pay nothing
}

-- Studio only. Never active in a live server.
BattleConfig.Test = {
	unlockAttribute = "BattleTestUnlock", -- set on Workspace in Studio: all cars usable, labeled Test, never saved
	standInAttribute = "BattleStandIn", -- set on Workspace in Studio: plain test boxes while the models are missing
	devBotAttribute = "DevBot", -- set on a player the server trusts: shows the DEV BOT button, allows queueBot
	devUserIds = {} :: { number }, -- extra Roblox user ids allowed to start a fight against a bot (the game owner always is)
}

-- Garage performance upgrades never apply in this mode (shown in the UI).
BattleConfig.Text = {
	chooseLine = "Choose your car. You drive it and attack with the big button.",
	rulesLine = "Most round wins after three rounds wins. Reach two wins to finish early.",
	upgradesLine = "Garage performance upgrades do not apply to this mode.",
}

-- The driver of each car, for the VS screen (original names and lines).
BattleConfig.Drivers = {
	RamTruck = { name = "Big Bonnie", line = "I never brake for anything." },
	CannonVan = { name = "Captain Pop", line = "Duck. Or don't. I'm fine either way." },
	SawBuggy = { name = "Zippy Zed", line = "Hold still, this won't take long!" },
} :: { [string]: { name: string, line: string } }

function BattleConfig.driverLine(id: any): string
	local d = if type(id) == "string" then BattleConfig.Drivers[id] else nil
	return if d then `{d.name}: "{d.line}"` else ""
end

function BattleConfig.fighter(id: any): Fighter?
	if type(id) ~= "string" then
		return nil
	end
	return BattleConfig.Fighters[id]
end

-- Fighters that are switched on, in catalog order.
function BattleConfig.activeOrder(): { string }
	local list = {}
	for _, id in BattleConfig.Order do
		local f = BattleConfig.Fighters[id]
		if f and f.enabled then
			table.insert(list, id)
		end
	end
	return list
end

return BattleConfig
