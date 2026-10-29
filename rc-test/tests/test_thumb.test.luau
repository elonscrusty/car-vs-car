--!strict
-- The Studio-only test thumb (shared/ThumbBrain + client/TestThumb): it can never be on in a live
-- game, it drives at boxes then karts like a kid (late, wobbly), and FIRE goes through the HUD's
-- own fire.
local H = require("./harness")
local fs = require("@lune/fs")
local ThumbBrain = require("../src/shared/ThumbBrain")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Test thumb (Studio only)")

local function rng(): ThumbBrain.Rng
	local x = 0.5
	return {
		NextNumber = function(_: any): number
			x = (x * 9301 + 49297) % 233280 / 233280
			return x
		end,
	} :: any
end

test("the gate: only Studio AND workspace TestThumb == true", function()
	eq(ThumbBrain.allowed(false, true), false, "live game, attribute on")
	eq(ThumbBrain.allowed(true, nil), false, "Studio, attribute off (the default)")
	eq(ThumbBrain.allowed(true, false), false, "Studio, attribute false")
	eq(ThumbBrain.allowed(true, "true"), false, "a string is not true")
	eq(ThumbBrain.allowed(true, 1), false, "a number is not true")
	eq(ThumbBrain.allowed(true, true), true, "Studio + attribute on")
end)

test(
	"wiring: Studio check in the client, Main steps it only when on, the HUD's FIRE, no server use",
	function()
		local client = fs.readFile("src/client/TestThumb.luau")
		truthy(
			string.find(
				client,
				"ThumbBrain.allowed(RunService:IsStudio(), workspace:GetAttribute(ThumbBrain.ATTR))",
				1,
				true
			),
			"TestThumb.on asks RunService:IsStudio() and the attribute"
		)
		local main = fs.readFile("src/client/Main.client.luau")
		local calls = 0
		for _ in string.gmatch(main, "TestThumb%.drive%(") do
			calls += 1
		end
		eq(calls, 1, "one drive call")
		truthy(
			string.find(
				main,
				"if TestThumb.on() then\n\t\tinput = TestThumb.drive(body, input)",
				1,
				true
			),
			"Main steps the thumb only inside if TestThumb.on()"
		)
		local hud = fs.readFile("src/client/MatchHud.client.luau")
		truthy(
			string.find(hud, "TestThumb.onFire(fire)", 1, true),
			"the HUD hands over its own fire"
		)
		for _, f in fs.readDir("src/server") do
			local path = "src/server/" .. f
			if fs.isFile(path) then
				local src = fs.readFile(path)
				eq(string.find(src, "ThumbBrain", 1, true), nil, path .. " uses ThumbBrain")
				eq(string.find(src, "TestThumb", 1, true), nil, path .. " uses TestThumb")
			end
		end
	end
)

-- me at the origin, nose along -z (Roblox forward); +x is to the right
local ME: ThumbBrain.Me = { x = 0, z = 0, fx = 0, fz = -1 }

test("unarmed: steers at the nearest box (right is +)", function()
	local s = ThumbBrain.new(rng())
	local out = ThumbBrain.step(s, 0, ME, { { x = 10, z = -10 }, { x = -30, z = -30 } }, {}, false)
	truthy(out.steer > 0.5, `right toward the near box, got {out.steer}`)
	eq(out.fire, false, "no FIRE without a weapon")
	local s2 = ThumbBrain.new(rng())
	local left = ThumbBrain.step(s2, 0, ME, { { x = -10, z = -10 } }, {}, false)
	truthy(left.steer < -0.5, `left toward a box on the left, got {left.steer}`)
end)

test("unarmed: no FIRE even with a kart dead ahead", function()
	local s = ThumbBrain.new(rng())
	local fired = false
	for i = 0, 20 do
		fired = fired or ThumbBrain.step(s, i * 0.05, ME, {}, { { x = 0, z = -10 } }, false).fire
	end
	eq(fired, false, "fired with no weapon")
end)

test("armed: FIRE only after the kart has been in the cone for the reaction time", function()
	local s = ThumbBrain.new(rng())
	local ahead = { { x = 0, z = -15 } }
	local a = ThumbBrain.step(s, 0, ME, {}, ahead, true)
	eq(a.fire, false, "not at once")
	local b = ThumbBrain.step(s, ThumbBrain.REACT * 0.5, ME, {}, ahead, true)
	eq(b.fire, false, "not before the reaction time")
	local c = ThumbBrain.step(s, ThumbBrain.REACT + 0.01, ME, {}, ahead, true)
	eq(c.fire, true, "after it")
end)

test("armed: no FIRE at a kart behind, off to the side, or too far", function()
	for _, k in
		{
			{ x = 0, z = 15 }, -- behind
			{ x = 15, z = -5 }, -- way off the nose
			{ x = 10, z = -10 }, -- 45 deg: just outside the 30 deg cone
			{ x = 0, z = -(ThumbBrain.RANGE + 10) }, -- too far
		}
	do
		local s = ThumbBrain.new(rng())
		local fired = false
		for i = 0, 20 do
			fired = fired or ThumbBrain.step(s, i * 0.05, ME, {}, { k }, true).fire
		end
		eq(fired, false, `fired at {k.x},{k.z}`)
	end
end)

test("it sees late: a box that comes up nearer is driven at only REACT seconds later", function()
	local s = ThumbBrain.new(rng())
	local far, near = { x = 30, z = -30 }, { x = -5, z = -5 }
	local first = ThumbBrain.step(s, 0, ME, { far }, {}, false)
	truthy(first.target and first.target.x == 30, "the only box")
	local mid = ThumbBrain.step(s, ThumbBrain.REACT * 0.5, ME, { far, near }, {}, false)
	truthy(mid.target and mid.target.x == 30, "hasn't seen the near one yet")
	local late = ThumbBrain.step(s, ThumbBrain.REACT + 0.01, ME, { far, near }, {}, false)
	truthy(late.target and late.target.x == -5, "now it has")
end)

test(
	"a kart driven by the thumb reaches a box, then hits a still kart (kid speed, 20 studs/s)",
	function()
		local s = ThumbBrain.new(rng())
		local me = { x = 0, z = 0, yaw = 0 } -- yaw 0 = nose -z
		local box = { x = 20, z = 15 } -- off to the side and behind
		local kart = { x = -15, z = -20 }
		local box2 = { x = -25, z = -35 } -- the next box, past the kart
		local armedAt, firedAt = nil, nil
		local t = 0
		while t < 20 and not firedAt do
			local fx, fz = -math.sin(me.yaw), -math.cos(me.yaw)
			local armed = armedAt ~= nil
			local out = ThumbBrain.step(
				s,
				t,
				{ x = me.x, z = me.z, fx = fx, fz = fz },
				if armed then { box2 } else { box },
				{ kart },
				armed
			)
			-- a simple car: turns up to 2.5 rad/s, drives at 20 studs/s
			me.yaw -= out.steer * 2.5 * 0.05
			me.x += -math.sin(me.yaw) * 20 * out.throttle * 0.05
			me.z += -math.cos(me.yaw) * 20 * out.throttle * 0.05
			if not armed and math.sqrt((me.x - box.x) ^ 2 + (me.z - box.z) ^ 2) < 2 then
				armedAt = t
			end
			if out.fire then
				firedAt = t
			end
			t += 0.05
		end
		truthy(armedAt and armedAt < 6, `got the box ({armedAt} s)`)
		truthy(firedAt and firedAt < 15, `fired at the kart ({firedAt} s)`)
		print(
			`       box at {string.format("%.1f", armedAt or -1)} s, FIRE at {string.format(
				"%.1f",
				firedAt or -1
			)} s`
		)
	end
)

test("round report: stuck, flipped and put-back time, speed, from frames", function()
	local t = ThumbBrain.tally()
	for _ = 1, 100 do
		ThumbBrain.sample(t, 0.1, 1.5, 1) -- 15 studs/s, upright
	end
	for _ = 1, 30 do
		ThumbBrain.sample(t, 0.1, 0.05, 1) -- wedged on a wall
	end
	for _ = 1, 10 do
		ThumbBrain.sample(t, 0.1, 0, 0.1) -- on its roof
	end
	ThumbBrain.sample(t, 0.1, 30, 1) -- put back
	ThumbBrain.sample(t, 3, 1, 1) -- a hitch: skipped
	truthy(math.abs(t.alive - 14) < 1e-6, `alive {t.alive}`)
	truthy(math.abs(t.stuck - 4) < 1e-6, `stuck {t.stuck}`)
	truthy(math.abs(t.flipped - 1) < 1e-6, `flipped {t.flipped}`)
	eq(t.putBack, 1, "put back")
	local lines = ThumbBrain.report(t, 2, 3, 8, 21.04)
	eq(lines[1], "round over: smashes 2, place 3/8, hits taken 0, first smash 21.0 s", "line 1")
	truthy(string.find(lines[3], "stuck 4 s (29%)", 1, true), lines[3])
	truthy(string.find(lines[3], "put back 1", 1, true), lines[3])
	truthy(string.find(lines[3], "avg speed 10.8", 1, true), lines[3])
	eq(
		ThumbBrain.report(ThumbBrain.tally(), 0, 8, 8, nil)[1],
		"round over: smashes 0, place 8/8, hits taken 0, first smash none",
		"no smash"
	)
end)

test("hits landed: only our own shots that hit (WeaponFx)", function()
	eq(ThumbBrain.isHit("GunShot", { owner = 5, hit = true }, 5), true, "gun hit")
	eq(ThumbBrain.isHit("GunShot", { owner = 5, hit = false }, 5), false, "gun miss")
	eq(ThumbBrain.isHit("GunShot", { owner = -2, hit = true }, 5), false, "a bot's hit")
	eq(ThumbBrain.isHit("FreezeShot", { owner = 5, hit = true }, 5), true, "freeze hit")
	eq(ThumbBrain.isHit("RocketBoom", { owner = 5, hit = -3 }, 5), true, "rocket direct hit")
	eq(ThumbBrain.isHit("RocketBoom", { owner = 5 }, 5), false, "rocket into a wall")
	eq(ThumbBrain.isHit("RocketBoom", { owner = 5, hit = -3, quiet = true }, 5), false, "cleared")
	eq(ThumbBrain.isHit("MineBoom", { owner = 5 }, 5), true, "our mine went off")
	eq(ThumbBrain.isHit("GunShot", "junk", 5), false, "junk")
	eq(ThumbBrain.isHit("RocketLaunch", { owner = 5 }, 5), false, "a launch isn't a hit")
end)

test("the round report hooks MatchResult and WeaponFx only in Studio", function()
	local client = fs.readFile("src/client/TestThumb.luau")
	local gate = string.find(client, "if RunService:IsStudio() then", 1, true)
	local result = string.find(client, 'onRemote("MatchResult"', 1, true)
	local fx = string.find(client, "onRemote(Weapons.FX_REMOTE", 1, true)
	truthy(gate and result and fx and gate < result and gate < fx, "both inside the Studio check")
	truthy(string.find(client, "MatchEnd.read(", 1, true), "place from the end screen's own read")
end)

test(
	"armed: chases a kart instead of the box; the one ahead (60 deg) over a nearer one behind",
	function()
		local s = ThumbBrain.new(rng())
		local out = ThumbBrain.step(
			s,
			0,
			ME,
			{ { x = 10, z = -10 } },
			{ { x = -10, z = -20 } },
			true
		)
		truthy(out.steer < -0.3, `left at the kart, not right at the box, got {out.steer}`)
		truthy(out.target and out.target.x == -10, "target is the kart")
		local s2 = ThumbBrain.new(rng())
		local ahead = { x = 8, z = -25 }
		local behind = { x = 0, z = 6 }
		local o2 = ThumbBrain.step(s2, 0, ME, {}, { behind, ahead }, true)
		truthy(o2.target and o2.target.x == 8, "the kart ahead, though the one behind is nearer")
		local s3 = ThumbBrain.new(rng())
		local o3 = ThumbBrain.step(s3, 0, ME, {}, { behind }, true)
		truthy(o3.target and o3.target.z == 6, "none ahead: turns for the nearest")
		local s4 = ThumbBrain.new(rng())
		local o4 = ThumbBrain.step(
			s4,
			0,
			ME,
			{ { x = 10, z = -10 } },
			{ { x = -10, z = -20 } },
			false
		)
		truthy(o4.target and o4.target.x == 10, "unarmed: the box")
	end
)

test("stuck and flip moments: one event each, grouped into catch spots", function()
	local t = ThumbBrain.tally()
	local events = {}
	local function run(n: number, moved: number, upY: number)
		for _ = 1, n do
			for _, e in ThumbBrain.sample(t, 0.1, moved, upY) or {} do
				table.insert(events, e)
			end
		end
	end
	run(25, 0.02, 1) -- 2.5 s on a rock: one stuck moment, not 15
	run(10, 1.5, 1) -- free
	run(12, 0.02, 0.1) -- tipped: the flip at 0.5 s, then stuck at 1 s
	eq(table.concat(events, " "), "stuck flip stuck", "events")
	-- slow for 0.5 s, then it tips: both moments start on the same frame, both are logged
	local t2 = ThumbBrain.tally()
	for _ = 1, 4 do
		ThumbBrain.sample(t2, 0.125, 0.02, 1) -- (0.125: exact in binary, so 4 + 4 frames = 1 s)
	end
	local both = {}
	for _ = 1, 4 do
		for _, e in ThumbBrain.sample(t2, 0.125, 0.02, 0.1) or {} do
			table.insert(both, e)
		end
	end
	eq(table.concat(both, " "), "stuck flip", "same frame")
	ThumbBrain.spot(t, "stuck", 7, 19, "Rocks.Rock3", true)
	ThumbBrain.spot(t, "stuck", 8, 20, "Rocks.Rock3", false)
	ThumbBrain.spot(t, "flip", 9, 21, "Ramps.RampA", false)
	ThumbBrain.spot(t, "stuck", -40, 5, "Walls.North", true)
	local list = ThumbBrain.spotList(t.spots, 8)
	eq(list[1], "(7, 19) 2 stuck 1 flip on Rocks.Rock3", "the busiest spot first")
	eq(list[2], "(-40, 5) 1 stuck 0 flip on Walls.North", "then the next")
	local lines = ThumbBrain.report(t, 0, 1, 8, nil)
	truthy(string.find(lines[4], "stuck moments 3 (2 driving straight", 1, true), lines[4])
	truthy(string.find(lines[4], "1 turning = the thumb), flips 1", 1, true), lines[4])
	truthy(string.find(lines[5], "catch spots: (7, 19)", 1, true), lines[5])
end)

test(
	"backs up like a kid: stuck, or the target far behind at low speed; then drives again",
	function()
		local function me(speed: number?): ThumbBrain.Me
			return { x = 0, z = 0, fx = 0, fz = -1, speed = speed }
		end
		local box = { { x = 3, z = -20 } } -- ahead, a little right
		-- stuck against something: 0.6 s under 2 studs/s with the gas on
		local s = ThumbBrain.new(rng())
		local out
		local t = 0
		while t < 0.55 do
			out = ThumbBrain.step(s, t, me(0.5), box, {}, false)
			eq(out.brake, 0, "not yet")
			t += 0.05
		end
		out = ThumbBrain.step(s, 0.65, me(0.5), box, {}, false)
		eq(out.throttle, 0, "off the gas")
		eq(out.brake, 1, "reverse")
		eq(out.steer, -1, "target right: steer left so the nose swings right")
		out = ThumbBrain.step(s, 1.3, me(0.5), box, {}, false)
		eq(out.brake, 1, "still backing at 0.65 s in")
		out = ThumbBrain.step(s, 1.5, me(0.5), box, {}, false)
		eq(out.brake, 0, "0.8 s up: drives again")
		eq(out.throttle, 1, "gas")
		out = ThumbBrain.step(s, 2.3, me(0.5), box, {}, false)
		eq(out.brake, 0, "no backing again inside the gap")
		-- target behind at low speed: back up at once, swinging round; fast: just turn
		local behind = { { x = -2, z = 20 } }
		local s2 = ThumbBrain.new(rng())
		local o2 = ThumbBrain.step(s2, 0, me(3), behind, {}, false)
		eq(o2.brake, 1, "slow with the target behind: reverse")
		eq(o2.steer, 1, "target behind-left: steer right so the nose swings left")
		local s3 = ThumbBrain.new(rng())
		eq(ThumbBrain.step(s3, 0, me(10), behind, {}, false).brake, 0, "fast: no reverse")
		local s4 = ThumbBrain.new(rng())
		eq(ThumbBrain.step(s4, 0, me(nil), behind, {}, false).brake, 0, "no speed given: never")
		-- driving fine: never backs up
		local s5 = ThumbBrain.new(rng())
		local backed = false
		for i = 0, 60 do
			backed = backed or ThumbBrain.step(s5, i * 0.05, me(12), box, {}, false).brake > 0
		end
		eq(backed, false, "backed up while driving")
	end
)

test("calm: a respawn or round start forgets being slow", function()
	local s = ThumbBrain.new(rng())
	local box = { { x = 3, z = -20 } }
	local me = { x = 0, z = 0, fx = 0, fz = -1, speed = 0.5 }
	for i = 0, 10 do
		ThumbBrain.step(s, i * 0.05, me, box, {}, false) -- 0.5 s slow
	end
	ThumbBrain.calm(s)
	eq(ThumbBrain.step(s, 0.6, me, box, {}, false).brake, 0, "no back-up right after a respawn")
	local frozen = { x = 0, z = 0, fx = 0, fz = -1, speed = nil }
	for i = 0, 40 do
		eq(ThumbBrain.step(s, 1 + i * 0.05, frozen, box, {}, false).brake, 0, "frozen: never")
	end
end)

test("round and round a near target: eases off the gas, then backs up", function()
	local s = ThumbBrain.new(rng())
	local box = { { x = 6, z = 0 } } -- 6 studs off to the right: 90 deg, too near to turn onto
	local me = { x = 0, z = 0, fx = 0, fz = -1, speed = 6 }
	local modes = {}
	local t = 0
	while t <= 3.2 do
		local out = ThumbBrain.step(s, t, me, box, {}, false)
		if modes[#modes] ~= out.mode then
			table.insert(modes, out.mode)
		end
		if out.mode == "ease" then
			eq(out.throttle, ThumbBrain.ORBIT_GAS, "eased gas")
		end
		t += 0.05
	end
	eq(table.concat(modes, " "), "drive ease back", "drive, then ease at 1 s, back at 3 s")
	-- a far target off to the side: just turns, no easing
	local s2 = ThumbBrain.new(rng())
	for i = 0, 60 do
		eq(ThumbBrain.step(s2, i * 0.05, me, { { x = 30, z = 0 } }, {}, false).mode, "drive", "far")
	end
end)

test(
	"the same back-up three times in one spot: gives up on that target and drives off to the side",
	function()
		local s = ThumbBrain.new(rng())
		local corner = { x = 0, z = -20 } -- the box past a corner it can't reach
		local other = { x = 40, z = -40 }
		local me = { x = 0, z = 0, fx = 0, fz = -1, speed = 0.5 } -- pinned: never moves
		local t, detourAt = 0, nil
		local targets = {}
		while t < 12 do
			local out = ThumbBrain.step(s, t, me, { corner, other }, {}, false)
			if out.mode == "detour" and not detourAt then
				detourAt = t
			end
			if out.target then
				targets[out.target.x .. "," .. out.target.z] = true
			end
			t += 0.05
		end
		truthy(detourAt and detourAt < 8, `detoured ({detourAt})`)
		truthy(targets["40,-40"], "went for the other box once it gave up on the corner one")
		truthy(targets["12,0"] or targets["-12,0"], "the detour point is 12 studs to one side")
	end
)

test("pinned or circling: under 4 studs from 3 s ago, once per 3 s", function()
	local t = ThumbBrain.tally()
	local got = {}
	-- pinned: sliding a stud back and forth along a wall
	for i = 0, 80 do
		local e = ThumbBrain.net(t, i * 0.1, math.sin(i * 0.3) * 0.5, 0)
		if e then
			table.insert(got, e)
		end
	end
	eq(table.concat(got, " "), "pinned pinned", "8 s pinned: logged at 3 s and 6 s")
	-- circling: round a 1.2-stud circle at speed
	local t2 = ThumbBrain.tally()
	local got2 = {}
	for i = 0, 40 do
		local a = i * 0.1 * 4
		local e = ThumbBrain.net(t2, i * 0.1, math.cos(a) * 1.2, math.sin(a) * 1.2)
		if e then
			table.insert(got2, e)
		end
	end
	eq(table.concat(got2, " "), "circling", "circling")
	-- driving: never
	local t3 = ThumbBrain.tally()
	for i = 0, 80 do
		eq(ThumbBrain.net(t3, i * 0.1, i * 1.0, 0), nil, "driving")
	end
	ThumbBrain.mode(t3, 0.1, "back")
	ThumbBrain.mode(t3, 0.1, "back")
	ThumbBrain.mode(t3, 0.1, "detour")
	ThumbBrain.mode(t3, 0.5, "ease")
	eq(t3.backs, 1, "one back-up")
	eq(t3.detours, 1, "one detour")
	eq(t3.eased, 0.5, "eased")
end)
