--!strict
-- The league-up ceremony (League.ceremony): only a step up gets one, and each league adds layers.
local H = require("./harness")
local League = require("../src/shared/League")

local test, eq, truthy = H.test, H.eq, H.truthy

print("League up")

test("league up: no ceremony when staying, going down, or for Bronze", function()
	eq(League.ceremony(1, 1), nil)
	eq(League.ceremony(3, 2), nil)
	eq(League.ceremony(2, 2), nil)
	eq(League.ceremony(0, 1), nil)
end)

test("league up: Silver, Gold and Diamond each get their name, color and real pay", function()
	local s = League.ceremony(1, 2) :: League.Ceremony
	eq(s.name, "SILVER LEAGUE")
	eq(s.pay, "Races pay 1.5x coins!")
	eq(s.color, League.COLORS[2])
	local g = League.ceremony(2, 3) :: League.Ceremony
	eq(g.name, "GOLD LEAGUE")
	eq(g.pay, "Races pay 2.2x coins!")
	local d = League.ceremony(3, 4) :: League.Ceremony
	eq(d.name, "DIAMOND LEAGUE")
	eq(d.pay, "Races pay 3x coins!")
	truthy(d.top)
	eq(g.top, false)
end)

test("league up: a jump of two shows the higher league", function()
	eq((League.ceremony(1, 3) :: League.Ceremony).to, 3)
	eq((League.ceremony(1, 9) :: League.Ceremony).to, 4)
end)

test("league up: each step up adds layers and never takes one away", function()
	local s = League.ceremony(1, 2) :: League.Ceremony
	local g = League.ceremony(2, 3) :: League.Ceremony
	local d = League.ceremony(3, 4) :: League.Ceremony
	truthy(s.confetti < g.confetti and g.confetti < d.confetti)
	truthy(s.fireworks < g.fireworks and g.fireworks < d.fireworks)
	truthy(s.hold <= g.hold and g.hold <= d.hold)
	eq(s.flash, false)
	truthy(g.flash and d.flash)
	-- the shake is kept for the top league only
	eq(s.shake, false)
	eq(g.shake, false)
	truthy(d.shake)
	-- buttons come last but never keep a kid waiting long
	truthy(d.hold <= 1.5)
end)
