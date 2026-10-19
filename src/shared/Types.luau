--!strict
-- Shapes of the messages the server sends to the client (UiUpdate remote).

export type UiUpdate = {
	kind: "aim"
		| "ready"
		| "fight"
		| "roundEnd"
		| "matchEnd"
		| "hit"
		| "ko"
		| "move"
		| "buff"
		| "modeInfo"
		| "fightHud"
		| "banner",
	soccer: boolean?, -- ready: this is car soccer (the camera follows your car and the ball)
	move: string?, -- move: "boost" | "jump" | "special" (cooldown started, `seconds` long)
	round: number?,
	yourCar: string?,
	enemyCar: string?,
	center: Vector3?, -- bowl center (camera looks here)
	carPos: Vector3?, -- your car (arrow starts here)
	enemyPos: Vector3?, -- the other car
	enemyName: string?, -- aim: name of the other player ("BOT" for the bot)
	baseDir: Vector3?, -- angle 0 direction (always +Z: aim angles are absolute)
	seconds: number?, -- aim: time you have before the server pushes for you
	youLost: boolean?, -- roundEnd: did you lose this round
	focus: BasePart?, -- roundEnd: crash dummy to film
	youWon: boolean?, -- matchEnd
	pos: Vector3?, -- hit: where the cars touched
	strength: number?, -- hit: 0..1 how hard
	damagePos: Vector3?, -- hit: where the car that got hit is (the damage number floats over it)
	damage: number?, -- hit: HP taken
	youHit: boolean?, -- hit: true when the damage went to your car
	tag: string?, -- hit: "BACK HIT!", "SIDE HIT!", "COMBO x2"
	auto: boolean?, -- fight: the cars drive themselves (build-and-watch)
	ability: string?, -- fight: name of your car's ability (the SPECIAL button), nil = none
	buff: string?, -- buff: "shield" | "bighit" | "speed" (seconds = time left, 0 = ended)
	carsLeft: number?, -- fight / fightHud: cars still alive
	wins: number?, -- fight / fightHud: rounds you have won in this match
	text: string?, -- ko: "K.O.!" or "RING OUT!"; modeInfo: the line shown at the top; banner: big centered text (3, 2, 1, GO!, score)
}

-- Lobby messages (LobbyUpdate remote), a union discriminated by `kind`.
export type LobbyUpdate =
	{
		kind: "profile",
		coins: number,
		wins: number,
		matches: number?, -- finished matches (new-player menu)
		owned: { string },
		freePullAvailable: boolean,
		hintsSeen: { string },
		carLevels: { [string]: number }?, -- progression
		rank: string?,
		streak: number?,
		botLevel: string?,
		mode: string?, -- the player's chosen mode ("auto" = rotation)
		quests: { { title: string, progress: number, target: number, reward: number, done: boolean } }?,
		daily: { ready: boolean, freePulls: number }?,
		spinReady: boolean?, -- daily spin wheel not used yet today
		paint: { owned: { string }, equipped: { [string]: { color: string?, sticker: string? } } }?,
		build: {
			carId: string,
			parts: { [string]: string },
			owned: { string },
			levels: { [string]: number },
			power: number,
		}?, -- build-and-watch garage
	}
	| {
		kind: "gacha",
		carId: string,
		isNew: boolean,
		refund: number,
		free: boolean,
		coins: number,
	}
	| { kind: "gachaError", reason: string }
	| { kind: "spinResult", index: number, label: string }
	| { kind: "storeResult", ok: boolean, carId: string, reason: string?, coins: number }
	| { kind: "paintResult", ok: boolean, reason: string? }
	| { kind: "buildResult", ok: boolean, reason: string? }
	| { kind: "countdown", seconds: number, alone: boolean? }
	| { kind: "choices", cars: { string }, seconds: number }
	| { kind: "toLobby", coinsEarned: number, won: boolean, firstWin: boolean?, left: boolean? }

return {}
