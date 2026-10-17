--!strict
-- Shapes of the messages the server sends to the client (UiUpdate remote).

export type UiUpdate = {
	kind: "aim" | "fight" | "roundEnd" | "matchEnd" | "hit" | "ko",
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
	damage: number?, -- hit: HP taken
	youHit: boolean?, -- hit: true when the damage went to your car
	text: string?, -- ko: "K.O.!" or "RING OUT!"
}

-- Lobby messages (LobbyUpdate remote), a union discriminated by `kind`.
export type LobbyUpdate =
	{
		kind: "profile",
		coins: number,
		wins: number,
		owned: { string },
		freePullAvailable: boolean,
		hintsSeen: { string },
		carLevels: { [string]: number }?, -- progression
		rank: string?,
		streak: number?,
	}
	| { kind: "gacha", carId: string, isNew: boolean, refund: number, free: boolean, coins: number }
	| { kind: "gachaError", reason: string }
	| { kind: "storeResult", ok: boolean, carId: string, reason: string?, coins: number }
	| { kind: "countdown", seconds: number }
	| { kind: "choices", cars: { string }, seconds: number }
	| { kind: "toLobby", coinsEarned: number, won: boolean }

return {}
