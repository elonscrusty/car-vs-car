--!nocheck
-- Name tags never stack (auditor round 13: "Zippy" over "Lil Smasher" when two karts touch).
local H = require("./harness")
local TagStack = require("../src/shared/TagStack")

local test, truthy = H.test, H.truthy

print("Name tags don't stack")

local W, H_ = 84, 18

test("two touching karts: the farther tag is hidden, even one tag height above", function()
	local out = TagStack.pick({
		{ x = 400, y = 200, on = true }, -- Lil Smasher, nearest
		{ x = 410, y = 178, on = true }, -- Zippy, just above it
	}, W, H_)
	truthy(out[1] == true, "nearest keeps its name")
	truthy(out[2] == false, "the farther one hides")
end)

test("tags far apart on screen both show", function()
	local out = TagStack.pick({
		{ x = 200, y = 200, on = true },
		{ x = 400, y = 200, on = true },
		{ x = 200, y = 260, on = true },
	}, W, H_)
	truthy(out[1] and out[2] and out[3], "all three show")
end)

test("a hidden tag only checks against shown ones, and off-screen ones never block", function()
	local out = TagStack.pick({
		{ x = 300, y = 200, on = false }, -- behind the camera
		{ x = 300, y = 200, on = true },
		{ x = 300, y = 210, on = true },
		{ x = 300, y = 236, on = true }, -- clear of the shown one (36 >= 2 * 18)
	}, W, H_)
	truthy(out[1] and out[2], "off screen doesn't block")
	truthy(out[3] == false, "stacked one hides")
	truthy(out[4] == true, "the hidden one doesn't block the next")
end)

test("a hidden tag needs a bit more room to come back (no blinking)", function()
	local spots = {
		{ x = 300, y = 200, on = true },
		{ x = 300, y = 238, on = true, hid = true },
	}
	truthy(TagStack.pick(spots, W, H_)[2] == false, "still hidden just past the edge")
	spots[2].y = 250
	truthy(TagStack.pick(spots, W, H_)[2] == true, "back once well clear")
	spots[2].y, spots[2].hid = 238, false
	truthy(TagStack.pick(spots, W, H_)[2] == true, "a shown tag stays at the same spot")
end)

test("OtherCars hides tags with TagStack", function()
	local src = require("@lune/fs").readFile("src/client/OtherCars.luau")
	truthy(string.find(src, "TagStack.pick(", 1, true) ~= nil, "uses TagStack")
	truthy(string.find(src, "tag.Enabled = false", 1, true) ~= nil, "hides the farther tag")
end)

test("a big race tag and a small match tag use each one's own size", function()
	local out = TagStack.pick({
		{ x = 300, y = 200, on = true, w = 120, h = 26 },
		{ x = 395, y = 200, on = true, w = 84, h = 18 }, -- 95 apart: inside (120 + 84) / 2 = 102
		{ x = 420, y = 200, on = true, w = 84, h = 18 }, -- 120 apart: clear of the big one
	}, 84, 18)
	truthy(out[2] == false, "inside half of each")
	truthy(out[3] == true, "clear of both halves")
end)
