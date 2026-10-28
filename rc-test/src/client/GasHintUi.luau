--!strict
-- The big pulsing HOLD GAS! (GasHint): on a phone it sits over the GAS button with an arrow down
-- to it, on a computer in the middle under the lap clock.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage.Shared.Features)
local GasHint = require(ReplicatedStorage.Shared.GasHint)

local GasHintUi = {}

function GasHintUi.new(gui: ScreenGui): { set: (on: boolean) -> () }
	local touch = UserInputService.TouchEnabled
	local label = Instance.new("TextLabel")
	label.Name = "GasHint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.fromScale(0.34, 0.11)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 120)
	label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	label.TextStrokeTransparency = 0
	-- words for the buttons on screen: a GAS button there (a phone, a tablet) = HOLD GAS!, never
	-- a key a phone hasn't got (critic REPORT-1 saw HOLD W TO GO! on a phone screen)
	local shownTouch: boolean? = nil
	local function setWords(t: boolean)
		if t ~= shownTouch then
			shownTouch = t
			label.Text = GasHint.words(t) .. (if t then "\n▼" else "")
		end
	end
	setWords(touch)
	label.ZIndex = 20
	label.Visible = false
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = label

	local on = false
	RunService.RenderStepped:Connect(function()
		if not on then
			return
		end
		-- over the GAS button when there is one (Controls makes it, named GAS), else mid-screen
		local gas = gui:FindFirstChild("GAS")
		local hasGas = gas ~= nil and gas:IsA("GuiObject") and gas.Visible
		setWords(
			hasGas
				or touch
				or UserInputService:GetLastInputType() == Enum.UserInputType.Touch
				or not UserInputService.KeyboardEnabled
		)
		if hasGas and gas and gas:IsA("GuiObject") then
			local p, s = gas.AbsolutePosition, gas.AbsoluteSize
			label.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y - 4)
			label.Size = UDim2.fromOffset(math.max(s.X * 1.6, 160), math.max(s.Y * 0.55, 50))
		else
			label.Position = UDim2.fromScale(0.5, 0.42)
			label.Size = UDim2.fromScale(0.4, 0.1)
		end
		scale.Scale = 1 + 0.12 * math.abs(math.sin(os.clock() * 5))
	end)

	return {
		set = function(show: boolean)
			-- (SMASH: no GAS button, the stick is the gas; the hint would point at nothing)
			show = show and (Features :: any).SMASH ~= true
			on = show
			label.Visible = show
		end,
	}
end

return GasHintUi
