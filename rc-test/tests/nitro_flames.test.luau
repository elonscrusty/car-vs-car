--!strict
-- Nitro Flames (carter's pick 2 of 3 speed boost looks, 10-30): a flame look in CarFxStyles with
-- fire licks off the body and a pickup badge. Checks it is complete, phone-light, picked by name,
-- and that ExhaustFx builds the licks. The starter flame stays Twin Jets.
local fs = require("@lune/fs")
local H = require("./harness")
local S = require("../src/shared/CarFxStyles")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Nitro Flames")

test("nitro flames: the style is there, complete and phone-light", function()
	local st = S.EXHAUST.nitro_flames
	truthy(st ~= nil, "missing nitro_flames")
	eq(st.id, "nitro_flames", "id matches its key")
	eq(S.exhaust("nitro_flames").name, "Nitro Flames")
	truthy(st.jet.rate <= 150, "jet rate")
	truthy(#st.extras == 2, "orange shell + embers")
	for _, e in st.extras do
		truthy(e.rate <= 60, "extra rate")
	end
	eq(st.idle, 0, "nothing burns with no boost")
	truthy(st.lightPower > 0 and st.lightPower <= 8, "glow power")
	local licks = st.licks
	truthy(licks ~= nil and #licks >= 1, "fire licks")
	if licks then
		for _, e in licks do
			-- six spots, each its own emitter: keep each light
			truthy(e.rate <= 30, "lick rate")
			truthy(#e.colors >= 2, "lick colours")
			truthy(e.life[2] <= 1.5, "lick life")
		end
	end
end)

test("nitro flames: six lick spots sit on the car body", function()
	eq(#S.LICK_SPOTS, 6)
	local mirrored = 0
	for _, p in S.LICK_SPOTS do
		eq(#p, 3, "a spot is x, y, z")
		truthy(math.abs(p[1]) <= 0.6, "within the width")
		truthy(p[2] >= -0.5 and p[2] <= 0.5, "within the height")
		truthy(math.abs(p[3]) <= 0.5, "within the length")
		if p[1] < 0 then
			mirrored += 1
		end
	end
	eq(mirrored, 3, "three on each side")
end)

test("nitro flames: the pickup badge and the starter", function()
	local icon = S.EXHAUST.nitro_flames.icon
	truthy(icon ~= nil, "has an icon")
	if icon then
		eq(icon.glyph, "flame")
		eq(#icon.rim, 3)
		eq(#icon.fill, 3)
	end
	eq(S.DEFAULT_EXHAUST, "twin_jets", "the starter flame is unchanged")
	truthy(S.EXHAUST.twin_jets.licks == nil, "Twin Jets has no licks")
end)

test("nitro flames: ExhaustFx builds the licks and only burns them while boosting", function()
	local fx = fs.readFile("src/client/ExhaustFx.luau")
	truthy(fx:find("style.licks", 1, true), "reads the style's licks")
	truthy(fx:find("CarFxStyles.LICK_SPOTS", 1, true), "places them from the shared spots")
	truthy(fx:find("idle = 0", 1, true), "licks have no idle burn")
	truthy(fx:find("nose * p[3]", 1, true), "the nose side is respected")
end)
