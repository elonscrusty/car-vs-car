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
	near(all.Rockets, 40, 1e-9)
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
	local n, got = 30000, { Rockets = 0, Gun = 0, Mine = 0 }
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
	eq(B.roll(0.9999999), "Mine")
	eq(B.roll(1), "Mine")
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
	for _, r in { 0, 0.1, 0.39 } do -- all of these would be Rockets
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
	local boxes = B.new({ { x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 } })
	local taken = B.step(boxes, { kart("far", 20, 0), kart("dead", 50, 1, false) }, 0, yes)
	eq(#taken, 0)
	taken = B.step(boxes, { kart("a", 3, 4) }, 0, yes)
	eq(#taken, 1)
	eq(taken[1].kart, "a")
	eq(boxes[1].up, false)
	eq(boxes[2].up, true)
end)

test("boxes on a hill: too far below doesn't count", function()
	local boxes = B.new({ { x = 0, y = 20, z = 0 } })
	eq(#B.step(boxes, { kart("under", 0, 0) }, 0, yes), 0)
	eq(#B.step(boxes, { { id = "top", x = 1, y = 19, z = 1, alive = true } }, 0, yes), 1)
end)

test("a taken box is back in 8 s or less, not before BACK_IN", function()
	truthy(B.BACK_IN <= 8)
	local boxes = B.new({ { x = 0, y = 0, z = 0 } })
	B.step(boxes, { kart("a", 0, 0) }, 10, yes)
	local _, back = B.step(boxes, {}, 10 + B.BACK_IN - 0.05, yes)
	eq(#back, 0)
	_, back = B.step(boxes, {}, 10 + B.BACK_IN, yes)
	eq(#back, 1)
	eq(boxes[1].up, true)
end)

test("a kart that can't hold another weapon leaves the box for the next kart", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 } })
	local taken = B.step(boxes, { kart("full", 0, 0), kart("empty", 1, 0) }, 0, function(id)
		return id ~= "full"
	end)
	eq(#taken, 1)
	eq(taken[1].kart, "empty")
end)

test("one kart takes at most one box per check", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 }, { x = 4, y = 0, z = 0 } })
	local taken = B.step(boxes, { kart("a", 2, 0) }, 0, yes)
	eq(#taken, 1)
	eq(boxes[2].up, true)
end)

test("a kart at full speed can't skip over a box between checks", function()
	truthy(40 / B.CHECK_HZ < B.RADIUS * 2)
end)

test("reset puts every box back up", function()
	local boxes = B.new({ { x = 0, y = 0, z = 0 } })
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
				{ id = "bot1", position = "junk", alive = true }, -- junk is skipped
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
	local box1 = handle.folder:FindFirstChild("Box1")
	truthy(box1, "box model made")
	eq(box1:GetAttribute("Up"), true)
	S.advance(0.3, 0.05)
	eq(#gave, 1)
	eq(gave[1], "7:Rockets")
	eq(box1:GetAttribute("Up"), false)
	eq(box1:GetAttribute("TakenBy"), "7")
	eq(box1:GetAttribute("TakenWeapon"), "Rockets")
	eq(handle.folder:FindFirstChild("Box2"):GetAttribute("Up"), true)

	-- kart drives away; the box is back within 8 s
	pos = Vector3.new(50, 0, 50)
	S.advance(8, 0.05)
	eq(box1:GetAttribute("Up"), true)

	-- a kart that's full doesn't take it
	full = true
	pos = Vector3.new(0, 0, 0)
	S.advance(1, 0.05)
	eq(box1:GetAttribute("Up"), true)
	eq(#gave, 1)

	near(handle.odds().Rockets, 100, 1e-9)
	handle.stop()
	eq(handle.folder.Parent, nil)
	eq(#S.errors, 0, table.concat(S.errors, "\n"))
end)
