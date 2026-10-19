--!strict
-- The back of the hall, behind the hero stage: three lit work bays in front of the roller doors
-- (car lifts, tool carts, a workbench), a parts and tyre corner on each side, and floor paint that
-- shows the work zone. The lane to the stage and the walk to the garages stay clear. Look only;
-- a missing model is skipped.

local LobbyDecor = require(script.Parent.LobbyDecor)

local LobbyWorkArea = {}

local BACK = math.pi
local YELLOW = Color3.fromRGB(255, 205, 40)
local BLACK = Color3.fromRGB(30, 32, 40)
local PLATE = Color3.fromRGB(96, 102, 118)
local SOURCES = { "Decor", "More", "Garage", "Props" }

local function paint(
	parent: Instance,
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

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

	local function at(x: number, z: number, y: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	-- Work bays: a plate floor with a yellow frame and a hazard-striped front edge.
	local bays = {
		{ x = -36, lift = "TwoPostLift" },
		{ x = -12, lift = "FourPostLift" },
		{ x = 12, lift = "TwoPostLift" },
	}
	local W, D, Z = 17, 20, -82
	for _, b in bays do
		paint(group, "WorkPlate", Vector3.new(W, 0.05, D), at(b.x, Z, 0.045), PLATE)
		for _, e in { -1, 1 } do
			paint(
				group,
				"WorkFrame",
				Vector3.new(W, 0.06, 0.5),
				at(b.x, Z + e * D / 2, 0.06),
				YELLOW
			)
			paint(
				group,
				"WorkFrame",
				Vector3.new(0.5, 0.06, D),
				at(b.x + e * W / 2, Z, 0.06),
				YELLOW
			)
		end
		for k = 0, 7 do
			paint(
				group,
				"WorkHazard",
				Vector3.new(W / 8, 0.07, 1),
				at(b.x - W / 2 + (k + 0.5) * W / 8, Z + D / 2 + 1, 0.065),
				if k % 2 == 0 then YELLOW else BLACK
			)
		end
		put(b.lift, b.x, Z - 1, BACK)
		put("ShopLight", b.x, Z + 2, 0, 31, 28)
	end

	-- Tool carts and a chest between the bays.
	put("ToolCart", -24, -78, BACK)
	put("ToolChest", 0, -86, BACK)
	put("ToolCart", 24, -78, BACK)

	-- A tyre and drum corner on the right, a workbench on the left.
	put("TireRack", 52, -84, BACK)
	put("OilDrum", 30, -88, 0)
	put("OilDrum", 33, -87, 0)
	put("PalletCrates", 24, -91, BACK)
	put("Workbench", -54, -80, 0)

	-- A dashed yellow and black line separating the work zone from the stage.
	for k = 0, 10 do
		paint(
			group,
			"WorkDash",
			Vector3.new(2.4, 0.06, 0.9),
			at(-38 + k * 6, -68, 0.06),
			if k % 2 == 0 then YELLOW else BLACK
		)
	end
end

return LobbyWorkArea
