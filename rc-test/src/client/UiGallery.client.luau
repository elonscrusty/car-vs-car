--!strict
-- Studio only: a small SCREENS button (top left) that flips through every new Car VS Car screen
-- with sample words, so each one can be looked at without playing to it. Nothing here runs in
-- the live game, and it doesn't touch game logic.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Ui = script.Parent:WaitForChild("Ui")
local Screens = Ui:WaitForChild("Screens")
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))
local Screen = require(Ui:WaitForChild("Screen"))
local Flow = require(Screens:WaitForChild("Flow"))
local Hud = require(Screens:WaitForChild("Hud"))
local Windows = require(Screens:WaitForChild("Windows"))
local Shop = require(Screens:WaitForChild("Shop"))
local States = require(Screens:WaitForChild("States"))

local function col(name: string): Color3
	return Base.color(name)
end

local function car(
	name: string,
	rarity: string,
	colorName: string,
	kind: string,
	extra: { [string]: any }?
): { [string]: any }
	local c: { [string]: any } = extra or {}
	c.name = name
	c.rarity = rarity
	c.color = col(colorName)
	c.kind = kind
	return c
end

local function odds(a: number, b: number, c: number, d: number): { { [string]: any } }
	return {
		{ rarity = "common", chance = a },
		{ rarity = "rare", chance = b },
		{ rarity = "epic", chance = c },
		{ rarity = "legendary", chance = d },
	}
end

local garageCars = {
	car("Zippy", "common", "blue", "racer", {
		tone = "lime",
		count = "x6",
		badge = "ON",
		stars = 2,
		stats = { power = "12", air = "8", speed = "10" },
	}),
	car("Mudbug", "rare", "lime", "truck", {
		tone = "lime",
		count = "x2",
		badge = "ON",
		stars = 1,
		stats = { power = "9", air = "14", speed = "7" },
	}),
	car("Bubbles", "epic", "pink", "buggy", {
		tone = "lime",
		count = "x1",
		badge = "ON",
		stars = 3,
		stats = { power = "16", air = "11", speed = "15" },
	}),
	car("Rocket", "legendary", "boost", "racer", {
		tone = "blue",
		count = "x1",
		stars = 1,
		stats = { power = "20", air = "18", speed = "21" },
	}),
	car(
		"Pebble",
		"common",
		"navy",
		"truck",
		{ tone = "blue", count = "x4", stats = { power = "5", air = "6", speed = "4" } }
	),
}

-- name, how to open it
local LIST: { { string | () -> () } } = {
	{
		"0 Loading",
		function()
			Flow.loading({ progress = 0.6, tip = "Tap COACH to make your car train 2x faster!" })
		end,
	},
	{
		"1 Pick a car",
		function()
			Flow.pick({
				cars = {
					car(
						"Zippy",
						"common",
						"blue",
						"racer",
						{ word = "FAST", stats = { power = 0.5, air = 0.3, speed = 0.8 } }
					),
					car(
						"Mudbug",
						"common",
						"lime",
						"truck",
						{ word = "STRONG", stats = { power = 0.8, air = 0.4, speed = 0.4 } }
					),
					car(
						"Bubbles",
						"common",
						"pink",
						"buggy",
						{ word = "JUMPY", stats = { power = 0.4, air = 0.8, speed = 0.5 } }
					),
				},
			})
		end,
	},
	{
		"2 Plot",
		function()
			Hud.plot({
				coins = 12450,
				rate = "+12/s",
				nextUp = { title = "BIG RACE in 1:42", sub = "Train up, then race 8 cars!" },
				car = {
					name = "Zippy",
					stats = { power = { 0.6, 4 }, air = { 0.35, 2 }, speed = { 0.8, 5 } },
				},
				dots = { Crates = 2, League = -1 },
				coach = { 24, 60 },
			})
		end,
	},
	{
		"3 Race start",
		function()
			Hud.start({ lap = "1/2", lit = 2 })
		end,
	},
	{
		"4 Race",
		function()
			Hud.race({
				lap = "2/2",
				place = 3,
				total = 8,
				boost = 0.7,
				top = {
					{ name = "Maya", colorName = "pink" },
					{ name = "Leo", colorName = "boost" },
					{ name = "You", colorName = "lime", me = true },
				},
			})
		end,
	},
	{
		"5 Podium",
		function()
			Flow.podium({
				place = 1,
				coins = 450,
				trophies = 12,
				top = {
					car("You", "epic", "pink", "buggy"),
					car("Leo", "rare", "boost", "racer"),
					car("Maya", "common", "blue", "truck"),
				},
			})
		end,
	},
	{
		"6 Crates",
		function()
			Windows.crates({
				coins = 12450,
				chosen = 2,
				best = 3,
				choices = {
					{
						word = "BASIC",
						rarity = "common",
						price = 300,
						odds = odds(70, 25, 4.5, 0.5),
					},
					{ word = "BIG", rarity = "rare", price = 900, odds = odds(50, 35, 12, 3) },
					{ word = "MEGA", rarity = "epic", price = 2500, odds = odds(25, 45, 23, 7) },
				},
			})
		end,
	},
	{
		"7 Crate reveal",
		function()
			Flow.reveal({
				rarity = "epic",
				name = "Bubbles",
				color = col("pink"),
				kind = "buggy",
				stars = 3,
				new = true,
			})
		end,
	},
	{
		"8 Garage",
		function()
			Windows.garage({
				onTrack = { garageCars[1], garageCars[2], garageCars[3] },
				cars = garageCars,
				selected = 1,
				room = "5 / 50",
				trackTag = "3/3",
			})
		end,
	},
	{
		"9 Shop",
		function()
			Shop.open({})
		end,
	},
	{
		"10 League up",
		function()
			Flow.leagueUp({ from = 1, to = 2, coins = 500 })
		end,
	},
	{
		"11 Daily",
		function()
			Windows.daily({
				streak = 3,
				today = 3,
				day7 = "BIG CRATE",
				days = {
					{ icon = "coin", amount = "100", state = "got" },
					{ icon = "coin", amount = "200", state = "got" },
					{ icon = "gem", amount = "5", state = "today" },
					{ icon = "coin", amount = "400", state = "later" },
					{ icon = "gift", amount = "1", state = "later" },
					{ icon = "coin", amount = "800", state = "later" },
				},
			})
		end,
	},
	{
		"12 Car book",
		function()
			local cars = {}
			for i = 1, 24 do
				local c = garageCars[(i - 1) % #garageCars + 1]
				table.insert(
					cars,
					{ name = c.name, color = c.color, kind = c.kind, own = i <= 9, new = i == 3 }
				)
			end
			Windows.book({
				tabs = { "ALL", "BACKYARD", "KITCHEN" },
				tab = 1,
				found = 9,
				total = 24,
				marks = {
					{ at = 0.25, label = "6", icon = "coin" },
					{ at = 0.5, label = "12", icon = "gem" },
					{ at = 1, label = "24", icon = "trophy" },
				},
				cars = cars,
			})
		end,
	},
	{
		"13 Settings",
		function()
			Windows.settings({
				music = true,
				sounds = true,
				vibrate = false,
				low = false,
				camera = 0.5,
			})
		end,
	},
	{
		"14 Leaderboard",
		function()
			local rows = {}
			local names = { "Maya", "Leo", "Sam", "Ava", "Max", "Zoe", "Kai", "Mia" }
			for i, n in names do
				local c = garageCars[(i - 1) % #garageCars + 1]
				table.insert(rows, {
					rank = i,
					name = n,
					league = 4 - math.floor((i - 1) / 2),
					trophies = 3000 - i * 240,
					color = c.color,
					kind = c.kind,
				})
			end
			Windows.leaderboard({
				tabs = { "WORLD", "FRIENDS" },
				tab = 1,
				rows = rows,
				me = {
					rank = 42,
					name = "You",
					league = 2,
					trophies = 860,
					color = col("lime"),
					kind = "racer",
				},
			})
		end,
	},
	{
		"15 Quests",
		function()
			Windows.quests({
				tab = 1,
				timer = "5:12:08",
				rows = {
					{
						icon = "trophy",
						words = "Win 2 races",
						have = 2,
						need = 2,
						rewardIcon = "coin",
						reward = "300",
						state = "claim",
					},
					{
						icon = "power",
						words = "Coach your car 5 times",
						have = 3,
						need = 5,
						rewardIcon = "coin",
						reward = "150",
						state = "go",
					},
					{
						icon = "crate",
						words = "Open a crate",
						have = 1,
						need = 1,
						rewardIcon = "gem",
						reward = "5",
						state = "done",
					},
				},
			})
		end,
	},
	{
		"16 Popup: coins",
		function()
			Windows.popup({ kind = "coins" })
		end,
	},
	{
		"16 Popup: sell",
		function()
			Windows.popup({ kind = "sell" })
		end,
	},
	{
		"16 Popup: leave",
		function()
			Windows.popup({ kind = "leave" })
		end,
	},
	{
		"States",
		function()
			States.open()
		end,
	},
	{
		"17 Match",
		function()
			local h = Hud.match({
				place = 2,
				total = 5,
				secs = 154,
				hp = 64,
				maxHp = 100,
				weapon = "Rockets",
				ammo = 3,
			})
			h.api.feed("Maya", "Leo", "Gun", false)
			h.api.feed("You", "Bolt", "Rockets", true)
		end,
	},
	{
		"17 Match: no weapon, shield, last 10 s",
		function()
			local h = Hud.match({
				place = 4,
				total = 5,
				secs = 8,
				hp = 100,
				maxHp = 100,
				shield = true,
				weapon = "",
				ammo = 0,
			})
			h.api.setClock(8)
			h.api.feed("Bolt", "You", "Mine", true)
		end,
	},
}

-- the viewer's own little bar, over everything, bottom middle (clear of the move stick corner)
local bar = Base.screen("Ui_Gallery", 60, false)
local stage = Base.stage(bar.canvas)
local at = 0
local nameLabel: TextLabel

local function show(i: number)
	Screen.closeAll()
	at = (i - 1) % #LIST + 1
	local entry = LIST[at]
	nameLabel.Text = entry[1] :: string
	local openIt = entry[2] :: () -> ()
	local ok, err = pcall(function()
		openIt()
	end)
	if not ok then
		warn("[UiGallery] " .. (entry[1] :: string) .. " broke: " .. tostring(err))
	end
end

local open = false
local controls = Base.box(stage, "Controls", 270, 346, 330, 44, 2)
controls.Visible = false
Kit.button(controls, "Back", 0, 0, 70, 40, "blue", "BACK", {
	size = 15,
	onClick = function()
		show(at - 1)
	end,
})
Kit.button(controls, "Next", 76, 0, 70, 40, "lime", "NEXT", {
	size = 15,
	onClick = function()
		show(at + 1)
	end,
})
nameLabel = Base.text(controls, "Name", 152, 10, 178, 22, "", { stroke = 3.5, align = "l" })

local toggle = Kit.button(stage, "Toggle", 164, 348, 100, 36, "white", "SCREENS", {
	size = 14,
	onClick = function()
		open = not open
		controls.Visible = open
		if open then
			show(if at == 0 then 1 else at)
		else
			Screen.closeAll()
		end
	end,
})
Base.show(bar, true)
-- (out of the way of a game window's buttons: it sat on the crate window's OPEN, Studio garage 5;
-- and out of every match shot, Studio round3)
local me = game:GetService("Players").LocalPlayer
RunService.Heartbeat:Connect(function()
	-- (Studio only, never in a player's game; and not in phone-size shots, PhoneUi: auditor 12b)
	-- (and only while workspace.ShowScreensGallery is on: never in shots, auditor 13)
	toggle.Visible = open
		or workspace:GetAttribute("ShowScreensGallery") == true
			and not (Screen.anyOver() or me:GetAttribute("InMatch") == true or me:GetAttribute(
				"PhoneUi"
			) == true)
end)
