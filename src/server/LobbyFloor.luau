--!strict
-- Extra floor and pad looks for the lobby: a soft tile pattern down the hall, lit corner posts and
-- a glowing rim on every match pad, and a glowing ring round the hero stage. Look only (no collision).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyFloor = {}

local TILE = 10
local TILE_A = Color3.fromRGB(78, 83, 98)
local TILE_B = Color3.fromRGB(64, 68, 82)
local CYAN = Color3.fromRGB(60, 220, 255)
local YELLOW = Color3.fromRGB(255, 205, 40)

local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	neon: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function LobbyFloor.build(folder: Folder, origin: Vector3)
	local L = LobbyLayout
	local group = Instance.new("Folder")
	group.Name = "FloorLook"
	group.Parent = folder
	local halfL = L.room.halfL
	local halfW = L.room.halfW

	-- Soft checker tiles over the walking area (under the painted marks, which sit a hair higher).
	local cols = math.floor(halfW * 2 / TILE)
	local rows = math.floor(halfL * 2 / TILE)
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if (r + c) % 2 == 0 then
				local x = (c + 0.5) * TILE - halfW
				local z = (r + 0.5) * TILE - halfL
				deco(
					group,
					"FloorTile",
					Vector3.new(TILE - 0.3, 0.03, TILE - 0.3),
					CFrame.new(origin + Vector3.new(x, 0.025, z)),
					if (r // 2 + c // 2) % 2 == 0 then TILE_A else TILE_B,
					false
				)
			end
		end
	end

	-- Match pads: a glowing rim and four lit corner posts.
	local size = L.padSize
	for _, pp in L.pads do
		local c = origin + Vector3.new(pp.x, 0, pp.z)
		for _, e in { -1, 1 } do
			deco(
				group,
				"PadGlow",
				Vector3.new(size - 2.4, 0.12, 0.25),
				CFrame.new(c + Vector3.new(0, 0.55, e * (size / 2 - 1.2))),
				CYAN,
				true
			)
			deco(
				group,
				"PadGlow",
				Vector3.new(0.25, 0.12, size - 2.4),
				CFrame.new(c + Vector3.new(e * (size / 2 - 1.2), 0.55, 0)),
				CYAN,
				true
			)
		end
		for _, ex in { -1, 1 } do
			for _, ez in { -1, 1 } do
				local at = c + Vector3.new(ex * (size / 2 - 0.6), 0, ez * (size / 2 - 0.6))
				deco(
					group,
					"PadPost",
					Vector3.new(0.9, 1.6, 0.9),
					CFrame.new(at + Vector3.new(0, 0.8, 0)),
					Color3.fromRGB(40, 44, 58),
					false
				)
				deco(
					group,
					"PadPostLamp",
					Vector3.new(0.6, 0.35, 0.6),
					CFrame.new(at + Vector3.new(0, 1.7, 0)),
					YELLOW,
					true
				)
			end
		end
	end

	-- Hero stage: two glowing rings on the floor round the showcase.
	local sc = L.showcase
	for i, r in { sc.radius + 4, sc.radius + 6 } do
		local ring = deco(
			group,
			"StageRing",
			Vector3.new(0.06, r * 2, r * 2),
			CFrame.new(origin + Vector3.new(sc.x, 0.07 + i * 0.01, sc.z))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(86, 112, 140), -- muted steel-blue, matte (the yellow neon ring was too loud)
			false
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.4
	end
end

return LobbyFloor
