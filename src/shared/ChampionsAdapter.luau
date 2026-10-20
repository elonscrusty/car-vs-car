--!strict
-- Glue between the game and carter's Champions UI (src/champions). PURE: no Roblox calls, so it is
-- unit tested (tests/champions.test.luau). The client bridge (client/ChampionsBridge) feeds it the
-- server's messages and hands the snapshots to the UI. It only DISPLAYS what the server says: the
-- UI's buttons turn into the same LobbyAction / Action remote calls the old buttons sent.

local Adapter = {}

export type Call = { remote: string, name: string, arg: any? }

-- What the bridge should do after a message: show a line, open a screen, apply settings.
export type Effects = {
	notify: string?,
	notifyOk: boolean?, -- false = the action failed (clears the UI's pending state)
	open: string?, -- screen to open: "LOBBY", "PICKER", "RESULTS"...
	settings: { music: boolean, sfx: boolean, reducedMotion: boolean }?,
}

export type Options = {
	maxSeconds: number, -- length of one fight round (ModesConfig.LastStanding.maxSeconds)
	cars: number, -- cars in a fight (ModesConfig.LastStanding.cars)
	isLive: (id: string) -> boolean, -- CarConfig.isLive
}

export type Model = {
	profile: (u: any, now: number) -> Effects,
	lobby: (u: any) -> Effects,
	ui: (u: any, now: number, extra: { place: number?, kos: number? }?) -> Effects,
	level: (level: number, xp: number, needed: number) -> (),
	intent: (action: string, payload: any) -> (Call?, Effects),
	snapshot: () -> any,
	inMatch: () -> boolean,
}

local GACHA_ERRORS: { [string]: string } = {
	coins = "NOT ENOUGH COINS",
	busy = "THE GUMBALL MACHINE IS BUSY",
	complete = "YOU HAVE EVERY CAR!",
	loading = "LOADING YOUR DATA",
}

local STORE_ERRORS: { [string]: string } = {
	coins = "NOT ENOUGH COINS",
	owned = "YOU ALREADY OWN THIS CAR",
	unknown = "THIS CAR IS NOT FOR SALE",
	loading = "LOADING YOUR DATA",
	busy = "TRY AGAIN IN A MOMENT",
}

local function none(): Effects
	return {}
end

function Adapter.new(opts: Options): Model
	local ready = false
	local coins = 0
	local owned: { [string]: boolean } = {}
	local equipped: string? = nil
	local starterOffer: { string }? = nil
	local padOffer: { string }? = nil
	local dailyReady = false
	local dailyNextAt: number? = nil
	local dailyGift: number? = nil
	local freePull = false
	local level = 1
	local xp = 0
	local xpGoal = 1
	local queue: { status: string, count: number, pad: string }? = nil
	local reveal: { vehicleId: string, duplicate: boolean, refund: number }? = nil
	local match: any = nil
	local result: any = nil
	local wins = 0
	local lastPlace: number? = nil
	local settings = { music = true, sfx = true, reducedMotion = false }
	local openedStarter = false

	local model = {} :: Model

	function model.level(newLevel: number, newXp: number, needed: number)
		level = math.max(1, math.floor(newLevel))
		xp = math.max(0, math.floor(newXp))
		xpGoal = math.max(1, math.floor(needed))
	end

	function model.inMatch(): boolean
		return match ~= nil
	end

	function model.profile(u: any, now: number): Effects
		local fx = none()
		ready = true
		coins = if type(u.coins) == "number" then u.coins else coins
		owned = {}
		if type(u.owned) == "table" then
			for _, id in u.owned do
				owned[id] = true
			end
		end
		local build = u.build
		if
			type(build) == "table"
			and type(build.carId) == "string"
			and opts.isLive(build.carId)
		then
			equipped = build.carId
		elseif equipped == nil or not owned[equipped] then
			equipped = nil
			for id in owned do
				if opts.isLive(id) then
					equipped = id
					break
				end
			end
		end
		local daily = u.daily
		if type(daily) == "table" then
			dailyReady = daily.ready == true
			dailyNextAt = if not dailyReady and type(daily.secondsToNext) == "number"
				then now + daily.secondsToNext
				else nil
			dailyGift = if type(daily.coins) == "number" then daily.coins else dailyGift
		end
		freePull = u.freePullAvailable == true
		if type(u.starterChoices) == "table" and #u.starterChoices > 0 and not u.starterPicked then
			starterOffer = u.starterChoices
			if not openedStarter and match == nil then
				openedStarter = true
				fx.open = "PICKER"
			end
		else
			starterOffer = nil
		end
		return fx
	end

	function model.lobby(u: any): Effects
		local fx = none()
		local kind = u.kind
		if kind == "gacha" then
			coins = if type(u.coins) == "number" then u.coins else coins
			fx.notify = "" -- the pull worked: clear any old BUSY notice
			fx.notifyOk = true
			reveal = {
				vehicleId = u.carId,
				duplicate = u.isNew == false,
				refund = if type(u.refund) == "number" then u.refund else 0,
			}
		elseif kind == "gachaError" then
			fx.notify = GACHA_ERRORS[u.reason or ""] or "THE GUMBALL MACHINE COULD NOT RUN"
			fx.notifyOk = false
		elseif kind == "storeResult" then
			if type(u.coins) == "number" then
				coins = u.coins
			end
			if u.ok ~= true then
				fx.notify = STORE_ERRORS[u.reason or ""] or "PURCHASE FAILED"
				fx.notifyOk = false
			end
		elseif kind == "buildResult" then
			if u.ok ~= true then
				fx.notify = "COULD NOT CHANGE YOUR CAR"
				fx.notifyOk = false
			end
		elseif kind == "countdown" then
			if type(u.seconds) == "number" and u.seconds > 0 then
				queue = {
					pad = "PAD",
					count = if u.alone == true then 1 else 2,
					status = "FIGHT IN " .. math.ceil(u.seconds),
				}
			else
				queue = nil
				if u.busy == true then
					fx.notify = "ALL FIGHTS ARE FULL. TRY AGAIN"
					fx.notifyOk = false
				end
			end
		elseif kind == "choices" then
			queue = nil
			if type(u.cars) == "table" and #u.cars > 0 then
				padOffer = u.cars
				fx.open = "PICKER"
			end
		elseif kind == "toLobby" then
			queue = nil
			padOffer = nil
			match = nil
			if u.left == true then
				result = nil
				fx.open = "LOBBY"
			else
				local earned = if type(u.coinsEarned) == "number" then u.coinsEarned else 0
				local rewards = {}
				local text = if type(u.resultText) == "string" and u.resultText ~= ""
					then string.upper(u.resultText)
					elseif u.won == true then "VICTORY"
					else "FIGHT"
				table.insert(rewards, { label = text, amount = earned })
				local total = earned
				local levelUp = u.levelUp
				if
					type(levelUp) == "table"
					and type(levelUp.coins) == "number"
					and levelUp.coins > 0
				then
					table.insert(rewards, { label = "LEVEL UP", amount = levelUp.coins })
					total += levelUp.coins
				end
				result = {
					mode = "DUEL",
					won = u.won == true,
					place = if type(u.place) == "number" then u.place else lastPlace,
					total = total,
					rewards = rewards,
				}
				fx.open = "RESULTS"
			end
			wins = 0
			lastPlace = nil
		end
		return fx
	end

	function model.ui(u: any, now: number, extra: { place: number?, kos: number? }?): Effects
		local fx = none()
		local kind = u.kind
		if kind == "ready" then
			queue = nil
			padOffer = nil
			result = nil
			reveal = nil
			local round = if type(u.round) == "number" then u.round else 1
			if round <= 1 then
				wins = 0
			end
			match = {
				mode = "DUEL",
				phase = "READY",
				timer = opts.maxSeconds, -- shows the full round time until the fight starts
				round = round,
				youScore = wins,
				carsLeft = opts.cars,
			}
		elseif kind == "fight" then
			if match == nil then
				match = { mode = "DUEL", round = 1 }
			end
			wins = if type(u.wins) == "number" then u.wins else wins
			match = {
				mode = "DUEL",
				phase = "ACTIVE",
				round = if type(u.round) == "number" then u.round else match.round,
				youScore = wins,
				carsLeft = if type(u.carsLeft) == "number" then u.carsLeft else opts.cars,
				hp = if type(u.hp) == "number" then u.hp else nil,
				hpMax = if type(u.hpMax) == "number" then u.hpMax else nil,
				endsAt = now + opts.maxSeconds,
			}
		elseif kind == "fightHud" then
			if match ~= nil then
				wins = if type(u.wins) == "number" then u.wins else wins
				match.youScore = wins
				match.carsLeft = u.carsLeft
				if type(u.hp) == "number" and type(u.hpMax) == "number" then
					match.hp, match.hpMax = u.hp, u.hpMax
				end
				match.round = if type(u.round) == "number" then u.round else match.round
			end
		elseif kind == "move" then
			if match ~= nil and type(u.seconds) == "number" then
				if u.move == "boost" then
					match.boostEndsAt = now + u.seconds
					match.boostDuration = u.seconds
				elseif u.move == "special" then
					match.abilityEndsAt = now + u.seconds
					match.abilityDuration = u.seconds
				end
			end
		elseif kind == "roundEnd" then
			if match ~= nil then
				match.phase = "ROUND_END"
			end
		elseif kind == "matchEnd" then
			if extra and extra.place then
				lastPlace = extra.place
			end
			local rewards = {}
			local total: number? = nil
			if type(u.coins) == "number" then
				table.insert(
					rewards,
					{ label = if u.youWon == true then "VICTORY" else "FIGHT", amount = u.coins }
				)
				total = u.coins
				if type(u.bonus) == "number" and u.bonus > 0 then
					table.insert(rewards, { label = "PLACE + SMASHES", amount = u.bonus })
					total += u.bonus
				end
			end
			match = {
				mode = "DUEL",
				phase = "RESULTS",
				round = if match then match.round else 1,
				youScore = wins,
				carsLeft = if match then match.carsLeft else nil,
				result = {
					mode = "DUEL",
					won = u.youWon == true,
					place = lastPlace,
					total = total,
					rewards = rewards,
				},
			}
		end
		return fx
	end

	function model.snapshot(): any
		local picker: { string }? = padOffer or starterOffer
		return {
			ready = ready,
			coins = coins,
			level = level,
			xp = xp,
			xpGoal = xpGoal,
			owned = owned,
			equipped = equipped,
			selection = equipped,
			pickerOptions = picker or {},
			mode = "DUEL",
			dailyReady = dailyReady,
			dailyNextAt = dailyNextAt,
			dailyGift = dailyGift,
			clawPrice = if freePull then 0 else nil,
			settings = settings,
			queue = queue,
			match = match,
			result = result,
			reveal = reveal,
		}
	end

	-- A UI button -> the game's own remote call (nil = nothing to send; the effects say what else).
	function model.intent(action: string, payload: any): (Call?, Effects)
		local fx = none()
		local id = if type(payload) == "table" then payload.vehicleId else nil
		if action == "EquipCar" then
			return { remote = "LobbyAction", name = "buildCar", arg = id }, fx
		elseif action == "ChooseCar" then
			local name = if padOffer == nil and starterOffer ~= nil
				then "pickStarter"
				else "pickCar"
			return { remote = "LobbyAction", name = name, arg = id }, fx
		elseif action == "BuyCar" then
			return { remote = "LobbyAction", name = "buyCar", arg = id }, fx
		elseif action == "PullClaw" then
			return { remote = "LobbyAction", name = "buyGacha" }, fx
		elseif action == "ClaimGift" then
			return { remote = "LobbyAction", name = "claimDaily" }, fx
		elseif action == "Play" then
			return { remote = "LobbyAction", name = "play" }, fx
		elseif action == "CancelPlay" then
			queue = nil
			return { remote = "LobbyAction", name = "cancelPlay" }, fx
		elseif action == "Rematch" then
			-- Still on the end screen = the server's rematch vote; already back in the lobby = PLAY again.
			if match ~= nil then
				return { remote = "LobbyAction", name = "rematch" }, fx
			end
			result = nil
			fx.open = "LOBBY"
			return { remote = "LobbyAction", name = "play" }, fx
		elseif action == "LeaveMatch" then
			if match ~= nil then
				return { remote = "LobbyAction", name = "leaveMatch" }, fx
			end
			result = nil
			fx.open = "LOBBY"
			return nil, fx
		elseif action == "Boost" then
			return { remote = "Action", name = "boost" }, fx
		elseif action == "Ability" then
			return { remote = "Action", name = "special" }, fx
		elseif action == "SaveSettings" and type(payload) == "table" then
			for _, key in { "music", "sfx", "reducedMotion" } do
				if type(payload[key]) == "boolean" then
					(settings :: any)[key] = payload[key]
				end
			end
			fx.settings = settings
			return nil, fx
		end
		return nil, fx -- SetMode (fights only), ResetCar and the spectator arrows have no server side
	end

	return model
end

return Adapter
