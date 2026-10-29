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
