--!strict
-- Car VS Car: the RACE ME! button (carter's pick 42, 10-26). Opens Roblox's invite screen so you
-- can ask your friends in; a friend in the same server pays you both the friend coins
-- (FriendBonus on the server, Profile.FRIEND_COINS), which the small line under it says. Only
-- with Features.CVC on, on foot, after you've picked your car, and only where Roblox lets this
-- player send invites.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Profile = require(Shared:WaitForChild("Profile"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))

local player = Players.LocalPlayer

local hud = Instance.new("ScreenGui")
hud.Name = "CvcInvite"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")

local invite = CvcUi.button(hud, "RACE ME!", KartStyle.PINK)
invite.Name = "Invite"
HudLayout.place(invite, "Invite")
invite.Visible = false
CvcUi.rim(invite, KartStyle.BUTTON_RIM)

-- under it: what a friend is worth
local worth = CvcUi.label(invite, `+{Profile.FRIEND_COINS} EACH!`, KartStyle.YELLOW)
worth.Name = "Worth"
worth.AnchorPoint = Vector2.new(0.5, 0)
worth.Position = UDim2.new(0.5, 0, 1, 4)
worth.Size = UDim2.new(1, 0, 0.5, 0)
local worthRim = Instance.new("UIStroke")
worthRim.Color = KartStyle.INK
worthRim.Thickness = 2
worthRim.Parent = worth

local canInvite = false
local asking = false

local function show()
	invite.Visible = canInvite
		and player:GetAttribute("Picked") == true
		and player:GetAttribute("Driving") ~= true
		and player:GetAttribute("Racing") ~= true
end
for _, a in { "Picked", "Driving", "Racing" } do
	player:GetAttributeChangedSignal(a):Connect(show)
end

invite.Activated:Connect(function()
	if asking then
		return
	end
	asking = true
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Race me in Car VS Car!"
		SocialService:PromptGameInvite(player, options)
	end)
	if not ok then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
	task.delay(1, function()
		asking = false
	end)
end)

-- Roblox says whether this player may send invites (not every account can); it asks the web, so
-- off the main thread, and once more a bit later if it failed
task.spawn(function()
	for _ = 1, 2 do
		local ok, yes = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok then
			canInvite = yes == true
			show()
			return
		end
		task.wait(10)
	end
end)
