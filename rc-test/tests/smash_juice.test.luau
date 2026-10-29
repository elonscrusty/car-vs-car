--!strict
-- Smash juice (JUICE row): the words, streaks, killer camera and shake numbers, plus text checks
-- that the client shows the words at once (hard target: on screen ≤ 0.1 s after the hit).
local fs = require("@lune/fs")
local H = require("./harness")
local SmashJuice = require("../src/shared/SmashJuice")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Smash juice")

test("smash juice: the words from carter's video", function()
	eq(SmashJuice.smashLine("rocket"), "You SMASHED")
	eq(SmashJuice.smashLine("freeze"), "You SHATTERED")
	eq(SmashJuice.smashLine("whatever"), "You SMASHED")
	eq(SmashJuice.deathLine("rocket", "Botty"), "You were smashed by Botty's rocket")
	eq(SmashJuice.deathLine("nuke", "Botty"), "You were smashed by Botty's nuke")
	eq(SmashJuice.deathLine("gun", "CheriBibi"), "You were mowed down by CheriBibi's machine gun")
	eq(SmashJuice.deathLine("freeze", "Huy"), "You were shattered by Huy's freeze ray")
	eq(SmashJuice.deathLine("bump", "Huy"), "You were bumped out by Huy's bump")
	eq(SmashJuice.deathLine("ROCKET", "Huy"), "You were smashed by Huy's rocket")
	eq(SmashJuice.deathLine("rocket", nil), "You were smashed by a rocket!")
	eq(SmashJuice.deathLine("", "Huy"), "You were bumped out by Huy's bump")
end)

test("smash juice: the wrecked card has a verb, a tag and a weapon badge", function()
	local r = SmashJuice.wreck("gun", "CheriBibi")
	eq(r.verb, "MOWED DOWN!")
	eq(r.tag, "by CheriBibi's machine gun")
	eq(r.icon, "gun")
	eq(SmashJuice.wreck("rocket", "Zed").verb, "SMASHED!")
	eq(SmashJuice.wreck("rocket", "Zed").icon, "rocket")
	eq(SmashJuice.wreck("mine", "Ava").verb, "BLOWN UP!")
	eq(SmashJuice.wreck("freeze ray", "Huy").verb, "SHATTERED!")
	eq(SmashJuice.wreck("freeze ray", "Huy").icon, "freeze")
	eq(SmashJuice.wreck("bump", "Huy").icon, "burst")
	-- the arena got you: no one to blame
	local fell = SmashJuice.wreck("bump", nil)
	eq(fell.verb, "YOU FELL OUT!")
	eq(fell.tag, "no one to blame")
	-- a killer who left: the weapon still names itself
	eq(SmashJuice.wreck("rocket", nil).tag, "by a rocket")
	eq(SmashJuice.wreck("mine", nil).tag, "by a mine")
end)

test("smash juice: the match start shows 3, 2, 1, GO! then nothing", function()
	eq(SmashJuice.startStep(-0.1), nil)
	eq(SmashJuice.startStep(0), "3")
	eq(SmashJuice.startStep(0.99), "3")
	eq(SmashJuice.startStep(1), "2")
	eq(SmashJuice.startStep(2.5), "1")
	eq(SmashJuice.startStep(3), "GO!")
	eq(SmashJuice.startStep(3 + SmashJuice.START_GO_SECONDS - 0.01), "GO!")
	eq(SmashJuice.startStep(3 + SmashJuice.START_GO_SECONDS), nil)
	-- looks only: the client file never touches the server or the cars
	local src = fs.readFile("src/client/MatchStart.luau")
	truthy(string.find(src, "MatchRound", 1, true), "starts on the round number")
	truthy(string.find(src, "InMatch", 1, true), "only when you are in the round")
	truthy(not string.find(src, "FireServer", 1, true), "no asks to the server")
	local start = fs.readFile("src/client/SmashFxStart.client.luau")
	truthy(string.find(start, "MatchStart", 1, true), "something starts it")
end)

test("smash juice: long names are cut so they fit a phone", function()
	eq(SmashJuice.shortName("Botty"), "Botty")
	eq(SmashJuice.shortName("BottyMcBotface"), "BottyMcBotface")
	eq(SmashJuice.shortName("SilenceWillFallForever"), "SilenceWillFa…")
	eq(SmashJuice.shortName(""), "?")
	eq(SmashJuice.shortName("   "), "?")
	eq(SmashJuice.shortName(" Botty "), "Botty")
	eq(SmashJuice.shortName("a  \n b"), "a b")
	eq(SmashJuice.shortName("\255\254"), "?")
end)

test("smash juice: Double Smash for quick ones, Smash Streak for a run", function()
	local s = SmashJuice.streak()
	eq(s:smash(10), nil)
	eq(s:smash(12), "DOUBLE SMASH!")
	eq(s:smash(13), "TRIPLE SMASH!")
	eq(s:smash(14), "TRIPLE SMASH!")
	-- slow ones still build the run
	local r = SmashJuice.streak()
	eq(r:smash(0), nil)
	eq(r:smash(20), nil)
	eq(r:smash(40), "SMASH STREAK x3!")
	eq(r:smash(60), "SMASH STREAK x4!")
	-- getting smashed ends both
	r:reset()
	eq(r:smash(61), nil)
	eq(r.run, 1)
end)

test("smash juice: the feed reader takes players, bots and tables, and drops junk", function()
	local me = 42
	local f =
		SmashJuice.read({ name = "Me", userId = 42 }, "Botty", "rocket", me) :: SmashJuice.Feed
	truthy((f.attacker :: SmashJuice.Side).me)
	eq(f.victim.name, "Botty")
	eq(f.victim.me, false)
	eq(f.weapon, "rocket")
	local g = SmashJuice.read("Botty", { name = "Me", userId = 42 }, nil, me) :: SmashJuice.Feed
	truthy(g.victim.me)
	eq(g.weapon, "")
	local fell = SmashJuice.read(nil, { name = "Me", userId = 42 }, "fall", me) :: SmashJuice.Feed
	eq(fell.attacker, nil)
	eq(SmashJuice.read("Botty", nil, "rocket", me), nil)
	eq(SmashJuice.read("Botty", 5, "rocket", me), nil)
	eq(SmashJuice.read("Botty", { name = 5 }, "rocket", me), nil)
	eq(SmashJuice.read("Botty", { userId = 42 }, "rocket", me), nil)
	-- a guest id 0 is never "me" by accident
	eq(
		(SmashJuice.read("B", { name = "x", userId = 0 }, "", 0) :: SmashJuice.Feed).victim.me,
		false
	)
	-- huge strings are cut
	eq(
		#(
				SmashJuice.read(
					"B",
					string.rep("x", 500),
					string.rep("y", 500),
					me
				) :: SmashJuice.Feed
			).victim.name,
		40
	)
end)

test("smash juice: killer camera counts 3-2-1 and always ends", function()
	eq(SmashJuice.countdown(0), 3)
	eq(SmashJuice.countdown(0.99), 3)
	eq(SmashJuice.countdown(1.2), 2)
	eq(SmashJuice.countdown(2.5), 1)
	eq(SmashJuice.countdown(3), nil)
	eq(SmashJuice.countdown(-1), nil)
	eq(SmashJuice.flyAlpha(0), 0)
	eq(SmashJuice.flyAlpha(SmashJuice.KILLCAM_FLY), 1)
	eq(SmashJuice.flyAlpha(10), 1)
	truthy(
		SmashJuice.KILLCAM_MAX > 3 and SmashJuice.KILLCAM_MAX <= 4,
		"hands back soon after respawn"
	)
end)

test("smash juice: hits shake by damage; reduced motion keeps words, not shake", function()
	local mine = SmashJuice.feel("mySmash", 1)
	local nudge = SmashJuice.feel("hit", 10)
	local rocket = SmashJuice.feel("hit", 40)
	local smashed = SmashJuice.feel("smashed")
	-- getting hit shakes by the damage; being smashed is the hardest; your own smash is a
	-- solid thump that gets the zoom and confetti on top
	truthy(smashed.trauma > rocket.trauma and rocket.trauma > nudge.trauma)
	truthy(mine.trauma > nudge.trauma)
	truthy(mine.punch > 0 and mine.slow > 0 and mine.confetti > 0)
	eq(SmashJuice.feel("hit", 0).trauma, 0)
	truthy(SmashJuice.feel("mySmash", 5).confetti <= 48, "confetti pool is 48")
	truthy(SmashJuice.feel("mySmash", 99).trauma <= 0.6)
	local calm = SmashJuice.feel("mySmash", 3, true)
	eq(calm.trauma, 0)
	eq(calm.punch, 0)
	truthy(calm.confetti > 0, "confetti stays")
	truthy(SmashJuice.feel("boom", 10).trauma > SmashJuice.feel("boom", 50).trauma)
	eq(SmashJuice.feel("boom", 200).trauma, 0)
	-- the empty feel is fresh every time (no shared table to change by mistake)
	local a = SmashJuice.feel("boom", 200)
	a.trauma = 1
	eq(SmashJuice.feel("boom", 200).trauma, 0)
end)

test("smash juice: shake is capped, decays, and never jitters on a 30 fps phone", function()
	eq(SmashJuice.addTrauma(0.9, 0.6), 1)
	eq(SmashJuice.addTrauma(0, -1), 0)
	eq(SmashJuice.decay(0.1, 1), 0)
	truthy(SmashJuice.noiseHz(30) <= 12)
	eq(SmashJuice.noiseHz(60), SmashJuice.NOISE_HZ)
	local p = SmashJuice.tilt(1, 1, 0, 0)
	eq(p, SmashJuice.MAX_DEGREES)
	local small = SmashJuice.tilt(0.12, 1, 0, 0)
	truthy(small < 0.05, "a nudge barely moves the screen (trauma squared)")
	-- the zoom: in, hold, back to 0
	eq(SmashJuice.punchAt(8, 0.18, 0), 0)
	eq(SmashJuice.punchAt(8, 0.18, SmashJuice.PUNCH_IN + 0.1), 8)
	eq(SmashJuice.punchAt(8, 0.18, 5), 0)
	eq(SmashJuice.punchAt(0, 0.18, 0.1), 0)
end)

test(
	"smash juice: the client shows the words at once and lays the camera over the chase cam",
	function()
		local src = fs.readFile("src/client/SmashFx.luau")
		-- words go up inside the remote handler: no wait before them
		local handler = string.match(src, "local function onFeed(.-)\n\tend\n") :: string
		truthy(handler ~= nil, "onFeed not found")
		truthy(not string.find(handler, "task.wait", 1, true), "no waiting before the words")
		truthy(string.find(handler, "showWord(you", 1, true), "your smash words")
		truthy(string.find(handler, "SmashJuice.deathLine", 1, true), "smashed-by words")
		truthy(
			string.find(src, "RenderPriority.Camera.Value + 3", 1, true),
			"after the chase camera (+1) and plot camera (+2)"
		)
		truthy(string.find(src, "[SmashFx] shown in", 1, true), "timing log for the 0.1 s target")
		-- driving stays LOCKED: no car or chase camera code is touched
		truthy(not string.find(src, 'require(script.Parent:WaitForChild("ChaseCamera"))', 1, true))
		truthy(not string.find(src, "RCCar", 1, true))
		-- sounds come from Sfx (SOUNDS row), never a Sound made here
		for _, call in
			{ "Sfx.smash(", "Sfx.hit()", "Sfx.count(n)", "Sfx.respawn()", "Sfx.shield()" }
		do
			truthy(string.find(src, call, 1, true), `plays {call}`)
		end
		truthy(not string.find(src, 'Instance.new("Sound")', 1, true), "no Sound of its own")
		local start = fs.readFile("src/client/SmashFxStart.client.luau")
		truthy(string.find(start, "SmashFx.start()", 1, true), "something starts it")
	end
)

test(
	"smash juice (Studio 10-28): the words sit under the clock and health, clear of the HUD",
	function()
		local UiScreens = require("../src/shared/UiScreens")
		local UiTheme = require("../src/shared/UiTheme")
		local D = UiTheme.DESIGN
		-- The words fill the whole phone; the HUD canvas sits inside the safe area, which on a phone
		-- also takes Roblox's top bar (about 58 px) and sometimes a bottom strip. Check every case.
		for _, inset in
			{ { top = 0, bottom = 0 }, { top = 58, bottom = 0 }, { top = 58, bottom = 21 } }
		do
			local k = (D.phoneH - inset.top - inset.bottom) / D.h
			local hud = {}
			local function add(n: string, pc: any)
				table.insert(hud, {
					name = n,
					x = pc.x + D.safe,
					y = inset.top + pc.y * k,
					w = pc.w,
					h = pc.h * k,
				})
			end
			for _, n in { "Place", "Board", "Feed", "Clock", "Health", "Fire" } do
				add(n, UiScreens.piece("match", n))
			end
			add("Stick", UiScreens.stickZone())
			local w = SmashJuice.WORDS_W * D.phoneW
			for spot, at in SmashJuice.WORDS do
				local r = {
					x = (D.phoneW - w) / 2,
					y = (at.y - at.h / 2) * D.phoneH,
					w = w,
					h = at.h * D.phoneH,
				}
				for _, h in hud do
					truthy(
						not UiScreens.overlap(r :: any, h :: any),
						`{spot} covers {h.name} (top bar {inset.top})`
					)
				end
			end
			-- the match start: the giant number and GET READY!
			for spot, at in SmashJuice.START do
				local r = {
					x = (D.phoneW - at.w * D.phoneW) / 2,
					y = (at.y - at.h / 2) * D.phoneH,
					w = at.w * D.phoneW,
					h = at.h * D.phoneH,
				}
				for _, h in hud do
					truthy(
						not UiScreens.overlap(r :: any, h :: any),
						`start {spot} covers {h.name} (top bar {inset.top})`
					)
				end
			end
			-- the wrecked card: verb, tag, and the ring with its BACK IN words on the left
			for spot, at in SmashJuice.WRECK do
				local ring = at.h * D.phoneH
				local rw = if at.w > 0 then at.w * D.phoneW else ring * 1.9
				local r = {
					x = (D.phoneW - rw) / 2 - (if at.w > 0 then 0 else ring * 0.45),
					y = (at.y - at.h / 2) * D.phoneH,
					w = rw,
					h = ring,
				}
				for _, h in hud do
					truthy(
						not UiScreens.overlap(r :: any, h :: any),
						`wreck {spot} covers {h.name} (top bar {inset.top})`
					)
				end
			end
		end
		-- the smash lines and the smashed-by lines each stack without covering each other (the two
		-- sets never show at once)
		local function clear(a: string, b: string)
			local A, B = SmashJuice.WORDS[a], SmashJuice.WORDS[b]
			truthy(math.abs(A.y - B.y) >= (A.h + B.h) / 2 - 1e-9, `{a} and {b} overlap`)
		end
		clear("you", "name")
		clear("name", "streak")
		clear("by", "count")
	end
)

test(
	"every death line names the weapon (audit 12 #9): every server word, bumps and falls",
	function()
		local Weapons = require("../src/shared/Weapons")
		local seen = 0
		for _, name in Weapons.NAMES do
			local word = Weapons.feedWord(name) -- what MatchRunner sends
			local line = SmashJuice.deathLine(word, "Rocket Raccoon")
			truthy(string.find(line, "by Rocket Raccoon's ", 1, true) ~= nil)
			-- and it ends with a real word for the weapon, not nothing
			local thing = string.match(line, "Raccoon's (.+)$")
			truthy(thing ~= nil and #thing >= 3)
			seen += 1
		end
		truthy(seen >= 5)
		eq(
			SmashJuice.deathLine("rocket", "Rocket Raccoon"),
			"You were smashed by Rocket Raccoon's rocket"
		)
		eq(
			SmashJuice.deathLine("machine gun", "Rocket Raccoon"),
			"You were mowed down by Rocket Raccoon's machine gun"
		)
		eq(SmashJuice.deathLine("freeze ray", "Huy"), "You were shattered by Huy's freeze ray")
		eq(SmashJuice.smashLine("freeze ray"), "You SHATTERED")
		eq(SmashJuice.deathLine("bump", "Huy"), "You were bumped out by Huy's bump")
		-- falls: no killer
		eq(SmashJuice.deathLine("bump", nil), "You fell out of the arena!")
		eq(SmashJuice.deathLine("fall", nil), "You fell out of the arena!")
		eq(SmashJuice.deathLine("mine", nil), "You were blown up by a mine!")
		-- a weapon nobody listed yet still names itself
		eq(SmashJuice.deathLine("laser", "Huy"), "You were smashed by Huy's laser")
		-- short enough for the two-row feed: a long name is cut by shortName
		truthy(#SmashJuice.deathLine("machine gun", string.rep("W", 40)) <= 60)
	end
)
