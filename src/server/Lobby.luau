--!strict
-- Builds the Car Battle Lobby (carter's reference sheet + 70 picks, docs/LOBBY_SPEC.md) at
-- LobbyConfig.Lobby.origin: 220 x 180 studs of asphalt plaza with the PLAY pads in the middle, the
-- workshop with the giant gumball machine at the back, the customize garage and the shop beside it,
-- the two boards, parked cars, props and a grassy world outside. All positions live in
-- Shared.LobbyLayout; each piece is built by its own module and this file only puts them together.
-- The old warehouse lobby is archived in archive/lobby_v1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyCars = require(ReplicatedStorage.Shared.LobbyCars)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyCustomize = require(script.Parent.LobbyCustomize)
local LobbyBoards = require(script.Parent.LobbyBoards)
local LobbyGround = require(script.Parent.LobbyGround)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyPads = require(script.Parent.LobbyPads)
local LobbyProps = require(script.Parent.LobbyProps)
local LobbyParking = require(script.Parent.LobbyParking)
local LobbyScenery = require(script.Parent.LobbyScenery)
local LobbyShop = require(script.Parent.LobbyShop)
local LobbyShowcase = require(script.Parent.LobbyShowcase)
local LobbyWallSigns = require(script.Parent.LobbyWallSigns)
local LobbyWorkshop = require(script.Parent.LobbyWorkshop)
local Profiles = require(script.Parent.Profiles)
local GumballAnim = require(script.Parent.GumballAnim)

export type LobbyHandle = {
	spawn: SpawnLocation,
	folder: Folder,
	origin: Vector3,
	claw: GumballAnim.Anim, -- the gumball machine show (still called claw: other code reads it)
	parking: LobbyParking.Handle,
	pads: LobbyPads.Pads,
	boards: { weekly: Part, wins: Part },
	showcase: LobbyShowcase.Handle,
}

local Lobby = {}

function Lobby.build(): LobbyHandle
	local origin: Vector3 = LobbyConfig.Lobby.origin

	-- A leftover Lobby (e.g. built in edit mode) would overlap this one and flicker.
	for _, old in workspace:GetChildren() do
		if old.Name == "Lobby" then
			old:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	LobbyScenery.build(folder, origin)
	LobbyGround.build(folder, origin)
	LobbyProps.build(folder, origin)
	LobbyWallSigns.build(folder, origin)
	local pads = LobbyPads.build(folder, origin)
	local workshop = LobbyWorkshop.build(folder, origin)
	local customize = LobbyCustomize.build(folder, origin)
	local shop = LobbyShop.build(folder, origin)
	local boards = LobbyBoards.build(folder, origin)
	local parking = LobbyParking.new(folder, origin)

	local showcase = LobbyShowcase.start(folder, {
		stageRare = workshop.stageRare,
		stageGold = workshop.stageGold,
		goldSign = workshop.goldSign,
		shopSpots = shop.carSpots,
		turntable = customize.turntable,
		turntableCF = customize.turntableCF,
	})

	-- The customize turntable shows the best car of whoever opens the garage.
	local prompt = folder:FindFirstChild("CustomizePrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			local p = Profiles.get(player)
			showcase.setTurntable(LobbyCars.bestOwned(if p then p.owned else {}))
		end)
	end

	-- Spawn: on the front path, looks at the middle of the PLAY pads.
	local sp = LobbyLayout.spawn
	local spawnPos = origin + Vector3.new(sp.x, 0.2, sp.z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(sp.size, 0.4, sp.size)
	spawn.CFrame =
		CFrame.lookAt(spawnPos, origin + Vector3.new(LobbyLayout.ring.x, 0.2, LobbyLayout.ring.z))
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Transparency = 1 -- the path is the spawn: nothing to see
	spawn.CanQuery = false
	spawn.Parent = folder

	folder.Parent = workspace
	return {
		spawn = spawn,
		folder = folder,
		origin = origin,
		claw = workshop.anim,
		parking = parking,
		pads = pads,
		boards = boards,
		showcase = showcase,
	}
end

return Lobby
