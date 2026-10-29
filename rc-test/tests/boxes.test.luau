--!strict
-- "?" boxes: fair odds, pickup only by live karts that touch the box, back in 8 s or less, and the
-- real BoxServer running on the pretend server (no errors, a box goes away and comes back).
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")
local B = require("../src/shared/Boxes")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near
local Vector3 = roblox.Vector3

print("Boxes")

local function onlyRockets(name: string): boolean
	return name == "Rockets"
end

test("odds add up to 100 and only list weapons that exist", function()
	local all = B.odds()
	local sum = 0
	for _, p in all do
		sum += p
	end
	near(sum, 100, 1e-9)
	near(all.Rockets, 30, 1e-9)
	truthy(all.Nuke < all.Rockets, "the nuke is the rare one")
	local one = B.odds(onlyRockets)
	near(one.Rockets, 100, 1e-9)
	eq(one.Gun, nil)
	eq(
		next(B.odds(function()
			return false
		end)),
		nil,
		"no weapons, no odds"
	)
end)

test("rolls match the shown odds over 30000 boxes", function()
	local rng = Fake.random(11)
	local n, got = 30000, { Rockets = 0, Gun = 0, Mine = 0, Freeze = 0, Nuke = 0 }
	for _ = 1, n do
		local w = B.roll(rng:NextNumber()) :: string
		got[w] += 1
	end
	local odds = B.odds()
	for name, p in odds do
		near(got[name] / n * 100, p, 1.5, name)
	end
end)

test("roll edges: r = 0 and r near 1 give a real weapon; no weapons gives nil", function()
	eq(B.roll(0), "Rockets")
	eq(B.roll(0.9999999), "Nuke")
	eq(B.roll(1), "Nuke")
	eq(B.roll(-3), "Rockets")
	eq(
		B.roll(0.5, function()
			return false
		end),
		nil
	)
	eq(B.roll(0.99, onlyRockets), "Rockets", "a weapon not built yet is never rolled")
end)

test("one kart never gets the same weapon 3 times in a row (unless it's the only one)", function()
	for _, r in { 0, 0.1, 0.29 } do -- all of these would be Rockets
		truthy(B.roll(r, nil, "Rockets", 2) ~= "Rockets", `r={r}`)
	end
	eq(B.roll(0.1, nil, "Rockets", 1), "Rockets", "2 in a row is fine")
	eq(B.roll(0.1, onlyRockets, "Rockets", 5), "Rockets", "only weapon: still given")
	-- a long run with the streak rule: never 3 the same
	local rng = Fake.random(3)
	local last: string?, streak = nil, 0
	for _ = 1, 5000 do
		local w = B.roll(rng:NextNumber(), nil, last, streak) :: string
		if w == last then
			streak += 1
		else
			last, streak = w, 1
		end
		truthy(streak <= B.MAX_SAME)
	end
end)

local function kart(id: any, x: number, z: number, alive: boolean?): B.Kart
	return { id = id, x = x, y = 0, z = z, alive = alive ~= false }
end

local yes = function()
	return true
end

test("a live kart touching a box takes it; a far or dead kart doesn't", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 } }, 1)
	local taken = B.step(boxes, { kart("far", 20, 0), kart("dead", 50, 1, false) }, 0, yes)
	eq(#taken, 0)
	taken = B.step(boxes, { kart("a", 2, 3) }, 0, yes)
	eq(#taken, 1)
	eq(taken[1].kart, "a")
	eq(boxes[1].up, false)
	eq(boxes[2].up, true)
end)

test("boxes on a hill: too far below doesn't count", function()
	local boxes = B.new({ { x = 0, y = 20, z = 0 } }, 1)
	eq(#B.step(boxes, { kart("under", 0, 0) }, 0, yes), 0)
	eq(#B.step(boxes, { { id = "top", x = 1, y = 19, z = 1, alive = true } }, 0, yes), 1)
end)

test("a taken box is back in 8 s or less, not before BACK_IN", function()
	truthy(B.BACK_IN <= 8)
	local boxes = B.new({ { x = 0, y = 0, z = 0 } }, 1)
	B.step(boxes, { kart("a", 0, 0) }, 10, yes)
	local _, back = B.step(boxes, {}, 10 + B.BACK_IN - 0.05, yes)
	eq(#back, 0)
	_, back = B.step(boxes, {}, 10 + B.BACK_IN, yes)
	eq(#back, 1)
	eq(boxes[1].up, true)
end)

test("a kart that can't hold another weapon leaves the box for the next kart", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 } }, 1)
	local taken = B.step(boxes, { kart("full", 0, 0), kart("empty", 1, 0) }, 0, function(id)
		return id ~= "full"
	end)
	eq(#taken, 1)
	eq(taken[1].kart, "empty")
end)

test("a box that's back shows for SHOW_GAP before a parked kart can take it again", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 } }, 1)
	B.step(boxes, { kart("a", 0, 0) }, 0, yes)
	local taken, back = B.step(boxes, { kart("b", 0, 0) }, B.BACK_IN, yes)
	eq(#taken, 0)
	eq(#back, 1)
	eq(boxes[1].up, true)
	taken = B.step(boxes, { kart("b", 0, 0) }, B.BACK_IN + B.SHOW_GAP - 0.01, yes)
	eq(#taken, 0, "still showing")
	taken = B.step(boxes, { kart("b", 0, 0) }, B.BACK_IN + B.SHOW_GAP, yes)
	eq(#taken, 1)
	truthy(B.SHOW_GAP < 1)
end)

test("one kart takes at most one box per check", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 }, { x = 4, y = 0, z = 0 } }, 1)
	local taken = B.step(boxes, { kart("a", 2, 0) }, 0, yes)
	eq(#taken, 1)
	eq(boxes[2].up, true)
end)

test(
	"a kart driving fast past a box between two checks still takes it (its path counts)",
	function()
		local boxes = B.new({ { x = 0, y = 0, z = 0 } }, 1)
		local k = kart("a", 10, 1)
		k.px, k.pz = -10, 1 -- 20 studs since the last check, right past the box
		eq(#B.step(boxes, { k }, 0, yes), 1)
		local boxes2 = B.new({ { x = 0, y = 0, z = 0 } }, 1)
		local k2 = kart("b", 10, 15)
		k2.px, k2.pz = -10, 15 -- path 15 studs to the side: too far
		eq(#B.step(boxes2, { k2 }, 0, yes), 0)
	end
)

test("sizes come from the arena scale: reach and box fit a kart, not raw studs", function()
	-- RC arena: a kart is 5.5 big = 1.375 studs at scale 0.25
	local b = B.new({ { x = 0, y = 0, z = 0 } })[1]
	near(b.r, B.RADIUS * B.SCALE, 1e-9)
	local kartLen = B.KART * B.SCALE
	truthy(
		b.r >= kartLen * 1.8 and b.r <= kartLen * 2.4,
		`reach {b.r} = about 2 kart lengths ({kartLen})`
	)
	truthy(b.r > 2.5 and b.r < 3.2, `reach {b.r} studs`)
	truthy(B.SIZE <= B.KART, "box no longer than a kart")
	-- a kart 2.5 kart lengths away doesn't get it; 1.9 lengths away does
	eq(#B.step(B.new({ { x = 0, y = 0, z = 0 } }), { kart("far", kartLen * 2.5, 0) }, 0, yes), 0)
	eq(#B.step(B.new({ { x = 0, y = 0, z = 0 } }), { kart("on", kartLen * 1.9, 0) }, 0, yes), 1)
end)

test("reset puts every box back up", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 } }, 1)
	B.step(boxes, { kart("a", 0, 0) }, 0, yes)
	B.reset(boxes)
	eq(boxes[1].up, true)
	eq(boxes[1].backAt, 0)
end)

test("BoxServer on the pretend server: pickup gives a weapon, box comes back, no errors", function()
	local S = Fake.server(Fake.store())
	local BoxServer = S.require("BoxServer")
	local pos = Vector3.new(0, 0, 0)
	local gave: { string } = {}
	local full = false
	local handle = BoxServer.start({
		spots = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) },
		karts = function()
			return {
				{ id = 7, position = pos, alive = true },
				{ id = "bot1", position = "junk" :: any, alive = true }, -- junk is skipped
			}
		end,
		give = function(id, name)
			if full then
				return false
			end
			table.insert(gave, `{id}:{name}`)
			return true
		end,
		has = onlyRockets,
		seed = 5,
	})
	local box1 = handle.folder:FindFirstChild("Box1") :: any
	truthy(box1, "box model made")
	eq(box1:GetAttribute("Up"), true)
	near((box1:FindFirstChild("Body") :: any).Size.X, B.SIZE * B.SCALE, 1e-6, "RC-size box")
	S.advance(0.3, 0.05)
	eq(#gave, 1)
	eq(gave[1], "7:Rockets")
	eq(box1:GetAttribute("Up"), false)
	eq(box1:GetAttribute("TakenBy"), "7")
	eq(box1:GetAttribute("TakenWeapon"), "Rockets")
	eq(box1:GetAttribute("TakenCount"), 1)
	eq((handle.folder:FindFirstChild("Box2") :: any):GetAttribute("Up"), true)

	-- a jump (teleport) right across box 2 doesn't pick it up; a short drive across it does
	pos = Vector3.new(90, 0, 0)
	S.advance(0.2, 0.05)
	pos = Vector3.new(110, 0, 0) -- 20 studs in one check: a jump at RC scale
	S.advance(0.1, 0.05)
	eq((handle.folder:FindFirstChild("Box2") :: any):GetAttribute("Up"), true, "jump skips")
	pos = Vector3.new(96, 0, 0.3) -- 4 studs before box 2, out of reach
	S.advance(0.2, 0.05)
	eq(#gave, 1)
	pos = Vector3.new(104, 0, 0.3) -- 4 studs past it: only the path between was in reach
	S.advance(0.2, 0.05)
	eq(
		(handle.folder:FindFirstChild("Box2") :: any):GetAttribute("Up"),
		false,
		"drive-through takes it"
	)
	eq(#gave, 2)

	-- kart drives away; the box is back within 8 s
	pos = Vector3.new(50, 0, 50)
	S.advance(8, 0.05)
	eq(box1:GetAttribute("Up"), true)

	-- a kart that's full doesn't take it
	full = true
	pos = Vector3.new(0, 0, 0)
	S.advance(1, 0.05)
	eq(box1:GetAttribute("Up"), true)
	eq(#gave, 2)

	near(handle.odds().Rockets, 100, 1e-9)

	-- a second set (the warm-up yard) runs beside it; starting the same name again replaces it
	local yard = BoxServer.start({
		name = "WarmupBoxes",
		spots = { Vector3.new(500, 0, 0) },
		karts = function()
			return {}
		end,
		give = function()
			return true
		end,
	})
	truthy(yard.folder.Parent ~= nil and handle.folder.Parent ~= nil, "both sets live")
	local yard2 = BoxServer.start({
		name = "WarmupBoxes",
		spots = { Vector3.new(500, 0, 0) },
		karts = function()
			return {}
		end,
		give = function()
			return true
		end,
	})
	eq(yard.folder.Parent, nil, "old yard stopped")
	truthy(yard2.folder.Parent ~= nil)
	yard2.stop()
	handle.stop()
	eq(handle.folder.Parent, nil)
	eq(#S.errors, 0, table.concat(S.errors, "\n"))
end)
