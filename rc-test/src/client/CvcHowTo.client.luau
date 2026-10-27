--!strict
-- Car VS Car how-to (carter 10-26, rc-game/cvc-plan.md): one bouncing arrow at a time, pointing at
-- the button to tap next, with big words by it. Only with Features.CVC on.
--   racing        -> BOOST       "TAP TO GO FAST!"
--   a crate       -> CRATE       "OPEN YOUR CRATE!"
--   a car trains  -> COACH       "TRAIN YOUR CAR!"  (until you coach once)
--   no race yet   -> JOIN        "RACE!"
--   after that    -> MY GARAGE   "SEE YOUR CAR GET BETTER!" (until you open it once)
-- Each one goes once you've done it (this visit); the race and crate ones follow the game.
-- Only ever ONE arrow (carter's pick 2): none while the road guide (PlotGuide) is talking.
-- SKIP turns the tips off for this visit (pick 3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CvcLayout = require(Shared:WaitForChild("CvcLayout"))
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

-- AbsolutePosition starts under Roblox's top bar, but this gui's offsets start at the screen's
-- top (IgnoreGuiInset): this corner says where the screen's top left is in AbsolutePosition terms
-- (without it the tip sat 58 px high: the arrow on CRATE!, Studio final-10)
local origin = Instance.new("Frame")
origin.Name = "Kart_Origin"
origin.BackgroundTransparency = 1
origin.Size = UDim2.fromOffset(0, 0)
origin.Parent = gui

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

local skip = CvcUi.button(gui, "SKIP", Color3.fromRGB(110, 110, 120))
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(0.5, 0.5)
skip.Size = UDim2.fromOffset(76, 44)
skip.Visible = false
local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

-- a button another Car VS Car script made: PlayerGui.<gui>.<name>
-- (anywhere in it: Stars keeps the JOBS chip in a frame that comes after your first drive)
local function find(guiName: string, name: string): GuiObject?
	local g = playerGui:FindFirstChild(guiName)
	local b = g and g:FindFirstChild(name, true)
	return if b and b:IsA("GuiObject") then b else nil
end

-- on the screen: it, and every frame it sits in, shown
local function shown(b: GuiObject?): boolean
	if not b then
		return false
	end
	local at: Instance? = b
	while at and not at:IsA("ScreenGui") do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		end
		at = at.Parent
	end
	return at ~= nil and (at :: ScreenGui).Enabled
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

-- the Car VS Car buttons a tip must never cover
local AVOID = {
	{ "Cvc", "Coach" },
	{ "CvcRace", "BigJoin" },
	{ "CvcCrateButton", "CrateButton" },
	{ "CvcGarageButton", "GarageButton" },
}

-- the JOBS 1/3 chip (Stars) sits right under CRATE! and MY GARAGE: the tip keeps clear of it
-- when it can, and else the chip steps away while the tip shows (the arrow covered its 2/3,
-- Studio final-31)
local function hideJobs(on: boolean)
	if (player:GetAttribute("TipHidesJobs") == true) ~= on then
		player:SetAttribute("TipHidesJobs", on)
	end
end

type Tip = { target: GuiObject, text: string, below: boolean, drive: boolean? }

-- the one tip to show now (nil = none)
local function pick(): Tip?
	if skipped or not CvcState.loaded or player:GetAttribute("Picked") ~= true then
		return nil
	end
	-- the road guide's words are up (the walk to the crate shop): one arrow at a time
	local road = playerGui:FindFirstChild("PlotGuide")
	if road and road:IsA("ScreenGui") and road.Enabled then
		return nil
	end
	if panelOpen("CvcGarage") then
		garageSeen = true
	end
	local boost = find("CvcRace", "Boost")
	if player:GetAttribute("Racing") == true then
		if not boosted and not raced() and shown(boost) and boost then
			return { target = boost, text = "TAP TO GO FAST!", below = false, drive = true }
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
		return { target = coach, text = "TRAIN YOUR CAR!", below = true }
	end
	local join = find("CvcRace", "BigJoin")
	if not raced() and player:GetAttribute("RaceJoined") ~= true and shown(join) and join then
		return { target = join, text = "RACE!", below = false }
	end
	local garage = find("CvcGarageButton", "GarageButton")
	if raced() and not garageSeen and shown(garage) and garage then
		return { target = garage, text = "SEE YOUR CAR GET BETTER!", below = true }
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local tip = pick()
	-- (the open jobs list: you opened it to read it, so the tip waits until it folds again; it
	-- sat under the tip, Studio final-47)
	local jobs = find("StarsHud", "DailyJobs")
	if tip and jobs and shown(jobs) and jobs:GetAttribute("Open") == true then
		tip = nil
	end
	arrow.Visible = tip ~= nil
	words.Visible = tip ~= nil
	skip.Visible = tip ~= nil
	if not tip then
		hideJobs(false)
		return
	end
	-- it glows: yellow to white and back
	local glow = 0.5 + 0.5 * math.sin(os.clock() * 5)
	arrow.TextColor3 = KartStyle.YELLOW:Lerp(KartStyle.WHITE, glow * 0.7)
	local o = origin.AbsolutePosition
	local p, s = tip.target.AbsolutePosition - o, tip.target.AbsoluteSize
	local bob = math.abs(math.sin(os.clock() * 4)) * 10
	-- the other Car VS Car buttons on screen: the tip never covers them (CvcLayout.tip)
	local avoid = {}
	if tip.drive then
		-- in a race: clear of every driving chip and button (the lap box with "5TH OF 8", DRIFT...)
		for _, spot in HudLayout.SPOTS do
			if spot.mode == "drive" and not spot.off and CvcLayout.boostAvoids(spot.name) then
				local l, t, r, b = HudLayout.box(spot, gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
				table.insert(avoid, { l, t, r, b })
			end
		end
	end
	for _, it in AVOID do
		local b = find(it[1], it[2])
		if b and b ~= tip.target and shown(b) then
			local bp, bs = b.AbsolutePosition - o, b.AbsoluteSize
			table.insert(avoid, { bp.X, bp.Y, bp.X + bs.X, bp.Y + bs.Y })
		end
	end
	local size = gui.AbsoluteSize
	local target = { p.X, p.Y, p.X + s.X, p.Y + s.Y }
	-- (its box even while it has stepped away: whether the tip still needs it to; it lives in
	-- StarsHud: looking in "Stars" never found it, so it never stepped away, Studio final-50)
	local jobsHas = jobs ~= nil
		and (shown(jobs) or player:GetAttribute("TipHidesJobs") == true and jobs.Parent ~= nil)
	local spot = CvcLayout.tip(target, tip.below, size.X, size.Y, avoid)
	if jobs and jobsHas then
		local jp, js = jobs.AbsolutePosition - o, jobs.AbsoluteSize
		local spotJ = CvcLayout.tipClearOf(target, tip.below, size.X, size.Y, avoid, {
			jp.X,
			jp.Y,
			jp.X + js.X,
			jp.Y + js.Y,
		})
		hideJobs(spotJ == nil)
		spot = spotJ or spot
	else
		hideJobs(false)
	end
	local function centre(r: { number }): (number, number)
		return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	end
	local ax, ay = centre(spot.arrow)
	-- (the ▼ points at the button: up from under it, down from over it, right from its left)
	if spot.side == "under" then
		arrow.Rotation = 180
		arrow.Position = UDim2.fromOffset(ax, ay + bob)
	elseif spot.side == "left" then
		arrow.Rotation = -90
		arrow.Position = UDim2.fromOffset(ax - bob, ay)
	else
		arrow.Rotation = 0
		arrow.Position = UDim2.fromOffset(ax, ay - bob)
	end
	local wx, wy = centre(spot.words)
	words.Size = UDim2.fromOffset(spot.words[3] - spot.words[1], spot.words[4] - spot.words[2])
	words.Position = UDim2.fromOffset(wx, wy)
	words.Text = tip.text
	local sx, sy = centre(spot.skip)
	skip.Position = UDim2.fromOffset(sx, sy)
end)
