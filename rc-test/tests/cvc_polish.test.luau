--!strict
-- Car VS Car fixes from the Studio final pass that live in client scripts (no Roblox in Lune: these
-- read the source for the rule each fix keeps).
local fs = require("@lune/fs")
local H = require("./harness")
local test, truthy = H.test, H.truthy

print("Car VS Car polish")

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

test(
	"MY GARAGE updates in place on coins and training; it rebuilds only when its cars move",
	function()
		local src = fs.readFile("src/client/CvcGarage.client.luau")
		-- (a rebuild on every coin tick lost a BETTER tap, Studio final-14)
		truthy(has(src, "if now == built then"), "render compares the shape first")
		truthy(has(src, "table.insert(updates, update)"), "station cards update in place")
		local _, renders = string.gsub(src, "\n\tclear%(%)", "")
		truthy(renders == 0, "no clear() straight in render")
	end
)

test("a bar at its car's top is drawn full and gold (MAX! looks maxed)", function()
	local src = fs.readFile("src/client/CvcUi.luau")
	truthy(has(src, "local f = if full then 1 else v / Training.MAX_BAR"), "full width at the top")
	truthy(has(src, "if full then MAX_GOLD"), "gold at the top")
end)

test("dark words on a yellow button have no light outline (the tabs looked smeared)", function()
	local src = fs.readFile("src/client/CvcGarage.client.luau")
	truthy(
		has(src, "b.TextStrokeTransparency = if on then 1 else 0.2"),
		"inkText drops the outline"
	)
	truthy(not has(src, "TextColor3 = if view =="), "the tabs go through inkText")
end)

test("the crate's big car name waits for the ribbon to step aside", function()
	local src = fs.readFile("src/client/CvcCrate.client.luau")
	truthy(has(src, "ribbon.Visible = false"), "the ribbon hides while the name is up")
end)

test("Car VS Car's NEXT chip points at crates, never the car shop", function()
	local src = fs.readFile("src/client/Stars.client.luau")
	truthy(has(src, "info = cvcGoal(info)"), "the goal goes through cvcGoal")
	truthy(has(src, '"GET A CRATE!"'), "GET A CRATE! when you have the coins")
end)
