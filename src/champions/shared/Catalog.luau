-- Native collection, selection and purchase views. All economy changes remain server-owned.
local T = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local Catalog = {}

local function displayVehicles(featured)
	local result, seen = {}, {}
	for _, id in featured do
		local vehicle = T.find(id)
		if vehicle then
			table.insert(result, vehicle)
			seen[id] = true
		end
	end
	for _, vehicle in Config.Vehicles do
		if not seen[vehicle.Id] then
			table.insert(result, vehicle)
		end
	end
	return result
end

local function available(state, ctx)
	return state.ready == true and not state.pending and not ctx.pending
end

local function owned(state, id)
	return state.owned and state.owned[id] == true
end

local function accent(vehicle)
	return Config.RarityColors[vehicle.Rarity] or T.C.silver
end

local function selected(state)
	return T.find(state.selection) or T.find(state.equipped) or Config.Vehicles[1]
end

local function price(state, vehicle)
	return (state.prices and state.prices[vehicle.Id]) or vehicle.Price or 0
end

local function loading(state)
	return state.ready ~= true and "WAITING FOR PLAYER DATA" or nil
end

local function section(parent, title, subtitle, x, y, w)
	T.text(parent, "SectionTitle", title, x, y, w, 40, 34, T.C.white)
	if subtitle then
		T.text(parent, "SectionSubtitle", subtitle, x, y + 39, w, 26, 20, T.C.silver)
	end
end

local function ability(parent, vehicle, x, y, w, h)
	local rail = T.panel(parent, "Ability", x, y, w, h, accent(vehicle))
	T.icon(rail, "AbilityIcon", vehicle.Ability, 10, 5, h - 10, T.C.white)
	T.text(
		rail,
		"AbilityName",
		string.upper(vehicle.Ability),
		h + 8,
		0,
		w - h - 16,
		h,
		22,
		T.C.white
	)
end

local function filters(parent, state, ctx, options, x, y, width)
	local gap = 8
	local w = (width - gap * (#options - 1)) / #options
	for index, value in options do
		local chosen = (state.filter or "ALL") == value
		T.button(
			parent,
			"Filter_" .. value,
			string.upper(value),
			x + (index - 1) * (w + gap),
			y,
			w,
			48,
			function()
				ctx.filter(value)
			end,
			chosen and T.C.blue or T.C.navy
		)
	end
end

local function matches(state, vehicle)
	local filter = state.filter or "ALL"
	return filter == "ALL"
		or (filter == "OWNED" and owned(state, vehicle.Id))
		or (filter == "LOCKED" and not owned(state, vehicle.Id))
		or string.upper(vehicle.Rarity) == string.upper(filter)
end

local function selectionHit(parent, vehicle, ctx, name, w, h)
	local hit = T.button(parent, name, "", 0, 0, w, h, function()
		ctx.select(vehicle.Id)
	end, T.C.navy)
	hit.BackgroundTransparency = 1
	hit.ZIndex = 5
end

local function miniCard(parent, vehicle, state, ctx, x, y, w, h)
	local isSelected = selected(state).Id == vehicle.Id
	local card = T.panel(
		parent,
		"Car_" .. vehicle.Id,
		x,
		y,
		w,
		h,
		isSelected and T.C.cyan or accent(vehicle)
	)
	T.vehicle(card, "CarArt", vehicle, 3, 1, w - 6, h - 57)
	local rail = T.frame(card, "NameRail", 5, h - 62, w - 10, 57, T.C.navy, 8)
	T.text(rail, "CarName", vehicle.Name, 8, 0, w - 26, 27, 20, T.C.white)
	T.rarity(rail, vehicle, 8, 28, w - 26, 29)
	if state.equipped == vehicle.Id then
		T.frame(card, "EquippedBadge", w - 42, 8, 34, 34, T.C.green, 17)
		T.icon(card, "Equipped", "check", w - 37, 13, 24, T.C.ink)
	elseif not owned(state, vehicle.Id) then
		T.frame(card, "LockedBadge", w - 40, 8, 30, 30, T.C.navy, 15)
		T.icon(card, "Locked", "lock", w - 35, 13, 20, T.C.silver)
	end
	selectionHit(card, vehicle, ctx, "Select_" .. vehicle.Id, w, h)
end

local function renderCars(root, state, ctx)
	local vehicle = selected(state)
	section(root, "CHAMPIONS GARAGE", "YOUR COLLECTION  /  ONE CAR. ONE ABILITY.", 32, 105, 475)
	local hero = T.panel(root, "Hero", 26, 173, 482, 400, accent(vehicle))
	T.text(
		hero,
		"GarageNumber",
		string.format("%02d", vehicle.ArtIndex or 1),
		20,
		12,
		150,
		65,
		54,
		T.C.muted
	)
	T.vehicle(hero, "HeroCar", vehicle, 5, 20, 472, 275)
	local details = T.panel(hero, "HeroDetails", 10, 270, 462, 120, T.C.silver)
	T.text(details, "Name", vehicle.Name, 14, 2, 300, 34, 30, T.C.white)
	T.rarity(details, vehicle, 14, 38, 140, 30)
	T.text(
		details,
		"Ability",
		string.upper(vehicle.Ability)
			.. (
				if Config.AbilityLines[vehicle.Ability]
					then " • " .. Config.AbilityLines[vehicle.Ability]
					else ""
			),
		169,
		38,
		285,
		30,
		22,
		T.C.white
	)
	local isOwned = owned(state, vehicle.Id)
	local equipped = state.equipped == vehicle.Id
	local label = loading(state)
		or (equipped and "EQUIPPED" or (isOwned and "EQUIP CAR" or "VIEW IN SHOP"))
	local button = T.button(details, "EquipCar", label, 14, 70, 434, 42, function()
		if not available(state, ctx) then
			return
		end
		if isOwned and not equipped then
			ctx.request("EquipCar", { vehicleId = vehicle.Id })
		elseif not isOwned then
			ctx.select(vehicle.Id)
			ctx.navigate("SHOP", { selection = vehicle.Id })
		end
	end, equipped and T.C.navy or T.C.green, equipped and "check" or "car")
	T.disable(button, not available(state, ctx) or equipped)
	filters(root, state, ctx, { "ALL", "OWNED", "LOCKED" }, 530, 108, 640)
	local list = T.scroll(root, "Collection", 527, 169, 650, 392)
	local count, totalOwned = 0, 0
	for _, car in displayVehicles({ "Sedan", "Muscle", "SuperCar", "MonsterTruck", "Formula" }) do
		if owned(state, car.Id) then
			totalOwned += 1
		end
		if matches(state, car) then
			miniCard(
				list,
				car,
				state,
				ctx,
				(count % 3) * 211 + 3,
				math.floor(count / 3) * 196 + 3,
				202,
				186
			)
			count += 1
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, math.ceil(count / 3) * 196 + 4)
	if count == 0 then
		T.text(list, "Empty", "NO CARS IN THIS FILTER", 10, 90, 610, 70, 25, T.C.muted, "Center")
	end
	T.text(
		root,
		"CollectionCount",
		totalOwned .. " / " .. #Config.Vehicles .. " COLLECTED",
		883,
		562,
		285,
		32,
		20,
		T.C.silver,
		"Right"
	)
	T.nav(root, "CARS", ctx)
end

local function renderPicker(root, state, ctx)
	T.checkers(root, 280, 117, 80, 34, 17, T.C.silver)
	T.text(root, "PickerTitle", "PICK 1 CAR", 392, 102, 420, 60, 43, T.C.white, "Center")
	T.checkers(root, 840, 117, 80, 34, 17, T.C.silver)
	local options = state.pickerOptions or {}
	local defaults = displayVehicles({ "Compact", "Semi", "MonsterTruck" })
	local optionIds = #options > 0 and options or { defaults[1].Id, defaults[2].Id, defaults[3].Id }
	local selectionValid = false
	for index, id in optionIds do
		if index > 3 then
			break
		end
		local vehicle = T.find(id)
		if vehicle then
			local chosen = state.selection == id
			if chosen then
				selectionValid = true
			end
			local card = T.panel(
				root,
				"PickerCard_" .. id,
				93 + (index - 1) * 344,
				170,
				326,
				402,
				chosen and T.C.cyan or accent(vehicle)
			)
			T.text(card, "Slot", "0" .. index, 24, 14, 85, 53, 42, T.C.muted).ZIndex = 6
			T.vehicle(card, "CarArt", vehicle, 3, 10, 320, 268)
			T.frame(card, "InfoRail", 8, 263, 310, 128, T.C.navy, 9)
			T.text(card, "Name", vehicle.Name, 14, 266, 298, 40, 31, T.C.white, "Center")
			T.rarity(card, vehicle, 72, 306, 182, 36)
			ability(card, vehicle, 15, 345, 296, 48)
			if chosen then
				T.frame(card, "SelectedBadge", 267, 12, 46, 46, T.C.green, 23)
				T.icon(card, "Selected", "check", 275, 20, 30, T.C.ink)
			end
			selectionHit(card, vehicle, ctx, "Pick_" .. id, 326, 402)
		end
	end
	T.checkers(root, 0, 603, 1200, 52, 26, T.C.silver)
	T.button(root, "Back", "BACK", 58, 598, 276, 66, function()
		ctx.navigate("CARS")
	end, T.C.blue, "back")
	local confirm = T.button(
		root,
		"ConfirmCar",
		loading(state) or "CONFIRM CAR",
		351,
		598,
		791,
		66,
		function()
			if available(state, ctx) and selectionValid then
				ctx.request("ChooseCar", { vehicleId = state.selection })
			end
		end,
		T.C.green,
		"car"
	)
	T.disable(confirm, not available(state, ctx) or not selectionValid)
end

local function shopCard(parent, vehicle, state, ctx, x)
	local w, h = 210, 354
	local card = T.panel(parent, "ShopCar_" .. vehicle.Id, x, 3, w, h, accent(vehicle))
	T.vehicle(card, "CarArt", vehicle, 2, 6, 206, 190)
	T.frame(card, "Details", 6, 189, 198, 157, T.C.navy, 9)
	T.text(card, "Name", vehicle.Name, 12, 191, 186, 33, 25, T.C.white)
	T.rarity(card, vehicle, 12, 224, 92, 32)
	T.icon(card, "AbilityIcon", vehicle.Ability, 108, 226, 26, T.C.gold)
	local abilityName =
		T.text(card, "Ability", string.upper(vehicle.Ability), 136, 226, 66, 26, 20, T.C.white)
	abilityName.TextScaled = true
	abilityName.TextTruncate = Enum.TextTruncate.None
	local abilityFit = Instance.new("UITextSizeConstraint")
	abilityFit.MaxTextSize = 26
	abilityFit.MinTextSize = 10
	abilityFit.Parent = abilityName
	local cost = price(state, vehicle)
	T.icon(card, "Coin", "coin", 13, 263, 28, T.C.gold)
	T.text(card, "Price", T.format(cost) .. " COINS", 48, 261, 149, 34, 22, T.C.white)
	local isOwned = owned(state, vehicle.Id)
	local equipped = state.equipped == vehicle.Id
	local affordable = (state.coins or 0) >= cost
	local label = loading(state)
		or (
			equipped and "EQUIPPED"
			or (
				isOwned and "EQUIP"
				or (affordable and "BUY" or "NEED " .. T.format(cost - (state.coins or 0)))
			)
		)
	local button = T.button(
		card,
		"Buy_" .. vehicle.Id,
		label,
		10,
		298,
		190,
		48,
		function()
			if not available(state, ctx) then
				return
			end
			if isOwned and not equipped then
				ctx.request("EquipCar", { vehicleId = vehicle.Id })
			elseif not isOwned and affordable then
				ctx.confirm(
					"BuyCar",
					{ vehicleId = vehicle.Id },
					"BUY " .. vehicle.Name .. "?",
					"Spend " .. T.format(cost) .. " coins to unlock this car?"
				)
			end
		end,
		equipped and T.C.green or T.C.blue,
		equipped and "check" or (affordable and "shop" or "lock")
	)
	T.disable(button, not available(state, ctx) or equipped or (not isOwned and not affordable))
end

local function machine(parent, x, y, w, h, compact)
	local body = T.panel(parent, "ClawMachine", x, y, w, h, T.C.red)
	T.frame(body, "Marquee", 8, 8, w - 16, compact and 45 or 61, T.C.red, 12)
	T.text(
		body,
		"MachineTitle",
		"GUMBALL MACHINE",
		12,
		9,
		w - 24,
		compact and 43 or 59,
		compact and 24 or 37,
		T.C.gold,
		"Center"
	)
	local top = compact and 61 or 80
	local glass = T.panel(body, "Glass", 17, top, w - 34, h - top - 68, T.C.cyan)
	local cable =
		T.frame(glass, "Cable", (w - 34) / 2 - 3, 0, 6, compact and 36 or 69, T.C.silver, 2)
	cable.BackgroundTransparency = 0.1
	T.icon(
		glass,
		"Claw",
		"claw",
		(w - 34) / 2 - (compact and 24 or 40),
		compact and 19 or 44,
		compact and 48 or 80,
		T.C.silver
	)
	local cars = {
		Config.Vehicles[1],
		Config.Vehicles[5] or Config.Vehicles[2],
		Config.Vehicles[9] or Config.Vehicles[3],
		Config.Vehicles[12],
	}
	local artW = (w - 36) * 0.61
	local artH = compact and 95 or 151
	local glassH = h - top - 68
	for index, vehicle in cars do
		local px = ((index - 1) % 2) * (w - 34) * 0.4 - 4
		local py = glassH - artH - 8 - (index <= 2 and artH * 0.47 or 0)
		T.vehicle(glass, "PrizeCar_" .. index, vehicle, px, py, artW, artH)
	end
	for _, px in { 7, w - 13 } do
		for i = 1, compact and 3 or 6 do
			T.frame(
				body,
				"Bulb",
				px,
				top + i * ((h - top - 82) / (compact and 3 or 6)),
				6,
				compact and 14 or 22,
				T.C.gold,
				3
			)
		end
	end
	T.frame(body, "PrizeSlot", 18, h - 57, w - 36, 43, T.C.navy, 8)
	T.text(
		body,
		"PrizeCaption",
		"WIN A NEW CAR!",
		23,
		h - 56,
		w - 46,
		42,
		compact and 19 or 28,
		T.C.gold,
		"Center"
	)
	return body
end

local function renderShop(root, state, ctx)
	section(root, "SHOP", "FIND YOUR NEXT CHAMPION", 31, 105, 285)
	filters(root, state, ctx, { "ALL", "Common", "Rare", "Epic", "Legendary" }, 329, 112, 842)
	local list = T.scroll(root, "ShopStock", 24, 187, 896, 386)
	list.ScrollingDirection = Enum.ScrollingDirection.X
	local count = 0
	for _, vehicle in displayVehicles({ "offroad", "rally", "monster", "hyper" }) do
		if matches(state, vehicle) then
			shopCard(list, vehicle, state, ctx, count * 220 + 3)
			count += 1
		end
	end
	list.CanvasSize = UDim2.fromOffset(count * 220 + 4, 0)
	if count == 0 then
		T.text(list, "Empty", "NO CARS IN THIS FILTER", 25, 120, 830, 55, 28, T.C.muted, "Center")
	end
	local tile = T.panel(root, "ClawOffer", 936, 188, 239, 365, T.C.cyan)
	machine(tile, 8, 8, 223, 250, true)
	local cost = state.clawPrice or Config.ClawPrice
	T.icon(tile, "Coin", "coin", 13, 268, 29, T.C.gold)
	T.text(tile, "Cost", T.format(cost) .. " / PULL", 49, 268, 178, 31, 22, T.C.gold)
	T.button(tile, "ViewOdds", "VIEW ODDS", 11, 307, 217, 48, function()
		ctx.navigate("CLAW")
	end, T.C.blue, "claw")
	T.nav(root, "SHOP", ctx)
end

local function renderClaw(root, state, ctx)
	machine(root, 30, 109, 550, 471, false)
	local panel = T.panel(root, "OddsAndRewards", 599, 109, 573, 471, T.C.silver)
	T.text(panel, "OddsTitle", "ODDS & REWARDS", 15, 6, 543, 53, 35, T.C.white, "Center")
	local odds = state.clawOdds or Config.ClawOdds
	for index, entry in odds do
		if index > 4 then
			break
		end
		local vehicle
		for _, candidate in Config.Vehicles do
			if candidate.Rarity == entry.Rarity then
				vehicle = candidate
				break
			end
		end
		local color = Config.RarityColors[entry.Rarity] or T.C.silver
		local row =
			T.panel(panel, "Odds_" .. entry.Rarity, 15, 62 + (index - 1) * 67, 543, 59, color)
		if vehicle then
			T.vehicle(row, "Prize", vehicle, 0, -5, 112, 69)
		end
		T.frame(row, "RarityChip", 116, 8, 182, 43, color, 8)
		T.text(row, "Rarity", string.upper(entry.Rarity), 120, 8, 174, 43, 22, T.C.ink, "Center")
		T.text(
			row,
			"Chance",
			tostring(entry.Chance) .. "%",
			307,
			5,
			105,
			48,
			33,
			T.C.white,
			"Center"
		)
		T.frame(row, "Divider", 419, 12, 2, 35, T.C.muted, 0)
		T.text(
			row,
			"PerCar",
			tostring(entry.PerCar) .. "%",
			432,
			0,
			99,
			32,
			24,
			T.C.white,
			"Center"
		)
		T.text(row, "PerCarLabel", "PER CAR", 432, 27, 99, 32, 18, T.C.silver, "Center")
	end
	local note = T.panel(panel, "DuplicateRefund", 15, 337, 543, 57, T.C.blue)
	T.icon(note, "RefundIcon", "coin", 13, 10, 36, T.C.gold)
	T.text(note, "Owned", "OWNED CAR?", 61, 0, 469, 32, 24, T.C.white)
	T.text(note, "Refund", Config.RefundText .. " COINS BACK", 61, 25, 469, 32, 24, T.C.gold)
	local cost = state.clawPrice or Config.ClawPrice
	local affordable = (state.coins or 0) >= cost
	local label = loading(state)
		or (
			affordable and "PULL  •  " .. T.format(cost) .. " COINS"
			or "NEED " .. T.format(cost - (state.coins or 0)) .. " MORE"
		)
	local pull = T.button(panel, "PullClaw", label, 15, 407, 352, 52, function()
		if not available(state, ctx) or not affordable then
			return
		end
		ctx.confirm(
			"PullClaw",
			{},
			"SPIN THE GUMBALL MACHINE?",
			(
				if cost == 0
					then "Free pull! One random car."
					else "Spend " .. T.format(cost) .. " coins for one random car."
			)
				.. " Duplicates return "
				.. Config.RefundText
				.. " coins. Odds are shown before every pull."
		)
	end, T.C.blue, "coin")
	T.disable(pull, not available(state, ctx) or not affordable)
	T.button(panel, "AllCars", "ALL CARS", 379, 407, 179, 52, function()
		ctx.navigate("CARS")
	end, T.C.blue, "car")
	T.nav(root, "SHOP", ctx)
end

function Catalog.render(parent, screen, state, ctx)
	state = state or {}
	local root = T.menu(parent, screen)
	T.header(root, screen, state, ctx)
	if screen == "CARS" then
		renderCars(root, state, ctx)
	elseif screen == "PICKER" then
		renderPicker(root, state, ctx)
	elseif screen == "SHOP" then
		renderShop(root, state, ctx)
	elseif screen == "CLAW" then
		renderClaw(root, state, ctx)
	else
		error("Unsupported catalog screen: " .. tostring(screen))
	end
	return root
end

return Catalog
