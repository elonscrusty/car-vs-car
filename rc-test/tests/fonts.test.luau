--!strict
-- The game's fonts: three jobs (carter 10-29, "Steel Shop"). The old candy fonts are gone and
-- every font used is one of the three, so no screen drifts back to its own face.
local fs = require("@lune/fs")
local H = require("./harness")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Fonts")

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, p)
		end
	end
end

test("no file uses LuckiestGuy, FredokaOne or GothamBlack any more", function()
	local files: { string } = {}
	walk("src", files)
	for _, p in files do
		local src = fs.readFile(p)
		for _, bad in { "LuckiestGuy", "FredokaOne", "GothamBlack" } do
			truthy(string.find(src, bad, 1, true) == nil, bad .. " is still in " .. p)
		end
	end
end)

test("every Enum.Font in the game is one of the three jobs' fonts", function()
	local files: { string } = {}
	walk("src", files)
	local ok = { Oswald = true, RobotoCondensed = true, Roboto = true }
	for _, p in files do
		for name in string.gmatch(fs.readFile(p), "Enum%.Font%.(%w+)") do
			truthy(ok[name] == true, "Enum.Font." .. name .. " in " .. p)
		end
	end
end)

test("UiFonts.role picks numbers, small words and big words", function()
	-- (UiFonts reads Enum.Font, which Lune does not have: read the picker's source rules)
	local src = fs.readFile("src/shared/UiFonts.luau")
	truthy(string.find(src, 'return "num"', 1, true) ~= nil)
	truthy(string.find(src, 'return "small"', 1, true) ~= nil)
	eq(string.find(src, "Enum.Font.Oswald", 1, true) ~= nil, true)
end)

return nil
