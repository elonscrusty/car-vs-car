--!strict
-- See your kart (auditor R7-5): props between the camera and your kart fade, floors and karts
-- never do, and everything comes back.
local fs = require("@lune/fs")
local H = require("./harness")
local SeeKart = require("../src/shared/SeeKart")

local test, eq, truthy = H.test, H.eq, H.truthy

print("See kart")

local function hit(over: { [string]: any }): SeeKart.Hit
	local h: any = {
		normalY = 0,
		hitY = 5,
		kartY = 2,
		size = { x = 2, y = 12, z = 2 }, -- a white post
		kart = false,
		terrain = false,
		transparency = 0,
	}
	for k, v in over do
		h[k] = v
	end
	return h
end

test("see kart: a post, a wall or a tree in the way fades", function()
	eq(SeeKart.skip(hit({})), false)
	eq(SeeKart.skip(hit({ size = { x = 30, y = 6, z = 2 } })), false, "an orange cover wall")
	eq(SeeKart.skip(hit({ normalY = 1, hitY = 6, kartY = 2 })), false, "the top of a tall wall")
end)

test("see kart: floors, ground, hills, karts and see-through things never fade", function()
	truthy(SeeKart.skip(hit({ normalY = 1, hitY = 0, kartY = 2 })), "floor under the kart")
	truthy(SeeKart.skip(hit({ size = { x = 240, y = 2, z = 240 } })), "the arena ground")
	truthy(SeeKart.skip(hit({ size = { x = 70, y = 20, z = 60 } })), "a big hill")
	truthy(SeeKart.skip(hit({ kart = true })), "a kart")
	truthy(SeeKart.skip(hit({ terrain = true })), "terrain")
	truthy(SeeKart.skip(hit({ transparency = 1 })), "already invisible")
end)

test("see kart: the line-through-box check", function()
	local half = { x = 1, y = 6, z = 1 }
	-- straight through
	truthy(SeeKart.segmentHitsBox({ x = -10, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, half))
	-- passes beside it (past the 0.5 pad)
	eq(SeeKart.segmentHitsBox({ x = -10, y = 0, z = 3 }, { x = 10, y = 0, z = 3 }, half), false)
	-- stops short of it
	eq(SeeKart.segmentHitsBox({ x = -10, y = 0, z = 0 }, { x = -4, y = 0, z = 0 }, half), false)
	-- over the top
	eq(SeeKart.segmentHitsBox({ x = -10, y = 9, z = 0 }, { x = 10, y = 9, z = 0 }, half), false)
	-- grazing inside the pad still counts (no flicker at the edge)
	truthy(SeeKart.segmentHitsBox({ x = -10, y = 0, z = 1.3 }, { x = 10, y = 0, z = 1.3 }, half))
	-- a line along an axis, outside
	eq(SeeKart.segmentHitsBox({ x = 5, y = -10, z = 0 }, { x = 5, y = 10, z = 0 }, half), false)
	truthy(SeeKart.segmentHitsBox({ x = 0, y = -10, z = 0 }, { x = 0, y = 10, z = 0 }, half))
end)

test("see kart: faded things come back HOLD seconds after they stop blocking", function()
	local f = SeeKart.fader() :: SeeKart.Fader<string>
	truthy(f:add("post", 0))
	eq(f:add("post", 0), false, "not twice")
	eq(#f:due(0.1), 0)
	f:keep("post", 0.2)
	eq(#f:due(0.3), 0, "still blocking")
	local back = f:due(0.2 + SeeKart.HOLD)
	eq(#back, 1)
	eq(back[1], "post")
	eq(f.count, 0)
	-- gone parts can be dropped; keep on an unknown key does nothing
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
	"see kart: the client casts one ray a frame, restores what it faded, and leaves the camera alone",
	function()
		local src = fs.readFile("src/client/SeeKart.client.luau")
		local _, rays = string.gsub(src, "workspace:Raycast%(", "")
		eq(rays, 1, "one ray a frame")
		truthy(not string.find(src, "Spherecast", 1, true))
		truthy(string.find(src, "LocalTransparencyModifier = was", 1, true), "puts it back")
		truthy(
			string.find(src, "RenderPriority.Camera.Value + 4", 1, true),
			"after the camera and SmashFx"
		)
		truthy(not string.find(src, "cam.CFrame =", 1, true), "never moves the camera")
		truthy(not string.find(src, "ChaseCamera", 1, true))
		truthy(not string.find(src, "RCCar", 1, true))
	end
)
