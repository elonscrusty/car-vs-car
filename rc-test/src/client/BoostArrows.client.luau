--!strict
-- The glowing orange arrows on each ramp (server/ArenaBuilder, tag ArenaData.BOOST_TAG, attribute
-- "U" = how far up the ramp, 0..1) light up one after the other, bottom to top, again and again.
-- Looks only: it sets colour and see-through on this screen, nothing else.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaData = require(ReplicatedStorage.Shared.ArenaData)

local DIM = Color3.fromRGB(120, 66, 12)
local LIT = Color3.fromRGB(255, 176, 46)
local SPEED = 6 -- pulses per 2*pi seconds: one sweep up the ramp about every second
local SPREAD = 9 -- how far the pulse lags per unit up the ramp

local arrows: { [BasePart]: number } = {}

local function add(inst: Instance)
	local u = inst:GetAttribute("U")
	if inst:IsA("BasePart") and type(u) == "number" then
		arrows[inst] = u
	end
end

for _, a in CollectionService:GetTagged(ArenaData.BOOST_TAG) do
	add(a)
end
CollectionService:GetInstanceAddedSignal(ArenaData.BOOST_TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(ArenaData.BOOST_TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		arrows[inst] = nil
	end
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for arrow, u in arrows do
		local k = math.max(0, math.sin(t * SPEED - u * SPREAD))
		arrow.Color = DIM:Lerp(LIT, k)
		arrow.Transparency = 0.55 - 0.55 * k
	end
end)
