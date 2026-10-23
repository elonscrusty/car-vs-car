--!strict
-- Puts each plot owner's cars on the three stands at their plot (PlotStands has the layout).
-- The cars someone has: their player attribute "Cars" ("race:1,drift:2"), set by the car shop
-- once buying exists; until then the first car of the plot's kind. Rebuilt when the plot's
-- owner or that list changes. A plot nobody owns shows empty stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotStands = require(ReplicatedStorage.Shared.PlotStands)
local LobbyPlots = require(script.Parent.LobbyPlots)

local PlotStandsBuilder = {}

function PlotStandsBuilder.start()
	local slots = LobbyLayout.slots()
	local shown: { [number]: string } = {} -- what each plot's stands show now
	local watching: { [Player]: RBXScriptConnection } = {}

	local function rebuild(slot: number)
		local s = slots[slot]
		local plot = workspace.Plots:FindFirstChild(slot .. "_" .. s.id)
		if not plot then
			return
		end
		local owner = LobbyPlots.ownerOf(slot)
		local list = if owner then tostring(owner:GetAttribute("Cars") or "") else nil
		local key = if owner then owner.UserId .. "|" .. (list :: string) else "-"
		if shown[slot] == key then
			return
		end
		shown[slot] = key
		local old = plot:FindFirstChild("Stands")
		if old then
			old:Destroy()
		end
		local cars = if owner then PlotStands.parse(list, s.id) else {}
		local model = Instance.new("Model")
		model.Name = "Stands"
		local pivot = CFrame.new(s.plotX, 0, s.plotZ) * CFrame.Angles(0, s.angle, 0)
		Garage.makeParts(PlotStands.pieces(cars), model, pivot)
		model.Parent = plot
		-- follow the owner's list
		if owner and not watching[owner] then
			watching[owner] = owner:GetAttributeChangedSignal("Cars"):Connect(function()
				local mine = LobbyPlots.slotOf(owner)
				if mine then
					rebuild(mine)
				end
			end)
			owner.AncestryChanged:Connect(function()
				if not owner.Parent and watching[owner] then
					watching[owner]:Disconnect()
					watching[owner] = nil
				end
			end)
		end
	end

	for i in slots do
		rebuild(i)
	end
	LobbyPlots.changed:Connect(rebuild)
end

return PlotStandsBuilder
