--!strict
-- CarGlow: how each kind of car glows.

local H = require("./harness")
local Cat = require("../src/shared/CarCatalog")
local CarGlow = require("../src/shared/CarGlow")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Car glow")

test("common cars don't glow; each kind up glows brighter; only legends pulse", function()
	eq(CarGlow.look("common"), nil)
	eq(CarGlow.look(nil), nil)
	eq(CarGlow.look("space"), nil)
	local last = 0
	for i = 2, #Cat.RARITY_ORDER do
		local look = CarGlow.look(Cat.RARITY_ORDER[i])
		truthy(look ~= nil, Cat.RARITY_ORDER[i] .. " glows")
		if look then
			truthy(look.brightness > last, "brighter than the kind below")
			last = look.brightness
			eq(look.pulse, Cat.RARITY_ORDER[i] == "legend")
		end
	end
end)
