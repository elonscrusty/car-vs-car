--!strict
-- Car VS Car how-to (carter 10-26, rc-game/cvc-plan.md): one bouncing arrow at a time, pointing at
-- the button to tap next, with big words by it. Only with Features.CVC on.
--   racing        -> BOOST       "TAP TO GO FAST!"
--   a crate       -> CRATE       "OPEN YOUR CRATE!"
--   a car trains  -> COACH       "TAP TO TRAIN 2X!"  (until you coach once)
--   no race yet   -> JOIN        "JOIN THE BIG RACE!"
--   after that    -> MY GARAGE   "SEE YOUR CAR GET BETTER!" (until you open it once)
-- Each one goes once you've done it (this visit); the race and crate ones follow the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Profile = require(Shared:WaitForChild("Profile"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Popup = require(script.Parent:WaitForChild("Popup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local INK = KartStyle.INK

CvcState.start()

local gui = Instance.new("ScreenGui")
gui.Name = "CvcHowTo"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = HudLayout.HUD + 1 -- over the buttons, under the popups
gui.Parent = playerGui

local arrow = CvcUi.label(gui, "▼", KartStyle.YELLOW)
arrow.Name = "Arrow"
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Size = UDim2.fromOffset(54, 54)
arrow.Visible = false
local arrowRim = Instance.new("UIStroke")
arrowRim.Color = INK
arrowRim.Thickness = 3
arrowRim.Parent = arrow

local words = CvcUi.label(gui, "", KartStyle.WHITE)
words.Name = "Words"
words.AnchorPoint = Vector2.new(0.5, 0.5)
words.Size = UDim2.fromOffset(300, 40)
words.Visible = false
local wordsRim = Instance.new("UIStroke")
wordsRim.Color = INK
wordsRim.Thickness = 3
wordsRim.Parent = words

-- a button another Car VS Car script made: PlayerGui.<gui>.<name>
local function find(guiName: string, name: string): GuiObject?
	local g = playerGui:FindFirstChild(guiName)
	local b = g and g:FindFirstChild(name)
	return if b and b:IsA("GuiObject") then b else nil
end

local function shown(b: GuiObject?): boolean
	if not b or not b.Visible then
		return false
	end
	local g = b:FindFirstAncestorOfClass("ScreenGui")
	return g ~= nil and g.Enabled
end

local function panelOpen(guiName: string): boolean
	local p = find(guiName, "Panel")
	return p ~= nil and p.Visible
end

-- done this visit
local coached = false
local garageSeen = false
local boosted = false
player:GetAttributeChangedSignal("CoachAt"):Connect(function()
	coached = true
end)
player:GetAttributeChangedSignal("BoostOn"):Connect(function()
	if player:GetAttribute("BoostOn") == true then
		boosted = true
	end
end)

local function raced(): boolean
	local s = player:GetAttribute("Stage")
	return type(s) == "number" and s >= Profile.STAGE.RACED
end

type Tip = { target: GuiObject, text: string, below: boolean }

-- the one tip to show now (nil = none)
local function pick(): Tip?
	if not CvcState.loaded or player:GetAttribute("Picked") ~= true then
		return nil
	end
	if panelOpen("CvcGarage") then
		garageSeen = true
	end
	local boost = find("CvcRace", "Boost")
	if player:GetAttribute("Racing") == true then
		if not boosted and not raced() and shown(boost) and boost then
			return { target = boost, text = "TAP TO GO FAST!", below = false }
		end
		return nil
	end
	if Popup.isOpen() then
		return nil
	end
	local crate = find("CvcCrateButton", "CrateButton")
	if shown(crate) and crate then
		return { target = crate, text = "OPEN YOUR CRATE!", below = true }
	end
	local coach = find("Cvc", "Coach")
	if not coached and shown(coach) and coach then
		return { target = coach, text = "TAP TO TRAIN 2X!", below = true }
	end
	local join = find("CvcRace", "BigJoin")
	if not raced() and player:GetAttribute("RaceJoined") ~= true and shown(join) and join then
		return { target = join, text = "JOIN THE BIG RACE!", below = false }
	end
	local garage = find("CvcGarageButton", "GarageButton")
	if raced() and not garageSeen and shown(garage) and garage then
		return { target = garage, text = "SEE YOUR CAR GET BETTER!", below = true }
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local tip = pick()
	arrow.Visible = tip ~= nil
	words.Visible = tip ~= nil
	if not tip then
		return
	end
	local p, s = tip.target.AbsolutePosition, tip.target.AbsoluteSize
	local bob = math.abs(math.sin(os.clock() * 4)) * 10
	local cx = p.X + s.X / 2
	local w = math.min(300, gui.AbsoluteSize.X - 24)
	words.Size = UDim2.fromOffset(w, 40)
	-- keep the words on the screen
	local wx = math.clamp(cx, w / 2 + 12, gui.AbsoluteSize.X - w / 2 - 12)
	if tip.below then
		-- the button is up top: the arrow under it points up, the words under the arrow
		arrow.Rotation = 180
		arrow.Position = UDim2.fromOffset(cx, p.Y + s.Y + 30 + bob)
		words.Position = UDim2.fromOffset(wx, p.Y + s.Y + 80)
	else
		-- the button is down low: the arrow over it points down, the words over the arrow
		arrow.Rotation = 0
		arrow.Position = UDim2.fromOffset(cx, p.Y - 30 - bob)
		words.Position = UDim2.fromOffset(wx, p.Y - 80)
	end
	words.Text = tip.text
end)
