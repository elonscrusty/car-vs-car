--!strict
-- Builds the props of the Car Battle Lobby from shared/LobbyProps.luau (carter's picks L21-L40,
-- docs/LOBBY_POLISH.md): plain wooden benches, rainbow cones, stacks of bright tires, colorful junk
-- piles, big tip billboards, tool props by the customize garage, a chain fence round the edge,
-- puffy cartoon clouds and the painted ground (skid marks, patches, bright lines).
-- Chunky toy-size shapes. Everything is look-only; the solid props (benches, tires, junk, tools,
-- billboard posts) get a short invisible box so nobody climbs them, the cones get none (they are
-- never kickable: the lobby stays calm, L8). Local coordinates like LobbyLayout; `origin` is added.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)
local Props = require(ReplicatedStorage.Shared.LobbyProps)

local LobbyProps = {}

local rgb, shade, part, can, ball, group =
	MapParts.rgb, MapParts.shade, MapParts.part, MapParts.can, MapParts.ball, MapParts.group
local C = LobbyLayout.colors

local PROP_BLOCKER_TALL = 14

local function look(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return part(parent, name, size, cf, color, false, nil, material)
end

-- Small repeatable random numbers, so a pile or a cloud always looks the same.
local function rng(seed: number): (number, number) -> number
	local s = (seed * 7919 + 104729) % 2147483648
	return function(lo: number, hi: number): number
		s = (s * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * (s / 2147483648)
	end
end

local function rainbow(i: number): Color3
	local list = C.rainbow
	return rgb(list[(i - 1) % #list + 1])
end

local function accentColor(name: string): Color3
	return if name == "blue" then rgb(C.blue) else rgb(C.orangeWall)
end

local function at(origin: Vector3, x: number, y: number, z: number, yawDeg: number?): CFrame
	return CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

-- ---------------------------------------------------------------------------------------------
-- invisible climb blockers

local function blocker(
	grp: Folder,
	name: string,
	x: number,
	z: number,
	w: number,
	d: number,
	yaw: number,
	origin: Vector3
)
	local p = part(
		grp,
		name,
		Vector3.new(w, PROP_BLOCKER_TALL, d),
		at(origin, x, PROP_BLOCKER_TALL / 2, z, yaw),
		Color3.new(1, 1, 1),
		true,
		nil,
		nil
	)
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- ---------------------------------------------------------------------------------------------
-- benches (plain wood, chunky; they are not seats, so nobody can sit)

local function bench(grp: Folder, origin: Vector3, b: Props.Bench)
	local m = group(grp, "Bench")
	local wood = rgb(C.wood)
	local woodBack = shade(C.wood, 1.12)
	local trim = accentColor(b.accent)
	-- yaw 0: the long side runs along z, the sitter faces +x, the back is on the -x side
	look(
		m,
		"Seat",
		Vector3.new(3.4, 0.8, 8.4),
		at(origin, b.x, 2.1, b.z, b.yawDeg) * CFrame.new(0.2, 0, 0),
		wood,
		Enum.Material.Wood
	)
	look(
		m,
		"Back",
		Vector3.new(0.8, 2.6, 8.4),
		at(origin, b.x, 3.8, b.z, b.yawDeg) * CFrame.new(-1.4, 0, 0),
		woodBack,
		Enum.Material.Wood
	)
	for _, s in { -1, 1 } do
		look(
			m,
			"Leg",
			Vector3.new(2.8, 1.7, 1.0),
			at(origin, b.x, 0.85, b.z, b.yawDeg) * CFrame.new(0, 0, s * 3.2),
			trim
		)
		-- a rolled cap at each end of the seat (round, chunky)
		local cap = look(
			m,
			"Cap",
			Vector3.new(3.4, 1.2, 1.2),
			at(origin, b.x, 2.7, b.z, b.yawDeg) * CFrame.new(0.2, 0, s * 4.3),
			trim
		)
		cap.Shape = Enum.PartType.Cylinder
	end
end

-- ---------------------------------------------------------------------------------------------
-- cones (rainbow, look-only: nobody can kick them)

local function cone(grp: Folder, origin: Vector3, c: Props.Cone)
	local m = group(grp, "Cone")
	local p = origin + Vector3.new(c.x, 0, c.z)
	look(
		m,
		"Base",
		Vector3.new(2.2, 0.3, 2.2),
		CFrame.new(p + Vector3.new(0, 0.15, 0)),
		rgb(C.asphaltDark)
	)
	local color = rainbow(c.color)
	can(m, "Lower", 1.7, 1.0, p + Vector3.new(0, 0.3, 0), color)
	can(m, "Stripe", 1.2, 0.45, p + Vector3.new(0, 1.3, 0), rgb(C.marking))
	can(m, "Top", 0.8, 0.8, p + Vector3.new(0, 1.75, 0), color)
end

-- ---------------------------------------------------------------------------------------------
-- stacks of bright tires

local TIRE_D, TIRE_H = 4.4, 1.35

local function tireStack(grp: Folder, origin: Vector3, t: Props.TireStack)
	local m = group(grp, "TireStack")
	local r = rng(t.seed * 31)
	for i = 1, t.count do
		local color = rainbow(t.seed + i * 3)
		if (t.seed + i) % 7 == 0 then
			color = rgb(C.marking)
		end
		local jx, jz = r(-0.35, 0.35), r(-0.35, 0.35)
		local y = (i - 1) * TIRE_H
		local pos = origin + Vector3.new(t.x + jx, y, t.z + jz)
		can(m, "Tire", TIRE_D, TIRE_H, pos, color, false, nil, Enum.Material.Rubber)
		can(
			m,
			"Hole",
			TIRE_D * 0.5,
			TIRE_H + 0.02,
			pos,
			rgb(C.tire),
			false,
			nil,
			Enum.Material.Rubber
		)
	end
end

-- ---------------------------------------------------------------------------------------------
-- junk piles: colorful old car parts

local function junkPile(grp: Folder, origin: Vector3, j: Props.JunkPile)
	local m = group(grp, "JunkPile")
	local r = rng(j.seed * 53)
	local base = at(origin, j.x, 0, j.z, j.yawDeg)
	local function put(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		rx: number,
		ry: number,
		rz: number,
		color: Color3,
		material: Enum.Material?
	): Part
		return look(
			m,
			name,
			size,
			base * CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz),
			color,
			material
		)
	end
	-- an oil stain under it
	local stain = can(m, "Stain", 10, 0.1, origin + Vector3.new(j.x, 0.02, j.z), rgb(C.asphaltDark))
	stain.CFrame = base * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2)
	-- doors and a hood stacked and leaning (bright paint)
	put(
		"Door",
		Vector3.new(4.8, 0.5, 3.2),
		-1.2,
		0.8,
		0.6,
		r(-0.15, 0.15),
		r(0, 1),
		r(-0.25, 0.25),
		rainbow(j.seed),
		nil
	)
	put(
		"Door",
		Vector3.new(4.8, 0.5, 3.2),
		0.8,
		1.5,
		-0.8,
		r(-0.3, 0.3),
		r(1, 2),
		r(0.1, 0.5),
		rainbow(j.seed + 2),
		nil
	)
	put(
		"Hood",
		Vector3.new(5.4, 0.45, 3.6),
		1.6,
		2.4,
		0.9,
		r(-0.2, 0.2),
		r(2, 3),
		r(-0.45, -0.1),
		rainbow(j.seed + 4),
		nil
	)
	put(
		"Bumper",
		Vector3.new(6.6, 0.9, 1.1),
		-1.4,
		0.45,
		-2.6,
		0,
		r(-0.4, 0.4),
		0,
		rgb(C.marking),
		Enum.Material.Metal
	)
	-- an engine block with a pipe
	put(
		"Engine",
		Vector3.new(2.6, 2.2, 2.6),
		-3.2,
		1.1,
		1.2,
		0,
		r(0, 1),
		0,
		rgb(C.metal),
		Enum.Material.Metal
	)
	local pipe = put(
		"Pipe",
		Vector3.new(3.4, 0.7, 0.7),
		-3.2,
		2.5,
		1.2,
		0,
		r(0, 3),
		0,
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	pipe.Shape = Enum.PartType.Cylinder
	-- two wheels, one lying, one leaning on the pile
	for k, w in { { 3.0, 0.65, -2.4, 0.0 }, { 3.6, 2.0, 1.2, 1.15 } } do
		local tire = put(
			"Wheel",
			Vector3.new(1.3, 3.5, 3.5),
			w[1],
			w[2],
			w[3],
			0,
			r(0, 3),
			if k == 1 then math.pi / 2 else w[4],
			rgb(C.tire),
			Enum.Material.Rubber
		)
		tire.Shape = Enum.PartType.Cylinder
		local hub = put(
			"Hub",
			Vector3.new(1.4, 1.6, 1.6),
			w[1],
			w[2],
			w[3],
			0,
			0,
			if k == 1 then math.pi / 2 else w[4],
			rgb(C.marking),
			Enum.Material.Metal
		)
		hub.CFrame = tire.CFrame
		hub.Shape = Enum.PartType.Cylinder
	end
	-- a bright seat on top
	put(
		"Seat",
		Vector3.new(2.4, 1.0, 2.2),
		0.2,
		3.1,
		-0.4,
		r(-0.2, 0.2),
		r(0, 3),
		r(-0.2, 0.2),
		rainbow(j.seed + 6),
		nil
	)
end

-- ---------------------------------------------------------------------------------------------
-- billboards

local function billboardText(panel: Part, face: Enum.NormalId, d: Props.Billboard)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TipGui" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = panel
	local function line(text: string, top: number, height: number)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(0.92, height)
		l.Position = UDim2.fromScale(0.04, top)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = rgb(C.marking)
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = rgb(C.panel)
		l.Parent = gui
	end
	line(d.line1, 0.08, 0.5)
	line(d.line2, 0.6, 0.3)
end

local function billboard(grp: Folder, origin: Vector3, d: Props.Billboard)
	local m = group(grp, "Billboard")
	local colors = Props.billboardColors[d.color]
	local bg, trim = rgb(colors.bg), rgb(colors.trim)
	local base = at(origin, d.x, 0, d.z, d.yawDeg)
	local midY = d.bottom + d.h / 2
	local panel =
		look(m, "BillboardPanel", Vector3.new(d.w, d.h, 0.8), base * CFrame.new(0, midY, 0), bg)
	local t = 0.7
	look(
		m,
		"TrimTop",
		Vector3.new(d.w + 1.4, t, 1.2),
		base * CFrame.new(0, d.bottom + d.h + t / 2 - 0.1, 0),
		trim
	)
	look(
		m,
		"TrimBottom",
		Vector3.new(d.w + 1.4, t, 1.2),
		base * CFrame.new(0, d.bottom - t / 2 + 0.1, 0),
		trim
	)
	for _, s in { -1, 1 } do
		look(
			m,
			"TrimSide",
			Vector3.new(t, d.h + 1.2, 1.2),
			base * CFrame.new(s * (d.w / 2 + t / 2 - 0.1), midY, 0),
			trim
		)
		-- the posts run from the ground up behind the board
		local px = s * (d.w / 2 - 2)
		look(
			m,
			"Post",
			Vector3.new(1.2, d.bottom + d.h * 0.7, 1.2),
			base * CFrame.new(px, (d.bottom + d.h * 0.7) / 2, -1.0),
			rgb(C.metalDark),
			Enum.Material.Metal
		)
		look(
			m,
			"Footing",
			Vector3.new(2.6, 0.6, 2.6),
			base * CFrame.new(px, 0.3, -1.0),
			rgb(C.metal),
			Enum.Material.Concrete
		)
	end
	billboardText(panel, Enum.NormalId.Back, d)
	billboardText(panel, Enum.NormalId.Front, d)
end

-- ---------------------------------------------------------------------------------------------
-- tool props by the customize garage

local function toolbox(grp: Folder, origin: Vector3, t: Props.ToolProp)
	local m = group(grp, "Toolbox")
	local body = accentColor(t.accent)
	local base = at(origin, t.x, 0, t.z, t.yawDeg)
	look(m, "Body", Vector3.new(4.4, 1.8, 2.6), base * CFrame.new(0, 0.9, 0), body)
	look(
		m,
		"Lid",
		Vector3.new(4.6, 0.6, 2.8),
		base * CFrame.new(0, 2.1, 0),
		shade(C.orangeWall, 0.8)
	)
	look(
		m,
		"Handle",
		Vector3.new(2.2, 0.3, 0.4),
		base * CFrame.new(0, 2.6, 0),
		rgb(C.metal),
		Enum.Material.Metal
	)
	for _, s in { -1, 1 } do
		look(
			m,
			"Latch",
			Vector3.new(0.5, 0.9, 0.3),
			base * CFrame.new(s * 1.4, 1.5, 1.4),
			rgb(C.gold),
			Enum.Material.Metal
		)
	end
end

local function carJack(grp: Folder, origin: Vector3, t: Props.ToolProp)
	local m = group(grp, "CarJack")
	local base = at(origin, t.x, 0, t.z, t.yawDeg)
	local body = accentColor(t.accent)
	-- a chunky trolley jack: a low body on two wheels, a lifting arm, a pad and a long handle
	look(m, "Body", Vector3.new(3.6, 0.9, 1.9), base * CFrame.new(0, 0.9, 0), body)
	for _, s in { -1, 1 } do
		local w = look(
			m,
			"Wheel",
			Vector3.new(0.6, 1.1, 1.1),
			base * CFrame.new(s * 1.3, 0.55, 1.0),
			rgb(C.tire),
			Enum.Material.Rubber
		)
		w.Shape = Enum.PartType.Cylinder
		w.CFrame = base * CFrame.new(s * 1.3, 0.55, 1.0) * CFrame.Angles(0, math.pi / 2, 0)
	end
	look(
		m,
		"Arm",
		Vector3.new(0.9, 0.7, 3.0),
		base * CFrame.new(0, 1.9, -0.3) * CFrame.Angles(math.rad(-22), 0, 0),
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	local pad =
		look(m, "Pad", Vector3.new(0.5, 1.6, 1.6), base * CFrame.new(0, 3.0, -1.5), rgb(C.marking))
	pad.Shape = Enum.PartType.Cylinder
	pad.CFrame = base * CFrame.new(0, 3.0, -1.5) * CFrame.Angles(0, 0, math.pi / 2)
	look(
		m,
		"Handle",
		Vector3.new(0.45, 0.45, 4.6),
		base * CFrame.new(0, 2.4, 2.6) * CFrame.Angles(math.rad(30), 0, 0),
		rgb(C.metal),
		Enum.Material.Metal
	)
end

local function wrenchRack(grp: Folder, origin: Vector3, t: Props.ToolProp)
	local m = group(grp, "WrenchRack")
	local base = at(origin, t.x, 0, t.z, t.yawDeg)
	look(
		m,
		"Board",
		Vector3.new(6.4, 3.8, 0.5),
		base * CFrame.new(0, 3.4, 0),
		rgb(C.wood),
		Enum.Material.Wood
	)
	for _, s in { -1, 1 } do
		look(
			m,
			"Post",
			Vector3.new(0.7, 3.4, 0.7),
			base * CFrame.new(s * 2.8, 1.7, -0.2),
			rgb(C.metalDark),
			Enum.Material.Metal
		)
	end
	for i = 1, 5 do
		local x = (i - 3) * 1.1
		local color = if i % 2 == 1 then rgb(C.metal) else accentColor(t.accent)
		look(
			m,
			"WrenchShaft",
			Vector3.new(0.4, 2.6, 0.3),
			base * CFrame.new(x, 3.2, 0.4),
			color,
			Enum.Material.Metal
		)
		local head = look(
			m,
			"WrenchHead",
			Vector3.new(0.3, 1.0, 1.0),
			base * CFrame.new(x, 4.7, 0.4),
			color,
			Enum.Material.Metal
		)
		head.Shape = Enum.PartType.Cylinder
		head.CFrame = base * CFrame.new(x, 4.7, 0.4) * CFrame.Angles(0, math.pi / 2, 0)
	end
end

local function toolCart(grp: Folder, origin: Vector3, t: Props.ToolProp)
	local m = group(grp, "ToolCart")
	local base = at(origin, t.x, 0, t.z, t.yawDeg)
	local body = accentColor(t.accent)
	local drawer = shade(C.orangeWall, 1.22)
	-- footprint 6 x 4: long side along x, the drawers face +z
	look(m, "Body", Vector3.new(5.6, 2.6, 3.4), base * CFrame.new(0, 1.9, 0), body)
	look(
		m,
		"Top",
		Vector3.new(6, 0.4, 3.8),
		base * CFrame.new(0, 3.4, 0),
		rgb(C.metalDark),
		Enum.Material.Metal
	)
	for k = -1, 1 do
		look(m, "Drawer", Vector3.new(1.6, 0.7, 0.2), base * CFrame.new(k * 1.8, 1.9, 1.75), drawer)
		look(
			m,
			"Handle",
			Vector3.new(0.9, 0.15, 0.2),
			base * CFrame.new(k * 1.8, 1.9, 1.9),
			rgb(C.marking)
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = look(
				m,
				"Wheel",
				Vector3.new(0.6, 1.2, 1.2),
				base * CFrame.new(sx * 2.4, 0.6, sz * 1.5) * CFrame.Angles(0, math.pi / 2, 0),
				rgb(C.tire),
				Enum.Material.Rubber
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- the chain fence

local FENCE_WIRE = 0.3

local function fence(grp: Folder, origin: Vector3)
	local m = group(grp, "Fence")
	local H = Props.fenceHeight
	local postColor = rgb(C.metalDark)
	local wireColor = shade(C.metal, 1.25)
	local bays = Props.fence()
	-- the rails are one long bar for each straight run, so they cost two parts, not two per bay
	local runs: { { ax: number, az: number, bx: number, bz: number } } = {}
	for _, b in bays do
		local last = runs[#runs]
		local sameLine = last
			and math.abs(last.bx - b.ax) < 1e-6
			and math.abs(last.bz - b.az) < 1e-6
			and math.abs(
					(last.bx - last.ax) * (b.bz - b.az) - (last.bz - last.az) * (b.bx - b.ax)
				)
				< 1e-4
		if sameLine then
			last.bx, last.bz = b.bx, b.bz
		else
			table.insert(runs, { ax = b.ax, az = b.az, bx = b.bx, bz = b.bz })
		end
	end
	local function yawOf(ax: number, az: number, bx: number, bz: number): number
		return math.atan2(-(bz - az), bx - ax) -- local +x runs along the bay
	end
	for _, r in runs do
		local len = math.sqrt((r.bx - r.ax) ^ 2 + (r.bz - r.az) ^ 2)
		local mid = Vector3.new((r.ax + r.bx) / 2, 0, (r.az + r.bz) / 2)
		local cf = CFrame.new(origin + mid) * CFrame.Angles(0, yawOf(r.ax, r.az, r.bx, r.bz), 0)
		look(
			m,
			"TopRail",
			Vector3.new(len, 0.6, 0.6),
			cf * CFrame.new(0, H, 0),
			wireColor,
			Enum.Material.Metal
		)
		look(
			m,
			"BottomRail",
			Vector3.new(len, 0.5, 0.5),
			cf * CFrame.new(0, 0.9, 0),
			wireColor,
			Enum.Material.Metal
		)
	end
	-- a post at the start of every bay, and one more at the end of a run
	local posted: { [string]: boolean } = {}
	local function post(x: number, z: number)
		local key = string.format("%.2f,%.2f", x, z)
		if posted[key] then
			return
		end
		posted[key] = true
		can(
			m,
			"Post",
			0.9,
			H + 0.5,
			origin + Vector3.new(x, 0, z),
			postColor,
			false,
			nil,
			Enum.Material.Metal
		)
		ball(
			m,
			"PostCap",
			1.3,
			origin + Vector3.new(x, H + 0.7, z),
			rgb(C.gold),
			false,
			nil,
			Enum.Material.Metal
		)
	end
	for _, b in bays do
		post(b.ax, b.az)
		post(b.bx, b.bz)
		-- the wire: an X across the bay
		local len = math.sqrt((b.bx - b.ax) ^ 2 + (b.bz - b.az) ^ 2)
		local mid = Vector3.new((b.ax + b.bx) / 2, 0, (b.az + b.bz) / 2)
		local cf = CFrame.new(origin + mid + Vector3.new(0, (H + 0.9) / 2, 0))
			* CFrame.Angles(0, yawOf(b.ax, b.az, b.bx, b.bz), 0)
		local rise = H - 0.9
		local diag = math.sqrt(len * len + rise * rise)
		local tilt = math.atan2(rise, len)
		for _, s in { -1, 1 } do
			look(
				m,
				"Wire",
				Vector3.new(diag, FENCE_WIRE, FENCE_WIRE),
				cf * CFrame.Angles(0, 0, s * tilt),
				wireColor,
				Enum.Material.Metal
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- puffy clouds

local function cloud(grp: Folder, origin: Vector3, c: Props.Cloud)
	local m = group(grp, "Cloud")
	local r = rng(c.seed * 17)
	local k = c.scale
	local center = origin + Vector3.new(c.x, c.y, c.z)
	-- a flat grayish underside, then round white puffs standing on it
	can(m, "CloudBase", 28 * k, 3 * k, center, rgb(C.cloudShade))
	local n = 5
	for i = 1, n do
		local d = r(11, 18) * k
		local x = (i - (n + 1) / 2) * 6.2 * k + r(-1.5, 1.5) * k
		local z = r(-3, 3) * k
		local y = 3 * k + d / 2 - 2.6 * k + (if i == 2 or i == 4 then 3.2 * k else 0)
		ball(m, "Puff", d, center + Vector3.new(x, y, z), rgb(C.cloud))
	end
end

-- ---------------------------------------------------------------------------------------------
-- painted ground

local function paint(grp: Folder, origin: Vector3)
	local m = group(grp, "Paint")
	local dark = rgb(C.asphaltDark)
	for _, q in Props.patches() do
		look(
			m,
			"Patch",
			Vector3.new(q.w, 0.06, q.d),
			at(origin, q.x, 0.03, q.z, q.yawDeg),
			dark,
			Enum.Material.Asphalt
		)
	end
	-- black tire skid marks: a pair of thin strips for each (the two tires)
	for _, s in Props.skids() do
		for k = -1, 1, 2 do
			look(
				m,
				"Skid",
				Vector3.new(0.6, 0.05, s.len),
				at(origin, s.x, 0.045, s.z, s.yawDeg) * CFrame.new(k * 0.75, 0, 0),
				rgb(C.tire),
				Enum.Material.Asphalt
			)
		end
	end
	-- bright painted lines (they lie just over the light paths too)
	local colors: { [string]: Color3 } =
		{ yellow = rgb(C.gold), black = rgb(C.tire), white = rgb(C.marking) }
	for _, l in Props.lines() do
		look(
			m,
			"Line",
			Vector3.new(l.w, 0.06, l.d),
			at(origin, l.x, 0.24, l.z, l.yawDeg),
			colors[l.color] or rgb(C.marking)
		)
	end
end

-- ---------------------------------------------------------------------------------------------

function LobbyProps.build(folder: Folder, origin: Vector3)
	local grp = group(folder, "Props")
	local blockers = group(grp, "PropBlockers")

	local benches = group(grp, "Benches")
	for _, b in Props.benches() do
		bench(benches, origin, b)
		blocker(blockers, "BenchBlocker", b.x, b.z, 3.6, 8.8, b.yawDeg, origin)
	end

	local cones = group(grp, "Cones")
	for _, c in Props.cones() do
		cone(cones, origin, c)
	end

	local tires = group(grp, "TireStacks")
	for _, t in Props.tireStacks() do
		tireStack(tires, origin, t)
		blocker(blockers, "TireBlocker", t.x, t.z, 5, 5, 0, origin)
	end

	local junk = group(grp, "JunkPiles")
	for _, j in Props.junkPiles() do
		junkPile(junk, origin, j)
		blocker(blockers, "JunkBlocker", j.x, j.z, 10, 8, j.yawDeg, origin)
	end

	local boards = group(grp, "Billboards")
	for _, b in Props.billboards() do
		billboard(boards, origin, b)
		for _, post in Props.billboardPosts(b) do
			blocker(
				blockers,
				"BillboardBlocker",
				post.x,
				post.z,
				post.w + 0.6,
				post.d + 0.6,
				post.yawDeg,
				origin
			)
		end
	end

	local tools = group(grp, "ToolProps")
	for _, t in Props.toolProps() do
		if t.kind == "toolbox" then
			toolbox(tools, origin, t)
		elseif t.kind == "jack" then
			carJack(tools, origin, t)
		elseif t.kind == "rack" then
			wrenchRack(tools, origin, t)
		else
			toolCart(tools, origin, t)
		end
		local size = Props.toolSize[t.kind]
		blocker(blockers, "ToolBlocker", t.x, t.z, size.w + 0.6, size.d + 0.6, t.yawDeg, origin)
	end

	fence(grp, origin)

	local clouds = group(folder, "Clouds") -- way up: not part of the lobby box
	for _, c in Props.clouds() do
		cloud(clouds, origin, c)
	end

	paint(grp, origin)
end

return LobbyProps
