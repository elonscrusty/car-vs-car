--!strict
-- See your kart (auditor R7-5): props between the camera and your kart fade, floors and karts
-- never do, and everything comes back.
local fs = require("@lune/fs")
local H = require("./harness")
local SeeKart = require("../src/shared/SeeKart")

local test, eq, truthy = H.test, H.eq, H.truthy

print("See kart")

test(
	"see kart: only arena props fade, never the floor, road, hills, outer wall or karts",
	function()
		for _, n in { "Cover", "CoverCap", "TreeStick", "TreeTop", "Crate", "Barrel", "WallPillar" } do
			truthy(SeeKart.PROPS[n], n)
		end
		for _, n in
			{
				"Grass",
				"Road",
				"Curb",
				"Platform",
				"OuterWall",
				"WallTrim",
				"Sand",
				"Hill",
				"Ramp",
				"Bumper",
			}
		do
			eq(SeeKart.PROPS[n], nil, n)
		end
		-- every prop name is a real ArenaBuilder part name
		local src = fs.readFile("src/server/ArenaBuilder.luau")
		for n in SeeKart.PROPS do
			truthy(string.find(src, `"{n}"`, 1, true), `{n} is built by ArenaBuilder`)
		end
	end
)

test("see kart: the quick ball test", function()
	-- a line along x, a prop centre 1 stud off it
	truthy(SeeKart.near(0, 0, 0, 10, 0, 0, 5, 1, 0, 1.5))
	eq(SeeKart.near(0, 0, 0, 10, 0, 0, 5, 3, 0, 1.5), false)
	-- past the ends doesn't count
	eq(SeeKart.near(0, 0, 0, 10, 0, 0, 14, 0, 0, 2), false)
	truthy(SeeKart.near(0, 0, 0, 10, 0, 0, 11, 0, 0, 2))
	-- a zero-length line is just a point
	truthy(SeeKart.near(1, 1, 1, 1, 1, 1, 1, 1, 2, 1))
end)

test("see kart: the line-through-box check", function()
	local p = SeeKart.PAD
	-- a post: half sizes 0.4 x 1.5 x 0.4
	truthy(SeeKart.segmentHitsBox(-10, 0, 0, 10, 0, 0, 0.4, 1.5, 0.4), "straight through")
	eq(SeeKart.segmentHitsBox(-10, 0, 1, 10, 0, 1, 0.4, 1.5, 0.4), false, "beside it")
	eq(SeeKart.segmentHitsBox(-10, 0, 0, -2, 0, 0, 0.4, 1.5, 0.4), false, "stops short")
	eq(SeeKart.segmentHitsBox(-10, 2, 0, 10, 2, 0, 0.4, 1.5, 0.4), false, "over the top")
	truthy(
		SeeKart.segmentHitsBox(-10, 0, 0.4 + p * 0.5, 10, 0, 0.4 + p * 0.5, 0.4, 1.5, 0.4),
		"in the pad"
	)
	eq(SeeKart.segmentHitsBox(1, -10, 0, 1, 10, 0, 0.4, 1.5, 0.4), false, "along an axis, outside")
	truthy(SeeKart.segmentHitsBox(0, -10, 0, 0, 10, 0, 0.4, 1.5, 0.4), "along an axis, inside")
	-- a slanted line from above (the chase camera looks down at the kart)
	truthy(SeeKart.segmentHitsBox(-6, 4, 0, 6, -1, 0, 0.4, 1.5, 0.4))
end)

test("see kart: put back only our own fade; never undo another script's hide", function()
	-- LocalTransparencyModifier is a float32: 0.7 reads back as 0.699999988
	truthy(SeeKart.ours(0.699999988))
	truthy(SeeKart.ours(SeeKart.FADE))
	eq(SeeKart.ours(0), false)
	eq(SeeKart.ours(1), false)
	truthy(SeeKart.hiddenAlready(1), "TopViewClear hid it")
	eq(SeeKart.hiddenAlready(0.699999988), false)
	eq(SeeKart.hiddenAlready(0), false)
end)

test("see kart: faded things come back HOLD seconds after they stop blocking", function()
	local f = SeeKart.fader() :: SeeKart.Fader<string>
	eq(#f:due(0), 0, "nothing faded")
	truthy(f:add("post", 0))
	eq(f:add("post", 0), false, "not twice")
	eq(#f:due(0.1), 0)
	f:keep("post", 0.2)
	eq(#f:due(0.3), 0, "still blocking")
	local back = f:due(0.2 + SeeKart.HOLD)
	eq(#back, 1)
	eq(back[1], "post")
	eq(f.count, 0)
	f:add("tree", 1)
	f:drop("tree")
	f:keep("tree", 2)
	eq(f.count, 0)
	eq(f.seen.tree, nil)
end)

test("see kart: never more than MAX_FADED at once (phones)", function()
	local f = SeeKart.fader() :: SeeKart.Fader<number>
	for i = 1, SeeKart.MAX_FADED do
		truthy(f:add(i, 0))
	end
	eq(f:add(99, 0), false)
	eq(f.count, SeeKart.MAX_FADED)
	eq(#f:due(SeeKart.HOLD), SeeKart.MAX_FADED)
	truthy(f:add(99, 1), "room again once they come back")
end)

test(
	"see kart: the client uses no rays, works in the arena only, restores, and leaves the camera alone",
	function()
		local src = fs.readFile("src/client/SeeKart.client.luau")
		truthy(not string.find(src, "workspace:Raycast(", 1, true), "no rays")
		truthy(not string.find(src, "Spherecast", 1, true))
		truthy(string.find(src, 'FindFirstChild("SmashArena")', 1, true), "arena props only")
		truthy(string.find(src, "LocalTransparencyModifier = was", 1, true), "puts it back")
		truthy(string.find(src, "SeeKart.ours(", 1, true), "float-safe compare")
		truthy(
			string.find(src, "SeeKart.blocks(", 1, true),
			"the margin and beside-the-camera rules"
		)
		truthy(string.find(src, "SeeKart.hiddenAlready(", 1, true), "never undoes another hide")
		truthy(
			string.find(src, "RenderPriority.Camera.Value + 4", 1, true),
			"after the camera and SmashFx"
		)
		truthy(not string.find(src, "cam.CFrame =", 1, true), "never moves the camera")
		truthy(not string.find(src, "ChaseCamera", 1, true))
		truthy(not string.find(src, "RCCar", 1, true))
	end
)

test("see kart (Studio round 8): a prop just past the kart never fades", function()
	local m = SeeKart.KART_MARGIN
	-- camera at x = -10, kart centre at x = 0; a bush box centred 0.5 past the kart
	-- (in the bush's own space: camera at -10.5, kart at -0.5, half size 0.6)
	eq(SeeKart.blocks(-10.5, 0, 0, -0.5, 0, 0, 0.6, 0.6, 0.6), false, "bush just past the kart")
	-- the same bush halfway between camera and kart fades
	truthy(SeeKart.blocks(-5, 0, 0, 5, 0, 0, 0.6, 0.6, 0.6), "bush in between")
	-- a prop that ends just before the margin still fades
	truthy(SeeKart.blocks(-10, 0, 0, m + 0.6 + 0.1, 0, 0, 0.6, 0.6, 0.6))
	-- camera right on top of the kart: nothing in between
	eq(SeeKart.blocks(-10, 0, 5, -10 + m * 0.5, 0, 5, 0.6, 0.6, 0.6), false)
end)

test("see kart (Studio round 8): a prop right beside the camera fades even off the line", function()
	local d = SeeKart.NEAR_CAM
	-- a tree stick (half 0.3 x 2 x 0.3) one stud to the side of the camera; the kart is ahead
	truthy(SeeKart.blocks(1, 0, 0, 1, 0, 10, 0.3, 2, 0.3), "fills the screen edge")
	truthy(SeeKart.pointNearBox(0.3 + d, 0, 0, 0.3, 2, 0.3, d))
	eq(SeeKart.pointNearBox(0.3 + d + 0.1, 0, 0, 0.3, 2, 0.3, d), false)
	-- far to the side: no
	eq(SeeKart.blocks(6, 0, 0, 6, 0, 10, 0.3, 2, 0.3), false)
end)
