--!strict
-- Small "Invite a friend" button on the end screen after a WIN. Uses Roblox's own invite prompt:
-- SocialService:CanSendGameInviteAsync (yields, so pcall) then SocialService:PromptGameInvite.
-- Nothing is sent by us; Roblox shows its friend picker. If invites are not allowed for this player
-- or place, the button stays hidden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local UiLayoutConfig = require(ReplicatedStorage.Shared.UiLayoutConfig)
local UiStyle = require(script.Parent.UiStyle)

local InviteUi = {}

export type InviteUi = { setVisible: (show: boolean) -> () }

local function canInvite(player: Player): boolean
	local ok, result = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return ok and result == true
end

-- `parent` = the end screen frame (the button hides with it). Call setVisible(true) after a win.
function InviteUi.new(parent: GuiObject): InviteUi
	local player = Players.LocalPlayer
	local button = Instance.new("TextButton")
	button.Name = "InviteButton"
	UiStyle.place(button, UiLayout.endScreen().invite)
	UiStyle.textLimit(button, UiLayoutConfig.minText, 26)
	button.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	button.Text = "Invite a friend"
	button.TextScaled = true
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Visible = false
	button.ZIndex = 10
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button

	local busy = false
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		-- The prompt itself is Roblox UI; it may fail (offline, blocked): that is fine, ignore it.
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
		task.delay(2, function()
			busy = false
		end)
	end)

	local checkId = 0
	local self: InviteUi = {
		setVisible = function(show: boolean)
			checkId += 1
			local mine = checkId
			if not show then
				button.Visible = false
				return
			end
			task.spawn(function()
				local allowed = canInvite(player)
				if mine == checkId then
					button.Visible = allowed
				end
			end)
		end,
	}
	return self
end

return InviteUi
