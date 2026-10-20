--!nocheck
-- Offline preview, step 1: build a piece of the game on the fake Roblox (tests/robloxmock.luau) and
-- write every visible part as JSON, so tools/preview/render.py can draw a picture of it.
-- No Studio needed. Run from the repo root:
--   lune run tools/preview/dump lobby /tmp/lobby.json
--   lune run tools/preview/dump practice /tmp/practice.json
-- Coordinates in the file are relative to the build's origin (lobby: plaza top is y = 0).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Mock = require("../../tests/robloxmock")

local what = process.args[1] or "lobby"
local out = process.args[2] or "/tmp/preview.json"

local world = Mock.new("./src")
world.quiet = true

local folder, origin
if what == "lobby" then
	local Lobby = world.require("server/Lobby")
	local handle = Lobby.build()
	folder, origin = handle.folder, handle.origin
elseif what == "practice" then
	local Yard = world.require("shared/PracticeYard")
	local Layout = world.require("shared/PracticeLayout")
	local at = Mock.V3.new(Layout.origin.x, Layout.origin.y, Layout.origin.z)
	local handle = Yard.build(world.workspace, at)
	folder, origin = handle.root, handle.origin
else
	error("unknown target " .. what)
end

local parts = {}
local function num(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local c = d.CFrame
		local m = c.m
		local shape = if d.Shape then d.Shape.Name else "Block"
		if d.ClassName == "WedgePart" then
			shape = "Wedge"
		end
		local color = d.Color
		table.insert(parts, {
			n = d.Name,
			p = { num(c.x - origin.X), num(c.y - origin.Y), num(c.z - origin.Z) },
			s = { num(d.Size.X), num(d.Size.Y), num(d.Size.Z) },
			m = {
				num(m[1]),
				num(m[2]),
				num(m[3]),
				num(m[4]),
				num(m[5]),
				num(m[6]),
				num(m[7]),
				num(m[8]),
				num(m[9]),
			},
			c = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) },
			sh = shape,
			t = num(d.Transparency),
			mat = if d.Material then d.Material.Name else "Plastic",
			g = d.Parent and d.Parent.Name or "",
		})
	end
end
fs.writeFile(out, serde.encode("json", { parts = parts }))
print(`wrote {#parts} parts to {out}`)
