--!strict
-- Moves the decoration models the server tags on this player's own screen, so the movement costs no
-- network traffic and the server never moves them:
--   "MapSpin": the big wheel behind the toy battle arena, turning about its axle.
--   "MapWave": the garage flags in the duel arena. Their strips (Strip1..Strip5) sway sideways, more
--   toward the free end.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MapFx = {}

local spinning: { [Model]: { base: CFrame, center: Vector3, speed: number } } = {}

local waving: { [Model]: { { part: BasePart, base: CFrame, k: number } } } = {}

-- Wrecking-ball cranes: the "Swing" model turns about the mast's vertical axis. The angle comes
-- from the server clock (same formula as ChaseMapLayout.craneAngle), so every client and the
-- server see the ball in the same place without sending anything.
local cranes: {
	[Model]: {
		swing: Model,
		rest: CFrame,
		axis: Vector3,
		amp: number,
		period: number,
		phase: number,
	},
} =
	{}

local function addCrane(inst: Instance)
	if not inst:IsA("Model") or cranes[inst] ~= nil then
		return
	end
	-- the model streams in whole (atomic), but wait a moment for the pieces anyway
	local swing = inst:WaitForChild("Swing", 10)
	local mast = inst:WaitForChild("Mast", 10)
	if swing == nil or not swing:IsA("Model") or mast == nil or not mast:IsA("BasePart") then
		return
	end
	local rest = swing:GetPivot()
	cranes[inst] = {
		swing = swing,
		rest = rest,
		axis = mast.Position,
		amp = (inst:GetAttribute("Amp") :: number?) or 1.3,
		period = (inst:GetAttribute("Period") :: number?) or 4.6,
		phase = (inst:GetAttribute("Phase") :: number?) or 0,
	}
end

local function collectStrips(inst: Instance): { { part: BasePart, base: CFrame, k: number } }
	local strips = {}
	for _, c in inst:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Strip(%d+)$"))
		if n ~= nil and c:IsA("BasePart") then
			table.insert(strips, { part = c, base = c.CFrame, k = n })
		end
	end
	return strips
end

local function addWave(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	waving[inst] = collectStrips(inst)
end

local function add(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local pivot = inst:GetPivot()
	local speed = inst:GetAttribute("SpinSpeed")
	spinning[inst] = {
		base = pivot,
		center = pivot.Position,
		speed = if type(speed) == "number" then speed else 0.2,
	}
end

function MapFx.start()
	for _, inst in CollectionService:GetTagged("MapSpin") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("MapSpin"):Connect(add)
	for _, inst in CollectionService:GetTagged("MapWave") do
		addWave(inst)
	end
	CollectionService:GetInstanceAddedSignal("MapWave"):Connect(addWave)
	for _, inst in CollectionService:GetTagged("MapCrane") do
		task.spawn(addCrane, inst)
	end
	CollectionService:GetInstanceAddedSignal("MapCrane"):Connect(function(inst)
		task.spawn(addCrane, inst)
	end)
	CollectionService:GetInstanceRemovedSignal("MapCrane"):Connect(function(inst)
		cranes[inst :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("MapWave"):Connect(function(inst)
		waving[inst :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("MapSpin"):Connect(function(inst)
		spinning[inst :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, strips in waving do
			if model.Parent then
				if #strips < 5 then
					-- the strips may still be streaming in: look again until all five are here
					strips = collectStrips(model)
					waving[model] = strips
				end
				for _, st in strips do
					st.part.CFrame = st.base
						* CFrame.new(math.sin(t * 4 - st.k * 0.9) * 0.16 * st.k, 0, 0)
				end
			else
				waving[model] = nil
			end
		end
		-- the camera rides high behind the car: while it is in the tunnel, the deck above turns see-through
		local cam = workspace.CurrentCamera
		if cam then
			local focus = cam.Focus.Position
			for _, deck in CollectionService:GetTagged("ChaseDeck") do
				if deck:IsA("BasePart") then
					local rel = focus - deck.Position
					local inside = math.abs(rel.X) < deck.Size.X / 2
						and math.abs(rel.Z) < deck.Size.Z / 2
						and rel.Y < 0
					deck.LocalTransparencyModifier = if inside then 0.8 else 0
				end
			end
		end
		local now = workspace:GetServerTimeNow()
		for model, c in cranes do
			if model.Parent then
				local a = c.amp * math.sin(now / c.period * 2 * math.pi + c.phase)
				c.swing:PivotTo(
					CFrame.new(c.axis) * CFrame.Angles(0, a, 0) * CFrame.new(-c.axis) * c.rest
				)
			else
				cranes[model] = nil
			end
		end
		for model, s in spinning do
			if model.Parent then
				-- turns about the wheel's own axle (the x axis, through the hub)
				model:PivotTo(
					CFrame.new(s.center)
						* CFrame.Angles(t * s.speed, 0, 0)
						* CFrame.new(-s.center)
						* s.base
				)
			else
				spinning[model] = nil
			end
		end
	end)
end

return MapFx
