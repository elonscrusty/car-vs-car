--!strict
-- Words over the 3D world read on bright sky and white roads too: any text with nothing behind
-- it (its own background and every frame above it see-through) gets a dark outline. Words on a
-- panel or a button already have their backing and are left as they are. One place for all of
-- them, so new words get it too. Opt out with the attribute NoOutline = true.
local Players = game:GetService("Players")

local OUTLINE = Color3.fromRGB(15, 15, 20)

-- nothing solid behind it, up to its ScreenGui / BillboardGui
local function overWorld(t: GuiObject): boolean
	if t.BackgroundTransparency < 0.6 then
		return false
	end
	local p = t.Parent
	while p and p:IsA("GuiObject") do
		if p.BackgroundTransparency < 0.6 then
			return false
		end
		p = p.Parent
	end
	return true
end

local function fix(d: Instance)
	if not (d:IsA("TextLabel") or d:IsA("TextButton")) then
		return
	end
	if d:GetAttribute("NoOutline") == true or d:FindFirstChildOfClass("UIStroke") then
		return
	end
	if d.TextStrokeTransparency < 1 or not overWorld(d) then
		return -- already outlined, or on a panel
	end
	d.TextStrokeColor3 = OUTLINE
	d.TextStrokeTransparency = 0.35
end

local pgui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, d in pgui:GetDescendants() do
	fix(d)
end
pgui.DescendantAdded:Connect(function(d: Instance)
	task.defer(fix, d) -- once its maker has set its colours and parent
end)
