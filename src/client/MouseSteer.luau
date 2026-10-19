--!strict
-- Keyboard + mouse driving: hold the RIGHT mouse button and the cursor steers (left of the screen
-- middle = left, right = right); W / S are still the gas and brake. Let go and A / D steer as usual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FeelRules = require(ReplicatedStorage.Shared.FeelRules)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type MouseSteer = {
	read: () -> number?, -- steer -1..1 while the right button is held, else nil
}

local MouseSteer = {}

function MouseSteer.new(): MouseSteer
	local held = false
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			held = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			held = false
		end
	end)
	-- Losing focus can swallow the release.
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
	end)

	local function read(): number?
		if not held then
			return nil
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		local width = math.max(1, camera.ViewportSize.X)
		local x = UserInputService:GetMouseLocation().X
		local feel = GameConfig.Feel
		return FeelRules.mouseSteer((x - width / 2) / width, feel.mouseDead, feel.mouseFull)
	end

	return { read = read }
end

return MouseSteer
