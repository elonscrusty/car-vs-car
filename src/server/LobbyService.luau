--!strict
-- Lobby brain (server only). Pads -> countdown -> bot fills -> pick 1 of 3 owned cars -> match
-- -> rewards -> back to lobby. Also rolls the gacha and keeps clients' profile HUD in sync.
-- The server decides everything: clients only say "pickCar", "buyGacha", "buyCar" or "leavePad".
-- The pad rules live in the pure module PadLogic (unit tested).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Daily = require(ReplicatedStorage.Shared.Daily)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Gacha = require(ReplicatedStorage.Shared.Gacha)
local FirstWin = require(ReplicatedStorage.Shared.FirstWin)
local Hints = require(ReplicatedStorage.Shared.Hints)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local MenuRules = require(ReplicatedStorage.Shared.MenuRules)
local NextGoal = require(ReplicatedStorage.Shared.NextGoal)
local ResultRewards = require(ReplicatedStorage.Shared.ResultRewards)
local SessionSummary = require(ReplicatedStorage.Shared.SessionSummary)
local Paint = require(ReplicatedStorage.Shared.Paint)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local PadLogic = require(ReplicatedStorage.Shared.PadLogic)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Spin = require(ReplicatedStorage.Shared.Spin)
local PickChoices = require(ReplicatedStorage.Shared.PickChoices)
local PlayerLevel = require(ReplicatedStorage.Shared.PlayerLevel)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Leaderboards = require(script.Parent.Leaderboards)
local ProgressConfig = require(ReplicatedStorage.Shared.ProgressConfig)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local BotLevels = require(ReplicatedStorage.Shared.BotLevels)
local Modes = require(ReplicatedStorage.Shared.Modes)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Store = require(ReplicatedStorage.Shared.Store)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)
local Appearance = require(script.Parent.Appearance)
local GumballAnim = require(script.Parent.GumballAnim)
local LobbyCars = require(ReplicatedStorage.Shared.LobbyCars)
local LobbyParking = require(script.Parent.LobbyParking)
local Telemetry = require(script.Parent.Telemetry)

-- What a finished match can tell the lobby about one player. Every field is optional; nil = absent.
export type MatchResult = {
	mode: string?,
	place: number?,
	goals: number?,
	survivedSeconds: number?,
	tags: number?,
}

export type Participant = {
	player: Player,
	carId: string,
	-- result: what the match reports about this player (all optional, read defensively):
	-- mode, place (1 = first), goals, survivedSeconds, tags.
	onFinished: (won: boolean, stay: boolean?, result: MatchResult?) -> (),
	appearance: Appearance.Appearance?, -- paint, sticker, level badge
	botLevel: string?, -- bot difficulty for a lone player
	mode: string?, -- the player's chosen mode
	build: Build.BuildData?, -- build-and-watch parts
}

-- Only the parts of the lobby handle we use (see docs/LOBBY_CONTRACT.md).
export type PadHandle = {
	part: BasePart,
	prompt: ProximityPrompt,
	setStatus: (text: string) -> (),
}
export type LobbyHandle = {
	spawn: SpawnLocation,
	folder: Folder,
	claw: GumballAnim.Anim?, -- the gumball machine show (still called claw: other code reads it)
	parking: LobbyParking.Handle, -- each player's car in its spot, with their name
}

export type Deps = {
	lobby: LobbyHandle,
	remotes: Remotes.RemoteSet,
	-- Create a Match for this player; call onFinished(won) when its end screen is over.
	startMatch: (participants: { Participant }) -> (),
}

export type Handle = {
	onPlayerAdded: (player: Player) -> (),
	onPlayerRemoving: (player: Player) -> (),
	action: (player: Player, action: any, arg: any) -> (),
	-- The match let go of this player (they tapped LOBBY): back to the lobby, nothing paid.
	leftMatch: (player: Player) -> (),
	sendProfile: (player: Player) -> (), -- push the saved coins and cars to the player's screen
	stop: () -> (),
}

type Stage = "pad" | "picking" | "match"
type PlayerState = {
	stage: Stage,
	offered: { string },
	picked: string?, -- chosen car; the match starts when everyone on the pad has picked
	token: number, -- bumps whenever the pick phase ends so old timeouts do nothing
	queued: boolean?, -- joined with the PLAY button: no need to stand near a pad
}

local LobbyService = {}

local PAD_LEAVE_EXTRA = 10 -- studs past the prompt distance before we cancel
local LOOP_STEP = 0.25

function LobbyService.start(deps: Deps): Handle
	if FeatureFlags.enabled("battleMode") then
		Gacha.useFighters() -- the gumball machine drops the battle cars
	end
	local remotes = deps.remotes
	local pads: { PadHandle } = {} -- the old pad fights are gone; PLAY pads live in LobbyPads
	local padCfg = LobbyConfig.Pad
	local state = PadLogic.new(#pads, padCfg.maxPlayers, padCfg.countdownSeconds)
	local players: { [Player]: PlayerState } = {}
	local padAcc: { [number]: number } = {}
	local random = Random.new()
	local claw = deps.lobby.claw
	local rng = function(): number
		return random:NextNumber()
	end
	local gachaLimiter = RateLimiter.new(2, 3)
	local playLimiter = RateLimiter.new(2, 2)
	local storeLimiter = RateLimiter.new(2, 3)
	local hintLimiter = RateLimiter.new(4, 3)
	local botLevelLimiter = RateLimiter.new(3, 3)
	local modeLimiter = RateLimiter.new(4, 3)
	local modePref: { [Player]: string } = {} -- lobby MODE button choice (not saved: resets per visit)
	local questLimiter = RateLimiter.new(2, 3)
	local summaryLimiter = RateLimiter.new(2, 5)
	local sessions: { [Player]: SessionSummary.Data } = {} -- this visit only, never saved
	local spinLimiter = RateLimiter.new(2, 3)
	local paintLimiter = RateLimiter.new(4, 3)
	local buildLimiter = RateLimiter.new(6, 3)
	local parking = deps.lobby.parking
	local bayKeys: { [Player]: string } = {}
	local refreshBay: (player: Player) -> () -- defined below
	local running = true
	local conns: { RBXScriptConnection } = {}
	local charConns: { [Player]: RBXScriptConnection } = {} -- one per player, dropped when they leave

	-- Some messages carry newer fields than Types.LobbyUpdate lists, so callers may pass `any`.
	local function send(player: Player, update: Types.LobbyUpdate | any)
		if player.Parent ~= nil then
			if type(update) == "table" and update.kind == "countdown" then
				-- For carter's PLAY button: QueueSeconds = seconds left in line (nil when not in line).
				local secs = if type(update.seconds) == "number" and update.seconds > 0
					then update.seconds
					else nil
				player:SetAttribute("QueueSeconds", secs)
				player:SetAttribute("InQueue", if secs then true else nil)
			end
			remotes.LobbyUpdate:FireClient(player, update)
		end
	end

	-- For carter's UI, on the Player: PlayerLevel, PlayerXp (into this level), PlayerXpNeeded.
	local function setLevelAttributes(player: Player, p: Inventory.Profile)
		local v = PlayerLevel.view(PlayerLevel.totalXp(p.progress))
		player:SetAttribute("PlayerLevel", v.level)
		player:SetAttribute("PlayerXp", v.into)
		player:SetAttribute("PlayerXpNeeded", v.needed)
	end

	local function levelOf(player: Player, carId: string): number
		local p = Profiles.get(player)
		return if p then Progress.levelOf(p.progress, carId) else 1
	end

	local function buildView(p: Inventory.Profile): any
		local b = p.build
		local carId = Build.carFor(b, p.owned)
		local owned = {}
		for id in b.owned do
			table.insert(owned, id)
		end
		table.sort(owned)
		return {
			carId = carId,
			parts = b.parts,
			owned = owned,
			levels = b.levels,
			power = Build.power(CarConfig.Cars[carId], b),
		}
	end

	local function sendProfile(player: Player)
		local p = Profiles.get(player)
		if p == nil then
			return
		end
		if Quests.ensure(p, os.time()) then
			Profiles.markDirty(player)
		end
		local now = os.time()
		player:SetAttribute("CoinMultiplier", Progress.coinMultiplier(now)) -- 2 on weekends
		setLevelAttributes(player, p)
		if player:GetAttribute("CrownChecked") ~= true then
			player:SetAttribute("CrownChecked", true)
			-- Last week's #1 in wins gets the gold paint (once; later weeks keep it).
			Leaderboards.checkChampion(player, function()
				local cur = Profiles.get(player)
				if cur and not cur.paint.owned.gold then
					cur.paint.owned.gold = true
					Profiles.markDirty(player)
					player:SetAttribute("WeeklyChampion", true)
					sendProfile(player)
				end
			end)
		end
		local carId = Build.carFor(p.build, p.owned)
		local xp = Progress.xpView(p.progress, carId)
		local goal = NextGoal.compute({
			matches = p.matches,
			coins = p.coins,
			owned = p.owned,
			modesPlayed = p.progress.modesPlayed,
		})
		local menu = MenuRules.visible(p)
		local message: any = {
			kind = "profile",
			coins = p.coins,
			wins = p.wins,
			matches = p.matches,
			owned = Inventory.ownedList(p),
			-- battle mode: the Ram Truck is the free starter, so the old 3-car starter pick never opens
			starterPicked = p.starterPicked or FeatureFlags.enabled("battleMode"),
			starterChoices = if p.starterPicked or FeatureFlags.enabled("battleMode")
				then nil
				else LobbyConfig.StarterChoices,
			freePullAvailable = (LobbyConfig.Gacha.firstPullFree and not p.freePullUsed)
				or p.daily.freePulls > 0,
			hintsSeen = Hints.seenList(p.hintsSeen),
			carLevels = Progress.levels(p.progress),
			rank = Progress.rankFor(p.wins),
			streak = p.progress.streak,
			botLevel = p.botLevel,
			mode = modePref[player] or "auto",
			quests = Quests.views(p),
			daily = {
				ready = Daily.canClaim(p.daily, now),
				freePulls = p.daily.freePulls,
				secondsToNext = Daily.secondsUntilNext(p.daily, now), -- 0 = a gift is waiting
				coins = Daily.nextCoins(p.daily, now), -- what the next claim pays
			},
			spinReady = Spin.canSpin(p.spin, now),
			paint = { owned = Paint.ownedList(p.paint), equipped = p.paint.equipped },
			build = buildView(p),
			-- XP bar for the garage car: into / needed (needed 0 + maxed = top level).
			xp = {
				carId = carId,
				level = xp.level,
				into = xp.into,
				needed = xp.needed,
				maxed = xp.maxed,
			},
			levelBonus = Progress.bonusText(xp.level), -- e.g. "+6% HP and damage" ("" at level 1)
			nextGoal = goal.text, -- one line: closest car, or a mode not played yet
			nextGoalKind = goal.kind,
			lastMode = p.progress.lastMode, -- the mode played last (nil before the first match)
			menu = menu, -- which menu buttons show
			unlockNotice = MenuRules.unlockNotice(p, p.hintsSeen), -- QUESTS/GARAGE just appeared
			claw = {
				odds = Gacha.oddsView(p), -- rarity rows: cars marked owned + duplicate refund
				pity = Gacha.pityView(p), -- count / every / left until an Epic or better
				pityMinRarity = LobbyConfig.Gacha.pityMinRarity,
				price = LobbyConfig.Gacha.price,
				labels = LobbyConfig.Labels, -- text keys: claw = surprise car, store = choose your car
			},
		}
		send(player, message)
		refreshBay(player)
	end

	-- A copy of this player's garage build (nil before the profile loads).
	local function buildOf(player: Player): Build.BuildData?
		local p = Profiles.get(player)
		return if p then Build.copy(p.build) else nil
	end

	-- Paint and sticker this player put on `carId` (nil fields when none).
	local function paintLook(player: Player, carId: string): Appearance.Appearance
		local p = Profiles.get(player)
		if p == nil then
			return {}
		end
		local rgb, sticker = Paint.look(p.paint, carId)
		return {
			paintColor = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else nil,
			sticker = sticker,
		}
	end

	-- Paint, sticker and level badge for a player's car.
	local function lookFor(player: Player, carId: string): Appearance.Appearance
		local look = paintLook(player, carId)
		look.level = levelOf(player, carId)
		return look
	end

	-- Keep this player's parking spot showing their rarest car (only rebuilt when it changed).
	function refreshBay(player: Player)
		local p = Profiles.get(player)
		if p == nil or player.Parent == nil then
			return
		end
		local carId = LobbyCars.bestOwned(p.owned)
		local look = paintLook(player, carId)
		local level = player:GetAttribute("PlayerLevel")
		local key = table.concat({ carId, tostring(look.paintColor), tostring(level) }, "|")
		if bayKeys[player] == key then
			return
		end
		bayKeys[player] = key
		parking.set(
			player,
			carId,
			look,
			p.build,
			`{player.DisplayName}  LV {if type(level) == "number" then level else 1}`
		)
	end

	local function updatePadText(i: number)
		local pad = pads[i]
		if pad then
			pad.setStatus(`{PadLogic.shown(state, i)}/{padCfg.maxPlayers} PLAYERS`)
		end
	end

	local function rootOf(player: Player): BasePart?
		local char = player.Character
		if char == nil then
			return nil
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum == nil or hum.Health <= 0 then
			return nil
		end
		return char:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	local function nearPad(player: Player, i: number, extra: number): boolean
		local pad = pads[i]
		local root = rootOf(player)
		if pad == nil or root == nil then
			return false
		end
		return (root.Position - pad.part.Position).Magnitude
			<= pad.prompt.MaxActivationDistance + extra
	end

	local maybeStart: (padIndex: number) -> () -- defined below

	-- Take a player off their pad (countdown or pick phase). Safe to call any time.
	local function cancelPlayer(player: Player)
		local ps = players[player]
		if ps == nil or ps.stage == "match" then
			return
		end
		ps.token += 1
		players[player] = nil
		local padIndex, nowIdle = PadLogic.leave(state, player)
		if padIndex then
			if nowIdle then
				padAcc[padIndex] = nil
			end
			updatePadText(padIndex)
			maybeStart(padIndex) -- the others may all have picked already
		end
		send(player, { kind = "countdown", seconds = 0 })
	end

	-- Reads what the match said about this player. Anything missing or odd is just nil.
	local function resultInfo(won: boolean, result: any): ResultRewards.Info
		local r: { [string]: any } = if type(result) == "table" then result else {}
		local function num(v: any): number?
			return if type(v) == "number" and v == v then v else nil
		end
		return {
			mode = if type(r.mode) == "string" then r.mode else nil,
			won = won,
			place = num(r.place),
			goals = num(r.goals),
			survivedSeconds = num(r.survivedSeconds),
			tags = num(r.tags),
		}
	end

	-- stay: the player goes straight into a rematch (rewards are paid, nothing else changes).
	-- result: optional per-player facts from the match (see MatchResult).
	local function finishMatch(
		player: Player,
		won: boolean,
		carId: string,
		vsBot: boolean,
		stay: boolean?,
		result: any?
	)
		local ps = players[player]
		if ps == nil or ps.stage ~= "match" then
			return
		end
		if not stay then
			players[player] = nil
		end
		-- Coins by what happened (goals, place, survival), not just win or lose.
		local info = resultInfo(won, result)
		local reward = ResultRewards.compute(info)
		local earned = reward.coins
		local p = Profiles.get(player)
		local firstWin = p ~= nil and FirstWin.isFirstWin(p.wins, won)
		local invitePrompt = false
		local levelPaid: PlayerLevel.Paid? = nil
		if p then
			local xpBefore = PlayerLevel.totalXp(p.progress)
			local progressResult = Progress.applyMatchResult(
				p,
				carId,
				won,
				ProgressConfig,
				ResultRewards.keepsStreak(info)
			)
			Quests.onMatchEnd(p, {
				won = won,
				carId = carId,
				opponentIsBot = vsBot,
				mode = reward.mode,
				goals = info.goals,
				tags = info.tags,
				place = info.place,
				kos = if type(result) == "table" and type(result.kos) == "number"
					then result.kos
					else nil,
				items = if type(result) == "table" and type(result.items) == "number"
					then result.items
					else nil,
			})
			Progress.recordMode(p.progress, reward.mode)
			earned += progressResult.coinsBonus
			earned = math.floor(earned * Progress.coinMultiplier(os.time()))
			Inventory.addCoins(p, earned)
			levelPaid = PlayerLevel.pay(p, xpBefore, PlayerLevel.totalXp(p.progress))
			setLevelAttributes(player, p)
			if won then
				p.wins += 1
				Leaderboards.recordWin(player)
			end
			if type(result) == "table" and type(result.kos) == "number" then
				Leaderboards.recordSmashes(player, math.floor(result.kos))
			end
			p.matches = math.min(p.matches + 1, 1e9)
			invitePrompt = ResultRewards.invitePrompt(info, p.matches)
			Profiles.markDirty(player)
			Leaderboards.submit(player, p)
		end
		local session = sessions[player]
		if session == nil then
			session = SessionSummary.new()
			sessions[player] = session
		end
		SessionSummary.record(session, won, earned, info.goals)
		if player.Parent == nil then
			return
		end
		if stay then
			sendProfile(player)
			return
		end
		-- Fresh character at the lobby spawn.
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
		local toLobby: any = {
			kind = "toLobby",
			coinsEarned = earned,
			won = won,
			firstWin = firstWin,
			-- Short result line ("3rd place", "Survived 1:10", "2 goals"); "" = keep the usual text.
			resultText = reward.resultText,
			mode = reward.mode,
			place = info.place,
			goals = info.goals,
			levelUp = if levelPaid
					and (levelPaid.coins > 0 or levelPaid.spins > 0 or #levelPaid.paints > 0)
				then levelPaid
				else nil, -- coins / spin tries / paints from reaching a new player level
			invitePrompt = invitePrompt, -- after a goal or any 2nd+ match, not only wins
		}
		send(player, toLobby)
		sendProfile(player)
	end

	-- Start the pad's match once every player still on it has picked a car (a lone player
	-- fights the bot).
	function maybeStart(padIndex: number)
		local pad = state.pads[padIndex]
		if pad == nil or pad.phase ~= "locked" then
			return
		end
		local picks: { [any]: string } = {}
		for _, key in pad.players do
			local ps = players[key :: Player]
			if ps and ps.stage == "picking" and ps.picked then
				picks[key] = ps.picked
			end
		end
		if not PadLogic.allPicked(pad.players, picks) then
			return
		end
		local participants: { Participant } = {}
		local vsBot = false -- set once we know how many humans joined (read later, when the match ends)
		for _, key in table.clone(pad.players) do
			local player = key :: Player
			local ps = players[player]
			local prof = Profiles.get(player)
			if ps then
				ps.stage = "match"
				ps.token += 1
				ps.offered = {}
				ps.picked = nil
				table.insert(participants, {
					player = player,
					carId = picks[key],
					mode = Modes.defaultPick(if prof then prof.matches else 0, modePref[player]),
					appearance = lookFor(player, picks[key]),
					build = buildOf(player),
					onFinished = function(won: boolean, stay: boolean?, result: MatchResult?)
						finishMatch(player, won, picks[key], vsBot, stay, result)
					end,
				})
			end
			PadLogic.leave(state, player)
			player:SetAttribute("QueueSeconds", nil)
			player:SetAttribute("InQueue", nil)
		end
		padAcc[padIndex] = nil
		updatePadText(padIndex)
		vsBot = #participants == 1
		-- Bot level for EVERY mode (group modes read participants[1].botLevel): a new player's
		-- first matches get the easy bots; with two humans the weakest level wins.
		local levels: { string } = {}
		for _, part in participants do
			local prof = Profiles.get(part.player)
			if prof then
				table.insert(
					levels,
					BotLevels.levelForPlayer(
						prof.matches,
						prof.wins,
						prof.botLevel,
						FeatureFlags.enabled("botLevelButton"),
						PlayerLevel.view(PlayerLevel.totalXp(prof.progress)).level
					)
				)
			end
		end
		if #levels > 0 then
			local weakest = BotLevels.weakest(levels)
			for _, part in participants do
				part.botLevel = weakest
			end
		end
		deps.startMatch(participants)
	end

	local function registerPick(player: Player, carId: string)
		local ps = players[player]
		if ps == nil or ps.stage ~= "picking" or ps.picked ~= nil then
			return
		end
		ps.picked = carId
		local padIndex = state.playerPad[player]
		if padIndex then
			maybeStart(padIndex)
		end
	end

	local function beginPicking(padIndex: number)
		updatePadText(padIndex) -- bot has joined: 2/2
		for _, key in table.clone(state.pads[padIndex].players) do
			local player = key :: Player
			local ps = players[player]
			local profile = Profiles.get(player)
			if ps == nil or profile == nil then
				cancelPlayer(player)
				continue
			end
			if GameConfig.Mode.useBuild then
				-- Garage build: no picking, you fight with the car in your garage.
				ps.stage = "picking"
				ps.offered = {}
				ps.picked = Build.carFor(profile.build, profile.owned)
				ps.token += 1
				continue
			end
			local ownedCars = Inventory.ownedList(profile)
			local offered = PickChoices.choose(ownedCars, LobbyConfig.PickChoices, rng)
			if #offered == 0 then
				cancelPlayer(player)
				continue
			end
			ps.stage = "picking"
			ps.offered = offered
			ps.picked = nil
			ps.token += 1
			if PadLogic.shouldSkipPick(#ownedCars) then
				-- Fewer than 2 cars owned: nothing to pick, use it (hides the pad countdown too).
				ps.picked = offered[1]
				send(player, { kind = "countdown", seconds = 0 })
				continue
			end
			local token = ps.token
			send(player, { kind = "choices", cars = offered, seconds = padCfg.pickSeconds })
			task.delay(padCfg.pickSeconds, function()
				local cur = players[player]
				if cur and cur.stage == "picking" and cur.token == token then
					local auto = PadLogic.autoPick(cur.offered, rng)
					if auto then
						registerPick(player, auto)
					else
						cancelPlayer(player)
					end
				end
			end)
		end
		maybeStart(padIndex) -- everyone auto-picked (one car owned): go now
	end

	-- Store counter: the server checks everything, then answers with a storeResult.
	local function buyCar(player: Player, carId: any)
		local id = if type(carId) == "string" then carId else ""
		local function fail(reason: string)
			local p = Profiles.get(player)
			send(player, {
				kind = "storeResult",
				ok = false,
				carId = id,
				reason = reason,
				coins = if p then p.coins else 0,
			})
		end
		local ps = players[player]
		if player:GetAttribute("InBattle") == true or (ps and ps.stage ~= "pad") then
			fail("busy")
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			fail("loading")
			return
		end
		local can, reason = Store.canBuy(p, carId)
		if not can then
			fail(reason or "unknown")
			return
		end
		Store.buy(p, id)
		Telemetry.carAcquired(player, "store")
		Profiles.markDirty(player)
		Profiles.saveNow(player)
		send(player, { kind = "storeResult", ok = true, carId = id, coins = p.coins })
		sendProfile(player)
	end

	-- Paint shop: buy a color/sticker, or wear/clear one on an owned car. Lobby only.
	local function paintReply(player: Player, ok: boolean, reason: string?)
		send(player, { kind = "paintResult", ok = ok, reason = reason })
	end

	local function buyPaint(player: Player, id: any)
		local ps = players[player]
		if player:GetAttribute("InBattle") == true or (ps and ps.stage ~= "pad") then
			paintReply(player, false, "busy")
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			paintReply(player, false, "loading")
			return
		end
		local can, reason = Paint.canBuy(p, id)
		if not can then
			paintReply(player, false, reason or "unknown")
			return
		end
		Paint.buy(p, id)
		Profiles.markDirty(player)
		paintReply(player, true, nil)
		sendProfile(player)
	end

	local function equipPaint(player: Player, arg: any)
		local ps = players[player]
		if player:GetAttribute("InBattle") == true or (ps and ps.stage ~= "pad") then
			paintReply(player, false, "busy")
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			paintReply(player, false, "loading")
			return
		end
		if type(arg) ~= "table" then
			paintReply(player, false, "unknown")
			return
		end
		local ok, reason = Paint.equip(p, arg.carId, arg.kind, arg.id)
		if not ok then
			paintReply(player, false, reason or "unknown")
			return
		end
		Profiles.markDirty(player)
		paintReply(player, true, nil)
		sendProfile(player)
	end

	-- Garage: buy / wear parts, level up a slot, pick the car. Lobby only; the server checks all.
	local function buildAction(player: Player, action: string, arg: any)
		local function reply(ok: boolean, reason: string?)
			send(player, { kind = "buildResult", ok = ok, reason = reason })
		end
		local ps = players[player]
		if player:GetAttribute("InBattle") == true or (ps and ps.stage ~= "pad") then
			reply(false, "busy")
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			reply(false, "loading")
			return
		end
		local ok, reason
		if action == "buildBuy" then
			ok, reason = Build.buyPart(p, arg)
		elseif action == "buildEquip" then
			ok, reason = Build.equipPart(p, arg)
		elseif action == "buildUpgrade" then
			ok, reason = Build.upgrade(p, arg)
		else
			ok, reason = Build.setCar(p, arg)
		end
		if ok then
			Profiles.markDirty(player)
		end
		reply(ok, reason)
		sendProfile(player)
	end

	local function onPadTriggered(player: Player, padIndex: number)
		if FeatureFlags.enabled("battleMode") then
			return -- the 1v1 auto-battle replaces the pad fights (BattleService)
		end
		if players[player] ~= nil or Players:GetPlayerByUserId(player.UserId) ~= player then
			return
		end
		if Profiles.get(player) == nil or not nearPad(player, padIndex, 5) then
			return
		end
		local ok = PadLogic.join(state, padIndex, player)
		if not ok then
			return
		end
		players[player] = { stage = "pad", offered = {}, picked = nil, token = 0 }
		Telemetry.padStepped(player)
		updatePadText(padIndex)
		send(player, {
			kind = "countdown",
			seconds = state.pads[padIndex].seconds,
			alone = #state.pads[padIndex].players == 1,
		})
	end

	-- The PLAY button (carter's UI sends action "play"): join the first pad that is still open,
	-- wherever you stand. The fight waits Pad.countdownSeconds for more players, bots fill the rest.
	local function onPlay(player: Player)
		if FeatureFlags.enabled("battleMode") then
			return -- PLAY queues for the 1v1 auto-battle (init.server routes it)
		end
		if players[player] ~= nil or Players:GetPlayerByUserId(player.UserId) ~= player then
			return
		end
		if Profiles.get(player) == nil then
			return
		end
		-- Party up: a pad that already holds a Roblox friend is tried first, so friends land in the
		-- same fight (it stays free-for-all). IsFriendsWith can yield, so look before joining.
		local order: { number } = {}
		for padIndex = 1, #state.pads do
			local withFriend = false
			for _, other in state.pads[padIndex].players do
				local okFriend, isFriend = pcall(function()
					return player:IsFriendsWith((other :: Player).UserId)
				end)
				if okFriend and isFriend then
					withFriend = true
					break
				end
			end
			table.insert(order, if withFriend then 1 else #order + 1, padIndex)
		end
		if players[player] ~= nil then
			return
		end
		for _, padIndex in order do
			if PadLogic.join(state, padIndex, player) then
				players[player] =
					{ stage = "pad", offered = {}, picked = nil, token = 0, queued = true }
				Telemetry.padStepped(player)
				updatePadText(padIndex)
				send(player, {
					kind = "countdown",
					seconds = state.pads[padIndex].seconds,
					alone = #state.pads[padIndex].players == 1,
				})
				return
			end
		end
		send(player, { kind = "countdown", seconds = 0, busy = true }) -- every pad is full right now
	end

	for i, pad in pads do
		local attr = pad.prompt:GetAttribute("PadIndex")
		local index = if type(attr) == "number" and pads[attr] == pad then attr else i
		table.insert(
			conns,
			pad.prompt.Triggered:Connect(function(player: Player)
				onPadTriggered(player, index)
			end)
		)
		updatePadText(index)
	end

	-- Countdown clock + safety checks (player walked away / died / left the character).
	task.spawn(function()
		while running do
			task.wait(LOOP_STEP)
			for player, ps in players do
				if ps.stage ~= "match" then
					local i = state.playerPad[player]
					if i == nil or (not ps.queued and not nearPad(player, i, PAD_LEAVE_EXTRA)) then
						cancelPlayer(player)
					end
				end
			end
			for i, pad in state.pads do
				if pad.phase == "countdown" then
					local acc = (padAcc[i] or 0) + LOOP_STEP
					if acc >= 1 then
						acc -= 1
						local result, secs = PadLogic.tick(state, i)
						if result == "counting" then
							for _, key in pad.players do
								send(key :: Player, {
									kind = "countdown",
									seconds = secs,
									alone = #pad.players == 1,
								})
							end
						elseif result == "ready" then
							beginPicking(i)
						end
					end
					padAcc[i] = acc
				end
			end
		end
	end)

	local function buyGacha(player: Player)
		local ps = players[player]
		if player:GetAttribute("InBattle") == true or (ps and ps.stage ~= "pad") then
			send(player, { kind = "gachaError", reason = "busy" })
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			send(player, { kind = "gachaError", reason = "loading" })
			return
		end
		if claw and claw.busy() then
			send(player, { kind = "gachaError", reason = "busy" })
			return
		end
		local can, reason = Gacha.canBuy(p)
		if not can then
			send(player, { kind = "gachaError", reason = reason or "coins" })
			return
		end
		local r = Gacha.pull(p, rng)
		Telemetry.clawPull(player)
		Telemetry.carAcquired(player, "claw")
		Profiles.markDirty(player)
		Profiles.saveNow(player)
		-- The prize is decided now; the claw machine plays its grab, then the result shows.
		local function reveal()
			if player.Parent == nil then
				return
			end
			send(player, {
				kind = "gacha",
				carId = r.carId,
				isNew = r.isNew,
				refund = r.refund,
				free = r.free,
				coins = p.coins,
				pity = r.pity, -- pulls since the last Epic or better
				pityForced = r.pityForced, -- this was the guaranteed one
			})
			sendProfile(player)
			if LobbyCars.isRarePull(r.carId) then
				-- everyone in the lobby hears about a rare pull (the client shows it in chat)
				remotes.LobbyUpdate:FireAllClients({
					kind = "announce",
					text = `{player.DisplayName} pulled a {LobbyCars.nameOf(r.carId)} from the gumball machine!`,
					carId = r.carId,
				})
			end
		end
		if claw == nil or not claw.play(reveal) then
			reveal()
		end
	end

	-- First-time hint flag: the id must be a known hint; saved so it shows once per player.
	local function hintSeen(player: Player, id: any)
		local p = Profiles.get(player)
		if p ~= nil and Hints.markSeen(p.hintsSeen, id) then
			Profiles.markDirty(player)
			sendProfile(player)
		end
	end

	-- Bot difficulty for solo matches: only the three known names are accepted.
	local function setBotLevel(player: Player, level: any)
		local p = Profiles.get(player)
		if p ~= nil and BotLevels.isValid(level) then
			p.botLevel = level
			Profiles.markDirty(player)
			sendProfile(player)
		end
	end

	-- Session summary card (this visit only). Sent when the client asks with action "summary".
	local function sendSummary(player: Player)
		local p = Profiles.get(player)
		local session = sessions[player] or SessionSummary.new()
		local goalText: string? = nil
		if p then
			goalText = NextGoal.compute({
				matches = p.matches,
				coins = p.coins,
				owned = p.owned,
				modesPlayed = p.progress.modesPlayed,
			}).text
		end
		local message: any = SessionSummary.view(session, goalText)
		message.kind = "summary"
		send(player, message)
	end

	-- Quest reward / daily gift: the server checks everything, repeats pay nothing.
	local function claimQuest(player: Player, index: any)
		local p = Profiles.get(player)
		if
			p ~= nil
			and Quests.claim(p, index, os.time(), function(n)
					Inventory.addCoins(p, n)
				end)
				> 0
		then
			Profiles.markDirty(player)
			sendProfile(player)
		end
	end

	local function claimDaily(player: Player)
		local p = Profiles.get(player)
		if p ~= nil and Daily.claim(p.daily, os.time()) then
			Inventory.addCoins(p, Daily.streakCoins(p.daily))
			player:SetAttribute("LoginStreak", p.daily.streak)
			Profiles.markDirty(player)
			sendProfile(player)
		end
	end

	-- Daily spin: the server rolls. Day is marked used before paying, so repeats pay nothing.
	local function spinWheel(player: Player)
		local p = Profiles.get(player)
		if p == nil or not FeatureFlags.enabled("dailySpin") then
			return
		end
		local result = Spin.spin(p.spin, os.time(), rng, function(n)
			Inventory.addCoins(p, n)
		end, function(n)
			Spin.addFreePulls(p.daily, n)
		end)
		if result ~= nil then
			Profiles.markDirty(player)
			send(player, { kind = "spinResult", index = result.index, label = result.label })
			sendProfile(player)
		end
	end

	local handle: Handle
	handle = {
		onPlayerAdded = function(player: Player)
			charConns[player] = player.CharacterAdded:Connect(function()
				sendProfile(player)
			end)
			task.spawn(function()
				if Profiles.waitFor(player, 30) then
					sendProfile(player)
				end
			end)
		end,
		onPlayerRemoving = function(player: Player)
			players[player] = nil -- a running Match is destroyed by the entry script
			local charConn = charConns[player]
			if charConn then
				charConn:Disconnect()
				charConns[player] = nil
			end
			local padIndex, nowIdle = PadLogic.leave(state, player)
			if padIndex then
				if nowIdle then
					padAcc[padIndex] = nil
				end
				updatePadText(padIndex)
				maybeStart(padIndex) -- the others may all have picked already
			end
			gachaLimiter.clear(player)
			playLimiter.clear(player)
			storeLimiter.clear(player)
			hintLimiter.clear(player)
			botLevelLimiter.clear(player)
			modeLimiter.clear(player)
			modePref[player] = nil
			questLimiter.clear(player)
			summaryLimiter.clear(player)
			sessions[player] = nil
			spinLimiter.clear(player)
			paintLimiter.clear(player)
			buildLimiter.clear(player)
			parking.clear(player)
			bayKeys[player] = nil
		end,
		action = function(player: Player, action: any, arg: any)
			if action == "pickCar" then
				local ps = players[player]
				if ps and ps.stage == "picking" then
					local carId = PadLogic.validatePick(ps.offered, arg)
					if carId then
						registerPick(player, carId)
					end
				end
			elseif action == "pickStarter" then
				-- A new player's first choice: 1 of 3 starter cars (carter).
				local prof = Profiles.get(player)
				if prof and hintLimiter.allow(player, os.clock()) then
					if Inventory.pickStarter(prof, arg) then
						Profiles.markDirty(player)
					end
					sendProfile(player)
				end
			elseif action == "play" then
				if playLimiter.allow(player, os.clock()) then
					onPlay(player)
				end
			elseif action == "cancelPlay" then
				local ps = players[player]
				if ps and ps.queued and ps.stage ~= "match" then
					cancelPlayer(player)
				end
			elseif action == "buyGacha" then
				if gachaLimiter.allow(player, os.clock()) then
					buyGacha(player)
				end
			elseif action == "buyCar" then
				if storeLimiter.allow(player, os.clock()) then
					buyCar(player, arg)
				end
			elseif action == "buyPaint" then
				if FeatureFlags.enabled("paintShop") and paintLimiter.allow(player, os.clock()) then
					buyPaint(player, arg)
				end
			elseif action == "equipPaint" then
				if FeatureFlags.enabled("paintShop") and paintLimiter.allow(player, os.clock()) then
					equipPaint(player, arg)
				end
			elseif
				action == "buildBuy"
				or action == "buildEquip"
				or action == "buildUpgrade"
				or action == "buildCar"
			then
				if buildLimiter.allow(player, os.clock()) then
					buildAction(player, action, arg)
				end
			elseif action == "hintSeen" then
				if hintLimiter.allow(player, os.clock()) then
					hintSeen(player, arg)
				end
			elseif action == "setBotLevel" then
				if botLevelLimiter.allow(player, os.clock()) then
					setBotLevel(player, arg)
				end
			elseif action == "setMode" then
				if modeLimiter.allow(player, os.clock()) and Modes.isPick(arg) then
					modePref[player] = arg
					Telemetry.modePicked(player, arg)
					sendProfile(player)
				end
			elseif action == "claimQuest" then
				if questLimiter.allow(player, os.clock()) then
					claimQuest(player, arg)
				end
			elseif action == "summary" then
				-- Session card: matches, coins and goals since joining, plus the next goal.
				if summaryLimiter.allow(player, os.clock()) then
					sendSummary(player)
				end
			elseif action == "claimDaily" then
				if questLimiter.allow(player, os.clock()) then
					claimDaily(player)
				end
			elseif action == "spin" then
				if spinLimiter.allow(player, os.clock()) then
					spinWheel(player)
				end
			elseif action == "leavePad" then
				cancelPlayer(player)
			end
		end,
		sendProfile = sendProfile,
		leftMatch = function(player: Player)
			local ps = players[player]
			if ps == nil or ps.stage ~= "match" or player.Parent == nil then
				return
			end
			players[player] = nil
			task.spawn(function()
				pcall(function()
					player:LoadCharacter()
				end)
			end)
			send(player, { kind = "toLobby", coinsEarned = 0, won = false, left = true })
			sendProfile(player)
		end,
		stop = function()
			running = false
			parking.destroy()
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(conns)
			for _, c in charConns do
				c:Disconnect()
			end
			table.clear(charConns)
		end,
	}
	return handle
end

return LobbyService
