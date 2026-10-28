--!strict
-- The tags over the race cars (YOU, the other cars' names, the win trophy) sit on the car's own
-- part, like the training tag (CarTag). Parented to PlayerGui they never showed in the Studio check.
local fs = require("@lune/fs")
local H = require("./harness")
local test, truthy = H.test, H.truthy

local FILES = {
	"src/client/Main.client.luau",
	"src/client/OtherCars.luau",
}

for _, path in FILES do
	test(path .. ": no race tag is put in PlayerGui", function()
		local src = fs.readFile(path)
		truthy(
			string.find(src, "youTag.Parent = body", 1, true) or path ~= FILES[1],
			"YOU tag on the car"
		)
		truthy(
			string.find(src, "tag.Parent = body", 1, true) or path ~= FILES[2],
			"name tag on the car"
		)
		truthy(
			string.find(src, "gui.Parent = head", 1, true) or path ~= FILES[3],
			"trophy on the car"
		)
		for line in string.gmatch(src, "[^\n]+") do
			local code = string.gsub(line, "%-%-.*$", "") -- (comments may name PlayerGui)
			local bad = string.find(code, "[Tt]ag%.Parent%s*=.*PlayerGui")
				or (path == FILES[3] and string.find(code, "gui%.Parent%s*=.*PlayerGui"))
			truthy(not bad, "tag parented to PlayerGui: " .. line)
		end
	end)
end
