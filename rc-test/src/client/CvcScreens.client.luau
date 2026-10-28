--!strict
-- Car VS Car's new screens in the live game (carter's UI handoff; 10-28 "Yes": put them in the
-- game for the friend test). Only with Features.CVC and Features.NEW_UI on; the old Kart screens
-- they replace (Cvc, CvcCrate, CvcGarage, CvcHowTo, CvcInvite, the walk HUD in Stars and the
-- JOIN RACE! button in CvcRace) step aside then.
--   * PICK YOUR FIRST CAR (a new player), then the plot screen, its pieces one at a time
--   * the plot screen: coins, BIG RACE in m:ss, RACE! (join), MY CAR's 3 bars, COACH, JOBS,
--     the 4 tiles: GARAGE (racer, stations, upgrades, one more station), CRATES, SHOP, LEAGUE
--   * a new car from a crate: the reveal; a league up: LEAGUE UP! (after the race card closes)
-- The server (TrainingServer: RemoteEvent Garage; ServerRace "join") decides everything; this
-- only shows it and asks. Looks only: no game rule changes here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not (Features.CVC and Features.NEW_UI) then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Crates = require(Shared:WaitForChild("Crates"))
local League = require(Shared:WaitForChild("League"))
local Profile = require(Shared:WaitForChild("Profile"))
local Training = require(Shared:WaitForChild("Training"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Ui = script.Parent:WaitForChild("Ui")
local Screens = Ui:WaitForChild("Screens")
local Base = require(Ui:WaitForChild("Base"))
local Screen = require(Ui:WaitForChild("Screen"))
local Flow = require(Screens:WaitForChild("Flow"))
local Hud = require(Screens:WaitForChild("Hud"))
local Windows = require(Screens:WaitForChild("Windows"))
local Shop = require(Screens:WaitForChild("Shop"))

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local raceEvent = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent

CvcState.start()

local function attr(name: string): any
	return player:GetAttribute(name)
end

local function num(name: string): number
	local n = attr(name)
	return if type(n) == "number" then n else 0
end

local function clock(secs: number): string
	local s = math.max(0, math.ceil(secs))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ===== cars as the screens draw them =====

local KINDS = { "racer", "truck", "buggy" }
-- a car's body for its stand-in picture (until carter's pictures are in): the same every time
local function kindOf(id: string): string
	local n = 0
	for i = 1, #id do
		n += string.byte(id, i)
	end
	return KINDS[n % #KINDS + 1]
end

local function colorOf(id: string): Color3
	local c = CarCatalog.get(id)
	if c and c.color and #c.color >= 3 then
		return Color3.fromRGB(c.color[1], c.color[2], c.color[3])
	end
	return Base.color("blue")
end

local function rarityOf(id: string): string
	return UiTheme.rarityId(CarCatalog.rarity(id).id)
end

local function strength(car: Training.Car): number
	return Training.strength(car, CvcState.stats(car.id))
end

-- { power = { fill, "26/60" }, ... } for MY CAR (each bar against the car's own top)
local function hudBars(car: Training.Car?): { [string]: { any } }
	local out: { [string]: { any } } = {}
	for _, stat in UiTheme.STATS do
		if car then
			local v, cap = CvcState.bar(car, stat.bar)
			out[stat.key] = { if cap > 0 then v / cap else 0, `{math.floor(v)}/{cap}` }
		else
			out[stat.key] = { 0, "" }
		end
	end
	return out
end

-- the bar it's best at, in the plot's words (SPEED / BOOST / TURN)
local function bestWord(car: Training.Car): string
	local best, word = -1, ""
	for _, stat in UiTheme.STATS do
		local v = CvcState.bar(car, stat.bar)
		if v > best then
			best, word = v, stat.word
		end
	end
	return word
end

-- ===== one big moment at a time =====
-- A reveal or LEAGUE UP! waits until no race, race card or other big screen is up (the daily
-- gift waits for these too: the UiBusy attribute, Stars.client).

local FULL = { "pick", "reveal", "leagueUp" }
local WINDOWS = { "crates", "garage", "shop", "quests", "popup" }

local function anyOpen(list: { string }): boolean
	for _, id in list do
		if Screen.isOpen(id) then
			return true
		end
	end
	return false
end

local function shown(name: string, gui: string): boolean
	local g = pgui:FindFirstChild(gui)
	local f = g and g:FindFirstChild(name, true)
	if not (f and f:IsA("GuiObject") and f.Visible) then
		return false
	end
	local up = f.Parent
	while up and up ~= g do
		if up:IsA("GuiObject") and not up.Visible then
			return false
		end
		up = up.Parent
	end
	return (g :: ScreenGui).Enabled
end

local function raceCardUp(): boolean
	return shown("Result", "ServerRace") or shown("Finish", "CvcRaceTop")
end

local function calm(): boolean
	return attr("Driving") ~= true
		and attr("Racing") ~= true
		and not raceCardUp()
		and not anyOpen(FULL)
		and not shown("DailyGift", "StarsTop")
end

local moments: { () -> () } = {}
local function later(fn: () -> ())
	table.insert(moments, fn)
end
task.spawn(function()
	local still = 0
	while true do
		local dt = task.wait(0.25)
		still = if calm() and #moments > 0 then still + dt else 0
		if still >= 0.75 then
			still = 0
			local fn = table.remove(moments, 1)
			if fn then
				Screen.closeOver()
				fn()
			end
		end
	end
end)

-- ===== popups =====

local openGarage: () -> ()
local openCrates: () -> ()

local function join()
	if attr("RaceJoined") ~= true then
		raceEvent:FireServer("join")
		Sfx.spark()
	end
end

local function noCoins(need: number, back: (() -> ())?)
	local short = need - num("Coins")
	Windows.popup({
		kind = "coins",
		text = `You need {commas(short)} more. Race to win coins!`,
		yes = { "RACE!", "lime" },
		no = { "OK", "white" },
	}, {
		yes = function()
			Screen.closeOver()
			join()
		end,
		no = function()
			Screen.closeOver()
			if back then
				back()
			end
		end,
	})
end

local function info(icon: string, title: string, text: string)
	Windows.popup({
		kind = "sell",
		icon = icon,
		title = title,
		text = text,
		yes = { "OK", "lime" },
		no = false,
	}, { yes = Screen.closeOver, no = Screen.closeOver })
end

-- ===== the asks (the server allows one each 0.2 s: a few in a row go out spaced) =====

local nextAsk = 0
local function ask(...: any)
	local args = table.pack(...)
	local now = os.clock()
	local at = math.max(now, nextAsk)
	nextAsk = at + 0.3
	task.delay(at - now, function()
		CvcState.ask(table.unpack(args, 1, args.n))
	end)
end

-- ===== the crates window =====

local CRATE_LOOK = {
	free = { word = "FREE", rarity = "common" },
	basic = { word = "SMALL", rarity = "common" },
	big = { word = "BIG", rarity = "rare" },
	mega = { word = "MEGA", rarity = "epic" },
}

local function oddsOf(kind: string): { { [string]: any } }
	local got = Crates.odds(kind)
	local out = {}
	for _, r in CarCatalog.RARITY_ORDER do
		table.insert(out, { rarity = UiTheme.rarityId(r), chance = got[r] or 0 })
	end
	return out
end

local crateChoice = 1
local wantReveal = false -- a crate was asked for: its car shows the moment it comes
function openCrates()
	local kinds: { string } = if CvcState.crates > 0
		then { "free", "big", "mega" }
		else { "basic", "big", "mega" }
	local choices = {}
	for _, kind in kinds do
		local look = CRATE_LOOK[kind]
		local price = Crates.price(kind) or 0
		table.insert(choices, {
			kind = kind,
			word = look.word,
			rarity = look.rarity,
			price = price,
			priceWords = if kind == "free" then `FREE x{CvcState.crates}` else nil,
			odds = oddsOf(kind),
		})
	end
	Windows.crates({
		choices = choices,
		chosen = crateChoice,
		best = 2,
		coins = num("Coins"),
		note = "1 new car per crate. The odds are shown before you open.",
	}, {
		choose = function(i: number)
			crateChoice = i
		end,
		open = function(i: number)
			local ch = choices[i]
			if not ch then
				return
			end
			if #CvcState.garage >= Profile.MAX_GARAGE then
				info("lock", "Garage full", "Your garage has no room for a new car.")
				return
			end
			if ch.kind == "free" then
				wantReveal = true
				ask("open")
			elseif num("Coins") < ch.price then
				noCoins(ch.price, openCrates)
			else
				wantReveal = true
				ask("buy", ch.kind)
			end
		end,
		close = Screen.closeOver,
	})
end

-- the crate signs on the plot (CrateShop.client) open the same window
local shopEvent = ReplicatedStorage:FindFirstChild("CvcCrateShop")
if not (shopEvent and shopEvent:IsA("BindableEvent")) then
	local made = Instance.new("BindableEvent")
	made.Name = "CvcCrateShop"
	made.Parent = ReplicatedStorage
	shopEvent = made
end
(shopEvent :: BindableEvent).Event:Connect(function(kind: unknown)
	local list = if CvcState.crates > 0
		then { "free", "big", "mega" }
		else { "basic", "big", "mega" }
	crateChoice = table.find(list, kind) or crateChoice
	openCrates()
end)

-- ===== the garage window =====

local selectedUid = ""

local function garageCars(): { Training.Car }
	local list = table.clone(CvcState.garage)
	table.sort(list, function(a, b)
		local ra, rb = a.uid == CvcState.racer, b.uid == CvcState.racer
		if ra ~= rb then
			return ra
		end
		local ta, tb = CvcState.stationOf(a.uid) ~= nil, CvcState.stationOf(b.uid) ~= nil
		if ta ~= tb then
			return ta
		end
		local sa, sb = strength(a), strength(b)
		if sa ~= sb then
			return sa > sb
		end
		return a.uid < b.uid
	end)
	return list
end

local function stationPopup(i: number)
	local st = CvcState.stations[i]
	if not st then
		return
	end
	local name = Training.NAMES[st.kind] or "STATION"
	local word = ""
	for _, stat in UiTheme.STATS do
		if stat.station == st.kind then
			word = stat.word
		end
	end
	local cost = Training.upgradeCost(st.level)
	if st.level >= Training.MAX_STATION_LEVEL or not cost then
		info("trophy", `{name} LV {st.level}`, `Trains {word}. It is at the top level!`)
		return
	end
	Windows.popup({
		kind = "sell",
		icon = "coin",
		title = `{name} LV {st.level}`,
		text = `Trains {word}. LV {st.level + 1} trains faster: {commas(cost)} coins.`,
		yes = { "UPGRADE", "lime" },
		no = { "LATER", "white" },
	}, {
		yes = function()
			if num("Coins") < cost then
				noCoins(cost, openGarage)
				return
			end
			ask("upgrade", i)
			Sfx.levelUp()
			openGarage()
		end,
		no = openGarage,
	})
end

local function morePopup()
	local cost = Training.plotCost(CvcState.plotLevel)
	if not cost then
		return
	end
	local kinds = Training.stationsFor(CvcState.plotLevel + 1)
	local kind = kinds[#kinds]
	Windows.popup({
		kind = "sell",
		icon = "coin",
		title = "One more station!",
		text = `A new {Training.NAMES[kind] or "station"} for {commas(cost)} coins. One more car trains.`,
		yes = { "BUY", "lime" },
		no = { "LATER", "white" },
	}, {
		yes = function()
			if num("Coins") < cost then
				noCoins(cost, openGarage)
				return
			end
			ask("level")
			Sfx.levelUp()
			openGarage()
		end,
		no = openGarage,
	})
end

-- put a car on a station: an empty one first, else the one with the weakest car
local function trainCar(uid: string)
	if CvcState.stationOf(uid) then
		return
	end
	local pick, weakest = nil :: number?, math.huge
	for i, st in CvcState.stations do
		if st.uid == "" then
			pick = i
			break
		end
		local car = CvcState.find(st.uid)
		local s = if car then strength(car) else 0
		if s < weakest then
			pick, weakest = i, s
		end
	end
	if pick then
		ask("station", pick, uid)
	end
end

function openGarage()
	local cars = garageCars()
	local list = {}
	local selected = 1
	for i, car in cars do
		local racing = car.uid == CvcState.racer
		local st = CvcState.stationOf(car.uid)
		local stats = {}
		for _, stat in UiTheme.STATS do
			local v, cap = CvcState.bar(car, stat.bar)
			stats[stat.key] = `{math.floor(v)}/{cap}`
		end
		if car.uid == selectedUid then
			selected = i
		end
		table.insert(list, {
			id = car.id,
			uid = car.uid,
			name = CvcState.name(car.id),
			rarity = rarityOf(car.id),
			color = colorOf(car.id),
			kind = kindOf(car.id),
			tone = if racing then "lime" else "blue",
			badge = if racing then "RACE" elseif st then "TRAIN" else nil,
			stats = stats,
		})
	end
	local onTrack = {}
	for i, st in CvcState.stations do
		local car = if st.uid ~= "" then CvcState.find(st.uid) else nil
		if car then
			onTrack[i] = {
				id = car.id,
				color = colorOf(car.id),
				kind = kindOf(car.id),
				count = `LV{st.level}`,
			}
		end
	end
	Windows.garage({
		onTrack = onTrack,
		slots = #CvcState.stations,
		more = CvcState.plotLevel < Training.MAX_PLOT_LEVEL,
		moreWords = commas(Training.plotCost(CvcState.plotLevel) or 0),
		trackWord = "TRAINING",
		cars = list,
		selected = selected,
		trackTag = "CARS",
		room = tostring(#cars),
		equipWord = "RACE",
		deleteWord = "TRAIN",
		deleteTone = "blue",
		bestWord = "BEST CARS",
	}, {
		select = function(i: number)
			local c = list[i]
			selectedUid = if c then c.uid else ""
		end,
		equip = function(i: number)
			local c = list[i]
			if c then
				selectedUid = c.uid
				ask("racer", c.uid)
				Sfx.spark()
			end
		end,
		delete = function(i: number)
			local c = list[i]
			if c then
				selectedUid = c.uid
				trainCar(c.uid)
				Sfx.train()
			end
		end,
		equipBest = function()
			-- the strongest car races; the strongest ones train
			local best = garageCars()
			table.sort(best, function(a, b)
				return strength(a) > strength(b)
			end)
			if best[1] then
				ask("racer", best[1].uid)
			end
			for i in CvcState.stations do
				local c = best[i]
				if c and CvcState.stations[i].uid ~= c.uid then
					ask("station", i, c.uid)
				end
			end
			Sfx.spark()
		end,
		station = stationPopup,
		more = morePopup,
		close = Screen.closeOver,
	})
end

-- ===== the jobs window =====

local jobLines: { any } = {}
local jobsResetAt = 0

local function jobIcon(text: string): string
	local t = string.lower(text)
	if t:find("race") then
		return "trophy"
	elseif t:find("crate") then
		return "crate"
	elseif t:find("coach") or t:find("train") then
		return "power"
	end
	return "coin"
end

local function jobsWords(): string?
	if #jobLines == 0 then
		return nil
	end
	local done = 0
	for _, l in jobLines do
		done += if l.done then 1 else 0
	end
	return `JOBS {done}/{#jobLines}`
end

local function openJobs()
	local rows = {}
	for _, l in jobLines do
		table.insert(rows, {
			icon = jobIcon(l.text),
			words = l.text,
			have = math.min(l.have or 0, l.goal or 1),
			need = l.goal or 1,
			rewardIcon = "coin",
			reward = tostring(l.coins or 0),
			state = if l.done then "done" else "go",
		})
	end
	Windows.quests({
		title = "Jobs",
		tabs = { "TODAY" },
		tab = 1,
		timer = if jobsResetAt > 0 then clock(jobsResetAt - os.time()) else "",
		rows = rows,
	}, { go = Screen.closeOver, close = Screen.closeOver, tab = function() end })
end

-- ===== the plot screen =====

local hud: Screen.Handle? = nil
local staggered = false -- a new player gets the pieces one at a time, once

local function racer(): Training.Car?
	return CvcState.find(CvcState.racer)
end

local function openHud(stagger: boolean)
	local car = racer()
	hud = Hud.plot({
		coins = num("Coins"),
		rate = "",
		nextUp = { title = "BIG RACE soon", sub = "Tap RACE! to join" },
		car = { name = if car then CvcState.name(car.id) else "", stats = hudBars(car) },
		dots = { Crates = if CvcState.crates > 0 then CvcState.crates else nil },
		race = "RACE!",
		jobs = jobsWords() or "JOBS",
		stagger = stagger,
		-- (over the 3D plot: the scoreboard is top middle, the speed tracks right; the pads and the
		-- board show the bars, the RACE! button the clock)
		banner = false,
		myCar = false,
	}, {
		Garage = openGarage,
		Crates = openCrates,
		Shop = function()
			-- (no Robux prices until carter sets them: SOON, not R$ ???)
			Shop.open({ tab = 1, offer = { price = "SOON" } }, {
				close = Screen.closeOver,
				tab = function() end,
				buyOffer = function()
					info(
						"bag",
						"Coming soon!",
						"The shop opens soon. Skins only: no car gets faster."
					)
				end,
				buySale = function()
					info(
						"bag",
						"Coming soon!",
						"The shop opens soon. Skins only: no car gets faster."
					)
				end,
				buyMini = function()
					info(
						"bag",
						"Coming soon!",
						"The shop opens soon. Skins only: no car gets faster."
					)
				end,
			})
		end,
		League = function()
			local n = League.clamp(attr("League"))
			info(
				"trophy",
				`{string.upper(League.name(n))} LEAGUE`,
				if n < #League.NAMES
					then "Train your car and win races to move up!"
					else "The top league! Keep winning!"
			)
		end,
		race = join,
		jobs = openJobs,
		coach = function()
			if Training.coachReady(num("CoachAt"), workspace:GetServerTimeNow()) then
				ask("coach")
				Sfx.train()
			end
		end,
	})
end

local function refreshHud()
	local h = hud
	if not h then
		return
	end
	local api = h.api
	local car = racer()
	api.setCar(if car then CvcState.name(car.id) else "", hudBars(car))
	api.setDot("Crates", if CvcState.crates > 0 then CvcState.crates else nil)
	api.setJobs(jobsWords() or "JOBS")
end

-- the plot screen shows on foot once you have a car; not in a race, not under a big screen
local hudOn = false
local lastCoins = -1
local lastText = 0
RunService.Heartbeat:Connect(function()
	local want = CvcState.loaded
		and attr("Picked") == true
		and attr("Driving") ~= true
		and attr("Racing") ~= true
		and not anyOpen(FULL)
	-- (and it steps away under a window, so nothing peeks out past it, and while the race card
	-- is up, Studio live1)
	local shows = want and not anyOpen(WINDOWS) and not raceCardUp()
	if want and not hud then
		openHud(not staggered and attr("JustPicked") == true)
		staggered = true
	end
	local h = hud
	if h and shows ~= hudOn then
		hudOn = shows
		Base.show(h.gui, shows)
	end
	player:SetAttribute("UiBusy", anyOpen(FULL) or anyOpen(WINDOWS))
	if not (h and shows) then
		return
	end
	-- the words change at most 10 times a second
	local now = os.clock()
	if now - lastText < 0.1 then
		return
	end
	lastText = now
	local api = h.api
	local coins = num("Coins")
	if coins ~= lastCoins then
		lastCoins = coins
		api.setCoins(coins)
	end
	-- BIG RACE in m:ss, and RACE! / YOU'RE IN! (white words on blue: never yellow on yellow)
	local raw = workspace:GetAttribute("NextRaceAt")
	local left = if type(raw) == "number" then raw - workspace:GetServerTimeNow() else nil
	local inIt = attr("RaceJoined") == true
	local t = if left and left > 0 then clock(left) else nil
	if inIt then
		api.setNextUp(
			if t then `BIG RACE in {t}` else "BIG RACE soon",
			"You're in! Keep training",
			left ~= nil and left < 10
		)
		api.setRace(if t then `YOU'RE IN! {t}` else "YOU'RE IN!", "blue", false)
	else
		api.setNextUp(
			if t then `BIG RACE in {t}` else "BIG RACE soon",
			"Tap RACE! to join 8 cars",
			left ~= nil and left < 10
		)
		api.setRace(if t then `RACE! {t}` else "RACE!", "lime", true)
	end
	-- COACH: 2x training for 10 s, once a minute
	local at = num("CoachAt")
	local sNow = workspace:GetServerTimeNow()
	if Training.coaching(at, sNow) then
		local f = (Training.COACH_SECS - (sNow - at)) / Training.COACH_SECS
		api.setCoach(f, `2X {math.ceil(Training.COACH_SECS - (sNow - at))}`)
	elseif Training.coachReady(at, sNow) then
		api.setCoach(0, "")
	else
		local wait = Training.COACH_EVERY - (sNow - at)
		api.setCoach(wait / Training.COACH_EVERY, clock(wait))
	end
end)

-- ===== a bar goes up: "+1 SPEED" floats up by MY CAR =====

-- one at a time, each a bit apart, so two that come together don't land on each other
-- ("+1 TURN" over "+1 BOOST", Studio plot-edges 16)
local floatAt = 0
local floatSide = 1
local function floatUp(words: string, tone: string, max: boolean)
	local now = os.clock()
	local at = math.max(now, floatAt)
	if at - now > 3 then
		return -- (lots at once: the rest wait for the next change)
	end
	floatAt = at + 0.7
	floatSide = -floatSide
	local x = 378 + floatSide * 50
	task.delay(at - now, function()
		local h = hud
		if h and hudOn then
			h.api.float(x, 290, words, tone)
			if max then
				Sfx.maxed()
			else
				Sfx.speedUp()
			end
		end
	end)
end

local lastBars: { [string]: number } = {}
local lastStations: { any } = CvcState.stations
CvcState.changed:Connect(function()
	refreshHud()
	local h = hud
	for _, st in CvcState.stations do
		local car = if st.uid ~= "" then CvcState.find(st.uid) else nil
		if car then
			for _, stat in UiTheme.STATS do
				local v, cap = CvcState.bar(car, stat.bar)
				local whole = math.floor(v)
				local key = car.uid .. stat.bar
				local was = lastBars[key]
				if was and whole > was and h and hudOn and car.uid == CvcState.racer then
					local words = if v >= cap
						then `{stat.word} MAX!`
						else `+{whole - was} {stat.word}`
					floatUp(words, stat.tone, v >= cap)
				end
				lastBars[key] = whole
			end
		end
	end
	-- a new list (an ask went through): an open garage shows it
	if CvcState.stations ~= lastStations then
		lastStations = CvcState.stations
		if Screen.isOpen("garage") then
			openGarage()
		end
	end
end)

-- ===== PICK YOUR FIRST CAR =====

local function openPick()
	local ids = CvcState.starters()
	-- the bars against the biggest starting bar of the three, so they don't look empty
	local top = 1
	for _, id in ids do
		local car = CvcState.fresh(id)
		for _, b in Training.BARS do
			top = math.max(top, (CvcState.bar(car, b)))
		end
	end
	local cars = {}
	for _, id in ids do
		local car = CvcState.fresh(id)
		local stats = {}
		for _, stat in UiTheme.STATS do
			stats[stat.key] = (CvcState.bar(car, stat.bar)) / top
		end
		table.insert(cars, {
			id = id,
			name = CvcState.name(id),
			word = bestWord(car),
			color = colorOf(id),
			kind = kindOf(id),
			stats = stats,
		})
	end
	Flow.pick({ cars = cars }, {
		go = function(i: number)
			local c = cars[i]
			if c then
				player:SetAttribute("JustPicked", true)
				ask("pick", c.id)
				Sfx.cheer()
			end
		end,
	})
end

task.spawn(function()
	while not CvcState.loaded do
		task.wait(0.2)
	end
	while attr("Picked") ~= true do
		if not Screen.isOpen("pick") then
			openPick()
		end
		task.wait(0.5)
	end
	if Screen.isOpen("pick") then
		Screen.closeOver()
	end
end)

-- ===== a new car from a crate: the reveal =====

local function reveal(id: string, rarity: string)
	Sfx.crate(table.find(CarCatalog.RARITY_ORDER, rarity) or 1)
	Flow.reveal({
		id = id,
		rarity = UiTheme.rarityId(rarity),
		name = CvcState.name(id),
		color = colorOf(id),
		kind = kindOf(id),
		new = true,
		note = "New car! It's in your GARAGE: tap TRAIN to put it on a station.",
		-- OPEN ANOTHER only with a free crate left or the coins for a small one
		again = CvcState.crates > 0 or num("Coins") >= (Crates.price("basic") or math.huge),
	}, {
		cool = Screen.closeOver,
		again = function()
			Screen.closeOver()
			openCrates()
		end,
	})
end

CvcState.event:Connect(function(kind: unknown, a: unknown, b: unknown)
	if kind == "crate" and type(a) == "string" then
		local rarity = if type(b) == "string" then b else CarCatalog.rarity(a).id
		if wantReveal and calm() then
			wantReveal = false
			Screen.closeOver()
			reveal(a, rarity)
		else
			later(function()
				reveal(a, rarity)
			end)
		end
	end
end)

-- ===== LEAGUE UP! =====

local shownLeague: number? = nil
local function onLeague()
	if attr("League") == nil then
		return
	end
	local n = League.clamp(attr("League"))
	if shownLeague and n > shownLeague then
		local from = shownLeague
		later(function()
			Sfx.fireworks()
			Flow.leagueUp({ from = from, to = n }, { ok = Screen.closeOver })
		end)
	end
	shownLeague = n
end
player:GetAttributeChangedSignal("League"):Connect(onLeague)
onLeague()

-- ===== today's jobs (StarsEvent "jobs", the same list the old JOBS chip showed) =====

task.spawn(function()
	local e = ReplicatedStorage:WaitForChild("StarsEvent", 60)
	if not (e and e:IsA("RemoteEvent")) then
		return
	end
	e.OnClientEvent:Connect(function(kind: unknown, lines: unknown, secs: unknown)
		if kind == "jobs" and type(lines) == "table" then
			jobLines = {}
			for _, l in lines :: { any } do
				if type(l) == "table" and type(l.text) == "string" then
					table.insert(jobLines, l)
				end
			end
			if type(secs) == "number" then
				jobsResetAt = os.time() + secs
			end
			refreshHud()
		end
	end)
end)
