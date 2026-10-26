--!strict
-- carter's pick 23 (10-26): after the big race, the top 3 cars stand on a podium on the result
-- card: 1st in the middle on the tall gold block, 2nd left on silver, 3rd right on bronze, the
-- cars turning slowly. The cars are copies of the real ones in the race (players' and bots').
-- Looks only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Podium = { frame: ViewportFrame, show: (rows: { any }) -> number, hide: () -> () }

local Podium = {}

local BLOCK = { -- place -> x, height, colour
	{ x = 0, h = 3, color = Color3.fromRGB(255, 205, 60) },
	{ x = -6.5, h = 2, color = Color3.fromRGB(200, 205, 215) },
	{ x = 6.5, h = 1.3, color = Color3.fromRGB(215, 140, 70) },
}
local CAR_LONG = 5 -- every car is shown this long, whatever its real size

-- The car model a result row drove (a player's Car_<uid>, or the bot with that name; the one in
-- your own race first). nil = gone already.
local function modelOf(row: any): Model?
	if type(row.uid) == "number" then
		local m = workspace:FindFirstChild("Car_" .. row.uid)
		return if m and m:IsA("Model") then m else nil
	end
	local mine = Players.LocalPlayer:GetAttribute("RaceGroup")
	local found: Model? = nil
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("BotName") == row.name then
			if found == nil or m:GetAttribute("RaceGroup") == mine then
				found = m
			end
		end
	end
	return found
end

function Podium.new(parent: GuiObject): Podium
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Podium"
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 170, 180)
	frame.LightColor = Color3.new(1, 1, 1)
	frame.LightDirection = Vector3.new(-0.4, -1, -0.6)
	frame.Visible = false
	frame.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 7, 26), Vector3.new(0, 2.6, 0))
	cam.Parent = frame
	frame.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = frame
	local spinning: { { model: Model, base: CFrame } } = {}
	local topY = 5 -- the highest point of the blocks and cars (studs)
	local spin: RBXScriptConnection? = nil

	-- the camera fills the frame with the podium (it was far back: tiny cars, Studio check 10-26)
	-- (every frame: the card grows in, and the frame is far wider than tall)
	local HALF_W = 6.5 + 2.75 + 0.6 -- the side blocks' outer edges, and a little room
	local TAN = math.tan(math.rad(cam.FieldOfView / 2))
	local UP = Vector3.new(0, 0.28, 1).Unit -- from a little above
	local function fit()
		local px = frame.AbsoluteSize
		local aspect = if px.Y > 0 then px.X / px.Y else 3
		local halfH = topY / 2 + 0.5
		local dist = math.max(halfH / TAN, HALF_W / (TAN * aspect)) + 2.5 -- (+ half the blocks' depth)
		local look = Vector3.new(0, topY / 2, 0)
		cam.CFrame = CFrame.lookAt(look + UP * dist, look)
	end

	local self = {} :: Podium
	self.frame = frame

	function self.hide()
		frame.Visible = false
		if spin then
			spin:Disconnect()
			spin = nil
		end
		world:ClearAllChildren()
		table.clear(spinning)
	end

	-- Builds the podium for these rows (best first); returns how many cars stand on it (0 = no
	-- podium to show).
	function self.show(rows: { any }): number
		self.hide()
		local cars = 0
		topY = 0
		for place = 1, math.min(3, #rows) do
			local b = BLOCK[place]
			local block = Instance.new("Part")
			block.Anchored = true
			block.Size = Vector3.new(5.5, b.h, 4)
			block.CFrame = CFrame.new(b.x, b.h / 2, 0)
			block.Color = b.color
			block.Material = Enum.Material.SmoothPlastic
			block.Parent = world
			topY = math.max(topY, b.h)
			local real = modelOf(rows[place])
			if real and real.PrimaryPart then
				local ok, copy = pcall(function()
					return real:Clone()
				end)
				if ok and copy then
					for _, d in copy:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.LocalTransparencyModifier = 0
						elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") then
							d:Destroy()
						end
					end
					local size = copy:GetExtentsSize()
					local long = math.max(size.X, size.Z, 0.1)
					copy:ScaleTo(copy:GetScale() * CAR_LONG / long)
					local tall = copy:GetExtentsSize().Y
					local base = CFrame.new(b.x, b.h + tall / 2 + 0.05, 0)
					copy:PivotTo(base)
					topY = math.max(topY, b.h + tall)
					copy.Parent = world
					table.insert(spinning, { model = copy, base = base })
					cars += 1
				end
			end
		end
		if cars == 0 then
			self.hide()
			return 0
		end
		frame.Visible = true
		local t = 0
		spin = RunService.RenderStepped:Connect(function(dt: number)
			t += dt
			fit()
			for i, s in spinning do
				s.model:PivotTo(s.base * CFrame.Angles(0, t * 0.9 + i, 0))
			end
		end)
		return cars
	end

	return self
end

return Podium
