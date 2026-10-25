--!strict
-- Phone speed: the lobby's part count stays under a budget. Counts what each lobby builder makes
-- from its shared piece list (the plots' own tracks are built in Roblox only, so not here).
-- Hills, trees and hill props are counted at their most: a block stand-in hill is 3 parts, a
-- block tree 3, a flower patch 5 (a mesh is fewer).
local H = require("./harness")
local LobbyDecor = require("../src/shared/LobbyDecor")
local LobbyHills = require("../src/shared/LobbyHills")
local LobbyLake = require("../src/shared/LobbyLake")
local LobbyLayout = require("../src/shared/LobbyLayout")
local LobbyWater = require("../src/shared/LobbyWater")
local PlotDecor = require("../src/shared/PlotDecor")
local PlotStands = require("../src/shared/PlotStands")
local SpawnLobby = require("../src/shared/SpawnLobby")

local test, truthy = H.test, H.truthy

print("Lobby part budget")

-- each builder's cap (about 15% over today's count) and the whole lobby's
local BUDGET = {
	spawn = 870, -- 757 today
	decor = 380, -- 331 (bunting, planters, flags, road paint, RC corners)
	water = 250, -- 218 (docks, beach)
	lake = 320, -- 278 (boats, shore)
	plotDecor = 520, -- 452 (8 plots' arches and fences)
	stands = 3800, -- 3360: all 8 plots showing every car there is (420 each; LobbyPerf takes their
	-- shadows and collisions off)
	hills = 2500, -- 2183 at most
}
local TOTAL = 8700 -- 7579 at most today

local function counts(): { [string]: number }
	local plotDecor = 0
	for _, s in LobbyLayout.slots() do
		plotDecor += #PlotDecor.parts(s.id)
	end
	local all = {}
	for _, c in PlotStands.ALL do
		table.insert(all, c.id)
	end
	local most = PlotStands.parse(table.concat(all, ","))
	local hills, trees, props = LobbyHills.layout()
	return {
		spawn = #SpawnLobby.allParts(),
		decor = #LobbyDecor.parts(),
		water = #LobbyWater.pieces(),
		lake = #LobbyLake.pieces(),
		plotDecor = plotDecor,
		stands = #PlotStands.pieces(most) * #LobbyLayout.slots(),
		hills = #hills * 3 + #trees * 3 + #props * 5,
	}
end

test("every lobby builder stays under its part budget", function()
	local c = counts()
	for name, cap in BUDGET do
		truthy(c[name] <= cap, `{name}: {c[name]} parts, budget {cap}`)
	end
end)

test("the whole lobby stays under its part budget", function()
	local sum = 0
	for _, n in counts() do
		sum += n
	end
	truthy(sum <= TOTAL, `lobby: {sum} parts, budget {TOTAL}`)
end)
