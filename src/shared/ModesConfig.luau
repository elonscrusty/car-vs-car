--!strict
-- Numbers for the fight modes (pure data, placeholder values: change freely).
-- A match picks its mode from `Order`, one after the other (server rotation). Take a mode out
-- of `Order` to stop it coming up ("duel" is the normal 1v1).

return {
	Order = { "duel", "hill", "ice", "lastStanding", "soccer" },
	Names = {
		duel = "DUEL",
		hill = "KING OF THE HILL",
		ice = "ICE BOWL",
		lastStanding = "LAST CAR STANDING",
		soccer = "CAR SOCCER",
	},
	Blurbs = {
		duel = "Crash into your enemy until their HP runs out!",
		hill = "Stay on the glowing circle. Alone on it = points. Hold 20 seconds to win!",
		ice = "The floor is ice! Cars slide. Push your enemy off the edge!",
		lastStanding = "8 cars. Fall off or run out of HP and you are out. Last one wins!",
		soccer = "Push the giant ball into the other team's goal. First to 3 wins!",
	},
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
		cars = 8, -- cars in the match (humans first, bots fill the rest)
		maxSeconds = 150, -- time up: most HP among the cars still alive wins
		spawnRadius = 68, -- start ring, studs from the middle
		hpScale = 0.6, -- every car has this share of its normal HP (8 cars = quick knock-outs)
		hudSeconds = 1,
	},
	Soccer = {
		teamSize = 3, -- cars per team (humans first, bots fill the rest)
		ballSize = 16, -- the giant ball (diameter, studs)
		ballDensity = 0.25, -- low = a hit sends it flying
		ballMaxSpeed = 140, -- the server never lets the ball go faster
		goalRadius = 66, -- the ball crossing this distance from the middle, inside a goal arc = goal
		goalHalfAngle = 0.55, -- radians either side of the goal's middle
		scoreToWin = 3,
		maxSeconds = 150, -- time up: more goals wins (tie = next goal wins)
		spawnRadius = 68,
		spawnSpread = 0.3, -- radians between cars of the same team
		goalPause = 2.5, -- seconds the cars sit still after a goal before the ball is back
		lostMargin = 6, -- ball this far past the rim (or fell out) is put back in the middle
		botOffset = 14, -- bots aim this far behind the ball, away from the goal they attack
		colors = { { 70, 150, 255 }, { 255, 90, 70 } }, -- team 1 blue, team 2 red
	},
}
