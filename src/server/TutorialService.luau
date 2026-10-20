--!strict
-- The server side of the first-time tutorial (docs/LOBBY_POLISH.md, L3 L6 L10 L20). The practice
-- drive itself runs on the player's own device; the server only decides what must not be trusted
-- to the client: the saved flags (saved when the tutorial STARTS, so leaving half-way never shows it
-- again), the one-time coin gift, and parking the character while it is away in the yard.
--
-- Actions (LobbyAction, routed here by init.server):
--   tutorialStart  mark the tutorial seen NOW and remember when it began
--   tutorialDone   pay the coin gift once, and not before a real run could have finished
--   practiceEnter  park the character under the lobby (answers "practiceReady" or "practiceRefused")
--   practiceExit   put the character back at the lobby spawn (answers "practiceExited")
-- Every answer is a LobbyUpdate { kind = "tutorial", event = ..., coins = ... }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.TutorialConfig)
local Rules = require(ReplicatedStorage.Shared.TutorialRules)

export type Profile = any -- the saved profile (coins, hintsSeen ...), see Profiles / Inventory

export type Deps = {
	remotes: { LobbyUpdate: RemoteEvent },
	sendProfile: (player: Player) -> (),
	profiles: {
		get: (player: Player) -> Profile?,
		markDirty: (player: Player) -> (),
		saveNow: (player: Player) -> (),
	},
	addCoins: (profile: Profile, coins: number) -> (),
	pads: { park: (player: Player) -> (), toSpawn: (player: Player) -> () },
	isBusy: (player: Player) -> boolean, -- queued or fighting
	now: (() -> number)?, -- seconds (os.clock); the tests pass a fake one
	-- analytics (Telemetry.tutorial): tutorial_start, tutorial_practice, tutorial_done
	track: ((player: Player, name: string, data: { [string]: any }?) -> ())?,
}

export type Handle = {
	action: (player: Player, action: any, arg: any) -> boolean, -- true when it was a tutorial action
	remove: (player: Player) -> (), -- the player left the game
}

local TutorialService = {}

function TutorialService.start(deps: Deps): Handle
	local now = deps.now or os.clock
	local startedAt: { [Player]: number } = {}
	local practicing: { [Player]: number } = {} -- the token of the current practice
	local practiceSince: { [Player]: number } = {}
	local tokens = 0

	local function track(player: Player, name: string, data: { [string]: any }?)
		if deps.track ~= nil then
			deps.track(player, name, data)
		end
	end

	local function tell(player: Player, event: string, coins: number?)
		deps.remotes.LobbyUpdate:FireClient(
			player,
			{ kind = "tutorial", event = event, coins = coins }
		)
	end

	local function start(player: Player)
		local p = deps.profiles.get(player)
		if p == nil then
			return
		end
		startedAt[player] = now()
		local first = Rules.markStart(p.hintsSeen)
		if first then
			deps.profiles.markDirty(player)
			-- saved at once: a player who leaves a moment later must never see the tutorial again
			deps.profiles.saveNow(player)
			deps.sendProfile(player)
		end
		track(player, "tutorial_start", { first = first })
	end

	local function done(player: Player)
		local p = deps.profiles.get(player)
		if p == nil then
			return
		end
		local ok = Rules.canGift(p.hintsSeen, startedAt[player], now())
		local began = startedAt[player]
		track(player, "tutorial_done", { seconds = if began then now() - began else 0, gift = ok })
		if not ok then
			tell(player, "gift", 0)
			return
		end
		Rules.markGift(p.hintsSeen)
		deps.addCoins(p, Config.giftCoins)
		deps.profiles.markDirty(player)
		deps.profiles.saveNow(player)
		deps.sendProfile(player)
		tell(player, "gift", Config.giftCoins)
	end

	local function leaveYard(player: Player)
		if practicing[player] == nil then
			return
		end
		practicing[player] = nil
		local since = practiceSince[player]
		practiceSince[player] = nil
		if since ~= nil then
			track(player, "tutorial_practice", { seconds = now() - since })
		end
		deps.pads.toSpawn(player)
	end

	local function enter(player: Player)
		local busy = deps.isBusy(player) or player:GetAttribute("InBattle") == true
		if startedAt[player] == nil or not Rules.mayPractice(busy, practicing[player] ~= nil) then
			tell(player, "practiceRefused")
			return
		end
		tokens += 1
		local token = tokens
		practicing[player] = token
		practiceSince[player] = now()
		deps.pads.park(player)
		tell(player, "practiceReady")
		-- the device ends the practice by itself; if it never says so, the character comes back anyway
		task.delay(Config.practiceMaxSeconds + Config.serverPracticeGraceSeconds, function()
			if practicing[player] == token then
				leaveYard(player)
				tell(player, "practiceExited")
			end
		end)
	end

	local function exit(player: Player)
		leaveYard(player)
		tell(player, "practiceExited")
	end

	local handle = {} :: Handle

	handle.action = function(player: Player, action: any, _arg: any): boolean
		if action == "tutorialStart" then
			start(player)
		elseif action == "tutorialDone" then
			done(player)
		elseif action == "practiceEnter" then
			enter(player)
		elseif action == "practiceExit" then
			exit(player)
		else
			return false
		end
		return true
	end

	handle.remove = function(player: Player)
		local since = practiceSince[player]
		if since ~= nil then
			track(player, "tutorial_practice", { seconds = now() - since }) -- left while in the yard
		end
		startedAt[player] = nil
		practicing[player] = nil
		practiceSince[player] = nil
	end

	return handle
end

return TutorialService
