--!strict
-- UI kit v41 in the world (shared/KitWorld): the "-N" hit number's pop, rise and fade, its pool,
-- the low-health edge, and the weapon icon's picture slots; plus text checks on the clients.
local fs = require("@lune/fs")
local H = require("./harness")
local KitWorld = require("../src/shared/KitWorld")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Kit world")

local function near(a: number, b: number, msg: string)
	truthy(math.abs(a - b) < 1e-6, msg .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end

test(
	"kit world: the hit number grows 0.4 -> 1.2 -> 1 in 0.26 s, rises 44 px, fades at the end",
	function()
		local s0, r0, see0 = KitWorld.number(0)
		near(s0, 0.4, "starts small")
		eq(r0, 0)
		eq(see0, 0, "solid")
		near((KitWorld.number(KitWorld.POP_GROW)), 1.2, "the peak")
		near(KitWorld.POP_GROW + KitWorld.POP_SETTLE, 0.26, "the pop takes 0.26 s")
		near((KitWorld.number(0.26)), 1, "settled")
		near((KitWorld.number(0.6)), 1, "stays settled")
		local _, rEnd, seeEnd = KitWorld.number(KitWorld.SECONDS)
		near(rEnd, 44, "rose 44 px")
		near(seeEnd, 1, "gone at the end")
		local _, _, seeMid = KitWorld.number(KitWorld.SECONDS - KitWorld.FADE)
		eq(seeMid, 0, "solid until the last 0.3 s")
		local _, _, seeLate = KitWorld.number(KitWorld.SECONDS - KitWorld.FADE / 2)
		near(seeLate, 0.5, "half faded mid-fade")
		truthy(KitWorld.NUMBER_PX >= 15, "nothing under 15 px")
		truthy(KitWorld.NUMBER_SIDE >= 0.6, "beside the kart, off the name tag")
	end
)

test("kit world: reduced motion: no grow, no rise, it only fades", function()
	local s, r, see = KitWorld.number(0.1, true)
	eq(s, 1)
	eq(r, 0)
	eq(see, 0)
	local _, _, seeEnd = KitWorld.number(KitWorld.SECONDS, true)
	near(seeEnd, 1, "still fades")
end)

test("kit world: the number pool holds 12 and reuses the oldest", function()
	eq(KitWorld.POOL_CAP, 12)
	eq(KitWorld.pick({}, 0), 1, "the first")
	eq(KitWorld.pick({ [1] = 5 }, 1), 2, "room: a new slot")
	eq(KitWorld.pick({ [1] = 5, [2] = nil }, 2), 2, "a free one first")
	local full: { [number]: number? } = {}
	for i = 1, 12 do
		full[i] = 100 + i
	end
	full[7] = 1
	eq(KitWorld.pick(full, 12), 7, "full: the oldest")
end)

test("kit world: the low-health edge: in a match, alive, at 25 and under; a slow breath", function()
	eq(KitWorld.low(true, 25), true)
	eq(KitWorld.low(true, 10), true)
	eq(KitWorld.low(true, 26), false)
	eq(KitWorld.low(true, 0), false, "smashed: not low, gone")
	eq(KitWorld.low(false, 10), false, "lobby: never")
	eq(KitWorld.low(nil, 10), false)
	eq(KitWorld.low(true, nil), false)
	eq(KitWorld.PULSE, 1.8)
	near(KitWorld.breath(0), KitWorld.EDGE_LOW, "starts at the faint end")
	near(KitWorld.breath(KitWorld.PULSE / 2), 1, "strongest mid-breath")
	near(KitWorld.breath(KitWorld.PULSE), KitWorld.EDGE_LOW, "one breath in 1.8 s")
	eq(KitWorld.breath(0.3, true), KitWorld.breath(1.2, true), "reduced motion: steady")
	truthy(KitWorld.EDGE_DEPTH <= 0.2, "an edge, not the whole screen")
end)

test("kit world: weapon icon picture slots are empty or real ids only", function()
	for key, id in KitWorld.WEAPON_IMAGES do
		truthy(
			id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil,
			"a real id or empty: " .. key
		)
	end
	eq(
		KitWorld.weaponImage("rocket"),
		if KitWorld.WEAPON_IMAGES.rocket == "" then nil else KitWorld.WEAPON_IMAGES.rocket
	)
	eq(KitWorld.weaponImage("nope"), nil)
	for _, key in { "rocket", "nuke", "gun", "mine", "freeze", "power", "mystery" } do
		truthy(KitWorld.WEAPON_IMAGES[key] ~= nil, "a slot for " .. key)
	end
end)

test("kit world: client text checks", function()
	local hits = fs.readFile("src/client/SmashHits.client.luau")
	truthy(string.find(hits, "KitWorld.pick(busy, #pool)", 1, true) ~= nil, "numbers are pooled")
	truthy(string.find(hits, "KitWorld.number(", 1, true) ~= nil, "the kit's pop and rise")
	truthy(string.find(hits, "Base.reduced()", 1, true) ~= nil, "reduced motion")
	truthy(string.find(hits, "bb.AlwaysOnTop = true", 1, true) == nil, "not AlwaysOnTop")
	truthy(string.find(hits, "bb.AlwaysOnTop = false", 1, true) ~= nil, "draws on carter's PC")
	truthy(string.find(hits, "KitWorld.NUMBER_SIDE", 1, true) ~= nil, "off the name tag")
	local edge = fs.readFile("src/client/LowHealthEdge.client.luau")
	truthy(string.find(edge, "KitWorld.low(", 1, true) ~= nil, "low health only")
	truthy(
		string.find(edge, "KitWorld.breath(since, Base.reduced())", 1, true) ~= nil,
		"breath, reduced"
	)
	truthy(string.find(edge, "Base.ORDER.hud - 2", 1, true) ~= nil, "under the HUD")
	truthy(string.find(edge, "FireServer", 1, true) == nil, "looks only")
	local icon = fs.readFile("src/client/KartWeaponIcon.client.luau")
	truthy(string.find(icon, "KitWorld.weaponImage(key)", 1, true) ~= nil, "picture slot first")
	truthy(string.find(icon, "Icons.make(g, key", 1, true) ~= nil, "the drawn stand-in")
	truthy(string.find(icon, "g.AlwaysOnTop = false", 1, true) ~= nil, "not AlwaysOnTop")
	for _, src in { hits, edge, icon } do
		truthy(string.find(src, "rbxassetid://%d") == nil, "no made-up asset ids")
	end
end)

test(
	"kit world: Studio 10-29 fixes: flash on the kart you see, edge free of the kart skin",
	function()
		local hits = fs.readFile("src/client/SmashHits.client.luau")
		truthy(
			string.find(hits, 'workspace:FindFirstChild("OtherCars")', 1, true) ~= nil,
			"the drawn kart"
		)
		local edge = fs.readFile("src/client/LowHealthEdge.client.luau")
		truthy(
			string.find(edge, 'gui:SetAttribute("NoKart", true)', 1, true) ~= nil,
			"no kart-skin rims"
		)
		truthy(string.find(edge, 'f:SetAttribute("NoKart", true)', 1, true) ~= nil)
		truthy(string.find(edge, "Enum.ScreenInsets.None", 1, true) ~= nil, "the whole screen")
		-- exactly 4 soft sides and 1 thin rim, no tiles (Studio 10-29: lines like a grid)
		local _, sides = string.gsub(edge, '\nlocal %w+ = side%("', "")
		eq(sides, 4, "one soft side per edge")
		local _, frames = string.gsub(edge, 'Instance%.new%("Frame"%)', "")
		eq(frames, 2, "the side maker and the rim: no other frames")
		truthy(string.find(edge, "ImageLabel", 1, true) == nil, "no pictures, no tiles")
	end
)
