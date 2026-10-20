--!strict
-- One open-front garage building of the Car Battle Lobby (the shell only: floor, walls, roof, pillars,
-- the roller door rolled up above the opening, steady orange light strips). The workshop, the
-- customize garage and the shop each call this, then put their own things inside.
-- Looks only except the invisible mouth blocker that Lobby.luau builds from LobbyLayout.blockers.
--
-- Building-local coordinates: u = across the mouth (right is +u), v = toward the mouth (the open
-- side is +v, the back wall is -v), y = up from the plaza. `at(u, y, v)` turns them into a world CFrame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyGarageShell = {}

export type Rect = LobbyLayout.Rect & { h: number }

export type Shell = {
	group: Folder,
	at: (u: number, y: number, v: number) -> CFrame,
	width: number,
	depth: number,
	height: number,
	openingW: number, -- clear width of the mouth
	openingH: number, -- clear height of the mouth
	accent: Color3, -- the building's main color (orange or blue)
	accent2: Color3, -- the other one
}

local rgb, part, group = MapParts.rgb, MapParts.part, MapParts.group
local C = LobbyLayout.colors

local WALL = 1.6
local PILLAR = 4
local HEADER = 6 -- the beam above the mouth

-- `accent` is "orange" or "blue".
function LobbyGarageShell.build(
	parent: Instance,
	origin: Vector3,
	b: Rect,
	accent: string,
	name: string
): Shell
	local grp = group(parent, name)
	local main = if accent == "orange" then rgb(C.orangeWall) else rgb(C.blue)
	local other = if accent == "orange" then rgb(C.blue) else rgb(C.orangeWall)
	local base = CFrame.new(origin + Vector3.new(b.x, 0, b.z))
		* CFrame.Angles(0, math.rad(b.yawDeg), 0)
	local function at(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, v)
	end
	local w, d, h = b.w, b.d, b.h
	local openW = w - PILLAR * 2
	local openH = h - HEADER
	local function box(
		pname: string,
		size: Vector3,
		u: number,
		y: number,
		v: number,
		color: Color3,
		material: Enum.Material?
	): Part
		return part(grp, pname, size, at(u, y, v), color, false, nil, material)
	end

	-- floor of the garage: a slightly darker slab, a bit proud of the plaza
	box("Floor", Vector3.new(w, 0.4, d), 0, 0.2, 0, rgb(C.asphaltDark), Enum.Material.Concrete)
	-- back wall + side walls (blue/orange panels with a light band)
	box("BackWall", Vector3.new(w, h, WALL), 0, h / 2, -d / 2 + WALL / 2, main)
	box(
		"BackBand",
		Vector3.new(w - 2, 2.4, 0.3),
		0,
		h * 0.62,
		-d / 2 + WALL + 0.1,
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	for _, s in { -1, 1 } do
		box("SideWall", Vector3.new(WALL, h, d), s * (w / 2 - WALL / 2), h / 2, 0, main)
		box(
			"SideStripe",
			Vector3.new(WALL + 0.2, 2.2, d - 4),
			s * (w / 2 - WALL / 2),
			h * 0.3,
			0,
			other
		)
		-- the front pillars frame the mouth
		box(
			"Pillar",
			Vector3.new(PILLAR, h, WALL * 2),
			s * (w / 2 - PILLAR / 2),
			h / 2,
			d / 2 - WALL,
			other
		)
		box(
			"PillarCap",
			Vector3.new(PILLAR + 0.6, 1.2, WALL * 2 + 0.6),
			s * (w / 2 - PILLAR / 2),
			h + 0.6,
			d / 2 - WALL,
			main
		)
	end
	-- roof slab with a chunky rim
	box(
		"Roof",
		Vector3.new(w + 1.2, 1.4, d + 1.2),
		0,
		h + 0.7,
		0,
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	box("RoofRimFront", Vector3.new(w + 1.6, 1.6, 1.6), 0, h + 1.2, d / 2 + 0.4, main)
	for _, s in { -1, 1 } do
		box("RoofRimSide", Vector3.new(1.6, 1.6, d + 1.6), s * (w / 2 + 0.4), h + 1.2, 0, main)
	end
	-- header beam over the mouth, with the rolled-up door: three slats and a drum
	box("Header", Vector3.new(openW, HEADER, WALL * 2), 0, h - HEADER / 2, d / 2 - WALL, main)
	for i = 1, 3 do
		box(
			"DoorSlat",
			Vector3.new(openW - 2, 0.9, 0.5),
			0,
			openH + 0.8 + (i - 1) * 1.15,
			d / 2 - WALL * 2 - 0.1,
			rgb(C.marking),
			Enum.Material.Metal
		)
	end
	local drum = part(
		grp,
		"DoorDrum",
		Vector3.new(openW - 1, 1.6, 1.6),
		at(0, openH + 0.2, d / 2 - WALL * 2 - 0.5),
		rgb(C.metalDark),
		false,
		nil,
		Enum.Material.Metal
	)
	drum.Shape = Enum.PartType.Cylinder
	-- steady orange light strips: under the header (looks into the garage) and up the pillars
	local strip = box(
		"MouthLight",
		Vector3.new(openW - 2, 0.5, 0.5),
		0,
		openH - 0.4,
		d / 2 - WALL * 2,
		rgb(C.light),
		Enum.Material.Neon
	)
	strip.CastShadow = false
	for _, s in { -1, 1 } do
		local pl = box(
			"PillarLight",
			Vector3.new(0.5, h * 0.5, 0.5),
			s * (openW / 2 + 0.3),
			h * 0.4,
			d / 2 - WALL * 2,
			rgb(C.light),
			Enum.Material.Neon
		)
		pl.CastShadow = false
	end
	-- interior lights (few: phones)
	for k, u in { -w / 4, w / 4 } do
		local lamp = box(
			"Lamp" .. k,
			Vector3.new(4, 0.4, 4),
			u,
			h - 0.4,
			-2,
			rgb(C.marking),
			Enum.Material.SmoothPlastic
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 236, 205)
		light.Brightness = 0.45
		light.Range = math.max(w, d) * 0.8
		light.Shadows = false
		light.Parent = lamp
	end

	return {
		group = grp,
		at = at,
		width = w,
		depth = d,
		height = h,
		openingW = openW,
		openingH = openH,
		accent = main,
		accent2 = other,
	}
end

return LobbyGarageShell
