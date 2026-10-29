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
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
-- SMASH (10-28): the plot screen is the lobby's: coins, CUSTOMIZE, crates and the SMASH! goal (the
-- pad in the world starts a match); no coach, training or race goals
local SMASH = (Features :: any).SMASH == true
if not (Features.CVC and Features.NEW_UI) then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Crates = require(Shared:WaitForChild("Crates"))
local CvcGoal = require(Shared:WaitForChild("CvcGoal"))
local League = require(Shared:WaitForChild("League"))
local Profile = require(Shared:WaitForChild("Profile"))
local Training = require(Shared:WaitForChild("Training"))
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local WarmupYard = require(Shared:WaitForChild("WarmupYard"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local LeagueUp = require(script.Parent:WaitForChild("LeagueUp"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Ui = script.Parent:WaitForChild("Ui")
local Screens = Ui:WaitForChild("Screens")
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))
local Screen = require(Ui:WaitForChild("Screen"))
local Flow = require(Screens:WaitForChild("Flow"))
local Hud = require(Screens:WaitForChild("Hud"))
local Windows = require(Screens:WaitForChild("Windows"))
local Shop = require(Screens:WaitForChild("Shop"))
local Smash = require(Screens:WaitForChild("Smash"))

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
-- (Smash: the server race is gone; RCControl "quick" puts you on the next round's list)
local rcControl = ReplicatedStorage:WaitForChild("RCControl") :: RemoteEvent

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
local function hash(id: string): number
	local n = 0
	for i = 1, #id do
		n += string.byte(id, i)
	end
	return n
end
-- a car's body for its stand-in picture (until carter's pictures are in): the same every time
local function kindOf(id: string): string
	return KINDS[hash(id) % #KINDS + 1]
end

-- a bot on the podium (no car of ours): a color from its name, the next free one if another bot
-- on the same podium has it (Studio live4 04, 07)
local BOT_COLORS = { "danger", "lime", "boost", "pink", "go", "blue" }
local function botColor(name: string, used: { [number]: boolean }): Color3
	local i = hash(name) % #BOT_COLORS
	for _ = 1, #BOT_COLORS do
		if not used[i] then
			break
		end
		i = (i + 1) % #BOT_COLORS
	end
	used[i] = true
	return Base.color(BOT_COLORS[i + 1])
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

local FULL = { "pick", "reveal", "leagueUp", "podium" }
local WINDOWS = { "crates", "garage", "shop", "quests", "popup", "daily" }

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
		and not Screen.isOpen("daily")
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
	if attr("MatchQueued") ~= true and attr("InMatch") ~= true then
		rcControl:FireServer("quick")
		Sfx.spark()
	end
end

local function noCoins(need: number, back: (() -> ())?)
	local short = need - num("Coins")
	Windows.popup({
		kind = "coins",
		text = `Need {commas(short)} more coins!`,
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
		-- (a 0% row is a word to read that never matters: left out)
		if (got[r] or 0) > 0 then
			table.insert(out, { rarity = UiTheme.rarityId(r), chance = got[r] })
		end
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
		-- (smash: karts; every one drives the same, so a crate is a new look, not a win)
		note = if SMASH then SmashScreens.WORDS.crateNote else "1 car per crate.",
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
				info(
					"lock",
					"Garage full",
					if SMASH then SmashScreens.WORDS.garageFull else "No room for cars."
				)
				return
			end
			if ch.kind == "free" then
				wantReveal = true
				ask("open")
			elseif num("Coins") < ch.price then
				noCoins(ch.price, openCrates)
			else
				wantReveal = true
				Sfx.buy()
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
		info("trophy", `{name} LV {st.level}`, `{word}: top level!`)
		return
	end
	Windows.popup({
		kind = "sell",
		icon = "coin",
		title = `{name} LV {st.level}`,
		text = `{commas(cost)} coins: faster {word}!`,
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
		text = `{commas(cost)} coins: +1 {Training.NAMES[kind] or "station"}!`,
		yes = { "BUY", "lime" },
		no = { "LATER", "white" },
	}, {
		yes = function()
			if num("Coins") < cost then
				noCoins(cost, openGarage)
				return
			end
			ask("level")
			Sfx.buy()
			Sfx.unlock()
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
			stats = if SMASH then nil else stats,
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
		title = "Train",
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

-- TRAIN shows "!" while a station stands empty and a car could go on it
local function trainDot(): number?
	local empty = false
	for _, st in CvcState.stations do
		if st.uid == "" then
			empty = true
		end
	end
	if not empty then
		return nil
	end
	for _, car in CvcState.garage do
		if not CvcState.stationOf(car.uid) then
			return -1
		end
	end
	return nil
end

-- just picked: "THIS IS BOLT, YOUR CAR!" for a few seconds (the playtest: the kid never knew
-- which car was his, review fix 4)
local function yourCar()
	local car = racer()
	local h = hud
	if not car or not h then
		return
	end
	local words = `THIS IS {CvcState.name(car.id)}, YOUR CAR!`
	local l = Kit.shout(h.gui.canvas, 168, 104, 420, 46, words, "go")
	local holder = l.Parent
	task.delay(4.5, function()
		if holder then
			holder:Destroy()
		end
	end)
end

-- the race countdown: the car's name and speed under the big 3, 2, 1 (review fix 4)
local tagGui: Base.Gui? = nil
local function carTag()
	local car = racer()
	-- (Smash: no name bar over the kart at the start; the YOU tag and the weapon icon are
	-- enough, Studio round 6)
	if SMASH or not car then
		return
	end
	local g = tagGui or Base.screen("Ui_CarTag", Base.ORDER.hud, false)
	tagGui = g
	for _, c in g.canvas:GetChildren() do
		c:Destroy()
	end
	local spd = math.floor((CvcState.bar(car, "speed")))
	local pill = Base.fill(g.canvas, "Tag", 248, 230, 260, 40, Base.color("ink"), 2)
	pill.BackgroundTransparency = 0.15
	Base.corner(pill)
	Base.outline(pill, 3, Base.color("go"))
	local words = `{CvcState.name(car.id)}  SPD {spd}`
	Base.text(pill, "Words", 10, 4, 240, 32, words, {
		color = Base.color("go"),
		stroke = 4,
		z = 3,
	})
	Base.show(g, true)
	task.delay(5, function()
		if tagGui == g and pill.Parent then
			Base.show(g, false)
		end
	end)
end
-- from the first of 3, 2, 1 (Main's CountStep; Racing only comes on at GO, Studio pr816)
local tagAt = 0
local function tagOnce()
	if os.clock() - tagAt > 8 then
		tagAt = os.clock()
		carTag()
	end
end
player:GetAttributeChangedSignal("CountStep"):Connect(function()
	if attr("Driving") == true then
		tagOnce()
	end
end)
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if attr("Racing") == true then
		tagOnce()
	elseif tagGui then
		Base.show(tagGui, false)
	end
end)

local coachedAt = 0 -- (os.clock) this visit's last COACH tap

-- the one thing to tap next on the plot screen, and its words (first 10 minutes: COACH, then
-- RACE!, then the crate, a car onto its station, a crate to buy, the next race)
-- The small bar under the coins: coins toward the next buy, the cheaper of one more station and
-- a crate (gap 4 of the first-10 timeline: always something to save up for). nil = nothing left.
local function nextBuy(): (string?, number, string?)
	local coins = num("Coins")
	-- (SMASH: no training stations, only crates)
	local station = if SMASH then nil else Training.plotCost(CvcState.plotLevel)
	local crate = if #CvcState.garage < Profile.MAX_GARAGE then CvcGoal.cheapest() else nil
	if crate == math.huge then
		crate = nil
	end
	local kind, cost
	if station and (not crate or station <= crate) then
		kind, cost = "STATION", station
	elseif crate then
		kind, cost = "CRATE", crate
	else
		return nil, 0, nil
	end
	if coins >= cost then
		return `{kind} READY! TAP`, 1, kind
	end
	return `NEXT {kind}  {commas(coins)}/{commas(cost)}`, coins / cost, kind
end
local nextKind: string? = nil

-- driving in Smash's warm-up yard? (your kart, or you on foot; WarmupYard.client's check)
local function inYard(): boolean
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local body = if car and car:IsA("Model") then car.PrimaryPart else nil
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local part = body or (if root and root:IsA("BasePart") then root else nil)
	if not part then
		return false
	end
	local p = part.Position
	return WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z })
end

local function hudGoal(): (string?, string?)
	if attr("Picked") ~= true then
		return nil, nil
	end
	if SMASH then
		if CvcState.crates > 0 then
			return "Crates", "OPEN CRATE!"
		end
		if num("Coins") >= CvcGoal.cheapest() and #CvcState.garage < Profile.MAX_GARAGE then
			return "Crates", "GET A CRATE!"
		end
		if attr("InMatch") == true or attr("MatchQueued") == true then
			return nil, nil
		end
		return "Race", "GO SMASH!"
	end
	local joined = attr("RaceJoined") == true
	if num("Stage") < Profile.STAGE.RACED then
		if num("CoachAt") == 0 and coachedAt == 0 then
			return "Coach", "TAP COACH!"
		end
		if joined then
			return nil, nil
		end
		return "Race", "TAP RACE!"
	end
	if CvcState.crates > 0 then
		return "Crates", "OPEN CRATE!"
	end
	if trainDot() then
		return "Garage", "TAP TRAIN!"
	end
	-- (the bar under the coins is full: it is the next thing to tap)
	local _, full, kind = nextBuy()
	if full >= 1 and kind == "STATION" then
		return "Next", "BUY A STATION!"
	end
	if num("Coins") >= CvcGoal.cheapest() and #CvcState.garage < Profile.MAX_GARAGE then
		return "Crates", "GET A CRATE!"
	end
	if joined then
		return nil, nil
	end
	return "Race", "TAP RACE!"
end

-- no tap for a while: the arrow gets louder (says what to tap)
local IDLE_NUDGE = 5
local lastInput = os.clock()
UserInputService.InputBegan:Connect(function()
	lastInput = os.clock()
end)
local lastGoal: string? = nil

-- INVITE: Roblox's invite screen (a friend in this server pays you both, FriendBonus). Only where
-- Roblox lets this player send invites: it asks the web, so off the main thread, twice at most.
local canInvite = false
local inviting = false
task.spawn(function()
	for _ = 1, 2 do
		local ok, yes = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok then
			canInvite = yes == true
			return
		end
		task.wait(10)
	end
end)
local function invite()
	if inviting then
		return
	end
	inviting = true
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Race me in Car VS Car!"
		SocialService:PromptGameInvite(player, options)
	end)
	if not ok then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
	task.delay(1, function()
		inviting = false
	end)
end

-- SMASH: CUSTOMIZE is WINDOWS' window (SmashCustomize.client listens on OpenCustomize)
local function openCustomize()
	local ev = ReplicatedStorage:FindFirstChild("OpenCustomize")
	if ev and ev:IsA("BindableEvent") then
		ev:Fire()
	end
end
-- SMASH: the pad in the world starts a match, so the SMASH! button says where it is
local function smashHow()
	info("power", "SMASH!", "Drive onto the SMASH! pad to play!")
end

-- a phone's Smash lobby (carter 10-29: too cluttered): MENU + SMASH! and the coins; the other
-- buttons live in the MENU window (Smash.menu)
local PHONE_LOBBY = SMASH and Base.phone()
local plotActions: { [string]: (...any) -> () } = {}
-- (found or made here and in LuckySpin, whichever runs first: a tap never falls through)
local function spinEvent(): BindableEvent
	local ev = ReplicatedStorage:FindFirstChild("OpenSpin")
	if ev and ev:IsA("BindableEvent") then
		return ev
	end
	local made = Instance.new("BindableEvent")
	made.Name = "OpenSpin"
	made.Parent = ReplicatedStorage
	return made
end
local function openSpin()
	spinEvent():Fire()
end
local menuHandle: Screen.Handle? = nil
-- (a match starting puts the MENU away, as CUSTOMIZE and SPIN do)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	local m = menuHandle
	if attr("InMatch") == true and m and Screen.isOpen("menu") then
		m.close()
		menuHandle = nil
	end
end)
local function openMenu()
	local stage = num("Stage")
	local shopped = stage >= Profile.STAGE.SHOPPED
	local items: { { [string]: any } } = {
		{ id = "customize", word = "GARAGE", icon = "power" },
		{
			id = "crates",
			word = "CRATES",
			icon = "crate",
			dot = if CvcState.crates > 0 then CvcState.crates else nil,
		},
		{
			id = "spin",
			word = "SPIN",
			icon = "gift",
			dot = if attr("SpinReady") == true then -1 else nil,
		},
	}
	if shopped then
		table.insert(items, { id = "shop", word = "SHOP", icon = "bag" })
		table.insert(items, { id = "league", word = "LEAGUE", icon = "trophy" })
		table.insert(items, { id = "jobs", word = "JOBS", icon = "check" })
		if canInvite then
			table.insert(items, { id = "invite", word = "INVITE", icon = "heart" })
		end
	end
	menuHandle = Smash.menu({ items = items }, {
		close = Screen.closeOver,
		customize = openCustomize,
		crates = openCrates,
		spin = openSpin,
		shop = function()
			plotActions.Shop()
		end,
		league = function()
			plotActions.League()
		end,
		jobs = openJobs,
		invite = invite,
	})
end

local function openHud(stagger: boolean)
	local car = racer()
	hud = Hud.plot({
		coins = num("Coins"),
		rate = "",
		nextUp = { title = "BIG RACE soon", sub = "Tap RACE! to join" },
		car = { name = if car then CvcState.name(car.id) else "", stats = hudBars(car) },
		dots = {
			Crates = if CvcState.crates > 0 then CvcState.crates else nil,
			Garage = if SMASH then nil else trainDot(),
		},
		-- (the garage is where a car goes on a station: the tile says so, 10 s test)
		words = { Garage = if PHONE_LOBBY then "MENU" elseif SMASH then "CUSTOMIZE" else "TRAIN" },
		icons = if PHONE_LOBBY then { Garage = "plus" } else nil,
		smallCoins = PHONE_LOBBY,
		race = if SMASH then "SMASH!" else "RACE!",
		jobs = jobsWords() or "JOBS",
		invite = "INVITE",
		next = (function()
			local w, f, kind = nextBuy()
			nextKind = kind
			return { words = w or "", f = f }
		end)(),
		stagger = stagger,
		-- (over the 3D plot: the scoreboard is top middle, the speed tracks right; the pads and the
		-- board show the bars, the RACE! button the clock)
		banner = false,
		myCar = false,
	}, plotActions)
	if SMASH and hud then
		hud.api.setShown("Coach", false) -- (from the first frame, not the next tick)
	end
end

plotActions = {
	Garage = if PHONE_LOBBY then openMenu elseif SMASH then openCustomize else openGarage,
	Crates = openCrates,
	Shop = function()
		-- (no Robux prices until carter sets them: SOON, not R$ ???)
		Shop.open({ tab = 1, offer = { price = "SOON" } }, {
			close = Screen.closeOver,
			tab = function() end,
			buyOffer = function()
				info("bag", "Coming soon!", "Skins only. Soon!")
			end,
			buySale = function()
				info("bag", "Coming soon!", "Skins only. Soon!")
			end,
			buyMini = function()
				info("bag", "Coming soon!", "Skins only. Soon!")
			end,
		})
	end,
	League = function()
		local n = League.clamp(attr("League"))
		info(
			"trophy",
			`{string.upper(League.name(n))} LEAGUE`,
			if n < #League.NAMES then "Get top 3 to move up!" else "Top league!"
		)
	end,
	race = if SMASH then smashHow else join,
	jobs = openJobs,
	invite = invite,
	-- (full: the buy itself; not yet: where it's bought, to see what it gets)
	next = function()
		if nextKind == "STATION" then
			morePopup()
		elseif nextKind == "CRATE" then
			openCrates()
		end
	end,
	coach = function()
		if Training.coachReady(num("CoachAt"), workspace:GetServerTimeNow()) then
			ask("coach")
			Sfx.train()
			-- (right away, not when the server's next bar step comes: the tap shows at once)
			coachedAt = os.clock()
			local h = hud
			if h then
				-- (in from the edge: its "!" was cut; up over INVITE, Studio pr816)
				h.api.float(636, 205, `{Training.COACH_MULT}X TRAINING!`)
			end
		end
	end,
}

local function refreshHud()
	local h = hud
	if not h then
		return
	end
	local api = h.api
	local car = racer()
	api.setCar(if car then CvcState.name(car.id) else "", hudBars(car))
	api.setDot("Crates", if CvcState.crates > 0 then CvcState.crates else nil)
	if not PHONE_LOBBY then -- (a phone's MENU dot is set with the tiles)
		api.setDot("Garage", if SMASH then nil else trainDot())
	end
	api.setJobs(jobsWords() or "JOBS")
end

-- the plot screen shows on foot once you have a car; not in a race, not under a big screen
local hudOn = false
local lastCoins = -1
local lastNext: string? = nil
local lastText = 0
RunService.Heartbeat:Connect(function()
	local want = CvcState.loaded
		and attr("Picked") == true
		-- (Smash: you drive a kart all over the lobby, so driving doesn't hide it; the arena does)
		and (SMASH or (attr("Driving") ~= true and attr("Racing") ~= true))
		and attr("InMatch") ~= true
		and not anyOpen(FULL)
	-- (and not in the Smash arena: only the match HUD there, the lobby SMASH! button and its
	-- arrow sat on your kart all match, WEAPONS Studio after-923)
	-- (and it steps away under a window, so nothing peeks out past it, and while the race card
	-- is up, Studio live1)
	-- (any window at all, Customize too: INVITE peeked out behind its card)
	local shows = want and not anyOpen(WINDOWS) and not Screen.anyOver() and not raceCardUp()
	if want and not hud then
		local fresh = not staggered and attr("JustPicked") == true
		openHud(fresh)
		staggered = true
		if fresh then
			yourCar()
		end
	end
	local h = hud
	-- (against the gui itself too: it opens on, so a HUD made while it shouldn't show stayed up,
	-- the SMASH! button over the kart in the yard and the arena, Studio final)
	if h and (shows ~= hudOn or h.gui.gui.Enabled ~= shows) then
		hudOn = shows
		Base.show(h.gui, shows)
	end
	player:SetAttribute("UiBusy", anyOpen(FULL) or anyOpen(WINDOWS))
	if attr("InMatch") == true then
		-- (the match pays out while this is hidden: no late coin ching back in the lobby, the
		-- match end has its own +coins)
		lastCoins = -1
	end
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
	-- one step at a time: a tile shows once it has something for you (first 10 minutes)
	local stage = num("Stage")
	-- (SMASH: the lobby shows its tiles from the start; there's no first race to wait for)
	local raced = SMASH or stage >= Profile.STAGE.RACED
	local shopped = stage >= Profile.STAGE.SHOPPED
	-- (a phone's Smash lobby: MENU holds all of these)
	local menu = PHONE_LOBBY
	api.setShown("Crates", not menu and (raced or CvcState.crates > 0))
	api.setShown("Garage", raced or #CvcState.garage > 1 or trainDot() ~= nil)
	api.setShown("Shop", shopped and not menu)
	api.setShown("League", shopped and not menu)
	api.setShown("Jobs", shopped and not menu)
	-- (after the first race: by then there's a race to bring a friend to)
	-- (after the first crate, with the other later things: fewer pieces at once, auditor L2)
	api.setShown("Invite", shopped and canInvite and not menu)
	if menu then
		-- the MENU tile's dot: a crate to open or today's free spin
		api.setDot(
			"Garage",
			if CvcState.crates > 0
				then CvcState.crates
				elseif attr("SpinReady") == true then -1
				else nil
		)
	end
	-- one arrow on the one thing to tap
	local goal, goalWords = hudGoal()
	if menu and goal == "Crates" then
		goal = "Garage" -- (the crates are in the MENU)
	end
	if goal ~= lastGoal then
		lastGoal = goal
		-- (the world can follow the one next thing too: the plot thread reads it)
		player:SetAttribute("HudGoal", goal)
		lastInput = now
	end
	-- (Smash's warm-up yard: the SMASH! button and its arrow sat on your kart there, and the yard
	-- has its own NEXT MATCH clock; LOBBY 00:37)
	local yard = SMASH and inYard()
	-- (Smash: no arrow or GO SMASH! words at the SMASH! button, it pulses instead; beside it the
	-- words still sat over your kart, auditor round 12)
	api.point(
		if goal == "Race" and (yard or SMASH) then nil else goal,
		goalWords,
		now - lastInput >= IDLE_NUDGE,
		SMASH -- (from the side: over the SMASH! button it sat on the kart, auditor garage shot)
	)
	local coins = num("Coins")
	local nw, nf, nk = nextBuy()
	if coins ~= lastCoins or nk ~= nextKind or nw ~= lastNext then
		-- coins came in: a ching, a short climbing stream for a big win (none on join)
		if lastCoins >= 0 and coins > lastCoins then
			for i = 1, math.clamp(math.ceil((coins - lastCoins) / 25), 1, 6) do
				task.delay((i - 1) * 0.07, Sfx.coin, i)
			end
		end
		lastCoins = coins
		api.setCoins(coins)
		nextKind, lastNext = nk, nw
		api.setNext(nw or "", nf)
	end
	-- (after the first race, with the other later things: one new thing at a time)
	api.setShown("Next", raced and nk ~= nil and not PHONE_LOBBY)
	if SMASH then
		-- SMASH! / YOU'RE IN! (the pad queues you); no coach
		api.setShown("Coach", false)
		local queued = attr("MatchQueued") == true
		api.setShown("Race", attr("InMatch") ~= true and not yard)
		-- (no clock here: LOBBY's top strip has NEXT MATCH IN m:ss, one clock only, audit R4-5)
		if queued then
			api.setRace("YOU'RE IN!", "blue", false)
		else
			api.setRace("SMASH!", "lime", goal == "Race")
		end
		return
	end
	-- BIG RACE in m:ss, and RACE! / YOU'RE IN! (white words on blue: never yellow on yellow)
	local raw = workspace:GetAttribute("NextRaceAt")
	local left = if type(raw) == "number" then raw - workspace:GetServerTimeNow() else nil
	local inIt = attr("RaceJoined") == true
	-- (a new kid's first race starts a few seconds after their tap, so no clock to run out: carter's
	-- phone run 10-28 watched RACE! 0:01 hit 0 with nothing happening)
	local firstRace = num("Stage") < Profile.STAGE.RACED
	local t = if left and left > 0 and not firstRace then clock(left) else nil
	if inIt then
		api.setNextUp(
			if t then `BIG RACE in {t}` else "BIG RACE soon",
			"You're in! Keep training",
			left ~= nil and left < 10
		)
		-- (one clock only: BIG RACE in m:ss; the RACE! button has no clock)
		api.setRace("YOU'RE IN!", "blue", false)
	else
		api.setNextUp(
			if t then `BIG RACE in {t}` else "BIG RACE soon",
			"Tap RACE! to join 8 cars",
			left ~= nil and left < 10
		)
		-- (it pulses only when it's the next thing to do: one thing glows, auditor L2)
		api.setRace("RACE!", "lime", goal == "Race")
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
		-- (the ring fills back up; no third clock)
		api.setCoach(wait / Training.COACH_EVERY, "")
	end
end)

-- ===== a bar goes up: "+1 SPEED" floats up by MY CAR =====

-- one at a time, each a bit apart, so two that come together don't land on each other
-- ("+1 TURN" over "+1 BOOST", Studio plot-edges 16)
local floatAt = 0
local floatSide = 1
local function floatUp(words: string, _tone: string, max: boolean)
	local now = os.clock()
	local at = math.max(now, floatAt)
	if at - now > 3 then
		return -- (lots at once: the rest wait for the next change)
	end
	-- (1 s apart and 180 px apart: at 0.7 s and 100 px "+1 TURN" still ran into "+1 BOOST",
	-- carter's phone 10-28)
	floatAt = at + 1
	floatSide = -floatSide
	local x = 378 + floatSide * 90
	task.delay(at - now, function()
		local h = hud
		if h and hudOn then
			-- (one look for every float: gold with the ink edge; lime "+1 TURN" was faint on the
			-- light floor)
			h.api.float(x, 290, words)
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
				-- (only while coaching, or at MAX: a +1 every few seconds while the kid walked away
				-- rewarded nothing he did, phone 10-28)
				local loud = v >= cap
					or Training.coaching(num("CoachAt"), workspace:GetServerTimeNow())
				if was and whole > was and h and hudOn and car.uid == CvcState.racer and loud then
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
	-- SMASH: no pick screen (it would cover the match); the server gives a new kid the first
	-- starter kart as their save loads (GARAGE)
	if (Features :: any).SMASH == true then
		return
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

local function revealNote(id: string): string
	if SMASH then
		return SmashScreens.WORDS.revealNote
	end
	for _, car in CvcState.garage do
		if car.id == id and CvcState.stationOf(car.uid) then
			return "It's training!"
		end
	end
	return if trainDot() then "TAP TRAIN!" else "It's in your garage!"
end

local function reveal(id: string, rarity: string)
	Sfx.crate(table.find(CarCatalog.RARITY_ORDER, rarity) or 1)
	-- its starting bars, as on the garage card ("20/70")
	local car = CvcState.fresh(id)
	local stats = {}
	for _, stat in UiTheme.STATS do
		local v, cap = CvcState.bar(car, stat.bar)
		stats[stat.key] = `{math.floor(v)}/{cap}`
	end
	Flow.reveal({
		id = id,
		rarity = UiTheme.rarityId(rarity),
		name = CvcState.name(id),
		color = colorOf(id),
		kind = kindOf(id),
		new = true,
		stats = if SMASH then nil else stats,
		-- (the new car goes onto a free station by itself: then there's nothing to tap; with every
		-- station full it only waits in the garage, Studio pr847 shot 03)
		note = revealNote(id),
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
		-- (asked for: right away, even still on the driver stand after the race)
		if wantReveal and not anyOpen(FULL) and not raceCardUp() then
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
		-- the whole ceremony (tint, flash, rays, fireworks): LeagueUp.luau (the LEAGUE row)
		later(function()
			LeagueUp.play(from, n)
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

-- ===== the race: the podium =====

-- (the place shows in the lap clock top left, Main.client: no pill over the move stick)

local podiumAt = 0
-- the racer's SPEED at the last podium (or when the game started), for "+N SPD from training!"
local spdAtRace: number? = nil
local spdCar = "" -- (whose: a new racer starts again, its SPEED isn't training)
CvcState.changed:Connect(function()
	local me = racer()
	if me and (spdAtRace == nil or me.uid ~= spdCar) then
		spdAtRace = math.floor((CvcState.bar(me, "speed")))
		spdCar = me.uid
	end
end)
-- place: yours (past the cars = didn't finish: NICE TRY!); top: the top 3 cars, by place
local function showPodiumWith(place: number, top: { [number]: { [string]: any } }, coins: number)
	local at = os.clock()
	podiumAt = at
	Screen.closeOver()
	if place == 1 then
		Sfx.fireworks()
	else
		Sfx.cheer()
	end
	-- a crate to open (the first race's free one): the big button opens it, the car shows at once
	local crate = CvcState.crates > 0 and #CvcState.garage < Profile.MAX_GARAGE
	-- +N SPD since the last race (the first: since the game started)
	local me = racer()
	local spd = if me then math.floor((CvcState.bar(me, "speed"))) else nil
	local trained = if spd
			and not SMASH
			and spdAtRace
			and spd > spdAtRace
		then `+{spd - spdAtRace} SPD from training!`
		else nil
	if spd and me then
		spdAtRace = spd
		spdCar = me.uid
	end
	Flow.podium({
		place = place,
		top = top,
		coins = coins,
		trained = trained,
		trophies = if League.trophy(place) then 1 else 0,
		-- the loop: open the new car, or race again; the other button goes training
		nextWords = if crate then "OPEN CRATE!" else "RACE AGAIN!",
		backWords = "TRAIN",
	}, {
		next = function()
			Screen.closeOver()
			if crate and CvcState.crates > 0 then
				wantReveal = true
				ask("open")
			else
				join()
			end
		end,
		back = function()
			Screen.closeOver()
			openGarage()
		end,
	})
	-- it goes away by itself after a while
	task.delay(15, function()
		if podiumAt == at and Screen.isOpen("podium") then
			Screen.closeOver()
		end
	end)
end

local function showPodium(rows: { any })
	local mine: number? = nil
	for i, r in rows do
		if type(r) == "table" and r.uid == player.UserId then
			mine = i
		end
	end
	if not mine then
		return -- (not in this race)
	end
	local me = rows[mine]
	local finished = type(me.time) == "number"
	local myCar = racer()
	local top = {}
	local usedColors: { [number]: boolean } = {}
	for i, r in rows do
		if #top >= 3 then
			break
		end
		-- (YOU get no step when you didn't finish: YOU stood on 3 after NICE TRY, Studio after818;
		-- bots keep theirs, race 1 ends at the kid's finish before any bot has a time)
		if type(r) ~= "table" or (i == mine and not finished) then
			continue
		end
		local isMe = i == mine
		local name = if isMe then "YOU" elseif type(r.name) == "string" then r.name else "?"
		-- (just the name: "Turbo Tim (bot)" was cut to "Turbo Tim (.")
		name = string.gsub(name, "%s*%(bot%)$", "")
		if #name > 12 then
			name = string.sub(name, 1, 11) .. "."
		end
		-- (bots all race the same car name: their own names give each its own color)
		local bot = r.bot or type(r.car) ~= "string"
		local key = if bot then name else r.car
		top[#top + 1] = {
			name = name,
			id = if isMe and myCar then myCar.id else nil,
			color = if isMe and myCar
				then colorOf(myCar.id)
				elseif bot then botColor(name, usedColors)
				else colorOf(key),
			kind = if isMe and myCar then kindOf(myCar.id) else kindOf(key),
			me = isMe,
		}
	end
	-- (didn't finish: NICE TRY!, whatever the row)
	showPodiumWith(
		if finished then mine else 99,
		top,
		if type(me.coins) == "number" then me.coins else 0
	)
end

-- (the race result's podium: the server race is gone; a round's end screen is WINDOWS')
local _ = showPodium

-- (a race you were paid for whose result list never came, Studio live3 race 4: the podium shows
-- your own place and coins anyway, a few seconds later)
CvcState.event:Connect(function(kind: unknown, place: unknown, coins: unknown)
	if kind ~= "race" or type(place) ~= "number" then
		return
	end
	local at = os.clock()
	task.delay(4, function()
		if podiumAt >= at or Screen.isOpen("podium") then
			return
		end
		local myCar = racer()
		local top = {}
		if place >= 1 and place <= 3 then
			top[place] = {
				name = "YOU",
				id = if myCar then myCar.id else nil,
				color = if myCar then colorOf(myCar.id) else nil,
				kind = if myCar then kindOf(myCar.id) else nil,
				me = true,
			}
		end
		showPodiumWith(
			if place >= 1 then place else 99,
			top,
			if type(coins) == "number" then coins else 0
		)
	end)
end)
