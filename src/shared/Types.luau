--!strict
-- Shapes of the messages the server sends to the client (UiUpdate remote).

export type UiUpdate = {
	kind: "aim"
		| "fight"
		| "roundEnd"
		| "matchEnd"
		| "hit"
		| "boost"
		| "special"
		| "counter"
		| "ko",
	round: number?,
	yourCar: string?,
	enemyCar: string?,
	youHearts: number?,
	enemyHearts: number?,
	center: Vector3?, -- bowl center (camera looks here)
	carPos: Vector3?, -- your car (arrow starts here)
	baseDir: Vector3?, -- flat direction toward the middle
	youLost: boolean?, -- roundEnd: did you lose this round
	focus: BasePart?, -- roundEnd: crash dummy to film
	youWon: boolean?, -- matchEnd
	pos: Vector3?, -- hit: where the cars touched
	strength: number?, -- hit: 0..1 how hard
	damage: number?, -- hit: HP taken
	youHit: boolean?, -- hit: true when the damage went to your car
	cooldown: number?, -- boost / special: seconds until you can use it again
	text: string?, -- ko: "K.O.!" or "RING OUT!"
}

-- Lobby messages (LobbyUpdate remote), a union discriminated by `kind`.
export type LobbyUpdate =
	{ kind: "profile", coins: number, wins: number, owned: { string }, freePullAvailable: boolean }
	| { kind: "gacha", carId: string, isNew: boolean, refund: number, free: boolean, coins: number }
	| { kind: "gachaError", reason: string }
	| { kind: "countdown", seconds: number }
	| { kind: "choices", cars: { string }, seconds: number }
	| { kind: "toLobby", coinsEarned: number, won: boolean }

return {}
