--!strict
-- Every button on this screen answers a tap at once: a quick squish while pressed, a bounce back,
-- and one soft click (Sfx.tap). One place for all of them (any TextButton or ImageButton added to PlayerGui),
-- so a new button gets it too. GAS, BRAKE and the steer pad are Frames, not buttons: left alone.
-- A button opts out with the attribute NoTap = true.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local SQUISH = 0.9 -- size while held
local DOWN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local lastTick = 0
local function playTick()
	-- one tick per tap, even when two buttons hear the same press
	if os.clock() - lastTick < 0.05 then
		return
	end
	lastTick = os.clock()
	Sfx.tap()
end

-- (a table, not an attribute: a button cloned from a hooked one must be hooked too)
local hooked: { [Instance]: boolean } = {}

local function hook(b: Instance)
	if not b:IsA("GuiButton") or hooked[b] or b:GetAttribute("NoTap") == true then
		return
	end
	hooked[b] = true
	b.Destroying:Connect(function()
		hooked[b] = nil
	end)
	-- a button that scales itself (a popping chip) keeps its own UIScale: tick only
	-- (only one UIScale works on a button, so ours goes if one of its own comes later;
	-- a TapScale cloned along from another button is taken over)
	local scale: UIScale? = nil
	local copied = b:FindFirstChild("TapScale")
	if copied and copied:IsA("UIScale") then
		scale = copied
		copied.Scale = 1
	elseif not b:FindFirstChildOfClass("UIScale") then
		local s = Instance.new("UIScale")
		s.Name = "TapScale"
		s.Parent = b
		scale = s
		b.ChildAdded:Connect(function(c: Instance)
			if c:IsA("UIScale") and c ~= s and scale then
				scale = nil
				s:Destroy()
			end
		end)
	end
	local held = false
	b.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		if scale and b.Active then
			held = true
			TweenService:Create(scale, DOWN, { Scale = SQUISH }):Play()
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		if scale and held then
			held = false
			TweenService:Create(scale, UP, { Scale = 1 }):Play()
		end
	end)
	b.Activated:Connect(function()
		if b.Active then
			playTick()
		end
	end)
end

local pgui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, d in pgui:GetDescendants() do
	hook(d)
end
pgui.DescendantAdded:Connect(function(d: Instance)
	task.defer(hook, d) -- after the code making it has added its own parts (a UIScale)
end)
