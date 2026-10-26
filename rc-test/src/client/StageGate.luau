--!strict
-- One new thing at a time (JoinStage): a screen piece goes in a see-through, full-size holder
-- that shows only once the player's Stage reaches that piece's stage. The script that made the
-- piece keeps setting its own Visible as before; the holder only adds "not yet". The holder is
-- the same size as the old parent, so scale positions (HudLayout) land in the same spot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local JoinStage = require(ReplicatedStorage.Shared.JoinStage)

local StageGate = {}

local player = Players.LocalPlayer

-- pieces of a part the tycoon plan switched off (Features): never shown, at any stage
local OFF: { [string]: boolean } = {
	stars = not Features.STARS,
	top3 = not Features.PLOT_RACING,
	visit = not Features.PLOT_RACING,
	friends = not Features.PLOT_RACING, -- let others drive your plot
	quick = not Features.PLOT_RACING, -- QUICK RACE on a free plot
	looks = not Features.STARS, -- plot looks were bought with stars
}

function StageGate.shows(name: string): boolean
	return not OFF[name] and JoinStage.shows(player:GetAttribute("Stage"), name)
end

-- call fn now and each time the stage moves up
function StageGate.watch(fn: () -> ())
	player:GetAttributeChangedSignal("Stage"):Connect(fn)
	fn()
end

-- put obj in a holder that hides it until the stage for `name`
function StageGate.hold(obj: GuiObject, name: string): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Stage_" .. name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Position = UDim2.fromScale(0, 0)
	holder.ZIndex = obj.ZIndex
	holder.Parent = obj.Parent
	obj.Parent = holder
	StageGate.watch(function()
		holder.Visible = StageGate.shows(name)
	end)
	return holder
end

return StageGate
