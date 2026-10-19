--!strict
-- Numbers for the 1v1 auto-battle mode (pure data). ALL STARTING VALUES TO PLAYTEST, not final
-- balance. Distances and speeds are in L = one car's body length, so they scale to any model.
-- Prices are PLACEHOLDER coins (carter sets them).

local BattleConfig = {}

BattleConfig.Series = {
	rounds = 3, -- a match is up to three rounds
	winsNeeded = 2, -- first to two round wins finishes early
}

BattleConfig.Timing = {
	selectSeconds = 8, -- pick a car before each round
	prepSeconds = 3, -- both cars and weapons are shown
	fightSeconds = 45, -- longest fight; then higher HP percent wins
	resultSeconds = 3, -- round result on screen
	rematchSeconds = 20, -- how long the match result waits for a Rematch tap
	queueSeconds = 120, -- longest wait in the line before it gives up
	hudRate = 10, -- HUD updates per second during a fight
}

-- Everything about the arena is a rectangle on a flat floor, centered on `origin`.
BattleConfig.Arena = {
	origin = { x = 6000, y = 40, z = 0 }, -- far from the lobby and the old fight arenas
	halfX = 80, -- floor half width (studs)
	halfZ = 55, -- floor half depth
	wallHeight = 14,
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
	pitchDeg = 58, -- overhead three-quarter angle
	fovDeg = 50,
	padding = 1.3, -- room around the arena (the HUD and the prep bar sit in the margins)
	smooth = 6, -- only eased when the screen shape changes
}

-- Movement shared by every fighter (the AI asks, the server enforces these limits).
BattleConfig.Move = {
	accel = 3.2, -- cruise speeds per second
	brake = 5,
	reverseScale = 0.6, -- reverse is slower than forward
	turnScaleAtSpeed = 0.55, -- turn rate scale while moving fast (0..1)
	flipUpDot = 0.3, -- body up vector below this = flipped
	flipSeconds = 1.5, -- flipped this long -> set upright in place (no heal, no cooldown reset)
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
	price: number, -- PLACEHOLDER coins
	enabled: boolean,
	lengthStuds: number, -- the battle clone is scaled so its body is this long (one L)
	-- Weapon points, in L from the middle of the body floor (forward = nose, up = +y). The supplied
	-- models are single meshes, so these are measured from them (see docs/BATTLE_MODELS.md).
	-- A part with the same name inside the model (Muzzle / RamHit / SawHit) overrides these.
	weaponForward: number, -- distance of the weapon point ahead of the middle
	weaponUp: number, -- height of the weapon point
	hitSize: { number }, -- hit region size in L (width, height, depth); nil use = no region
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
		turnDeg = 105,
		price = 100,
		enabled = true,
		lengthStuds = 16,
		weaponForward = 0.42,
		weaponUp = 0.17,
		hitSize = { 0.6, 0.35, 0.35 },
	},
	CannonVan = {
		id = "CannonVan",
		name = "Cannon Van",
		model = "CannonVan",
		weaponName = "Roof Cannon",
		blurb = "Fires powerful shells from a distance.",
		weakness = "Fragile up close and slow to turn.",
		hp = 110,
		cruiseL = 2.3,
		turnDeg = 85,
		price = 500,
		enabled = true,
		lengthStuds = 15,
		weaponForward = 0.425,
		weaponUp = 0.633,
		hitSize = { 0, 0, 0 },
	},
	SawBuggy = {
		id = "SawBuggy",
		name = "Saw Buggy",
		model = "SawBuggy",
		weaponName = "Spinning Saw",
		blurb = "Zooms in and grinds with its front saw.",
		weakness = "Must stay close and is open to hits while it approaches.",
		hp = 115,
		cruiseL = 3.4,
		turnDeg = 190,
		price = 800,
		enabled = true,
		lengthStuds = 17,
		weaponForward = 0.48,
		weaponUp = 0.15,
		hitSize = { 0.55, 0.3, 0.3 },
	},
} :: { [string]: Fighter }

BattleConfig.Ram = {
	damage = 30,
	startRangeL = 2.5, -- may start a charge this close
	startAngleDeg = 15, -- ... when facing the foe within this angle
	telegraphSeconds = 0.6,
	chargeMult = 2.2, -- charge speed, times cruise
	chargeSeconds = 1.0, -- longest charge
	cooldownSeconds = 4, -- after the charge ends
	missDowntimeSeconds = 0.9, -- slow and unable to start a charge after a miss
	missDowntimeDrive = 0.35,
	frontConeDeg = 55, -- a strike only counts when the foe is in front within this angle
}

BattleConfig.Cannon = {
	damage = 22,
	minRangeL = 2,
	maxRangeL = 4,
	aimToleranceDeg = 6, -- may start a shot when facing the foe within this angle
	telegraphSeconds = 0.5,
	cooldownSeconds = 2.5,
	shellSpeedL = 6, -- L per second
	shellLifeSeconds = 2,
	shellRadiusL = 0.12,
	repositionDrive = 0.7, -- slower than cruise when backing off or closing in
}

BattleConfig.Saw = {
	damage = 7,
	tickSeconds = 0.5, -- least time between damage ticks on the same target
	frontConeDeg = 70,
	approachDrive = 1,
	eventSeconds = 2, -- "Saw contact" message at most this often
}

BattleConfig.Rewards = {
	botMatchesPay = false, -- Studio test matches against a bot pay nothing
}

-- Studio only. Never active in a live server.
BattleConfig.Test = {
	unlockAttribute = "BattleTestUnlock", -- set on Workspace in Studio: all cars usable, labeled Test, never saved
	standInAttribute = "BattleStandIn", -- set on Workspace in Studio: plain test boxes while the models are missing
}

-- Garage performance upgrades never apply in this mode (shown in the UI).
BattleConfig.Text = {
	chooseLine = "Choose your car. It drives and attacks automatically.",
	rulesLine = "Most round wins after three rounds wins. Reach two wins to finish early.",
	upgradesLine = "Garage performance upgrades do not apply to this mode.",
}

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
