--!strict
-- Every game action has a sound: a Studio-checked file or the ping, never silence, never a made-up id.
local fs = require("@lune/fs")
local H = require("./harness")
local C = require("../src/shared/SoundCues")
local L = require("../src/shared/SoundLevels")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Sound cues")

test(
	"every action the game must sound has a cue with notes and a volume under the start beeps",
	function()
		for _, name in C.MUST do
			local cue = C.get(name)
			truthy(cue ~= nil, `{name} has no sound`)
			local c = cue :: C.Cue
			truthy(#c.notes >= 1, `{name} has no notes`)
			truthy(c.volume > 0 and c.volume < L.START_BEEP, `{name} volume {c.volume}`)
			truthy(c.gap >= 0)
		end
	end
)

test("every real id is a Studio-checked Creator Store id", function()
	for name, cue in C.ACTIONS do
		local id = cue.id
		if id then
			truthy(string.match(id, "^rbxassetid://%d+$") ~= nil, `{name}: {id}`)
			truthy(C.CHECKED[id] ~= nil, `{name}: {id} was not checked in Studio`)
			eq(C.fileFor(cue), id)
		else
			eq(C.fileFor(cue), nil)
		end
	end
	for id, store in C.CHECKED do
		truthy(string.match(id, "^rbxassetid://%d+$") ~= nil and #store > 0, id)
	end
end)

test("an unchecked id falls back to the ping", function()
	eq(C.fileFor({ id = "rbxassetid://1", notes = { 1 }, gap = 0, volume = 0.3 }), nil)
end)

test("ping notes cut by count, never empty", function()
	local reveal = C.get("reveal") :: C.Cue
	eq(#C.notesFor(reveal, 3), 3)
	eq(#C.notesFor(reveal, 0), 1)
	eq(#C.notesFor(reveal, 99), #reveal.notes)
	eq(#C.notesFor(reveal), #reveal.notes)
end)

test("Sfx plays only cues that exist, and every must-sound action is played", function()
	local src = fs.readFile("src/client/Sfx.luau")
	local played: { [string]: boolean } = {}
	for name in string.gmatch(src, 'play%(%s*"(%w+)"') do
		truthy(C.get(name) ~= nil, `Sfx plays "{name}" with no cue`)
		played[name] = true
	end
	for name in string.gmatch(src, 'play,%s*"(%w+)"') do
		truthy(C.get(name) ~= nil, `Sfx plays "{name}" with no cue`)
		played[name] = true
	end
	for a, b in string.gmatch(src, 'play%(if [^"]*"(%w+)" else "(%w+)"%)') do
		played[a], played[b] = true, true
	end
	for _, name in C.MUST do
		truthy(played[name], `Sfx never plays "{name}"`)
	end
end)

test("the live screens call the coin, buy and unlock sounds", function()
	local screens = fs.readFile("src/client/CvcScreens.client.luau")
	truthy(string.find(screens, "Sfx.coin", 1, true) ~= nil, "no coin sound")
	truthy(string.find(screens, "Sfx.buy()", 1, true) ~= nil, "no buy sound")
	truthy(string.find(screens, "Sfx.unlock()", 1, true) ~= nil, "no station unlock sound")
	truthy(string.find(screens, "Sfx.crate(", 1, true) ~= nil, "no crate reveal sound")
	truthy(string.find(screens, "Sfx.fireworks()", 1, true) ~= nil, "no league-up sound")
	truthy(
		string.find(fs.readFile("src/client/Main.client.luau"), "Sfx.count(", 1, true) ~= nil,
		"no 3-2-1-GO"
	)
end)

test("Smash arena sounds: every new action has a Sfx call", function()
	local src = fs.readFile("src/client/Sfx.luau")
	for _, fn in
		{
			"pickup",
			"rocket",
			"boom",
			"gun",
			"mine",
			"freezeShot",
			"freeze",
			"shatter",
			"hit",
			"bump",
			"smash",
			"respawn",
			"shield",
			"matchStart",
			"matchEnd",
		}
	do
		truthy(string.find(src, `function Sfx.{fn}(`, 1, true) ~= nil, `no Sfx.{fn}`)
	end
end)

test(
	"Smash arena sounds sit under the start beeps; gun shots are quiet (bursts repeat them)",
	function()
		truthy(L.GUN < L.HIT and L.HIT < L.BOOM and L.BOOM < L.SMASH)
		truthy(L.SMASH < L.START_BEEP and L.MATCH < L.START_BEEP)
		truthy(L.GUN_GAP > 0 and L.HIT_GAP > 0)
	end
)

test("GUNMINE's names exist (mineDrop, mineBoom)", function()
	local src = fs.readFile("src/client/Sfx.luau")
	truthy(string.find(src, "Sfx.mineDrop = Sfx.mine", 1, true) ~= nil)
	truthy(string.find(src, "Sfx.mineBoom = Sfx.boom", 1, true) ~= nil)
end)
