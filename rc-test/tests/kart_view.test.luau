--!strict
-- The crate reveal and the round's winner show the real kart (CarSkin.copyOf through KartView),
-- not the drawn toy car (auditor R5-4, R4-8). Lune can't build a ViewportFrame, so check the text.
local fs = require("@lune/fs")
local H = require("./harness")

local test, truthy = H.test, H.truthy

print("Kart view")

local function code(path: string): string
	-- (comments don't count)
	local out = {}
	for _, l in string.split(fs.readFile(path), "\n") do
		table.insert(out, (string.gsub(l, "%-%-.*$", "")))
	end
	return table.concat(out, "\n")
end

test("KartView builds from CarSkin.copyOf (the kart with its driver)", function()
	local kv = code("src/client/Ui/Screens/KartView.luau")
	truthy(string.find(kv, "copyOf(carId)", 1, true), "KartView doesn't use CarSkin.copyOf")
	truthy(string.find(kv, "ViewportFrame", 1, true), "KartView isn't 3D")
	truthy(string.find(kv, "Ambient", 1, true), "KartView has no light (a white outline)")
	truthy(string.find(code("src/client/CarSkin.luau"), "function CarSkin.copyOf", 1, true))
end)

test("the crate reveal puts the kart over its card", function()
	local flow = code("src/client/Ui/Screens/Flow.luau")
	local at = string.find(flow, "function Flow.reveal", 1, true)
	truthy(at, "no Flow.reveal")
	local nextFn = string.find(flow, "\nfunction ", (at :: number) + 1, true) or #flow
	local body = string.sub(flow, at :: number, nextFn)
	truthy(string.find(body, "KartView.over(", 1, true), "the reveal still shows the drawn car")
end)

test("the round's winner is the kart", function()
	truthy(string.find(code("src/client/Ui/Screens/Smash.luau"), "KartView.make(", 1, true))
end)
