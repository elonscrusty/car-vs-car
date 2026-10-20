--!strict
-- A small message at the top of the screen when someone in the game pulls a rare car from the gumball
-- machine (carter's L51). It is not in the chat: a pill slides down under the top bar, stays a few
-- seconds and slides away. Messages wait their turn, one at a time. Look only: the server decides
-- what is rare and sends the text (LobbyService "announce").

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RareBanner = {}

export type Banner = {
	show: (text: string, rgb: { number }) -> (),
}

local NAVY = Color3.fromRGB(5, 23, 45)
local WHITE = Color3.fromRGB(251, 253, 255)
local FONT = Font.fromEnum(Enum.Font.Bangers)
local SHOW_SECONDS = 5
local SLIDE_SECONDS = 0.35
local MAX_WAITING = 3 -- a flood of pulls does not build a long queue
local TOP = 66 -- below the top bar and the tutorial's SKIP pill

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function RareBanner.new(): Banner
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = make("ScreenGui", {
		Name = "CVC_RareBanner",
		ResetOnSpawn = false,
		DisplayOrder = 38,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local pill: Frame = make("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, pill)
	local stroke: UIStroke = make("UIStroke", {
		Thickness = 3,
		Color = WHITE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, pill)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, pill)
	make("UISizeConstraint", { MaxSize = Vector2.new(560, 200) }, pill)
	local label: TextLabel = make("TextLabel", {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		TextWrapped = true,
		Text = "",
	}, pill)
	make("UISizeConstraint", { MaxSize = Vector2.new(500, 160) }, label)

	local waiting: { { text: string, rgb: { number } } } = {}
	local busy = false

	local function play()
		local item = table.remove(waiting, 1)
		if item == nil then
			busy = false
			return
		end
		busy = true
		label.Text = item.text
		stroke.Color = Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3])
		pill.Position = UDim2.new(0.5, 0, 0, -80)
		pill.Visible = true
		TweenService:Create(
			pill,
			TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, TOP) }
		):Play()
		task.delay(SHOW_SECONDS, function()
			TweenService:Create(
				pill,
				TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(0.5, 0, 0, -80) }
			):Play()
			task.delay(SLIDE_SECONDS, function()
				pill.Visible = false
				play()
			end)
		end)
	end

	local self = {} :: Banner
	self.show = function(text: string, rgb: { number })
		if #waiting >= MAX_WAITING then
			return
		end
		table.insert(waiting, { text = text, rgb = rgb })
		if not busy then
			play()
		end
	end
	return self
end

return RareBanner
