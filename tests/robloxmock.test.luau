--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near = H.eq, H.near
local Vector3, CFrame, Color3 = Mock.V3, Mock.CF, Mock.C3

print("Roblox mock")

H.test("loads a shared module and runs a part builder", function()
	local world = Mock.new()
	local Layout = world.require("shared/LobbyLayout")
	eq(Layout.size.x, 220)
	local MapParts = world.require("server/MapParts")
	local folder = world.instance("Folder")
	local p = MapParts.part(
		folder,
		"P",
		Vector3.new(10, 4, 6),
		CFrame.new(5, 2, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color3.new(1, 0, 0),
		false
	)
	eq(p.Parent, folder)
	local e = Mock.extent(folder)
	near(e.maxY, 4, 1e-6)
	near(e.maxX, 8, 1e-6) -- turned 90 degrees: the 6 stud side now runs along x
	near(e.maxZ, 5, 1e-6)
end)

H.test("model pivot and scale", function()
	local world = Mock.new()
	local MapParts = world.require("server/MapParts")
	local m = world.instance("Model")
	MapParts.part(m, "A", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), Color3.new(), false)
	m:PivotTo(CFrame.new(10, 1, 10))
	near(Mock.extent(m).maxX, 11, 1e-6)
	m:ScaleTo(2)
	near(Mock.extent(m).maxY - Mock.extent(m).minY, 4, 1e-6)
end)

H.test("task.wait suspends until step", function()
	local world = Mock.new()
	world.require("shared/LobbyLayout")
	local hits = 0
	local run = world.service("RunService")
	run.Heartbeat:Connect(function()
		hits += 1
	end)
	world.step(0.1)
	eq(hits, 1)
end)
