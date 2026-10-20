--!strict
-- What every player in the lobby gets: a faster walk (LobbyLayout.walkSpeed) and a name tag over the
-- head with their name and level. The weekly #1 also wears a gold crown tag. Server only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyPlayers = {}

export type Handle = {
	setChampion: (userId: number?) -> (), -- the weekly #1 (nil = nobody)
	stop: () -> (),
}

local TAG = "NameTag"

local function tagText(player: Player): string
	local level = player:GetAttribute("PlayerLevel")
	return `{player.DisplayName}  LV {if type(level) == "number" then level else 1}`
end

function LobbyPlayers.start(): Handle
	local conns: { RBXScriptConnection } = {}
	local champion: number? = nil

	local function refresh(player: Player)
		local char = player.Character
		local head = if char then char:FindFirstChild("Head") else nil
		local gui = if head then head:FindFirstChild(TAG) else nil
		if gui == nil then
			return
		end
		local name = gui:FindFirstChild("Name") :: TextLabel?
		if name then
			name.Text = tagText(player)
		end
		local crown = gui:FindFirstChild("Crown") :: TextLabel?
		if crown then
			crown.Visible = champion ~= nil and champion == player.UserId
		end
	end

	local function onCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		local head = char:WaitForChild("Head", 10)
		if hum == nil or head == nil then
			return
		end
		hum.WalkSpeed = LobbyLayout.walkSpeed
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our tag replaces the default
		local old = head:FindFirstChild(TAG)
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = TAG
		gui.Size = UDim2.fromOffset(220, 62)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.Parent = head
		local crown = Instance.new("TextLabel")
		crown.Name = "Crown"
		crown.Size = UDim2.fromScale(1, 0.4)
		crown.BackgroundTransparency = 1
		crown.Font = Enum.Font.FredokaOne
		crown.TextSize = 17
		crown.Text = "TOP DRIVER"
		crown.TextColor3 = Color3.fromRGB(255, 205, 64)
		crown.TextStrokeTransparency = 0.2
		crown.TextStrokeColor3 = Color3.fromRGB(20, 26, 40)
		crown.Visible = false
		crown.Parent = gui
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Size = UDim2.fromScale(1, 0.6)
		name.Position = UDim2.fromScale(0, 0.4)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 24
		name.TextColor3 = Color3.fromRGB(237, 240, 234)
		name.TextStrokeTransparency = 0.2
		name.TextStrokeColor3 = Color3.fromRGB(20, 26, 40)
		name.Parent = gui
		refresh(player)
	end

	local function onPlayer(player: Player)
		table.insert(
			conns,
			player.CharacterAdded:Connect(function(char: Model)
				onCharacter(player, char)
			end)
		)
		table.insert(
			conns,
			player:GetAttributeChangedSignal("PlayerLevel"):Connect(function()
				refresh(player)
			end)
		)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	table.insert(conns, Players.PlayerAdded:Connect(onPlayer))
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	return {
		setChampion = function(userId: number?)
			champion = userId
			for _, p in Players:GetPlayers() do
				refresh(p)
			end
		end,
		stop = function()
			for _, c in conns do
				c:Disconnect()
			end
		end,
	}
end

return LobbyPlayers
