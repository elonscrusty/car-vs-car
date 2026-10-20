--!strict
-- Builds the 1v1 battle map "Toy Room Showdown" from `BattleMapLayout` (all numbers live there):
-- the floor, play-mat road, plateau, highway overpasses, cover, hazards and the ramps. The room
-- around it (furniture walls, giant toys, lights, dust) is in `MapDecor`. Decoration has no
-- collision and no query, so it costs the physics nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.BattleMapLayout)
local MapDecor = require(script.Parent.MapDecor)
local MapParts = require(script.Parent.MapParts)

local BattleMap = {}

local rgb, shade, part, can, ball, group =
	MapParts.rgb, MapParts.shade, MapParts.part, MapParts.can, MapParts.ball, MapParts.group

-- One wedge ramp. Rises toward (dx, dz). The wedge's tall face is believed to be its back (+Z); the
-- caller checks that with `checkRamp` right after the map is in the workspace, so a wrong guess
-- cannot ship a ramp that drops instead of rises.
local function ramp(
	parent: Instance,
	origin: Vector3,
	r: Layout.Ramp,
	solids: { Instance }
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = r.name
	w.Anchored = true
	w.Size = Vector3.new(r.width, r.height, r.length)
	local center = origin + Vector3.new(r.x, r.height / 2, r.z)
	local rise = Vector3.new(r.dx, 0, r.dz)
	w.CFrame = CFrame.lookAt(center, center - rise)
	w.Color = rgb(r.color)
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w:SetAttribute("RiseX", r.dx)
	w:SetAttribute("RiseZ", r.dz)
	w.Parent = parent
	table.insert(solids, w)
	return w
end

-- Casts a ray down at the low end and the high end of the ramp; flips the ramp if it drops.
local function checkRamp(w: WedgePart, r: Layout.Ramp, origin: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { w }
	local function top(along: number): number?
		local p = origin
			+ Vector3.new(
				r.x + r.dx * along * r.length / 2,
				r.height + 6,
				r.z + r.dz * along * r.length / 2
			)
		local hit = workspace:Raycast(p, Vector3.new(0, -(r.height + 12), 0), params)
		return if hit then hit.Position.Y else nil
	end
	local low, high = top(-0.8), top(0.8)
	if low and high and low > high then
		w.CFrame = w.CFrame * CFrame.Angles(0, math.pi, 0)
	end
end

function BattleMap.build(folder: Folder, origin: Vector3, solids: { Instance })
	local halfX, halfZ, t = Layout.halfX, Layout.halfZ, Layout.wallThickness
	local c = Layout.colors
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end

	-- floor: wooden boards, a green play-mat on top, a grey road loop with a dashed yellow line
	local floor = part(
		folder,
		"Floor",
		Vector3.new(halfX * 2 + t * 2, 2, halfZ * 2 + t * 2),
		at(0, -1, 0),
		rgb(c.wood),
		true,
		solids,
		Enum.Material.WoodPlanks
	)
	floor.Name = "Floor"
	local marks = group(folder, "FloorMarks")
	part(
		marks,
		"MatEdge",
		Vector3.new(halfX * 2 - 6, 0.05, halfZ * 2 - 6),
		at(0, 0.025, 0),
		shade(c.grass, 0.7),
		false,
		nil,
		Enum.Material.Fabric
	)
	part(
		marks,
		"Mat",
		Vector3.new(halfX * 2 - 10, 0.07, halfZ * 2 - 10),
		at(0, 0.04, 0),
		rgb(c.grass),
		false,
		nil,
		Enum.Material.Fabric
	)
	for _, s in Layout.roadStrips() do
		part(
			marks,
			"Road",
			Vector3.new(s.sx, 0.09, s.sz),
			at(s.x, 0.06, s.z),
			rgb(c.road),
			false,
			nil,
			Enum.Material.Asphalt
		)
	end
	for _, d in Layout.roadDashes() do
		local size = if d.alongX then Vector3.new(7, 0.11, 1.1) else Vector3.new(1.1, 0.11, 7)
		part(marks, "Dash", size, at(d.x, 0.075, d.z), rgb(c.dash), false)
	end

	-- start pads (looks only): red for side A, blue for side B. The fight code reads them as the
	-- start spots (parts SpawnA / SpawnB); the front of the part is the driving direction.
	for side, color in { a = c.padA, b = c.padB } do
		local x, z, fx, fz = Layout.spawn(side)
		local pos = origin + Vector3.new(x, 0.1, z)
		part(
			folder,
			"Spawn" .. string.upper(side),
			Vector3.new(26, 0.14, 18),
			CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz)),
			rgb(color),
			false
		)
		local lx = if side == "a" then -Layout.startLineX else Layout.startLineX
		part(marks, "StartLine", Vector3.new(1.6, 0.12, 26), at(lx, 0.12, 0), rgb(c.white), false)
	end

	-- chevrons on the floor pointing up the plateau ramps (two thin bars make an arrow)
	for _, cv in Layout.chevrons() do
		for _, side in { -1, 1 } do
			local cf = at(cv.x, 0.13, cv.z + side * 3.2)
				* CFrame.Angles(0, math.rad(side * 38 * cv.dir), 0)
			part(
				marks,
				"Chevron",
				Vector3.new(8.5, 0.12, 1.7),
				cf,
				rgb(c.chevron),
				false,
				nil,
				Enum.Material.Neon
			)
		end
	end

	-- chunky solid pieces: plateau, highway decks, bunkers, cover blocks, corner bumpers, toy soldiers
	local deco = group(folder, "Details")
	for _, b in Layout.boxes() do
		if b.kind == "soldier" then
			MapDecor.soldier(folder, b, at, solids)
		else
			local cf = at(b.x, b.sy / 2, b.z) * CFrame.Angles(0, math.rad(b.yawDeg), 0)
			local mat = if b.kind == "highway" then Enum.Material.Concrete else nil
			local p = part(
				folder,
				b.name,
				Vector3.new(b.sx, b.sy, b.sz),
				cf,
				rgb(b.color),
				true,
				solids,
				mat
			)
			if b.kind == "plateau" then
				-- lighter lip on top, darker skirt at the foot, and a glowing red ring in the middle
				part(
					deco,
					"PlateauCap",
					Vector3.new(b.sx + 1.2, 0.8, b.sz + 1.2),
					at(0, b.sy - 0.2, 0),
					rgb(c.cap),
					false
				)
				part(
					deco,
					"PlateauSkirt",
					Vector3.new(b.sx + 2, 1.6, b.sz + 2),
					at(0, 0.8, 0),
					rgb(c.skirt),
					false
				)
				local d = b.sx - 6
				local ring = part(
					deco,
					"PlateauRing",
					Vector3.new(0.2, d, d),
					at(0, b.sy + 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(c.ring),
					false,
					nil,
					Enum.Material.Neon
				)
				ring.Shape = Enum.PartType.Cylinder
				p:SetAttribute("TopY", b.sy)
			elseif b.kind == "highway" then
				-- white curbs along both edges, a dashed yellow center line, a darker underside band
				for _, side in { -1, 1 } do
					part(
						deco,
						"Curb",
						Vector3.new(b.sx, 0.5, 1),
						at(b.x, b.sy + 0.25, b.z + side * (b.sz / 2 - 0.5)),
						rgb(c.white),
						false
					)
				end
				for k = -4, 4 do
					part(
						deco,
						"DeckDash",
						Vector3.new(6, 0.12, 0.9),
						at(b.x + k * 10.5, b.sy + 0.07, b.z),
						rgb(c.dash),
						false
					)
				end
				part(
					deco,
					"DeckBand",
					Vector3.new(b.sx + 0.4, 1.8, b.sz + 0.4),
					at(b.x, 1, b.z),
					rgb(c.stripes[2]),
					false
				)
			elseif b.kind == "block" then
				MapDecor.studs(deco, b, at, 2, 2)
				if b.letter then
					MapDecor.letter(p, b.letter)
				end
			elseif b.kind == "bunker" then
				MapDecor.studs(deco, b, at, 1, 3)
				part(
					deco,
					"BunkerBand",
					Vector3.new(b.sx + 0.4, 2, b.sz + 0.4),
					at(b.x, 2.2, b.z),
					rgb(c.white),
					false
				)
			elseif b.kind == "bumper" then
				for k = -1, 1, 2 do
					part(
						deco,
						"BumperBand",
						Vector3.new(2.4, b.sy + 0.2, b.sz + 0.3),
						cf * CFrame.new(k * 6, 0, 0),
						rgb(c.white),
						false
					)
				end
			end
		end
	end

	-- ramps
	local ramps = Layout.ramps()
	local wedges: { WedgePart } = {}
	for _, r in ramps do
		table.insert(wedges, ramp(folder, origin, r, solids))
	end

	-- hazard one: a spinner arm over the plateau (turned every frame by `BattleMap.animate`)
	local hazards = group(folder, "Hazards")
	local sp = Layout.spinner
	local topY = Layout.plateau.height + sp.clearance
	local spinner = Instance.new("Model")
	spinner.Name = "Spinner"
	local hub = can(
		spinner,
		"Hub",
		sp.hubRadius * 2,
		sp.height + 2,
		origin + Vector3.new(0, Layout.plateau.height, 0),
		rgb(c.stripes[1]),
		true,
		solids
	)
	part(
		spinner,
		"Arm",
		Vector3.new(sp.radius * 2, sp.height, sp.width),
		at(0, topY + sp.height / 2, 0),
		rgb(c.stripes[2]),
		true,
		solids
	)
	for k = -1, 1, 2 do
		ball(
			spinner,
			"Tip",
			sp.height + 2,
			origin + Vector3.new(k * sp.radius, topY + sp.height / 2, 0),
			rgb(c.stripes[1]),
			true,
			solids
		)
	end
	spinner.PrimaryPart = hub
	spinner.Parent = hazards

	-- hazard two: red blocks that slide across the highway decks (turned by `BattleMap.animate`)
	for _, sl in Layout.sliders() do
		local size = Vector3.new(sl.size[1], sl.size[2], sl.size[3])
		local base = at(sl.x, sl.baseY + size.Y / 2 + 0.2, sl.z)
		local p = part(hazards, sl.name, size, base, rgb(c.stripes[1]), true, solids)
		local band = part(
			hazards,
			sl.name .. "Band",
			Vector3.new(size.X + 0.2, 1.4, size.Z + 0.2),
			base * CFrame.new(0, size.Y / 2 - 1, 0),
			rgb(c.white),
			false
		)
		for _, piece in { p, band } do
			piece:SetAttribute("SlideAmp", sl.amplitude)
			piece:SetAttribute("SlidePeriod", sl.periodSeconds)
			piece:SetAttribute("SlidePhase", sl.phase)
		end
	end

	-- the room around the arena: furniture walls, bunting, giant toys, lights and dust
	MapDecor.room(folder, origin, solids)

	return wedges, ramps
end

-- Run once the folder is in the workspace.
function BattleMap.verify(origin: Vector3, wedges: { WedgePart }, ramps: { Layout.Ramp })
	for i, w in wedges do
		checkRamp(w, ramps[i], origin)
	end
end

-- Turns the spinner and slides the blocks until the arena folder is destroyed. The sliders ride
-- the highway decks and nudge cars toward the edge; the spinner sweeps the plateau.
function BattleMap.animate(folder: Folder)
	local hazards = folder:FindFirstChild("Hazards")
	if not hazards then
		return
	end
	local spinner = hazards:FindFirstChild("Spinner")
	local spinnerPivot: CFrame? = nil
	local center = Vector3.zero
	if spinner and spinner:IsA("Model") then
		spinnerPivot = spinner:GetPivot()
		center = (spinnerPivot :: CFrame).Position
	end
	local sliders: { { part: BasePart, base: CFrame, amp: number, period: number, phase: number } } =
		{}
	for _, child in hazards:GetChildren() do
		local amp = child:GetAttribute("SlideAmp")
		if child:IsA("BasePart") and type(amp) == "number" then
			table.insert(sliders, {
				part = child,
				base = child.CFrame,
				amp = amp,
				period = child:GetAttribute("SlidePeriod") :: number,
				phase = child:GetAttribute("SlidePhase") :: number,
			})
		end
	end
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock() - started
		if spinner and spinner:IsA("Model") and spinnerPivot then
			local angle = now * Layout.spinner.speed
			spinner:PivotTo(
				CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(-center) * spinnerPivot
			)
		end
		for _, sl in sliders do
			local off = sl.amp * math.sin(2 * math.pi * (now / sl.period + sl.phase))
			sl.part.CFrame = sl.base * CFrame.new(0, 0, off)
		end
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

return BattleMap
