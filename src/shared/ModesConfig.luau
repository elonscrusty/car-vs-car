--!strict
-- Numbers for the fight modes (pure data, placeholder values: change freely).
-- A match picks its mode from `Order`, one after the other (server rotation). Take a mode out
-- of `Order` to stop it coming up ("duel" is the normal 1v1).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local FeatureFlags = sibling("FeatureFlags")

-- Rotation: soccer (main game), tag, race, duel. Hill and ice come back with their flags. Last standing comes back with its flag.
local function orderFor(flags: { [string]: boolean }?): { string }
	local order = {}
	if FeatureFlags.enabled("soccerMode", flags) then
		table.insert(order, "soccer") -- car soccer is the main game: first in the rotation
	end
	if FeatureFlags.enabled("tagMode", flags) then
		table.insert(order, "tag")
	end
	if FeatureFlags.enabled("raceMode", flags) then
		table.insert(order, "race")
	end
	if not FeatureFlags.enabled("lastStandingMode", flags) then
		table.insert(order, "duel") -- the 4-car fight replaces the 1v1 duel when it is on
	end
	if FeatureFlags.enabled("hillMode", flags) then
		table.insert(order, "hill")
	end
	if FeatureFlags.enabled("iceMode", flags) then
		table.insert(order, "ice")
	end
	if FeatureFlags.enabled("lastStandingMode", flags) then
		table.insert(order, "lastStanding")
	end
	return order
end

return {
	orderFor = orderFor,
	Order = orderFor(nil),
	Names = {
		duel = "DUEL",
		hill = "KING OF THE HILL",
		ice = "ICE BOWL",
		lastStanding = "LAST CAR STANDING",
		soccer = "CAR SOCCER",
		tag = "CAR TAG",
		race = "CRAZY RACE",
	},
	Blurbs = {
		duel = "Crash into your enemy until their HP runs out!",
		hill = "Stay on the glowing circle. Alone on it = points. Hold 20 seconds to win!",
		ice = "The floor is ice! Cars slide. Push your enemy off the edge!",
		lastStanding = "8 cars. Fall off or run out of HP and you are out. Last one wins!",
		race = "Race 3 laps over jumps! Hit the checkpoints in order. First car over the line wins!",
		tag = "One car is IT and glows! Bump a car to pass IT on. IT when the fuse ends = BOOM. Last car wins!",
		soccer = "Push the ball into the other team's goal on the small field. First to 3 wins!",
	},
	NewPlayer = { matches = 3 }, -- until this many finished matches, AUTO means soccer
	Hill = {
		radius = 16, -- the circle in the middle (studs)
		holdSeconds = 20, -- alone on the circle this long = win
		hudSeconds = 0.5, -- how often the scores are sent to the players
	},
	Ice = {
		floorFriction = 0.02, -- bowl surface friction (normal floor: GameConfig.Drive.groundFriction)
		carFriction = 0.02, -- car friction while on ice
		gripScale = 0.12, -- side grip multiplier (1 = normal, lower = slides more)
		tint = { 170, 220, 255 }, -- icy blue paint on the bowl
	},
	LastStanding = {
		cars = 4, -- cars in the match (humans first, bots fill the rest)
		maxSeconds = 60, -- time up: most HP among the cars still alive wins
		spawnRadius = 48, -- start ring, studs from the middle
		hpScale = 1.2, -- share of the car's normal HP: ~6-8 front hits at a normal crash speed (carter: medium health)
		hudSeconds = 1,
		-- Flat fight floor with blocks, pillars and hammers, NO ramps (carter). Overrides GameConfig.Arena for this mode.
		-- Mirrored round the middle so no spot is luckier.
		Arena = {
			flatRadius = 60,
			rimRadius = 60, -- for a square arena: half the side length
			square = true, -- a square floor with four straight walls (carter)
			tiltDeg = 0,
			wallHeight = 4, -- a low lip: a big hit launches you over it = out
			spawnRadius = 40,
			noPads = true,
			dirt = true, -- brown dirt floor, monster-truck show
			stadium = true, -- stands, crowd and lights instead of the bowl scenery
			obstacles = {
				{ kind = "block", x = 0, z = -23, sx = 10, sy = 7, sz = 6 },
				{ kind = "block", x = 0, z = 23, sx = 10, sy = 7, sz = 6 },
				{ kind = "pillar", x = -18, z = 20, sx = 6, sy = 9 },
				{ kind = "pillar", x = 18, z = -20, sx = 6, sy = 9 },
				-- Two slow hammers, one each side (a red bar sweeping round).
				{ kind = "spinner", x = -34, z = 12, sx = 18, sy = 3, spin = 0.7 },
				{ kind = "spinner", x = 34, z = -12, sx = 18, sy = 3, spin = -0.7 },
			},
			gapEvery = 12, -- a gap of 2 wall pieces at every 12th: you can fall through
		},
		winBonus = 60, -- BIG coins for the match winner, on top of the normal win reward (PLACEHOLDER)
		placeCoins = { [2] = 30, [3] = 15 } :: { [number]: number }, -- 2nd and 3rd get coins too (PLACEHOLDER); KO'd cars drop no coins
		bountyCoins = 40, -- knocking out the crown car pays this to the car that did it (PLACEHOLDER)
		koCoins = 10, -- every knock-out pays a little (PLACEHOLDER)
		creditSeconds = 5, -- a fall off the edge counts for whoever hit the car in the last N seconds
		-- Best of 3: first to 2 round wins; after 3 rounds the most wins takes it.
		Rounds = { winsNeeded = 2, maxRounds = 3, breakSeconds = 3.5 },
		-- No closing walls (carter): minRadius = full radius keeps the safe radius fixed. A car outside it is out.
		Shrink = { startSeconds = 40, endSeconds = 110, minRadius = 60 },
		-- ONE item for now: a SHIELD that blocks the next hit (Pickups with this override).
		Items = {
			kinds = { "shield", "oil", "repair" }, -- a FEW boxes (carter)
			shield = { seconds = 20 }, -- blocks the next hit, then pops
			ringMin = 12,
			ringMax = 50,
			firstSpawnSeconds = 8,
			spawnEverySeconds = 14,
			maxOnFloor = 3,
		},
		-- Big hits (BrawlRules): the car that got hit is LAUNCHED and bits fly off it.
		Hit = {
			from = 0.3,
			push = 70,
			up = 34,
			spin = 14,
			scrapMax = 8,
			peelFrom = 0.55,
		},
	},
	Race = {
		cars = 6, -- cars in the match (humans first, bots fill the rest); track: RaceTrackConfig
		placeCoins = { 60, 45, 35, 25, 20, 20 }, -- coins by finishing place (PLACEHOLDER, to test); the 1st place equals the win reward
	},
	Tag = {
		cars = 6, -- cars in the match (humans first, bots fill the rest); plays on the flat field
		startFuse = 12, -- seconds on the fuse in round 1 (fun pass: was 18)
		fuseStep = 2, -- every round the fuse is this much shorter ...
		minFuse = 5, -- ... but never shorter than this
		immuneSeconds = 1.5, -- the car that just passed IT cannot be tagged back this long
		maxSeconds = 75, -- time up: nearest-to-middle alive car wins (audit #28: short rounds, was 240)
		allOutEndSeconds = 2, -- every human is out: the round ends this soon (no dead time)
		firstItBot = true, -- audit #27: the first IT is a bot whenever the match has one
		hudSeconds = 0.5,
		itColor = { 255, 70, 40 },
		fleeLook = 40, -- bots run toward a point this far away from IT
	},
	Soccer = {
		teamSize = 3, -- cars per team (humans first, bots fill the rest); 3v3 on the flat field (SoccerFieldConfig)
		-- NOTE: the ball of car soccer is SoccerFieldConfig.ball*; the three ball numbers below only feed ModeFx.
		ballSize = 16, -- the giant ball (diameter, studs)
		ballDensity = 0.25, -- low = a hit sends it flying
		ballMaxSpeed = 140, -- the server never lets the ball go faster
		goalRadius = 66, -- the ball crossing this distance from the middle, inside a goal arc = goal
		goalHalfAngle = 0.55, -- radians either side of the goal's middle
		scoreToWin = 3,
		maxSeconds = 120, -- time up: more goals wins (tie = next goal wins)
		suddenDeathAt = 50, -- 0-0 at this many seconds = next goal wins right away (0 = never; audit #25)
		goalCoins = 5, -- coins per goal a human scored, added on top of the normal match reward (audit #24; own goals never cost coins)
		markSeconds = 5, -- your own car carries the KickoffMark attribute this long after every kickoff (audit #16)
		touchCooldown = 0.4, -- stats: touches by the same car closer together than this count once
		logStats = true, -- print one stats line per soccer match (goals, touches, idle time per car)
		spawnRadius = 68,
		spawnSpread = 0.3, -- radians between cars of the same team
		goalPause = 2.2, -- seconds the cars sit frozen after a goal (score banner) before they are reset
		readySeconds = 1.5, -- the "get ready" screen before the first kickoff countdown
		kickoffSeconds = 2, -- 3-2-1 before the first kickoff (cars frozen, ball in the middle)
		restartSeconds = 2, -- 3-2-1 after a goal
		goSeconds = 0.8, -- how long "GO!" stays up
		hudSeconds = 1, -- how often the score and match clock are sent
		lostMargin = 6, -- ball this far past the rim (or fell out) is put back in the middle
		botOffset = 14, -- bots aim this far behind the ball, away from the goal they attack
		-- Chaos moments (fun pass): every `everySeconds` of play one fires, kinds take turns.
		-- boostAll = every pad lit + every car's BOOST ready; blast = the ball is shot across the field.
		Chaos = {
			firstSeconds = 14,
			everySeconds = 18,
			kinds = { "boostAll", "blast", "blast", "boostAll" },
			blastSpeed = 85, -- flat ball speed after a blast (SoccerFieldConfig.ballMaxSpeed still caps it)
			blastLift = 22, -- upward speed so the ball hops
		},
		-- SUPER KICK orbs: drive over one, your next touch on the ball shoots it away. Mirrored spots.
		Orbs = {
			spots = { { x = 0, z = -14 }, { x = 0, z = 14 }, { x = -40, z = 0 }, { x = 40, z = 0 } },
			radius = 5,
			respawn = 10, -- seconds until a taken orb is lit again
			holdSeconds = 8, -- the kick is lost if the ball is not touched this long
			kickSpeed = 110, -- flat ball speed (SoccerFieldConfig.ballMaxSpeed still caps it)
			kickLift = 6,
			color = { 255, 200, 40 },
		},
		colors = { { 70, 150, 255 }, { 255, 90, 70 } }, -- team 1 blue, team 2 red
	},
}
