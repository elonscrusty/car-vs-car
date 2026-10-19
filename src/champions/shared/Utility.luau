-- Native menu presentation only. All account changes go through the controller.
local T = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local Utility = {}

local function busy(state, ctx)
	return not state.ready
		or (state.pending ~= nil and state.pending ~= false)
		or ctx.pending == true
end

local function action(parent, name, label, x, y, w, h, state, ctx, enabled, callback, color, icon)
	local blocked = busy(state, ctx) or not enabled
	local button = T.button(parent, name, label, x, y, w, h, function()
		if not blocked then
			callback()
		end
	end, color, icon)
	T.disable(button, blocked)
	return button
end

local function back(state, ctx)
	local target = state.confirm and state.confirm.returnScreen or state.previousScreen
	if target and target ~= "CONFIRM" then
		ctx.navigate(target)
	else
		ctx.close()
	end
end

local function title(parent, value, subtitle)
	T.text(parent, "Title", value, 124, 104, 950, 55, 39, T.C.white, "Center")
	if subtitle then
		T.text(parent, "Subtitle", subtitle, 124, 158, 950, 30, 22, T.C.silver, "Center")
	end
end

local function countdown(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format(
		"%02d:%02d:%02d",
		math.floor(seconds / 3600),
		math.floor(seconds / 60) % 60,
		seconds % 60
	)
end

local modeDetails = {
	SOCCER = { icon = "soccer", color = "cyan", strap = "3v3  •  BOOST PADS" },
	TAG = { icon = "tag", color = "red", strap = "BUMP TO PASS IT" },
	RACE = { icon = "flag", color = "gold", strap = "6 CARS  •  3 LAPS" },
	DUEL = { icon = "duel", color = "purple", strap = "4 CARS  •  LAST ONE ALIVE" },
}

local function modes(root, state, ctx)
	title(root, "CHOOSE YOUR MODE")
	local selected = state.mode or "DUEL"
	local selectionLabels, selectedChecks = {}, {}
	local selectedLabel = T.text(
		root,
		"SelectedMode",
		"SELECTED: " .. selected,
		56,
		527,
		486,
		48,
		25,
		T.C.cyan,
		"Center"
	)
	for index, mode in Config.Modes do
		local detail = modeDetails[mode.Id] or modeDetails.RACE
		local accent = T.C[detail.color]
		local x, y = 58 + ((index - 1) % 2) * 554, 175 + math.floor((index - 1) / 2) * 171
		local card = T.panel(root, "ModeCard_" .. mode.Id, x, y, 530, 156, accent)
		card.ClipsDescendants = true
		T.frame(card, "ArenaStripe", 0, 114, 530, 42, T.C.navy, 0)
		T.checkers(card, 423, 8, 91, 30, 10, accent)
		T.icon(card, "ModeIllustration", detail.icon, 20, 15, 76, accent)
		-- Artwork stays native to the shared atlas, avoiding flattened screenshot controls.
		local car = Config.Vehicles[((index - 1) * 3) % #Config.Vehicles + 1]
		T.vehicle(card, "ModeCar", car, 325, -10, 205, 130)
		T.text(card, "ModeTitle", mode.Name, 110, 15, 209, 45, 35, T.C.white)
		T.text(card, "ModeDescription", mode.Description, 111, 61, 208, 38, 16, T.C.muted)
		selectionLabels[mode.Id] = T.text(
			card,
			"SelectionState",
			selected == mode.Id and "SELECTED" or detail.strap,
			19,
			119,
			389,
			26,
			17,
			accent
		)
		selectedChecks[mode.Id] = T.icon(card, "SelectedCheck", "check", 466, 108, 38, T.C.green)
		selectedChecks[mode.Id].Visible = selected == mode.Id
		local hit = T.button(card, "Mode_" .. mode.Id, "", 0, 0, 530, 156, function()
			if busy(state, ctx) then
				return
			end
			selected = mode.Id
			selectedLabel.Text = "SELECTED: " .. selected
			for _, item in Config.Modes do
				selectedChecks[item.Id].Visible = item.Id == selected
				selectionLabels[item.Id].Text = item.Id == selected and "SELECTED"
					or (modeDetails[item.Id] or modeDetails.RACE).strap
			end
		end, T.C.navy)
		hit.BackgroundTransparency = 1
		-- Keep illustrations unobscured; the native button supplies the full-card hit target.
		for _, child in hit:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
		T.disable(hit, busy(state, ctx))
	end
	action(root, "ConfirmMode", "CONFIRM MODE", 614, 527, 528, 52, state, ctx, true, function()
		ctx.request("SetMode", { mode = selected })
	end, T.C.blue, "check")
end

local function gift(root, state, ctx)
	title(root, "DAILY GIFT", "A LITTLE FUEL FOR YOUR NEXT CHAMPION")
	local panel = T.panel(root, "GiftPanel", 122, 197, 956, 375, T.C.cyan)
	T.panel(panel, "GiftStage", 18, 17, 367, 253, T.C.blue)
	T.checkers(panel, 39, 223, 322, 28, 14, T.C.silver)
	T.icon(panel, "GiftIllustration", "gift", 101, 47, 202, T.C.red)
	T.icon(panel, "GiftCoin", "coin", 413, 35, 69, T.C.gold)
	local amount = state.dailyGift or Config.DailyGift
	T.text(panel, "GiftAmount", "+" .. T.format(amount) .. " COINS", 499, 35, 421, 68, 43, T.C.gold)
	T.text(
		panel,
		"GiftFrequency",
		"ONE GIFT EVERY 24 HOURS",
		414,
		113,
		501,
		38,
		21,
		T.C.white,
		"Center"
	)
	local ready = state.dailyReady == true
	local wait = math.max(0, (state.dailyNextAt or 0) - T.monoTime())
	local label = state.pending == "ClaimGift" and "CLAIMING…"
		or (ready and "CLAIM  " .. T.format(amount) or "COME BACK LATER")
	action(panel, "ClaimGift", label, 414, 162, 500, 72, state, ctx, ready, function()
		ctx.request("ClaimGift")
	end, ready and T.C.green or T.C.navy, "gift")
	local status = T.text(
		panel,
		"DailyCountdown",
		ready and "READY TO CLAIM" or ("NEXT GIFT IN " .. countdown(wait)),
		414,
		240,
		500,
		28,
		18,
		ready and T.C.green or T.C.muted,
		"Center"
	)
	status:SetAttribute("DailyNextAt", state.dailyNextAt)
	-- Decorative gift markers do not imply an unsupported escalating streak reward.
	for day = 1, 7 do
		local marker = T.panel(
			panel,
			"GiftDay" .. day,
			20 + (day - 1) * 131,
			286,
			119,
			69,
			day == 1 and T.C.cyan or T.C.silver
		)
		T.icon(marker, "Gift", "gift", 11, 13, 38, day == 1 and T.C.gold or T.C.muted)
		T.text(marker, "Day", "DAY " .. day, 53, 20, 62, 27, 15, T.C.white)
	end
end

local function representative(rarity)
	for _, vehicle in Config.Vehicles do
		if string.upper(vehicle.Rarity) == string.upper(rarity) then
			return vehicle
		end
	end
	return Config.Vehicles[1]
end

local function confirmation(root, state, ctx)
	local confirm = state.confirm or {}
	if confirm.action == "LeaveMatch" then
		title(root, confirm.title or "RETURN TO LOBBY?")
		local panel = T.panel(root, "LeaveConfirmationPanel", 186, 195, 828, 354, T.C.silver)
		T.icon(panel, "LeaveIcon", "back", 363, 25, 102, T.C.cyan)
		T.text(
			panel,
			"ConfirmationBody",
			confirm.body or "Leave the current match and return to the garage.",
			53,
			148,
			722,
			83,
			27,
			T.C.white,
			"Center"
		)
		T.button(panel, "CancelPurchase", "CANCEL", 30, 270, 368, 61, function()
			back(state, ctx)
		end, T.C.blue, "back")
		-- Leaving remains available while player data loads or another request is pending.
		local leave = T.button(
			panel,
			"ConfirmPurchase",
			"RETURN TO LOBBY",
			430,
			270,
			368,
			61,
			function()
				if state.match then
					ctx.request(confirm.action, confirm.payload or {})
				end
			end,
			T.C.red,
			"close"
		)
		T.disable(leave, state.match == nil)
		return
	end
	local vehicle = confirm.payload and Config.ById[confirm.payload.vehicleId]
	local claw = confirm.action == "PullClaw"
	local valid = claw or (confirm.action == "BuyCar" and vehicle ~= nil)
	local price = claw and (state.clawPrice or Config.ClawPrice)
		or (vehicle and ((state.prices or {})[vehicle.Id] or vehicle.Price) or 0)
	local coins = state.coins or 0
	title(root, confirm.title or "CONFIRM PURCHASE")
	local panel = T.panel(root, "ConfirmationPanel", 186, 170, 828, 406, T.C.silver)
	T.icon(panel, "SpendCoin", "coin", 132, 16, 48, T.C.gold)
	T.text(
		panel,
		"SpendTitle",
		if price == 0 then "FREE PULL!" else "SPEND " .. T.format(price) .. " COINS?",
		194,
		15,
		591,
		51,
		31,
		T.C.gold
	)
	local before = T.panel(panel, "BeforePanel", 35, 78, 329, 75, T.C.blue)
	T.text(before, "Label", "BALANCE BEFORE", 12, 6, 305, 23, 17, T.C.muted, "Center")
	T.text(before, "BalanceBefore", T.format(coins), 12, 31, 305, 36, 29, T.C.white, "Center")
	T.text(panel, "BalanceArrow", ">", 377, 89, 74, 54, 41, T.C.cyan, "Center")
	local after = T.panel(panel, "AfterPanel", 464, 78, 329, 75, T.C.blue)
	T.text(after, "Label", "BALANCE AFTER", 12, 6, 305, 23, 17, T.C.muted, "Center")
	T.text(
		after,
		"BalanceAfter",
		T.format(coins - price),
		12,
		31,
		305,
		36,
		29,
		coins >= price and T.C.gold or T.C.red,
		"Center"
	)
	if claw then
		local odds = state.clawOdds or Config.ClawOdds
		T.text(
			panel,
			"OddsTitle",
			"PULL ODDS  •  " .. #Config.Vehicles .. " CARS TOTAL",
			30,
			159,
			768,
			29,
			22,
			T.C.white,
			"Center"
		)
		local width = (768 - (#odds - 1) * 10) / math.max(1, #odds)
		for index, odd in odds do
			local rarityColor = Config.RarityColors[odd.Rarity] or T.C.silver
			local cell = T.panel(
				panel,
				"Odds_" .. odd.Rarity,
				30 + (index - 1) * (width + 10),
				195,
				width,
				119,
				rarityColor
			)
			T.text(
				cell,
				"Rarity",
				string.upper(odd.Rarity),
				4,
				3,
				width - 8,
				24,
				16,
				rarityColor,
				"Center"
			)
			T.text(
				cell,
				"Chance",
				tostring(odd.Chance) .. "%",
				4,
				28,
				width - 8,
				30,
				27,
				T.C.white,
				"Center"
			)
			T.text(
				cell,
				"PerCar",
				tostring(odd.PerCar) .. "% EACH",
				4,
				61,
				width - 8,
				18,
				12,
				T.C.muted,
				"Center"
			)
			T.vehicle(cell, "ExampleCar", representative(odd.Rarity), 17, 75, width - 34, 43)
		end
		T.text(
			panel,
			"RefundPolicy",
			"DUPLICATE CAR: " .. Config.RefundText .. " COINS BACK",
			30,
			320,
			768,
			27,
			18,
			T.C.gold,
			"Center"
		)
	else
		if vehicle then
			T.vehicle(panel, "PurchaseCar", vehicle, 36, 165, 297, 170)
			T.text(panel, "PurchaseName", vehicle.Name, 361, 178, 419, 43, 31, T.C.white)
			T.rarity(panel, vehicle, 363, 231, 192, 30)
		end
		T.text(
			panel,
			"PurchaseBody",
			confirm.body or "Add this car to your collection.",
			363,
			269,
			413,
			54,
			18,
			T.C.muted
		)
	end
	local enabled = valid and coins >= price and (claw or not (state.owned or {})[vehicle.Id])
	local label = state.pending and "PROCESSING…"
		or (
			coins < price and "NEED MORE COINS"
			or (price == 0 and "FREE PULL" or "SPEND " .. T.format(price))
		)
	T.button(panel, "CancelPurchase", "CANCEL", 30, 351, 368, 49, function()
		back(state, ctx)
	end, T.C.red, "close")
	action(panel, "ConfirmPurchase", label, 430, 351, 368, 49, state, ctx, enabled, function()
		ctx.request(confirm.action, confirm.payload)
	end, T.C.green, "coin")
end

local function reveal(root, state, ctx)
	local result = state.reveal or {}
	local vehicle = Config.ById[result.vehicleId]
	title(root, result.duplicate and "DUPLICATE CAR!" or "NEW CAR!")
	local accent = vehicle and (Config.RarityColors[vehicle.Rarity] or T.C.purple) or T.C.silver
	local panel = T.panel(root, "RevealStage", 273, 168, 654, 350, accent)
	T.checkers(panel, 21, 18, 610, 29, 15, accent)
	if vehicle then
		T.vehicle(panel, "RevealedCar", vehicle, 38, 27, 578, 235)
		local strip = T.panel(panel, "RevealDetails", 14, 265, 626, 70, accent)
		T.text(strip, "VehicleName", vehicle.Name, 17, 3, 385, 39, 31, T.C.white)
		T.rarity(strip, vehicle, 19, 43, 256, 28)
		T.icon(strip, "AbilityIcon", vehicle.Ability, 432, 12, 44, accent)
		T.text(strip, "Ability", string.upper(vehicle.Ability), 485, 16, 130, 35, 21, T.C.white)
	else
		T.text(
			panel,
			"WaitingReveal",
			"WAITING FOR YOUR CAR…",
			20,
			131,
			614,
			70,
			31,
			T.C.white,
			"Center"
		)
	end
	local status = result.duplicate
			and ("ALREADY OWNED  •  " .. T.format(
				result.refund or state.duplicateRefund or Config.DuplicateRefund
			) .. " COINS REFUNDED")
		or "ADDED TO YOUR COLLECTION"
	T.text(
		root,
		"RevealStatus",
		vehicle and status or "WAITING FOR SERVER CONFIRMATION",
		190,
		520,
		820,
		28,
		20,
		result.duplicate and T.C.gold or T.C.white,
		"Center"
	)
	local equipped = vehicle and state.equipped == vehicle.Id
	action(
		root,
		"EquipCar",
		equipped and "EQUIPPED" or "EQUIP",
		276,
		593,
		314,
		65,
		state,
		ctx,
		vehicle ~= nil and not equipped and (state.owned or {})[result.vehicleId] == true,
		function()
			ctx.request("EquipCar", { vehicleId = vehicle.Id })
		end,
		T.C.blue,
		"car"
	)
	T.button(root, "RevealDone", "DONE", 611, 593, 314, 65, function()
		ctx.navigate("CARS")
	end, T.C.red, "check")
end

local function settings(root, state, ctx)
	title(root, "SETTINGS", "MAKE THE GARAGE YOURS")
	local panel = T.panel(root, "SettingsPanel", 229, 201, 742, 250, T.C.silver)
	local values = state.settings or {}
	local entries = {
		{
			key = "sfx",
			title = "SOUND EFFECTS",
			description = "Menu and gameplay sounds",
			icon = "boost",
			default = true,
		},
		{
			key = "reducedMotion",
			title = "REDUCED MOTION",
			description = "Calmer menus",
			icon = "Shield",
			default = false,
		},
	}
	for index, entry in entries do
		local y = 18 + (index - 1) * 105
		local row = T.panel(panel, entry.key .. "Row", 18, y, 706, 91, T.C.blue)
		local value = values[entry.key]
		if value == nil then
			value = entry.default
		end
		T.icon(row, "SettingIcon", entry.icon, 16, 21, 43, T.C.cyan)
		T.text(row, "SettingTitle", entry.title, 77, 10, 398, 31, 24, T.C.white)
		T.text(row, "SettingDescription", entry.description, 77, 48, 398, 24, 16, T.C.muted)
		action(
			row,
			"Toggle_" .. entry.key,
			value and "ON" or "OFF",
			519,
			17,
			166,
			57,
			state,
			ctx,
			true,
			function()
				local updated = {
					music = false,
					sfx = values.sfx ~= false,
					reducedMotion = values.reducedMotion == true,
				}
				updated[entry.key] = not value
				ctx.request("SaveSettings", updated)
			end,
			value and T.C.blue or T.C.navy,
			value and "check" or nil
		)
	end
	T.text(
		panel,
		"SettingsStatus",
		state.pending == "SaveSettings" and "SAVING…" or "",
		18,
		220,
		706,
		22,
		14,
		T.C.muted,
		"Center"
	)
end

function Utility.render(parent, screen, state, ctx)
	local root = T.menu(parent, "Utility_" .. screen)
	local headerContext = ctx
	if screen == "CONFIRM" then
		headerContext = setmetatable({
			close = function()
				back(state, ctx)
			end,
		}, { __index = ctx })
	end
	T.header(root, "CHAMPIONS GARAGE", state, headerContext)
	if screen == "MODES" then
		modes(root, state, ctx)
	elseif screen == "GIFT" then
		gift(root, state, ctx)
	elseif screen == "CONFIRM" then
		confirmation(root, state, ctx)
	elseif screen == "REVEAL" then
		reveal(root, state, ctx)
	elseif screen == "SETTINGS" then
		settings(root, state, ctx)
	end
	if screen ~= "REVEAL" then
		T.nav(root, screen == "GIFT" and "GIFT" or "", ctx)
	end
	return root
end

return Utility
