--!strict
-- The back of the hall, behind the hero stage: a few loose workshop pieces at the sides. The back
-- wall itself is kept free for the leaderboards and the gumball machine. Look only; a missing
-- model is skipped.

local LobbyDecor = require(script.Parent.LobbyDecor)

local LobbyWorkArea = {}

local BACK = math.pi
local SOURCES = { "Decor", "More", "Garage", "Props" }

function LobbyWorkArea.build(folder: Folder, origin: Vector3)
	local group = Instance.new("Folder")
	group.Name = "WorkArea"
	group.Parent = folder

	local function put(name: string, x: number, z: number, yaw: number, y: number?, glow: number?)
		for _, source in SOURCES do
			if LobbyDecor.has(name, source) then
				local m = LobbyDecor.clone(name, group, glow, source)
				if m then
					m:PivotTo(
						CFrame.new(origin + Vector3.new(x, y or 0, z)) * CFrame.Angles(0, yaw, 0)
					)
				end
				return
			end
		end
	end

	-- The lifts, work plates, hazard lines and tool chest that stood along the back wall are gone:
	-- the leaderboards hang on that wall now (x -41 to 21) and the gumball machine fills the right
	-- corner (x 43 to 57). Only side pieces stay, clear of both.
	put("ToolCart", 28, -86, BACK)
	put("TireRack", -58, -88, BACK)
	put("OilDrum", 33, -88, 0)
	put("OilDrum", 36, -87, 0)
	put("PalletCrates", 25, -92, BACK)
	put("Workbench", -54, -80, 0)
end

return LobbyWorkArea
