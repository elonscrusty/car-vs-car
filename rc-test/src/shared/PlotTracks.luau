--!strict
-- Keeps LobbyLayout.custom in step with the plots: a plot whose owner built their own track
-- carries its driving data as JSON in the plot model's "TrackJson" attribute (set by the server
-- when the track is rebuilt). Server and players both watch it; `onChange(slot)` runs after a
-- plot's data changed, so a screen can refresh its copy of that track.

local HttpService = game:GetService("HttpService")

local LobbyLayout = require(script.Parent.LobbyLayout)

local PlotTracks = {}

-- The server's side: set (or clear, with nil) a plot's own driving data.
function PlotTracks.set(slotIndex: number, data: any?)
	local slot = LobbyLayout.slots()[slotIndex]
	local plot = slot and workspace.Plots:FindFirstChild(slotIndex .. "_" .. slot.id)
	if plot then
		plot:SetAttribute("TrackJson", if data then HttpService:JSONEncode(data) else nil)
	end
end

function PlotTracks.watch(onChange: ((slotIndex: number) -> ())?)
	local plots = workspace:WaitForChild("Plots")
	local function read(slotIndex: number, plot: Instance)
		local json = plot:GetAttribute("TrackJson")
		local ok, data = false, nil
		if type(json) == "string" and json ~= "" then
			ok, data = pcall(HttpService.JSONDecode, HttpService, json)
		end
		LobbyLayout.custom[slotIndex] = if ok then data else nil
		if onChange then
			onChange(slotIndex)
		end
	end
	for i, slot in LobbyLayout.slots() do
		task.spawn(function()
			local plot = plots:WaitForChild(i .. "_" .. slot.id, 30)
			if plot then
				plot:GetAttributeChangedSignal("TrackJson"):Connect(function()
					read(i, plot)
				end)
				if plot:GetAttribute("TrackJson") ~= nil then
					read(i, plot)
				end
			end
		end)
	end
end

return PlotTracks
