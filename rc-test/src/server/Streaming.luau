--!strict
-- Phone speed: when Workspace.StreamingEnabled is on, the phone only keeps the parts near it.
-- The lobby, the plots and the race maps are small enough to want always loaded (scripts wait on
-- them by name), so their models are marked Persistent. Harmless while streaming is off.

local Streaming = {}

local function persist(model: Instance)
	if model:IsA("Model") then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
end

-- Call once after everything is built.
function Streaming.persist()
	for _, name in { "Plots", "RaceMaps", "Lobby" } do
		local root = workspace:FindFirstChild(name)
		if root then
			persist(root)
			for _, child in root:GetChildren() do
				persist(child)
			end
		end
	end
end

return Streaming
