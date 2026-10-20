--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Lobby workshop")

local function build()
	local world = Mock.new()
	local Workshop = world.require("server/LobbyWorkshop")
	local Layout = world.require("shared/LobbyLayout")
	local Gacha = world.require("shared/Gacha")
	local Config = world.require("shared/LobbyConfig")
	local folder = world.instance("Folder")
	local origin = Vector3.new(500, 10, -200)
	local result = Workshop.build(folder, origin)
	return world, result, folder, origin, Layout, Gacha, Config
end

local function texts(inst): { string }
	local out = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(out, d.Text)
		end
	end
	return out
end

local function countParts(inst): number
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

H.test("workshop builds with a prompt on the front panel", function()
	local _, r, folder = build()
	truthy(r.machine and r.anim and r.group and r.goldSign, "result fields")
	eq(r.machine.Name, "GumballMachine")
	truthy(r.machine.PrimaryPart, "primary part")
	local body = r.machine:FindFirstChild("GachaBody")
	truthy(body, "GachaBody")
	local prompt = body:FindFirstChild("GachaPrompt")
	truthy(prompt, "GachaPrompt")
	eq(prompt.KeyboardKeyCode.Name, "E")
	eq(prompt.ActionText, "Pull")
	eq(prompt.MaxActivationDistance, 22)
	eq(prompt.RequiresLineOfSight, false)
	truthy(r.machine:FindFirstChild("GumballCrank"), "crank")
	eq(r.goldSign.Text, "TOP DRIVER")
	truthy(countParts(folder) < 600, "part budget")
	local lights = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("PointLight") then
			lights += 1
		end
	end
	truthy(lights <= 3, "at most 3 point lights")
end)

H.test("odds sign lists the price and every rarity", function()
	local _, r, _, _, _, Gacha, Config = build()
	local all = table.concat(texts(r.group), "\n")
	truthy(string.find(all, "GUMBALL ODDS", 1, true), "title")
	truthy(string.find(all, tostring(Config.Gacha.price), 1, true), "price")
	for _, row in Gacha.oddsTable() do
		truthy(string.find(all, string.upper(row.rarity), 1, true), row.rarity)
		truthy(
			string.find(all, tostring(math.floor(row.percent)), 1, true),
			row.rarity .. " percent"
		)
	end
	truthy(string.find(all, "RAREST CAR", 1, true), "rare sign")
end)

H.test("everything stays inside the building and under 32 high", function()
	local _, r, folder, origin, Layout = build()
	local e = Mock.extent(folder)
	local b = Layout.workshop
	truthy(e.maxY <= origin.Y + 32 + 1e-6, "height " .. e.maxY)
	truthy(e.minY >= origin.Y - 1e-6, "floor")
	truthy(
		e.minX >= origin.X + b.x - b.w / 2 - 8 and e.maxX <= origin.X + b.x + b.w / 2 + 8,
		"x range"
	)
	truthy(
		e.minZ >= origin.Z + b.z - b.d / 2 - 8 and e.maxZ <= origin.Z + b.z + b.d / 2 + 8,
		"z range"
	)
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			eq(d.CanCollide, false, d.Name .. " collides")
		end
	end
	-- stage spots sit on the stages, facing the mouth
	near(r.stageRare.Position.X, origin.X + b.x + Layout.stageRare.u, 1e-6)
	near(r.stageGold.Position.Z, origin.Z + b.z + Layout.stageGold.v, 1e-6)
	truthy(r.stageRare.Position.Y > origin.Y)
end)

H.test("the pull show runs, ends where it began and cleans up", function()
	local world, r, folder = build()
	local machine = r.machine
	local before = machine:GetPivot()
	local partsBefore = countParts(folder)
	local crank = machine:FindFirstChild("GumballCrank")
	local crankBefore = crank.CFrame
	local done = 0
	eq(r.anim.busy(), false)
	eq(
		r.anim.play(function()
			done += 1
		end),
		true
	)
	eq(r.anim.busy(), true)
	eq(
		r.anim.play(function()
			done += 100
		end),
		false,
		"second play while busy"
	)
	local sawCapsule, moved = false, false
	for _ = 1, 10 do
		world.step(0.1)
		local p = machine:GetPivot()
		if math.abs(p.Position.X - before.Position.X) > 1e-6 then
			moved = true
		end
		for _, d in folder:GetDescendants() do
			if d.Name == "GumballCapsule" and #d:GetChildren() > 0 then
				sawCapsule = true
			end
		end
	end
	eq(r.anim.busy(), true, "still busy after 1 s")
	eq(done, 0)
	for _ = 1, 40 do
		world.step(0.1)
	end
	eq(r.anim.busy(), false)
	eq(done, 1, "onDone once")
	truthy(moved, "machine shook")
	truthy(sawCapsule, "capsule shown")
	local after = machine:GetPivot()
	for _, k in { "X", "Y", "Z" } do
		near(after.Position[k], before.Position[k], 1e-6)
	end
	for i = 1, 12 do
		near(({ after:GetComponents() })[i], ({ before:GetComponents() })[i], 1e-6)
	end
	for i = 1, 12 do
		near(({ crank.CFrame:GetComponents() })[i], ({ crankBefore:GetComponents() })[i], 1e-6)
	end
	eq(countParts(folder), partsBefore, "no capsule parts left")
	for _, d in folder:GetDescendants() do
		truthy(d.Name ~= "GumballCapsule", "holder removed")
	end
	-- and it can play again
	eq(
		r.anim.play(function()
			done += 1
		end),
		true
	)
	world.step(0.1)
	truthy(r.anim.duration() >= 2 and r.anim.duration() <= 4, "about 3 seconds")
end)

H.test("a machine destroyed mid-show still finishes", function()
	local world, r = build()
	local done = 0
	r.anim.play(function()
		done += 1
	end)
	world.step(0.5)
	r.machine:Destroy()
	world.step(0.1)
	eq(done, 1)
	eq(r.anim.busy(), false)
	world.step(0.5)
	eq(done, 1)
end)
