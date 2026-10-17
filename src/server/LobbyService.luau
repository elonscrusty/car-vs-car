--!strict
-- Lobby brain (server only). Pads -> countdown -> bot fills -> pick 1 of 3 owned cars -> match
-- -> rewards -> back to lobby. Also rolls the gacha and keeps clients' profile HUD in sync.
-- The server decides everything: clients only say "pickCar", "buyGacha" or "leavePad".
-- The pad rules live in the pure module PadLogic (unit tested).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gacha = require(ReplicatedStorage.Shared.Gacha)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local PadLogic = require(ReplicatedStorage.Shared.PadLogic)
local PickChoices = require(ReplicatedStorage.Shared.PickChoices)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)

-- Only the parts of the lobby handle we use (see docs/LOBBY_CONTRACT.md).
export type PadHandle = {
	part: BasePart,
	prompt: ProximityPrompt,
	setStatus: (text: string) -> (),
}
export type LobbyHandle = {
	spawn: SpawnLocation,
	pads: { PadHandle },
	folder: Folder,
}

export type Deps = {
	lobby: LobbyHandle,
	remotes: Remotes.RemoteSet,
	-- Create a Match for this player; call onFinished(won) when its end screen is over.
	startMatch: (player: Player, carId: string, onFinished: (won: boolean) -> ()) -> (),
}

export type Handle = {
	onPlayerAdded: (player: Player) -> (),
	onPlayerRemoving: (player: Player) -> (),
	action: (player: Player, action: any, arg: any) -> (),
	stop: () -> (),
}

type Stage = "pad" | "picking" | "match"
type PlayerState = {
	stage: Stage,
	offered: { string },
	token: number, -- bumps whenever the pick phase ends so old timeouts do nothing
}

local LobbyService = {}

local PAD_LEAVE_EXTRA = 10 -- studs past the prompt distance before we cancel
local LOOP_STEP = 0.25

function LobbyService.start(deps: Deps): Handle
	local remotes = deps.remotes
	local pads = deps.lobby.pads
	local padCfg = LobbyConfig.Pad
	local state = PadLogic.new(#pads, padCfg.maxPlayers, padCfg.countdownSeconds)
	local players: { [Player]: PlayerState } = {}
	local padAcc: { [number]: number } = {}
	local random = Random.new()
	local rng = function(): number
		return random:NextNumber()
	end
	local gachaLimiter = RateLimiter.new(2, 3)
	local running = true
	local conns: { RBXScriptConnection } = {}

	local function send(player: Player, update: Types.LobbyUpdate)
		if player.Parent ~= nil then
			remotes.LobbyUpdate:FireClient(player, update)
		end
	end

	local function sendProfile(player: Player)
		local p = Profiles.get(player)
		if p == nil then
			return
		end
		send(player, {
			kind = "profile",
			coins = p.coins,
			wins = p.wins,
			owned = Inventory.ownedList(p),
			freePullAvailable = LobbyConfig.Gacha.firstPullFree and not p.freePullUsed,
		})
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
		end
		send(player, { kind = "countdown", seconds = 0 })
	end

	local function finishMatch(player: Player, won: boolean)
		local ps = players[player]
		if ps == nil or ps.stage ~= "match" then
			return
		end
		players[player] = nil
		local earned = if won then LobbyConfig.Rewards.winCoins else LobbyConfig.Rewards.loseCoins
		local p = Profiles.get(player)
		if p then
			Inventory.addCoins(p, earned)
			if won then
				p.wins += 1
			end
			Profiles.markDirty(player)
		end
		if player.Parent == nil then
			return
		end
		-- Fresh character at the lobby spawn.
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
		send(player, { kind = "toLobby", coinsEarned = earned, won = won })
		sendProfile(player)
	end

	local function startPlayerMatch(player: Player, carId: string)
		local ps = players[player]
		if ps == nil or ps.stage ~= "picking" then
			return
		end
		ps.stage = "match"
		ps.token += 1
		ps.offered = {}
		local padIndex = PadLogic.leave(state, player)
		if padIndex then
			updatePadText(padIndex)
		end
		deps.startMatch(player, carId, function(won: boolean)
			finishMatch(player, won)
		end)
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
			local offered =
				PickChoices.choose(Inventory.ownedList(profile), LobbyConfig.PickChoices, rng)
			if #offered == 0 then
				cancelPlayer(player)
				continue
			end
			ps.stage = "picking"
			ps.offered = offered
			ps.token += 1
			local token = ps.token
			send(player, { kind = "choices", cars = offered, seconds = padCfg.pickSeconds })
			task.delay(padCfg.pickSeconds, function()
				local cur = players[player]
				if cur and cur.stage == "picking" and cur.token == token then
					local auto = PadLogic.autoPick(cur.offered, rng)
					if auto then
						startPlayerMatch(player, auto)
					else
						cancelPlayer(player)
					end
				end
			end)
		end
	end

	local function onPadTriggered(player: Player, padIndex: number)
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
		players[player] = { stage = "pad", offered = {}, token = 0 }
		updatePadText(padIndex)
		send(player, { kind = "countdown", seconds = state.pads[padIndex].seconds })
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
					if i == nil or not nearPad(player, i, PAD_LEAVE_EXTRA) then
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
								send(key :: Player, { kind = "countdown", seconds = secs })
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
		if ps and ps.stage ~= "pad" then
			send(player, { kind = "gachaError", reason = "busy" })
			return
		end
		local p = Profiles.get(player)
		if p == nil then
			send(player, { kind = "gachaError", reason = "loading" })
			return
		end
		local can, reason = Gacha.canBuy(p)
		if not can then
			send(player, { kind = "gachaError", reason = reason or "coins" })
			return
		end
		local r = Gacha.pull(p, rng)
		Profiles.markDirty(player)
		send(player, {
			kind = "gacha",
			carId = r.carId,
			isNew = r.isNew,
			refund = r.refund,
			free = r.free,
			coins = p.coins,
		})
		sendProfile(player)
	end

	local handle: Handle
	handle = {
		onPlayerAdded = function(player: Player)
			table.insert(
				conns,
				player.CharacterAdded:Connect(function()
					sendProfile(player)
				end)
			)
			task.spawn(function()
				if Profiles.waitFor(player, 30) then
					sendProfile(player)
				end
			end)
		end,
		onPlayerRemoving = function(player: Player)
			players[player] = nil -- a running Match is destroyed by the entry script
			local padIndex, nowIdle = PadLogic.leave(state, player)
			if padIndex then
				if nowIdle then
					padAcc[padIndex] = nil
				end
				updatePadText(padIndex)
			end
			gachaLimiter.clear(player)
		end,
		action = function(player: Player, action: any, arg: any)
			if action == "pickCar" then
				local ps = players[player]
				if ps and ps.stage == "picking" then
					local carId = PadLogic.validatePick(ps.offered, arg)
					if carId then
						startPlayerMatch(player, carId)
					end
				end
			elseif action == "buyGacha" then
				if gachaLimiter.allow(player, os.clock()) then
					buyGacha(player)
				end
			elseif action == "leavePad" then
				cancelPlayer(player)
			elseif action == "devMatch" and RunService:IsStudio() then
				-- Studio-only shortcut: skip pads, fight the bot now with a random owned car.
				local cur = players[player]
				if cur and cur.stage == "match" then
					return
				end
				local p = Profiles.get(player)
				local owned = if p then Inventory.ownedList(p) else { "Heavy" }
				local carId = owned[math.random(1, #owned)] or "Heavy"
				cancelPlayer(player)
				players[player] = { stage = "picking", offered = { carId }, token = 0 }
				startPlayerMatch(player, carId)
			end
		end,
		stop = function()
			running = false
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(conns)
		end,
	}
	return handle
end

return LobbyService
