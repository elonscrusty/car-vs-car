-- Lobby and driving overlays remain transparent so the existing game owns the world.
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

local function lobby(parent, state, ctx)
	return responsive(parent, "Lobby", function(root, w, h)
		local compact = w < 760
		local railW = math.min(w - 184, if compact then 360 else 570)
		T.panel(root, "ProfileRail", 12, 12, railW, 72, T.C.silver)
		T.icon(root, "Coin", "coin", 24, 27, 36, T.C.gold)
		T.text(
			root,
			"CoinBalance",
			T.format(state.coins or 0),
			67,
			21,
			if compact then 110 else 142,
			46,
			if compact then 25 else 32,
			T.C.white
		)
		local profileX = if compact then 180 else 228
		T.text(
			root,
			"Level",
			"LV " .. tostring(state.level or 1),
			profileX,
			19,
			83,
			25,
			19,
			T.C.gold
		)
		local barW = math.max(36, railW - profileX - 12)
		T.frame(root, "XPTrack", profileX, 50, barW, 12, T.C.ink, 6)
		T.frame(
			root,
			"XPFill",
			profileX,
			50,
			barW * math.clamp((state.xp or 0) / math.max(1, state.xpGoal or 1), 0, 1),
			12,
			T.C.cyan,
			6
		)
		if not compact then
			T.text(
				root,
				"XPLabel",
				tostring(state.xp or 0) .. " / " .. tostring(state.xpGoal or 1) .. " XP",
				profileX + 82,
				19,
				210,
				25,
				17,
				T.C.silver,
				"Right"
			)
		end
		local queue = state.queue
		local playW = if compact then 160 else 242
		local play = T.button(
			root,
			"Play",
			if queue then "CANCEL" else "PLAY",
			w - playW - 12,
			12,
			playW,
			72,
			function()
				request(ctx, if queue then "CancelPlay" else "Play")
			end,
			if queue then T.C.red else T.C.green,
			"duel"
		)
		T.disable(play, ctx.pending or not state.ready)
		local navSize = math.clamp(h * 0.13, 58, 88)
		local navY = math.max(100, (h - (navSize * 3 + 16)) * 0.5)
		for index, item in
			{
				{ "CARS", "car", T.C.red },
				{ "SHOP", "shop", T.C.blue },
				{ "GIFT", "gift", T.C.navy },
			}
		do
			T.button(
				root,
				item[1],
				item[1],
				w - navSize - 12,
				navY + (index - 1) * (navSize + 8),
				navSize,
				navSize,
				function()
					ctx.navigate(item[1])
				end,
				item[3],
				item[2]
			)
		end
		local hintW = math.min(410, w - 210)
		T.panel(root, "PadHint", (w - hintW) / 2, h - 66, hintW, 52, T.C.blue)
		local hint = if queue then tostring(queue.status or "WAITING") else "PRESS PLAY TO FIGHT"
		T.text(
			root,
			"QueueStatus",
			hint,
			(w - hintW) / 2 + 8,
			h - 62,
			hintW - 16,
			44,
			if compact then 15 else 20,
			T.C.white,
			"Center"
		)
		T.button(root, "Settings", "SETTINGS", 12, h - 62, 124, 48, function()
			ctx.navigate("SETTINGS")
		end, T.C.navy)
	end)
end

local function matchView(parent, state, ctx)
	local match = state.match or {}
	local mode = match.mode or state.mode or "DUEL"
	local vehicle = T.find(state.equipped) or Config.Vehicles[1]
	return responsive(parent, "Match", function(root, w, h)
		local small = w < 760
		local leaveW = if small then 92 else 118
		T.button(root, "LeaveMatch", "LOBBY", 12, 12, leaveW, 48, function()
			ctx.confirm(
				"LeaveMatch",
				{},
				"RETURN TO LOBBY?",
				"Leave the current match and return to the garage."
			)
		end, T.C.navy)
		T.button(root, "Settings", "MENU", w - leaveW - 12, 12, leaveW, 48, function()
			ctx.navigate("SETTINGS")
		end, T.C.navy)
		local scoreW = math.min(if small then 350 else 480, w - 2 * (leaveW + 24))
		local x = (w - scoreW) / 2
		T.panel(root, "MatchScoreboard", x, 10, scoreW, 82, T.C.silver)
		T.checkers(root, x + 8, 18, 24, 16, 8, T.C.white)
		T.checkers(root, x + scoreW - 32, 18, 24, 16, 8, T.C.white)
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
			14,
			scoreW - 70,
			22,
			if small then 15 else 18,
			T.C.silver,
			"Center"
		)
		if mode == "SOCCER" or mode == "DUEL" then
			local leftName = if mode == "DUEL" then "YOU" else "BLUE"
			local rightName = if mode == "DUEL" then "LEFT" else "RED"
			local leftScore = if mode == "DUEL" then match.youScore else match.blueScore
			local rightScore = if mode == "DUEL" then match.carsLeft else match.redScore
			T.frame(root, "BlueScorePanel", x + 8, 40, scoreW * 0.29, 43, T.C.blue, 8)
			T.frame(root, "RedScorePanel", x + scoreW * 0.71 - 8, 40, scoreW * 0.29, 43, T.C.red, 8)
			T.text(
				root,
				"BlueScore",
				leftName .. " " .. tostring(leftScore or 0),
				x + 10,
				43,
				scoreW * 0.29 - 4,
				36,
				if small then 17 else 22,
				T.C.white,
				"Center"
			)
			T.text(
				root,
				"RedScore",
				tostring(rightScore or 0) .. " " .. rightName,
				x + scoreW * 0.71 - 6,
				43,
				scoreW * 0.29 - 4,
				36,
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
				43,
				scoreW * 0.4,
				36,
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
			local bg =
				T.panel(root, "MatchBanner", (w - bannerW) / 2, 102, bannerW, 46, bannerColor)
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
		-- The native Roblox joystick owns the lower-left corner.
		local size = math.clamp(math.min(h * 0.23, w * 0.15), 64, 136)
		local controlsY = h - size - 20
		local boost = T.cooldown(
			root,
			"Boost",
			"BOOST",
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
			string.upper(vehicle.Ability),
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
	end, T.C.blue, "reset")
	local back = T.button(root, "Lobby", "LOBBY", 609, 582, 458, 78, function()
		request(ctx, "LeaveMatch")
	end, T.C.red, "back")
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
