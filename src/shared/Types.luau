--!strict
-- Shapes of the messages the server sends to the client (UiUpdate remote).

export type UiUpdate = {
	kind: "aim" | "fight" | "roundEnd" | "matchEnd" | "hit" | "ko" | "move" | "buff",
	move: string?, -- move: "boost" | "jump" | "special" | "weapon" (cooldown started, `seconds` long)
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
	tag: string?, -- hit: "BACK HIT!", "SIDE HIT!", "COMBO x2"
	weapon: string?, -- fight: id of the weapon your car wears (see WeaponsConfig), nil = none
	weaponPassive: boolean?, -- fight: true when the weapon needs no button
	buff: string?, -- buff: "shield" | "bighit" | "speed" (seconds = time left, 0 = ended)
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
		botLevel: string?,
		quests: { { title: string, progress: number, target: number, reward: number, done: boolean } }?,
		daily: { ready: boolean, freePulls: number }?,
		paint: { owned: { string }, equipped: { [string]: { color: string?, sticker: string? } } }?,
		weapons: { owned: { string }, equipped: string }?, -- weapons you own and the one you wear
	}
	| {
		kind: "gacha",
		carId: string, -- "" when the prize is a weapon
		weaponId: string?, -- set when the prize is a weapon
		isNew: boolean,
		refund: number,
		free: boolean,
		coins: number,
	}
	| { kind: "gachaError", reason: string }
	| { kind: "storeResult", ok: boolean, carId: string, reason: string?, coins: number }
	| { kind: "paintResult", ok: boolean, reason: string? }
	| { kind: "weaponResult", ok: boolean, reason: string? }
	| { kind: "countdown", seconds: number }
	| { kind: "choices", cars: { string }, seconds: number }
	| { kind: "toLobby", coinsEarned: number, won: boolean }

return {}
