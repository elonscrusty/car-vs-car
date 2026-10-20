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

local function addWave(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local strips = {}
	for _, c in inst:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Strip(%d+)$"))
		if n ~= nil and c:IsA("BasePart") then
			table.insert(strips, { part = c, base = c.CFrame, k = n })
		end
	end
	waving[inst] = strips
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
				for _, st in strips do
					st.part.CFrame = st.base
						* CFrame.new(math.sin(t * 4 - st.k * 0.9) * 0.16 * st.k, 0, 0)
				end
			else
				waving[model] = nil
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
