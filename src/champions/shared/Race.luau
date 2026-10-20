-- Lobby and driving overlays remain transparent so the existing game owns the world.
local UserInputService = game:GetService("UserInputService")
local T = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local Race = {}

local function clock(seconds)
	seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function ordinal(place)
	place = math.max(1, math.floor(tonumber(place) or 1))
	local last, hundred = place % 10, place % 100
	local suffix = if hundred >= 11 and hundred <= 13
		then "TH"
		elseif last == 1 then "ST"
		elseif last == 2 then "ND"
		elseif last == 3 then "RD"
		else "TH"
	return tostring(place) .. suffix
end

-- Keyboard players see the key on the button; touch players do not (input-specific hints).
local function keyLabel(name, key)
	if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		return name .. " [" .. key .. "]"
	end
	return name
end

local function request(ctx, action, payload)
	if not ctx.pending then
		ctx.request(action, payload or {})
	end
end

local function clearFrame(parent, name)
	local root = T.frame(parent, name, 0, 0, 0, 0, T.C.navy, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	return root
end

local function timer(parent, name, value, endsAt, x, y, w, h, size, color)
	local label = T.text(
		parent,
		name,
		clock(if endsAt then endsAt - T.monoTime() else value),
		x,
		y,
		w,
		h,
		size,
		color or T.C.white,
		"Center"
	)
	if endsAt then
		label:SetAttribute("EndsAt", endsAt)
	end
	label:SetAttribute("TimerFormat", if name == "FuseTimer" then "fuse" else "clock")
	return label
end

local function responsive(parent, name, draw)
	local root = clearFrame(parent, name)
	local previousW, previousH
	local function layout()
		local size = parent.AbsoluteSize
		local w, h = math.floor(size.X), math.floor(size.Y)
		if w <= 0 or h <= 0 or (w == previousW and h == previousH) then
			return
		end
		previousW, previousH = w, h
		root:ClearAllChildren()
		draw(root, w, h)
	end
	local connection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	root.Destroying:Connect(function()
		connection:Disconnect()
	end)
	layout()
	return root
end

-- Roblox's own menu + chat buttons sit in the top-left corner; our top row starts after them.
local ROBLOX_CLEAR = 176

local function lobby(parent, state, ctx)
	return responsive(parent, "Lobby", function(root, w, h)
		local compact = w < 760
		-- Top row, next to the chat icon: coins + level + XP.
		local railX = ROBLOX_CLEAR
		local railW = math.clamp(w - railX - 150, 260, if compact then 380 else 470)
		T.panel(root, "ProfileRail", railX, 6, railW, 56, T.C.silver)
		T.icon(root, "Coin", "coin", railX + 12, 15, 38, T.C.gold)
		T.text(
			root,
			"CoinBalance",
			T.format(state.coins or 0),
			railX + 56,
			10,
			if compact then 96 else 124,
			48,
			if compact then 24 else 28,
			T.C.white
		)
		local profileX = railX + (if compact then 160 else 190)
		T.text(
			root,
			"Level",
			"LV " .. tostring(state.level or 1),
			profileX,
			8,
			80,
			26,
			20,
			T.C.gold
		)
		local barW = math.max(36, railX + railW - profileX - 14)
		T.text(
			root,
			"XPLabel",
			tostring(state.xp or 0) .. " / " .. tostring(state.xpGoal or 1) .. " XP",
			profileX + 84,
			8,
			math.max(40, barW - 84),
			26,
			18,
			T.C.silver,
			"Right"
		)
		T.frame(root, "XPTrack", profileX, 38, barW, 18, T.C.ink, 9)
		T.frame(
			root,
			"XPFill",
			profileX,
			38,
			barW * math.clamp((state.xp or 0) / math.max(1, state.xpGoal or 1), 0, 1),
			18,
			T.C.cyan,
			9
		)
		T.button(root, "Settings", "SETTINGS", w - 132, 6, 120, 48, function()
			ctx.navigate("SETTINGS")
		end, T.C.navy, "gear")
		-- Left column: CARS / SHOP / GIFT (clear of the thumbstick below).
		local navSize = math.clamp((h - 130) / 3 - 8, 52, 76)
		for index, item in
			{
				{ "CARS", "car", T.C.blue },
				{ "SHOP", "shop", T.C.blue },
				{ "GIFT", "gift", T.C.blue },
			}
		do
			T.button(
				root,
				item[1],
				item[1],
				12,
				68 + (index - 1) * (navSize + 8),
				navSize + 14,
				navSize,
				function()
					ctx.navigate(item[1])
				end,
				item[3],
				item[2]
			)
		end
		-- PLAY: bottom right, left of the jump button.
		local queue = state.queue
		local playW = if compact then 200 else 250
		local playX = w - playW - (if compact then 112 else 130)
		local playY = h - 80
		local play = T.button(
			root,
			"Play",
			if queue then "CANCEL" else "PLAY",
			playX,
			playY,
			playW,
			68,
			function()
				request(ctx, if queue then "CancelPlay" else "Play")
			end,
			if queue then T.C.red else T.C.green,
			"duel"
		)
		T.disable(play, ctx.pending or not state.ready)
		if not queue then
			-- One line that says what the game is (carter's video review).
			T.text(
				root,
				"Objective",
				"PICK A CAR. DRIVE IT AND HIT! WIN 2 OF 3 ROUNDS!",
				playX - 20,
				playY - 70,
				playW + 20,
				62,
				20,
				T.C.white,
				"Center"
			)
		end
		if queue then
			T.panel(root, "PadHint", playX, playY - 50, playW, 44, T.C.blue)
			T.text(
				root,
				"QueueStatus",
				tostring(queue.status or "WAITING"),
				playX + 6,
				playY - 48,
				playW - 12,
				40,
				22,
				T.C.white,
				"Center"
			)
		end
	end)
end

local function matchView(parent, state, ctx)
	local match = state.match or {}
	local mode = match.mode or state.mode or "DUEL"
	local vehicle = T.find(state.equipped) or Config.Vehicles[1]
	return responsive(parent, "Match", function(root, w, h)
		local small = w < 760
		local leaveW = if small then 92 else 118
		T.button(root, "LeaveMatch", "LOBBY", 12, 66, leaveW, 46, function()
			ctx.confirm(
				"LeaveMatch",
				{},
				"RETURN TO LOBBY?",
				"Leave the current match and return to the garage."
			)
		end, T.C.navy)
		T.button(root, "Settings", "MENU", w - leaveW - 12, 6, leaveW, 46, function()
			ctx.navigate("SETTINGS")
		end, T.C.navy)
		local scoreW = math.min(if small then 340 else 440, w - 2 * (leaveW + 24))
		local x = (w - scoreW) / 2
		T.panel(root, "MatchScoreboard", x, 6, scoreW, 66, T.C.silver)
		T.checkers(root, x + 8, 12, 24, 16, 8, T.C.white)
		T.checkers(root, x + scoreW - 32, 12, 24, 16, 8, T.C.white)
		T.text(
			root,
			"MatchMode",
			(if mode == "DUEL" then "FIGHT" else mode)
				.. (
					if mode == "SOCCER"
						then "  3 v 3"
						elseif mode == "DUEL" then "  •  ROUND " .. tostring(
							match.round or 1
						)
						else ""
				),
			x + 35,
			8,
			scoreW - 70,
			24,
			if small then 15 else 18,
			T.C.silver,
			"Center"
		)
		if mode == "SOCCER" or mode == "DUEL" then
			local leftName = if mode == "DUEL" then "WINS" else "BLUE"
			local rightName = if mode == "DUEL" then "LEFT" else "RED"
			local leftScore = if mode == "DUEL" then match.youScore else match.blueScore
			local rightScore = if mode == "DUEL" then match.carsLeft else match.redScore
			T.frame(root, "BlueScorePanel", x + 8, 36, scoreW * 0.29, 32, T.C.blue, 8)
			T.frame(root, "RedScorePanel", x + scoreW * 0.71 - 8, 36, scoreW * 0.29, 32, T.C.red, 8)
			T.text(
				root,
				"BlueScore",
				leftName .. " " .. tostring(leftScore or 0),
				x + 10,
				36,
				scoreW * 0.29 - 4,
				32,
				if small then 17 else 22,
				T.C.white,
				"Center"
			)
			T.text(
				root,
				"RedScore",
				tostring(rightScore or 0) .. " " .. rightName,
				x + scoreW * 0.71 - 6,
				36,
				scoreW * 0.29 - 4,
				32,
				if small then 17 else 22,
				T.C.white,
				"Center"
			)
			timer(
				root,
				"MatchTimer",
				match.timer,
				match.endsAt,
				x + scoreW * 0.3,
				36,
				scoreW * 0.4,
				32,
				if small then 23 else 29
			)
		elseif mode == "TAG" then
			timer(
				root,
				"FuseTimer",
				match.fuse,
				match.fuseEndsAt,
				x + scoreW * 0.28,
				39,
				scoreW * 0.4,
				40,
				28,
				T.C.gold
			)
			T.text(
				root,
				"FuseLabel",
				"FUSE",
				x + 10,
				43,
				scoreW * 0.25,
				32,
				18,
				T.C.silver,
				"Center"
			)
			T.text(
				root,
				"CarsLeft",
				tostring(match.carsLeft or 0) .. " LEFT",
				x + scoreW * 0.68,
				43,
				scoreW * 0.3 - 8,
				32,
				18,
				T.C.white,
				"Center"
			)
		else
			T.text(
				root,
				"Lap",
				"LAP " .. tostring(match.lap or 1) .. " / 3",
				x + 10,
				41,
				scoreW * 0.46,
				36,
				if small then 22 else 27,
				T.C.white,
				"Center"
			)
			timer(
				root,
				"MatchTimer",
				match.timer,
				match.endsAt,
				x + scoreW * 0.49,
				41,
				scoreW * 0.48,
				36,
				if small then 22 else 27
			)
			T.panel(
				root,
				"PlacePanel",
				w - (if small then 125 else 175),
				76,
				if small then 113 else 163,
				54,
				T.C.blue
			)
			T.text(
				root,
				"Place",
				ordinal(match.place or 1) .. " / " .. tostring(match.totalPlayers or 6),
				w - (if small then 125 else 175),
				80,
				if small then 113 else 163,
				44,
				if small then 24 else 31,
				T.C.white,
				"Center"
			)
		end
		local banner, bannerColor
		if match.goal and (not match.goalUntil or match.goalUntil > T.monoTime()) then
			banner, bannerColor =
				tostring(if type(match.goal) == "string" then match.goal else "GOAL!"), T.C.blue
		elseif match.suddenDeath then
			banner, bannerColor = "SUDDEN DEATH • NEXT GOAL WINS", T.C.gold
		elseif mode == "TAG" and not match.spectating then
			banner, bannerColor =
				if match.isIt
					then "YOU ARE IT! • BUMP A CAR TO PASS IT"
					else "IT: " .. tostring(match.itName or "—"),
				if match.isIt then T.C.red else T.C.blue
		end
		if banner then
			local bannerW = math.min(440, w - 160)
			local bg = T.panel(root, "MatchBanner", (w - bannerW) / 2, 78, bannerW, 44, bannerColor)
			if match.goal and match.goalUntil then
				bg:SetAttribute("HideAt", match.goalUntil)
			end
			T.text(
				bg,
				"BannerText",
				banner,
				8,
				4,
				bannerW - 16,
				36,
				if small then 15 else 20,
				T.C.white,
				"Center"
			)
		end
		if match.spectating then
			local watchW = math.min(430, w - 32)
			local watchX = (w - watchW) / 2
			T.panel(root, "SpectatorPanel", watchX, h - 94, watchW, 78, T.C.blue)
			T.button(root, "SpectatePrevious", "<", watchX + 8, h - 80, 52, 50, function()
				request(ctx, "SpectatePrevious")
			end, T.C.blue)
			T.button(root, "SpectateNext", ">", watchX + watchW - 60, h - 80, 52, 50, function()
				request(ctx, "SpectateNext")
			end, T.C.blue)
			T.text(
				root,
				"Spectating",
				"SPECTATING",
				watchX + 66,
				h - 85,
				watchW - 132,
				24,
				17,
				T.C.cyan,
				"Center"
			)
			T.text(
				root,
				"Watching",
				tostring(match.watching or "WAITING FOR NEXT ROUND"),
				watchX + 66,
				h - 57,
				watchW - 132,
				26,
				19,
				T.C.white,
				"Center"
			)
			return
		end
		if mode == "DUEL" and match.hp and match.hpMax and match.hpMax > 0 then
			-- Your car's health, always on screen: it is what decides if you are out.
			local frac = math.clamp(match.hp / match.hpMax, 0, 1)
			local barW = math.clamp(w * 0.34, 190, 340)
			local barX = (w - barW) / 2
			local barY = h - 50
			T.panel(root, "HpPanel", barX, barY, barW, 40, T.C.navy)
			T.frame(root, "HpTrack", barX + 8, barY + 22, barW - 16, 12, T.C.ink, 6)
			local fill = if frac > 0.5 then T.C.green elseif frac > 0.25 then T.C.gold else T.C.red
			T.frame(
				root,
				"HpFill",
				barX + 8,
				barY + 22,
				math.max(6, (barW - 16) * frac),
				12,
				fill,
				6
			)
			T.text(
				root,
				"HpLabel",
				"YOUR HP  "
					.. tostring(math.ceil(match.hp))
					.. " / "
					.. tostring(math.ceil(match.hpMax)),
				barX + 8,
				barY + 2,
				barW - 16,
				20,
				16,
				if frac <= 0.25 then T.C.red else T.C.white,
				"Center"
			)
		end
		-- The native Roblox joystick owns the lower-left corner.
		local size = math.clamp(math.min(h * 0.23, w * 0.15), 64, 136)
		local controlsY = h - size - 20
		local boost = T.cooldown(
			root,
			"Boost",
			keyLabel("BOOST", "SHIFT"),
			"boost",
			w - size * 2 - 34,
			controlsY,
			size,
			function()
				request(ctx, "Boost")
			end
		)
		local ability = T.cooldown(
			root,
			"Ability",
			keyLabel(string.upper(vehicle.Ability), "E"),
			vehicle.Ability,
			w - size - 16,
			controlsY,
			size,
			function()
				request(ctx, "Ability")
			end
		)
		boost:SetAttribute("EndsAt", match.boostEndsAt or 0)
		boost:SetAttribute("Duration", match.boostDuration or 5)
		ability:SetAttribute("EndsAt", match.abilityEndsAt or 0)
		ability:SetAttribute("Duration", match.abilityDuration or 8)
		T.disable(boost, ctx.pending or false)
		T.disable(ability, ctx.pending or false)
		if mode == "RACE" and match.stuck then
			local reset = T.button(
				root,
				"ResetCar",
				"HOLD TO RESET",
				w - 150,
				controlsY - 65,
				134,
				52,
				function() end,
				T.C.red,
				"reset"
			)
			T.bindHold(reset, 0.8, function()
				request(ctx, "ResetCar")
			end)
		end
	end)
end

local function results(parent, state, ctx)
	local root = T.menu(parent, "Results")
	local result = state.result or (state.match and state.match.result) or {}
	local vehicle = T.find(state.equipped) or Config.Vehicles[1]
	T.header(root, "MATCH RESULTS", state, ctx)
	T.text(
		root,
		"Placement",
		if result.place then ordinal(result.place) .. " PLACE" else "MATCH COMPLETE",
		40,
		112,
		550,
		75,
		54,
		T.C.gold,
		"Center"
	)
	T.text(
		root,
		"Finished",
		if result.won then "YOU WON THE FIGHT" else "FIGHT OVER",
		70,
		188,
		490,
		36,
		24,
		T.C.white,
		"Center"
	)
	T.icon(root, "Trophy", "trophy", 68, 242, 86, T.C.gold)
	T.vehicle(root, "ResultCar", vehicle, 68, 235, 520, 265)
	T.panel(root, "Podium", 92, 488, 462, 61, T.C.gold)
	T.text(
		root,
		"PodiumPlace",
		if result.place then ordinal(result.place) else "WELL PLAYED",
		112,
		490,
		422,
		50,
		34,
		T.C.white,
		"Center"
	)
	T.panel(root, "RewardsPanel", 625, 119, 535, 434, T.C.blue)
	T.checkers(root, 642, 134, 40, 24, 12, T.C.white)
	T.text(root, "RewardsTitle", "MATCH REWARDS", 698, 130, 438, 43, 30, T.C.white)
	local rewards = result.rewards or {}
	local list = T.scroll(root, "RewardItems", 642, 188, 500, 226)
	list.CanvasSize = UDim2.fromOffset(0, math.max(226, #rewards * 72))
	for index, reward in rewards do
		local y = (index - 1) * 72
		T.panel(list, "Reward" .. index, 0, y, 480, 64, T.C.navy)
		T.text(
			list,
			"RewardLabel" .. index,
			string.upper(tostring(reward.label or "REWARD")),
			16,
			y + 10,
			320,
			43,
			22,
			T.C.white
		)
		T.text(
			list,
			"RewardAmount" .. index,
			"+" .. T.format(reward.amount or 0),
			338,
			y + 10,
			126,
			43,
			28,
			T.C.gold,
			"Right"
		)
	end
	if #rewards == 0 then
		T.text(
			list,
			"RewardsPending",
			"WAITING FOR MATCH REWARDS",
			10,
			72,
			470,
			40,
			22,
			T.C.muted,
			"Center"
		)
	end
	T.icon(root, "TotalCoin", "coin", 655, 456, 60, T.C.gold)
	T.text(
		root,
		"RewardTotal",
		if result.total ~= nil then "+" .. T.format(result.total) .. " COINS" else "REWARDS PENDING",
		725,
		443,
		412,
		80,
		if result.total ~= nil then 44 else 27,
		T.C.gold,
		"Center"
	)
	T.checkers(root, 20, 596, 94, 56, 14, T.C.white)
	T.checkers(root, 1087, 596, 94, 56, 14, T.C.white)
	local rematch = T.button(root, "Rematch", "REMATCH", 135, 582, 458, 78, function()
		request(ctx, "Rematch")
	end, T.C.green, "reset")
	local back = T.button(root, "Lobby", "LOBBY", 609, 582, 458, 78, function()
		request(ctx, "LeaveMatch")
	end, T.C.blue, "back")
	T.disable(rematch, ctx.pending or not state.ready)
	T.disable(back, ctx.pending or false)
	return root
end

function Race.render(parent, screen, state, ctx)
	if screen == "LOBBY" then
		return lobby(parent, state, ctx)
	end
	if screen == "MATCH" then
		return matchView(parent, state, ctx)
	end
	if screen == "RESULTS" then
		return results(parent, state, ctx)
	end
	error("Unsupported race screen: " .. tostring(screen))
end

return Race
