--!strict
-- Flame and wheel-trail looks (shared/CarFxStyles, client/ExhaustFx, TrailFx, FxEmitter): carter
-- picked Twin Jets (flames) and Scrap Sparks (trails) on 10-29; the rest are options. Checks the
-- numbers stay phone-light, every style is complete, unknown picks fall back to the starter, and
-- the car skin wires both in.
local fs = require("@lune/fs")
local H = require("./harness")
local S = require("../src/shared/CarFxStyles")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car flames + wheel trails")

local function checkEmit(label: string, e: S.Emit)
	truthy(#e.colors >= 2, label .. ": two colours or more")
	for _, c in e.colors do
		eq(#c, 3, label .. ": colour is r, g, b")
		for i = 1, 3 do
			truthy(c[i] >= 0 and c[i] <= 255, label .. ": colour 0-255")
		end
	end
	truthy(e.life[1] > 0 and e.life[1] <= e.life[2] and e.life[2] <= 1.5, label .. ": life")
	truthy(e.speed[1] >= 0 and e.speed[1] <= e.speed[2], label .. ": speed")
	truthy(e.size[1] > 0 and e.size[2] > 0 and e.size[1] <= 4 and e.size[2] <= 4, label .. ": size")
	truthy(e.glow >= 0 and e.glow <= 1, label .. ": glow")
	truthy(e.fade[1] >= 0 and e.fade[2] <= 1, label .. ": fade")
	truthy(e.spread >= 0 and e.spread <= 90, label .. ": spread")
	truthy(e.rate >= 0, label .. ": rate")
end

test("car fx: the three flames are all there and complete", function()
	for _, id in { "twin_jets", "dragon_breath", "afterburner" } do
		local st = S.EXHAUST[id]
		truthy(st ~= nil, "missing " .. id)
		eq(st.id, id, "id matches its key")
		checkEmit(id .. " jet", st.jet)
		checkEmit(id .. " pop", st.pop)
		for i, e in st.extras do
			checkEmit(`{id} extra {i}`, e)
		end
		truthy(st.idle >= 0 and st.idle < 1, id .. ": idle")
		truthy(st.lightPower > 0 and st.lightPower <= 8, id .. ": glow power")
	end
end)

test("car fx: phone-light (particles a second per emitter stay small)", function()
	for id, st in S.EXHAUST do
		truthy(st.jet.rate <= 150, id .. " jet rate")
		for _, e in st.extras do
			truthy(e.rate <= 60, id .. " extra rate")
		end
	end
	for id, t in S.TRAIL do
		checkEmit(id .. " sparks", t.sparks)
		checkEmit(id .. " dust", t.dust)
		-- the mobile guide: about 100 particles a second for one emitter
		truthy(t.sparks.rate * t.boostMul <= 100, id .. " sparks at boost")
		truthy(t.dust.rate * t.boostMul <= 100, id .. " dust at boost")
		truthy(t.minSpeed >= 0 and t.minSpeed < t.fullSpeed, id .. " speed window")
	end
end)

test("car fx: carter's picks are the starters, unknown picks fall back to them", function()
	eq(S.DEFAULT_EXHAUST, "twin_jets")
	eq(S.DEFAULT_TRAIL, "scrap_sparks")
	eq(S.exhaust(nil).id, "twin_jets")
	eq(S.exhaust("nope").id, "twin_jets")
	eq(S.exhaust("afterburner").id, "afterburner")
	eq(S.trail(nil).id, "scrap_sparks")
	eq(S.trail("nope").id, "scrap_sparks")
	-- Twin Jets is what shipped in the first exhaust piece: same flame
	eq(S.EXHAUST.twin_jets.jet.rate, 150)
	eq(S.EXHAUST.twin_jets.idle, 0)
end)

test("car fx: the afterburner bangs when you let go, the others don't", function()
	truthy(S.EXHAUST.afterburner.bang > 0)
	eq(S.EXHAUST.twin_jets.bang, 0)
	truthy(S.EXHAUST.dragon_breath.idle > 0, "dragon breath keeps smoking at idle")
end)

test("car fx: the car skin runs both, with the player's picks", function()
	local skin = fs.readFile("src/client/CarSkin.luau")
	truthy(skin:find("ExhaustFx.new()", 1, true), "flames")
	truthy(skin:find("TrailFx.new()", 1, true), "trails")
	truthy(skin:find("CarFxStyles.ATTR_EXHAUST", 1, true), "reads the flame pick")
	truthy(skin:find("CarFxStyles.ATTR_TRAIL", 1, true), "reads the trail pick")
	truthy(skin:find("LocalPlayer:GetAttribute", 1, true), "from the player's attributes")
	local trail = fs.readFile("src/client/TrailFx.luau")
	truthy(trail:find("telemetry.wheels", 1, true), "sparks come off the real tyre contact points")
	truthy(trail:find("info.rear", 1, true), "rear tyres")
	truthy(trail:find("Enum.Material.Water", 1, true), "no sparks on water")
	local fx = fs.readFile("src/client/ExhaustFx.luau")
	truthy(fx:find("FxEmitter.make", 1, true), "emitters come from the style")
	truthy(fx:find("destroy(r)", 1, true), "a new style replaces the old emitters")
end)
