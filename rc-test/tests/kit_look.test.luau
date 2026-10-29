--!nocheck
-- carter's UI kit v41 (ui-kit/v41, "UI chrome v2"): the shared pieces build in the pretend game
-- with the kit's colors (3D button face, navy panel, blue card + gold ring, tabs, title).
local Fake = require("./fakeroblox")
local H = require("./harness")

local test, truthy = H.test, H.truthy

print("Kit v41 look")

local S = Fake.server(Fake.store())
local req = S.client(1)
local Kit = req("Ui.Kit")
local UiTheme = require("../src/shared/UiTheme")

local function hex(c): string
	return string.format(
		"%02x%02x%02x",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function gradStops(f): { string }
	local g = f:FindFirstChild("Gloss")
	local out = {}
	if g then
		for _, k in g.Color.Keypoints do
			table.insert(out, hex(k.Value))
		end
	end
	return out
end

local root = S.Instance.new("Frame")

test(
	"a lime button: the kit's deep base and its hi -> c -> c2 face, with the rim and gloss",
	function()
		local b = Kit.button(root, "Go", 0, 0, 200, 66, "lime", "GO!")
		local body = b:FindFirstChild("Body")
		local face = body:FindFirstChild("Face")
		truthy(hex(body.BackgroundColor3) == UiTheme.FACE.lime.deep, hex(body.BackgroundColor3))
		local st = gradStops(face)
		truthy(st[1] == "d2ff96" and st[2] == "55ea2c" and st[3] == "2bc414", table.concat(st, ","))
		truthy(face:FindFirstChild("Rim") and face:FindFirstChild("Top"), "no rim or gloss band")
		Kit.enable(b, false)
		truthy(hex(body.BackgroundColor3) == UiTheme.FACE.off.deep, "off: not grey")
	end
)

test("navy panel: navy face, light-blue rim and ink line behind it", function()
	local p = Kit.navyPanel(root, "P", 10, 10, 300, 200)
	truthy(gradStops(p)[1] == "27509a", "panel face")
	local rim = root:FindFirstChild("PRim")
	truthy(rim and hex(rim.BackgroundColor3) == "4f93ec", "rim")
	truthy(root:FindFirstChild("PLine"), "ink line")
end)

test("card plate: blue face, the gold ring only when picked", function()
	local c = Kit.plate(root, "Card", 0, 0, 120, 160, false)
	truthy(gradStops(c)[1] == "3d7bd2", "card face")
	truthy(c:FindFirstChild("Ring").Visible == false, "ring on an unpicked card")
	Kit.select(c, true)
	truthy(c:FindFirstChild("Ring").Visible == true, "no ring on the picked card")
end)

test("tabs: the picked one cyan and raised, gold on the shop", function()
	local t = Kit.tabs(root, 0, 0, 300, 46, { "CARS", "HATS" }, 1, nil, nil, "gold")
	local t1 = t.frame:FindFirstChild("Tab1")
	local t2 = t.frame:FindFirstChild("Tab2")
	truthy(t1:FindFirstChild("On").Visible and not t1:FindFirstChild("Off").Visible, "tab 1")
	truthy(t2:FindFirstChild("Off").Visible and not t2:FindFirstChild("On").Visible, "tab 2")
	truthy(gradStops(t1:FindFirstChild("On"):FindFirstChild("Face"))[2] == "ffd93b", "gold")
end)

test("title: a gradient fill over the stroked words", function()
	local l = Kit.title(root, 0, 0, 300, 50, "PICK YOUR CAR!", "gold")
	truthy(l:FindFirstChild("Fill") and l:FindFirstChildOfClass("UIStroke"), "no fill or stroke")
end)

test("the kit pieces built with no script errors", function()
	truthy(#S.errors == 0, table.concat(S.errors, "\n"))
end)
