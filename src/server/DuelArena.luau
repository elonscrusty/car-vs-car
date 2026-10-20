--!strict
-- Builds the 1v1 battle map "Duel Car Arena" from `DuelArenaLayout` (all numbers live there): a dark
-- asphalt floor with rounded corners, painted orange and blue wall modules with tire stacks and
-- glowing lights, four striped cover blocks, a red and a blue garage behind the north wall, and
-- trees and rocks on the grass around it. Only the floor, walls and blocks collide; everything
-- else is looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.DuelArenaLayout)
local MapParts = require(script.Parent.MapParts)

local DuelArena = {}

local rgb, part, can, ball, group =
	MapParts.rgb, MapParts.part, MapParts.can, MapParts.ball, MapParts.group

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- A stack of tires standing at `pos` (bottom of the stack): thin gaps between the tires, each one a
-- little off the one below, and a pale hole on the top one, so it reads as tires and not as a block.
local function tires(parent: Instance, pos: Vector3, scale: number)
	local t = Layout.tire
	local step = (t.height + 0.3) * scale
	for k = 0, t.stack - 1 do
		local off =
			Vector3.new((k % 2 - 0.5) * 0.7 * scale, k * step, (1 - k % 2 * 2) * 0.25 * scale)
		can(
			parent,
			"Tire",
			t.diameter * scale,
			t.height * scale,
			pos + off,
			rgb(Layout.colors.tire),
			false,
			nil,
			Enum.Material.Rubber
		)
		if k == t.stack - 1 then
			can(
				parent,
				"TireRim",
				t.diameter * 0.55 * scale,
				0.3 * scale,
				pos + off + Vector3.new(0, t.height * scale - 0.1, 0),
				rgb(Layout.colors.rim),
				false,
				nil,
				Enum.Material.Metal
			)
		end
	end
end

-- Walls and cover throw a car back: their bounce wins over the car's (weight 100), so a hit is a
-- visible rebound and not a dead stop. No damage comes from it.
local function bouncy(p: Part): Part
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, Layout.wallBounce, 1, 100)
	return p
end

local function floor(folder: Folder, origin: Vector3, solids: { Instance })
	local c = Layout.colors
	local hx, hz, r = Layout.halfX, Layout.halfZ, Layout.corner
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local asphalt = rgb(c.asphalt)
	part(
		folder,
		"Floor",
		Vector3.new(hx * 2, 2, (hz - r) * 2),
		at(0, -1, 0),
		asphalt,
		true,
		solids,
		Enum.Material.Asphalt
	)
	part(
		folder,
		"FloorX",
		Vector3.new((hx - r) * 2, 2, hz * 2),
		at(0, -1, 0),
		asphalt,
		true,
		solids,
		Enum.Material.Asphalt
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			can(
				folder,
				"FloorCorner",
				r * 2,
				2,
				origin + Vector3.new(sx * (hx - r), -2, sz * (hz - r)),
				asphalt,
				true,
				solids,
				Enum.Material.Asphalt
			)
		end
	end
	-- the ground around it, a touch lower than the floor
	part(
		folder,
		"Grass",
		Vector3.new(Layout.totalX + 60, 2, Layout.totalZ + 60),
		at(0, -1.7, 0),
		rgb(c.grass),
		true,
		solids,
		Enum.Material.Grass
	)
end

local function markings(folder: Folder, origin: Vector3)
	local c = Layout.colors
	local marks = group(folder, "FloorMarks")
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	for _, d in Layout.dashes() do
		part(
			marks,
			"Dash",
			Vector3.new(d.length, 0.1, 0.9),
			at(d.x, 0.06, d.z) * yaw(d.yawDeg),
			rgb(c.marking),
			false
		)
	end
	for _, ch in Layout.chevrons() do
		local color = rgb(if ch.team == "orange" then c.orange else c.blue)
		for k = 0, 1 do
			-- two arrows ">" one behind the other, each made of two bars
			for _, side in { -1, 1 } do
				local base = at(ch.x, 0.07, ch.z) * yaw(ch.yawDeg) * CFrame.new(k * 7 - 3.5, 0, 0)
				part(
					marks,
					"Chevron",
					Vector3.new(8, 0.1, 2.4),
					base * CFrame.new(-3.06, 0, side * 2.57) * yaw(side * 40),
					color,
					false
				)
			end
		end
	end
	-- start pads: look only, the fight code reads them as the start spots
	for side, color in { a = c.padRed, b = c.padBlue } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.05, z)
		part(
			folder,
			"Spawn" .. string.upper(side),
			Vector3.new(Layout.pad.sx, 0.12, Layout.pad.sz),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz)),
			rgb(color),
			false
		)
		for _, e in { -1, 1 } do
			part(
				marks,
				"PadEdge",
				Vector3.new(Layout.pad.sx, 0.14, 0.7),
				CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
					* CFrame.new(0, 0, e * (Layout.pad.sz / 2 - 0.35)),
				rgb(c.marking),
				false
			)
		end
	end
end

local function walls(folder: Folder, origin: Vector3, solids: { Instance })
	local c = Layout.colors
	local t, h = Layout.wallThickness, Layout.wallHeight
	local group_ = group(folder, "Walls")
	local lights = group(folder, "WallLights")
	for _, w in Layout.walls() do
		local center = origin + Vector3.new(w.x - w.nx * t / 2, h / 2, w.z - w.nz * t / 2)
		local cf = CFrame.new(center) * yaw(w.yawDeg)
		local team = rgb(if w.team == "orange" then c.orange else c.blue)
		bouncy(
			part(
				group_,
				w.name,
				Vector3.new(w.length * 1.12, h, t),
				cf,
				team,
				true,
				solids,
				Enum.Material.Metal
			)
		)
		-- a dark base strip and a pale cap, so the module reads as painted metal
		part(
			lights,
			"Base",
			Vector3.new(w.length * 1.12, 1.4, t + 0.3),
			cf * CFrame.new(0, -h / 2 + 0.7, 0),
			rgb(c.metal),
			false,
			nil,
			Enum.Material.Metal
		)
		part(
			lights,
			"Cap",
			Vector3.new(w.length * 1.12, 0.5, t + 0.3),
			cf * CFrame.new(0, h / 2 + 0.25, 0),
			rgb(c.metal),
			false,
			nil,
			Enum.Material.Metal
		)
		if not w.arc or w.name:sub(-1) == "2" or w.name:sub(-1) == "3" then
			-- glowing light panel on the inner face, facing the arena
			part(
				lights,
				"Light",
				Vector3.new(w.length * 0.34, 1.5, 0.3),
				CFrame.new(origin + Vector3.new(w.x + w.nx * 0.15, 4.2, w.z + w.nz * 0.15))
					* yaw(w.yawDeg),
				rgb(c.light),
				false,
				nil,
				Enum.Material.Neon
			)
		end
	end
	-- tire stacks where wall modules meet, half sunk into the wall face
	local tireGroup = group(folder, "TireStacks")
	for _, s in Layout.tireStacks() do
		tires(tireGroup, origin + Vector3.new(s.x - s.nx * 1.5, 0, s.z - s.nz * 1.5), 1)
	end
end

-- Cover barrier: a chunky grey block with orange and dark stripes on both long faces.
local function blocks(folder: Folder, origin: Vector3, solids: { Instance })
	local c = Layout.colors
	local b = Layout.block
	local grp = group(folder, "Cover")
	for _, blk in Layout.blocks() do
		local cf = CFrame.new(origin + Vector3.new(blk.x, b.sy / 2, blk.z)) * yaw(blk.yawDeg)
		part(
			grp,
			blk.name,
			Vector3.new(b.sx, b.sy, b.sz),
			cf,
			rgb(c.metal),
			true,
			solids,
			Enum.Material.Metal
		)
		for i = 0, 3 do
			for _, side in { -1, 1 } do
				part(
					grp,
					"Stripe",
					Vector3.new(2.4, b.sy - 1.6, 0.2),
					cf * CFrame.new(-b.sx / 2 + 2.4 + i * 4.2, 0, side * (b.sz / 2 + 0.05)),
					rgb(if i % 2 == 0 then c.orange else c.tire),
					false
				)
			end
		end
		part(
			grp,
			"Top",
			Vector3.new(b.sx + 0.4, 0.5, b.sz + 0.4),
			cf * CFrame.new(0, b.sy / 2 + 0.25, 0),
			rgb(c.orange),
			false
		)
	end
end

local function garage(folder: Folder, origin: Vector3, g: { side: string, x: number, z: number })
	local c = Layout.colors
	local d = Layout.garage
	local team = rgb(if g.side == "a" then c.padRed else c.padBlue)
	local dark = Color3.fromRGB(58, 62, 74)
	local grp = group(folder, if g.side == "a" then "GarageRed" else "GarageBlue")
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(g.x + x, y, g.z + z))
	end
	local front = d.sz / 2 -- the side facing the arena
	part(
		grp,
		"Body",
		Vector3.new(d.sx, d.sy, d.sz),
		at(0, d.sy / 2, 0),
		dark,
		false,
		nil,
		Enum.Material.Metal
	)
	part(
		grp,
		"Roof",
		Vector3.new(d.sx + 3, 1.4, d.sz + 3),
		at(0, d.sy + 0.7, 0),
		team,
		false,
		nil,
		Enum.Material.Metal
	)
	part(
		grp,
		"Door",
		Vector3.new(30, 10, 0.6),
		at(0, 5.4, front + 0.2),
		Color3.fromRGB(30, 33, 40),
		false
	)
	part(
		grp,
		"DoorStripe",
		Vector3.new(30, 0.9, 0.5),
		at(0, 10.8, front + 0.45),
		team,
		false,
		nil,
		Enum.Material.Neon
	)
	part(
		grp,
		"DoorGlow",
		Vector3.new(28, 0.5, 0.4),
		at(0, 11.9, front + 0.5),
		rgb(c.light),
		false,
		nil,
		Enum.Material.Neon
	)
	for _, sx in { -1, 1 } do
		part(
			grp,
			"Post",
			Vector3.new(2, d.sy, 2),
			at(sx * 16.5, d.sy / 2, front + 0.4),
			team,
			false
		)
		can(
			grp,
			"Pole",
			0.7,
			17,
			origin + Vector3.new(g.x + sx * 25, 0, g.z + front),
			rgb(c.metal),
			false
		)
		part(grp, "Flag", Vector3.new(0.4, 5.5, 3.6), at(sx * 25, 14, front + 2), team, false)
	end
	for k = 1, 3 do
		part(
			grp,
			"Crate",
			Vector3.new(3.4, 3.4, 3.4),
			at(
				-d.sx / 2 - 3 + (k % 2) * 0.8,
				1.7 + (if k == 3 then 3.4 else 0),
				front - 2 - k * 1.5
			) * yaw(k * 14),
			rgb(c.crate),
			false,
			nil,
			Enum.Material.WoodPlanks
		)
	end
	tires(grp, origin + Vector3.new(g.x + d.sx / 2 + 3.5, 0, g.z + front - 2), 1)
	local glow = Instance.new("PointLight")
	glow.Color = team
	glow.Brightness = 1.2
	glow.Range = 28
	glow.Shadows = false
	glow.Parent = grp:FindFirstChild("DoorStripe")
end

local function scenery(folder: Folder, origin: Vector3)
	local c = Layout.colors
	local grp = group(folder, "Scenery")
	for _, s in Layout.scenery() do
		local base = origin + Vector3.new(s.x, -0.6, s.z)
		if s.kind == "tree" then
			can(
				grp,
				"Trunk",
				2.6 * s.scale,
				6 * s.scale,
				base,
				rgb(c.trunk),
				false,
				nil,
				Enum.Material.Wood
			)
			ball(
				grp,
				"Leaves",
				11 * s.scale,
				base + Vector3.new(0, 9.5 * s.scale, 0),
				rgb(c.leaf),
				false
			)
			ball(
				grp,
				"LeavesTop",
				7.5 * s.scale,
				base + Vector3.new(0.8 * s.scale, 14 * s.scale, 0.5 * s.scale),
				rgb(c.leafLight),
				false
			)
		else
			part(
				grp,
				"Rock",
				Vector3.new(7 * s.scale, 4.5 * s.scale, 5.5 * s.scale),
				CFrame.new(base + Vector3.new(0, 1.6 * s.scale, 0))
					* yaw(s.yawDeg)
					* CFrame.Angles(0.12, 0, 0.1),
				rgb(c.rock),
				false,
				nil,
				Enum.Material.Slate
			)
		end
	end
end

function DuelArena.build(folder: Folder, origin: Vector3, solids: { Instance })
	floor(folder, origin, solids)
	markings(folder, origin)
	walls(folder, origin, solids)
	blocks(folder, origin, solids)
	for _, g in Layout.garages() do
		garage(folder, origin, g)
	end
	scenery(folder, origin)
end

return DuelArena
