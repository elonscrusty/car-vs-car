--!strict
-- Shapes of the messages the server sends to the client (UiUpdate remote).

export type UiUpdate = {
	kind: "aim" | "fight" | "roundEnd" | "matchEnd" | "hit" | "boost",
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
	cooldown: number?, -- boost: seconds until you can boost again
}

return {}
