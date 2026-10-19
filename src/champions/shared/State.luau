-- Presentation validation is not a security boundary. The server owns all account changes.
local Config = require(script.Parent.Config)
local State = {}
local modes = {}
for _, mode in Config.Modes do
	modes[mode.Id] = true
end
local rarityCounts = {}
for _, car in Config.Vehicles do
	rarityCounts[car.Rarity] = (rarityCounts[car.Rarity] or 0) + 1
end

local function number(value, fallback, minimum, maximum, integer)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	value = math.clamp(value, minimum or 0, maximum or 1e12)
	return integer == false and value or math.floor(value)
end

local function text(value, fallback)
	return type(value) == "string" and string.sub(value, 1, 256) or fallback
end

local function carId(value)
	return type(value) == "string" and Config.ById[value] and value or nil
end

local function settings(source)
	source = type(source) == "table" and source or {}
	return {
		music = source.music ~= false,
		sfx = source.sfx ~= false,
		reducedMotion = source.reducedMotion == true,
	}
end

local function odds(source)
	local result, seen, total = {}, {}, 0
	local valid = type(source) == "table" and #source > 0 and #source <= 4
	if valid then
		for _, entry in source do
			if type(entry) ~= "table" or not rarityCounts[entry.Rarity] or seen[entry.Rarity] then
				valid = false
				break
			end
			local chance = number(entry.Chance, nil, 0, 100, false)
			local each = number(entry.PerCar, nil, 0, 100, false)
			if
				not chance
				or (each and math.abs(each - chance / rarityCounts[entry.Rarity]) > 0.0001)
			then
				valid = false
				break
			end
			table.insert(result, {
				Rarity = entry.Rarity,
				Chance = chance,
				PerCar = chance / rarityCounts[entry.Rarity],
			})
			total += chance
			seen[entry.Rarity] = true
		end
		valid = valid and math.abs(total - 100) < 0.0001
	end
	if valid then
		return result
	end
	result = {}
	for _, entry in Config.ClawOdds do
		table.insert(
			result,
			{ Rarity = entry.Rarity, Chance = entry.Chance, PerCar = entry.PerCar }
		)
	end
	return result
end

local function result(source)
	if type(source) ~= "table" then
		return nil
	end
	local value = {
		won = source.won == true,
		place = number(source.place, nil, 1, 100),
		mode = modes[source.mode] and source.mode or "DUEL",
		total = number(source.total),
		rewards = {},
	}
	if type(source.rewards) == "table" then
		for index, reward in source.rewards do
			if index > 12 then
				break
			end
			if type(reward) == "table" then
				table.insert(
					value.rewards,
					{ label = text(reward.label, "REWARD"), amount = number(reward.amount, 0) }
				)
			end
		end
	end
	return value
end

local function match(source)
	if type(source) ~= "table" then
		return nil
	end
	local value = {
		mode = modes[source.mode] and source.mode or "DUEL",
		phase = text(source.phase, "WAITING"),
	}
	for _, key in
		{
			"timer",
			"endsAt",
			"blueScore",
			"redScore",
			"youScore",
			"rivalScore",
			"lap",
			"place",
			"totalPlayers",
			"fuse",
			"fuseEndsAt",
			"carsLeft",
			"hp",
			"hpMax",
			"goalUntil",
			"boostEndsAt",
			"boostDuration",
			"abilityEndsAt",
			"abilityDuration",
			"round",
		}
	do
		value[key] = number(source[key], nil, 0, 1e12, false)
	end
	for _, key in { "isIt", "spectating", "stuck", "goal", "suddenDeath" } do
		value[key] = source[key] == true
	end
	if type(source.goal) == "string" then
		value.goal = text(source.goal)
	end
	for _, key in { "itName", "watching" } do
		value[key] = text(source[key])
	end
	value.result = result(source.result)
	return value
end

function State.normalize(snapshot)
	local present = type(snapshot) == "table"
	local source = present and snapshot or {}
	local value = {
		ready = present and (source.ready == nil or source.ready == true),
		coins = number(source.coins),
		level = number(source.level, 1, 1),
		xp = number(source.xp, 0),
		xpGoal = number(source.xpGoal, 1, 1),
		owned = {},
		equipped = carId(source.equipped),
		mode = modes[source.mode] and source.mode or "DUEL",
		selection = carId(source.selection) or carId(source.equipped) or Config.Vehicles[1].Id,
		filter = "ALL",
		pickerOptions = {},
		settings = settings(source.settings),
		prices = {},
		dailyReady = source.dailyReady == true,
		dailyNextAt = number(source.dailyNextAt, nil, 0, 1e12, false),
		dailyGift = number(source.dailyGift, Config.DailyGift),
		duplicateRefund = number(source.duplicateRefund, Config.DuplicateRefund),
		clawPrice = number(source.clawPrice, Config.ClawPrice),
		clawOdds = odds(source.clawOdds),
		match = match(source.match),
		result = result(source.result),
		pending = type(source.pending) == "string" and text(source.pending)
			or (source.pending == true and "Pending" or nil),
		previousScreen = text(source.previousScreen),
	}
	if
		source.filter == "ALL"
		or source.filter == "OWNED"
		or source.filter == "LOCKED"
		or rarityCounts[source.filter]
	then
		value.filter = source.filter
	end
	if type(source.owned) == "table" then
		for id, owned in source.owned do
			if carId(id) and type(owned) == "boolean" then
				value.owned[id] = owned
			end
		end
	end
	if type(source.prices) == "table" then
		for id, price in source.prices do
			if carId(id) then
				value.prices[id] = number(price)
			end
		end
	end
	if type(source.pickerOptions) == "table" then
		local seen = {}
		for _, id in source.pickerOptions do
			if #value.pickerOptions == 3 then
				break
			end
			if carId(id) and not seen[id] then
				table.insert(value.pickerOptions, id)
				seen[id] = true
			end
		end
	end
	if type(source.queue) == "table" then
		value.queue = {
			pad = text(source.queue.pad),
			count = number(source.queue.count, 0, 0, 100),
			status = text(source.queue.status, "WAITING"),
		}
	end
	if type(source.reveal) == "table" and carId(source.reveal.vehicleId) then
		value.reveal = {
			vehicleId = source.reveal.vehicleId,
			duplicate = source.reveal.duplicate == true,
			refund = number(source.reveal.refund, value.duplicateRefund),
		}
	end
	if type(source.confirm) == "table" then
		local confirm = source.confirm
		local payload = type(confirm.payload) == "table" and confirm.payload or {}
		value.confirm = {
			action = text(confirm.action),
			payload = {
				vehicleId = carId(payload.vehicleId),
				mode = modes[payload.mode] and payload.mode or nil,
			},
			title = text(confirm.title),
			body = text(confirm.body),
			returnScreen = text(confirm.returnScreen),
		}
	end
	return value
end

local activePhases = {
	ACTIVE = true,
	PLAYING = true,
	LIVE = true,
	RACING = true,
	MATCH = true,
	OVERTIME = true,
	SUDDEN_DEATH = true,
}

-- A nil route preserves the current view. Only authoritative snapshot changes
-- and fulfilled intents can dismiss a menu; rendering never commits an action.
function State.route(prior, nextState, currentScreen, activeIntent)
	prior = type(prior) == "table" and prior or {}
	nextState = type(nextState) == "table" and nextState or {}
	local before, after = prior.match, nextState.match
	local hadResult = prior.result or (before and before.result)
	local hasResult = nextState.result or (after and after.result)
	if hasResult and not hadResult then
		return "RESULTS"
	end
	if before and not after then
		return "LOBBY"
	end
	if after and (not before or before.phase ~= after.phase) then
		-- An unchanged completed result must not pull the user out of settings.
		if not (currentScreen == "SETTINGS" and hadResult and hasResult) then
			if hasResult or after.phase == "RESULTS" or after.phase == "ENDED" then
				return "RESULTS"
			end
			return "MATCH"
		end
	end
	-- A starter pick that already went through: nothing left to choose, leave the picker.
	if
		currentScreen == "PICKER"
		and not after
		and #(nextState.pickerOptions or {}) == 0
		and nextState.equipped
		and not nextState.pending
	then
		return "LOBBY"
	end
	if nextState.pending or type(activeIntent) ~= "table" then
		return nil
	end
	local action = activeIntent.action
	local payload = type(activeIntent.payload) == "table" and activeIntent.payload or {}
	local id = carId(payload.vehicleId)
	if action == "BuyCar" and id and (nextState.owned or {})[id] == true then
		return activeIntent.returnScreen or "SHOP"
	elseif
		action == "ChooseCar"
		and id
		and (nextState.equipped == id or nextState.selection == id)
	then
		return after and "MATCH" or "LOBBY"
	elseif action == "SetMode" and modes[payload.mode] and nextState.mode == payload.mode then
		return after and "MATCH" or "LOBBY"
	elseif action == "LeaveMatch" and not after then
		return "LOBBY"
	end
	return nil
end

function State.validateAction(state, action, payload, now)
	state = type(state) == "table" and state or {}
	payload = type(payload) == "table" and payload or {}
	local current = state.match
	if action == "LeaveMatch" then
		if current or state.result then
			return {}
		end
		return nil, "No match to leave."
	end
	if action == "SpectateNext" or action == "SpectatePrevious" then
		if current and current.spectating then
			return {}
		end
		return nil, "Spectator controls are unavailable."
	end
	if not state.ready then
		return nil, "Waiting for player data."
	end
	if state.pending then
		return nil, "Wait for the current action to finish."
	end
	if action == "EquipCar" or action == "ChooseCar" or action == "BuyCar" then
		local id = carId(payload.vehicleId)
		if not id then
			return nil, "Unknown car."
		end
		if action == "EquipCar" and not (state.owned or {})[id] then
			return nil, "You do not own this car."
		end
		if action == "ChooseCar" and not table.find(state.pickerOptions or {}, id) then
			return nil, "Choose one of the offered cars."
		end
		if action == "BuyCar" then
			if (state.owned or {})[id] then
				return nil, "You already own this car."
			end
			local price = (state.prices or {})[id] or Config.ById[id].Price
			if state.coins == nil or state.coins < price then
				return nil, "Not enough coins."
			end
		end
		return { vehicleId = id }
	elseif action == "PullClaw" then
		if state.coins == nil or state.coins < (state.clawPrice or Config.ClawPrice) then
			return nil, "Not enough coins."
		end
		return {}
	elseif action == "ClaimGift" then
		if not state.dailyReady then
			return nil, "Your next gift is not ready."
		end
		if state.dailyNextAt and state.dailyNextAt > number(now, 0, 0, 1e12, false) then
			return nil, "Your next gift is not ready."
		end
		return {}
	elseif action == "Play" then
		if current or state.queue then
			return nil, "You are already in line."
		end
		return {}
	elseif action == "CancelPlay" then
		if not state.queue then
			return nil, "You are not in line."
		end
		return {}
	elseif action == "SetMode" then
		if not modes[payload.mode] then
			return nil, "Unknown game mode."
		end
		return { mode = payload.mode }
	elseif action == "SaveSettings" then
		local updated, changed = settings(state.settings), false
		for _, key in { "music", "sfx", "reducedMotion" } do
			if payload[key] ~= nil then
				if type(payload[key]) ~= "boolean" then
					return nil, "Settings must use true or false."
				end
				updated[key] = payload[key]
				changed = true
			end
		end
		if not changed then
			return nil, "No settings supplied."
		end
		return updated
	elseif action == "Rematch" then
		if
			state.result
			or (
				current
				and (current.result or current.phase == "RESULTS" or current.phase == "ENDED")
			)
		then
			return {}
		end
		return nil, "Finish this match first."
	elseif action == "Boost" or action == "Ability" or action == "ResetCar" then
		if
			not current
			or current.spectating
			or not activePhases[string.upper(current.phase or "")]
		then
			return nil, "This control needs an active match."
		end
		if action == "ResetCar" then
			if not current.stuck then
				return nil, "Reset is only available when stuck."
			end
		else
			local endsAt = current.abilityEndsAt
			if action == "Boost" then
				endsAt = current.boostEndsAt
			end
			if endsAt and endsAt > number(now, 0, 0, 1e12, false) then
				return nil, "This control is cooling down."
			end
		end
		return {}
	end
	return nil, "Unsupported action."
end

return State
