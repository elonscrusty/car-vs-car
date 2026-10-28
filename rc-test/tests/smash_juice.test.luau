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
	eq(SmashJuice.deathLine("freeze", "Huy"), "You were shattered by Huy")
	eq(SmashJuice.deathLine("bump", "Huy"), "You were bumped out by Huy")
	eq(SmashJuice.deathLine("ROCKET", "Huy"), "You were smashed by Huy's rocket")
	eq(SmashJuice.deathLine("rocket", nil), "You were smashed!")
	eq(SmashJuice.deathLine("", "Huy"), "You were smashed by Huy")
end)

test("smash juice: long names are cut so they fit a phone", function()
	eq(SmashJuice.shortName("Botty"), "Botty")
	eq(SmashJuice.shortName("BottyMcBotface"), "BottyMcBotface")
	eq(SmashJuice.shortName("SilenceWillFallForever"), "SilenceWillFa…")
	eq(SmashJuice.shortName(""), "?")
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

test(
	"smash juice: your smash hits harder than a nudge; reduced motion keeps words, not shake",
	function()
		local mine = SmashJuice.feel("mySmash", 1)
		local nudge = SmashJuice.feel("hit", 10)
		local rocket = SmashJuice.feel("hit", 40)
		truthy(mine.trauma > rocket.trauma and rocket.trauma > nudge.trauma)
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
	end
)

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
			string.find(src, "RenderPriority.Camera.Value + 1", 1, true),
			"after the camera runs"
		)
		truthy(string.find(src, "[SmashFx] shown in", 1, true), "timing log for the 0.1 s target")
		-- driving stays LOCKED: no car or chase camera code is touched
		truthy(not string.find(src, 'require(script.Parent:WaitForChild("ChaseCamera"))', 1, true))
		truthy(not string.find(src, "RCCar", 1, true))
		local start = fs.readFile("src/client/SmashFxStart.client.luau")
		truthy(string.find(start, "SmashFx.start()", 1, true), "something starts it")
	end
)
