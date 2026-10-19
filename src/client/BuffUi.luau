--!strict
-- Shows your active power-ups at the top of the screen: a colored rounded square with a letter
-- and a bar that runs down. The server decides everything; this only displays "buff" updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PickupsConfig = require(ReplicatedStorage.Shared.PickupsConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local BuffUi = {}

export type BuffUi = {
	handleUpdate: (u: Types.UiUpdate) -> (),
	clear: () -> (),
}

function BuffUi.new(): BuffUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuffUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 214) -- under the scoreboard and the mode line
	row.Size = UDim2.fromOffset(0, 64)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row

	local icons: { [string]: Frame } = {}

	local function remove(kind: string)
		local icon = icons[kind]
		if icon then
			icon:Destroy()
			icons[kind] = nil
		end
	end

	local function show(kind: string, seconds: number)
		remove(kind) -- a refresh starts the bar again
		local c = (PickupsConfig.colors :: any)[kind] or { 255, 255, 255 }
		local icon = Instance.new("Frame")
		icon.Name = kind
		icon.Size = UDim2.fromOffset(84, 52)
		icon.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = icon
		local letter = Instance.new("TextLabel")
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.new(1, 0, 1, -10)
		letter.Font = Enum.Font.FredokaOne
		letter.TextScaled = true
		letter.TextColor3 = Color3.new(1, 1, 1)
		letter.Text = (PickupsConfig.names :: any)[kind] or "?"
		letter.Parent = icon
		local track = Instance.new("Frame")
		track.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		track.BackgroundTransparency = 0.4
		track.BorderSizePixel = 0
		track.Position = UDim2.new(0, 4, 1, -9)
		track.Size = UDim2.new(1, -8, 0, 5)
		track.Parent = icon
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 1)
		bar.Parent = track
		icon.Parent = row
		icons[kind] = icon
		-- Big name in the middle of the screen for a moment: "you got SHIELD".
		local toast = Instance.new("TextLabel")
		toast.AnchorPoint = Vector2.new(0.5, 0.5)
		toast.Position = UDim2.fromScale(0.5, 0.3)
		toast.Size = UDim2.fromOffset(300, 56)
		toast.BackgroundTransparency = 1
		toast.Font = Enum.Font.FredokaOne
		toast.TextScaled = true
		toast.TextColor3 = icon.BackgroundColor3
		toast.TextStrokeTransparency = 0
		toast.Text = (PickupsConfig.names :: any)[kind] or kind
		toast.Parent = gui
		TweenService:Create(toast, TweenInfo.new(1.1), {
			Position = UDim2.fromScale(0.5, 0.24),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.2, function()
			toast:Destroy()
		end)
		TweenService:Create(
			bar,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, 1) }
		):Play()
	end

	return {
		handleUpdate = function(u: Types.UiUpdate)
			if u.kind ~= "buff" or u.buff == nil then
				return
			end
			local seconds = u.seconds or 0
			if seconds > 0 then
				show(u.buff, seconds)
			else
				remove(u.buff)
			end
		end,
		clear = function()
			for kind in icons do
				remove(kind)
			end
		end,
	}
end

return BuffUi
