--!strict
local H = require("./harness")
local BowlLayout = require("../src/shared/BowlLayout")
local BowlView = require("../src/shared/BowlView")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy
local Cr = BowlLayout.crusher

print("BowlView (what the client draws)")

test("the crusher rests until a round runs, and with no round at all", function()
	for _, since in { nil, -1, 0, 2, Cr.first - Cr.warn - 0.01 } do
		local look = BowlView.crusher(since)
		eq(look.lift, Cr.restLift)
		eq(look.warn, 0)
		eq(look.ring, 0)
		eq(look.ringFade, 1)
		eq(look.shake, 0)
		eq(look.slam, -1)
	end
end)

test("the warning: the press lifts, the floor goes red, the lamps flash", function()
	local start = Cr.first - Cr.warn
	local early = BowlView.crusher(start + 0.1)
	local late = BowlView.crusher(start + Cr.warn - 0.05)
	truthy(early.lift > Cr.restLift and late.lift > early.lift, "lifting")
	truthy(late.lift <= Cr.warnLift + 1e-9)
	truthy(early.warn > 0 and late.warn > early.warn * 0.9, "the red grows")
	eq(early.ring, 0)
	-- the lamps are not lit all the time while it warns
	local on, off = 0, 0
	for i = 0, 30 do
		if BowlView.crusher(start + Cr.warn * i / 31).lamps then
			on += 1
		else
			off += 1
		end
	end
	truthy(on > 5 and off > 5, `flashing: {on} on, {off} off`)
end)

test("the slam: the press is down, then the ring spreads and fades", function()
	local slam = Cr.first
	local down = BowlView.crusher(slam + Cr.drop + 0.01)
	near(down.lift, Cr.slamLift, 1e-6)
	local a = BowlView.crusher(slam + Cr.drop + Cr.wave * 0.1)
	local b = BowlView.crusher(slam + Cr.drop + Cr.wave * 0.9)
	truthy(a.ring > 0 and b.ring > a.ring, "the ring grows")
	truthy(b.ring <= Cr.shockRadius * 2 + 1e-6)
	truthy(b.ringFade > a.ringFade and b.ringFade <= 1, "and fades")
	truthy(a.shake > b.shake and b.shake >= 0, "the shake is biggest at the slam")
	truthy(a.shake <= 4, "but never huge")
	eq(a.slam, 0)
	eq(
		BowlView.crusher(slam + Cr.period + Cr.drop + Cr.wave * 0.5).slam,
		1,
		"the second slam is number 1"
	)
	eq(BowlView.crusher(slam + 2).slam, -1, "none between slams")
	-- later it lifts back and the ring is gone
	local up = BowlView.crusher(slam + Cr.drop + Cr.wave + Cr.lift * 0.5)
	eq(up.ring, 0)
	truthy(up.lift > Cr.slamLift and up.lift < Cr.restLift)
	local back = BowlView.crusher(slam + Cr.drop + Cr.wave + Cr.lift + 0.1)
	eq(back.lift, Cr.restLift)
end)

test("it slams again every period, the same way", function()
	local one = BowlView.crusher(Cr.first + Cr.drop + Cr.wave * 0.5)
	local two = BowlView.crusher(Cr.first + Cr.period + Cr.drop + Cr.wave * 0.5)
	near(one.ring, two.ring, 1e-6)
	near(one.lift, two.lift, 1e-6)
end)

local CAR_HALF_LEN, CAR_HALF_WID = 8, 4

test("sparks: a car pressed against the tire wall while moving", function()
	local R = BowlLayout.wallRadius
	-- side on: the car's long side is toward the wall (facing along the wall)
	local s = BowlView.scrape(R - CAR_HALF_WID - 0.2, 0, 0, 1, 30, CAR_HALF_LEN, CAR_HALF_WID)
	truthy(s ~= nil, "touching with its side")
	if s then
		near(s.x, R, 1e-6)
		near(s.z, 0, 1e-6)
		truthy(s.nx < -0.99, "the sparks fly back into the bowl")
	end
	-- nose first
	local nose = BowlView.scrape(R - CAR_HALF_LEN - 0.2, 0, 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID)
	truthy(nose ~= nil, "touching with its nose")
	-- a few studs away: no sparks
	eq(BowlView.scrape(R - 20, 0, 0, 1, 30, CAR_HALF_LEN, CAR_HALF_WID), nil)
	-- resting against it: no sparks
	eq(BowlView.scrape(R - CAR_HALF_WID - 0.2, 0, 0, 1, 2, CAR_HALF_LEN, CAR_HALF_WID), nil)
	-- the other side of the bowl works the same
	local far = BowlView.scrape(0, -(R - CAR_HALF_WID - 0.2), 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID)
	truthy(far ~= nil and far.nz > 0.99)
end)

test("sparks: a car scraping round the crusher's base", function()
	local r = Cr.baseRadius
	local s = BowlView.scrape(r + CAR_HALF_WID + 0.2, 0, 0, 1, 30, CAR_HALF_LEN, CAR_HALF_WID)
	truthy(s ~= nil, "touching the base")
	if s then
		near(s.x, r, 1e-6)
		truthy(s.nx > 0.99, "the sparks fly out from the base")
	end
	eq(BowlView.scrape(r + 30, 0, 0, 1, 30, CAR_HALF_LEN, CAR_HALF_WID), nil)
	-- in the open floor between them: nothing
	eq(BowlView.scrape(60, 0, 0, 1, 40, CAR_HALF_LEN, CAR_HALF_WID), nil)
end)

test("sparks start where the bounce turns a car round, a few studs before the tires", function()
	-- a driven Studio test: the bounce turned every car with its nose 3 to 5 studs from the wall, and
	-- the sparks (touching = 0.9 studs) never fired in 14 hits
	local R = BowlLayout.wallRadius
	for _, gap in { 3.2, 4.4 } do -- the nose, at 60 and at 30 frames a second
		local s = BowlView.scrape(R - CAR_HALF_LEN - gap, 0, 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID)
		truthy(s ~= nil, `nose {gap} studs from the wall`)
	end
	-- well clear of it: nothing
	eq(BowlView.scrape(R - CAR_HALF_LEN - 8, 0, 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID), nil)
	-- the same round the crusher's base (a car facing away, its tail near the base)
	local r = Cr.baseRadius
	truthy(BowlView.scrape(r + CAR_HALF_LEN + 3.2, 0, 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID) ~= nil)
	eq(BowlView.scrape(r + CAR_HALF_LEN + 8, 0, 1, 0, 30, CAR_HALF_LEN, CAR_HALF_WID), nil)
end)

test(
	"the camera looks less far ahead when a wall pushed it in, so the car stays on screen",
	function()
		local ahead, least, back = 41.6, 8, 35
		near(BowlView.lookAhead(ahead, back, back, least), ahead, 1e-9) -- in the open: as usual
		near(BowlView.lookAhead(ahead, 50, back, least), ahead, 1e-9) -- never further than usual
		near(BowlView.lookAhead(ahead, back / 2, back, least), ahead / 2, 1e-9)
		near(BowlView.lookAhead(ahead, 0, back, least), least, 1e-9) -- never exactly over the car
		near(BowlView.lookAhead(ahead, 1, back, least), least, 1e-9)
		near(BowlView.lookAhead(ahead, 10, 0, least), ahead, 1e-9) -- nothing to compare with
		near(BowlView.lookAhead(5, 0, back, least), 5, 1e-9) -- a short look stays short
		-- a camera 42 up and `have` studs behind the car: the car never sits more than 25 degrees below
		-- the middle of the view (the view is 70 degrees tall, so 35 is its edge). A driven Studio test lost
		-- the car under the bottom edge with the camera pushed in to 4 studs behind it.
		for _, have in { 0, 2, 5, 10, 20, 35 } do
			local a = BowlView.lookAhead(ahead, have, back, least)
			local below = math.deg(math.atan2(42, have)) - math.deg(math.atan2(42, have + a))
			truthy(
				below < 25,
				`car {below} degrees below the middle with the camera {have} behind it`
			)
		end
	end
)

test("skid marks: a hard sideways slide at speed, not a straight drive or a slow wobble", function()
	local top = 42
	-- straight
	eq(BowlView.skid(top, 0, 1, 0, top, false), 0)
	-- gentle turn at speed (a little sideways speed)
	eq(BowlView.skid(top, 5, 1, 0, top, false), 0)
	-- sliding: the nose points north while the car goes east
	local hard = BowlView.skid(top, 0, 0, 1, top, false)
	eq(hard, 1)
	local part = BowlView.skid(top, 12, 1, 0, top, false)
	truthy(part > 0 and part < 1, "part way")
	-- slow: never
	eq(BowlView.skid(5, 0, 0, 1, top, false), 0)
	-- the drift flag alone marks the road
	truthy(BowlView.skid(top, 0, 1, 0, top, true) >= 0.6)
	-- but not when it is hardly moving
	eq(BowlView.skid(5, 0, 1, 0, top, true), 0)
	-- reversing straight leaves none
	eq(BowlView.skid(-top * 0.6, 0, 1, 0, top, false), 0)
end)

test("the camera stays inside the bowl: a point past the circle is pulled in", function()
	local x, z = BowlView.keepInside(10, 20, 112)
	eq(x, 10)
	eq(z, 20)
	local ox, oz = BowlView.keepInside(300, 0, 112)
	near(ox, 112, 1e-9)
	near(oz, 0, 1e-9)
	local dx, dz = BowlView.keepInside(-150, 150, 112)
	near(math.sqrt(dx * dx + dz * dz), 112, 1e-9)
	truthy(dx < 0 and dz > 0, "same direction")
	eq(select(1, BowlView.keepInside(0, 0, 112)), 0)
end)

test("the flyover starts high over the far end and ends low behind my car", function()
	for _, dir in { 1, -1 } do
		local px, py, pz, lx, _, lz, blend = BowlView.fly(0, dir)
		near(px, dir * 140, 1e-6)
		truthy(py > 90, "high")
		eq(blend, 0)
		-- at the start it looks at the middle of the bowl
		truthy(math.abs(lx) < 1e-6 and math.abs(lz) < 1e-6)
		-- the end: behind my start pad (the start is at -dir * spawnX), low, looking down the lane
		local ex, ey, ez, elx, _, elz, endBlend = BowlView.fly(1, dir)
		eq(endBlend, 1)
		truthy(ey < 50 and ey > 30, "low")
		truthy(ex * dir < -BowlLayout.spawnX, "behind my car")
		near(ez, BowlLayout.laneZ, 1e-6 + 30)
		near(elz, BowlLayout.laneZ, 1e-6)
		truthy(elx * dir < 0, "looking toward the middle from the start end")
		local _ = pz
	end
end)

test(
	"the flyover is one smooth sweep: no jumps, always over the bowl, never too low early",
	function()
		local lastX, lastY, lastZ
		local crossedMiddle = false
		for i = 0, 100 do
			local k = i / 100
			local x, y, z, _, _, _, blend = BowlView.fly(k, 1)
			truthy(blend >= 0 and blend <= 1)
			if lastX then
				local step = math.sqrt((x - lastX) ^ 2 + (y - lastY) ^ 2 + (z - lastZ) ^ 2)
				truthy(step < 12, `a jump of {step} at {k}`)
			end
			lastX, lastY, lastZ = x, y, z
			if x < 0 then
				crossedMiddle = true
			end
			-- above the crusher (19 high) and the tire wall (14.4) the whole way
			truthy(y > 30, "never low: " .. y)
		end
		truthy(crossedMiddle, "it passes over the middle")
		-- the blend only starts in the second half
		local _, _, _, _, _, _, early = BowlView.fly(0.4, 1)
		eq(early, 0)
	end
)
