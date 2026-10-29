--!nocheck
-- GemKit (the Bold nature + rubble kit): the generated data is sane, stays cheap, and the builder
-- hands back nil (so the caller keeps its PropKit prop) when a server can't make an EditableMesh.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local H = require("./harness")

local test, truthy, eq = H.test, H.truthy, H.eq

local data = luau.load(fs.readFile("src/shared/GemData.luau"), { environment = { math = math } })()
local yard =
	luau.load(fs.readFile("src/shared/GemYardData.luau"), { environment = { math = math } })()
local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	math = math,
	table = table,
	pcall = pcall,
	game = {
		GetService = function()
			error("no AssetService here")
		end,
	},
	script = { Parent = { GemData = data, GemYardData = yard } },
	require = function(d)
		return d
	end,
}
local GemKit = luau.load(fs.readFile("src/shared/GemKit.luau"), { environment = env })()

print("GemKit")

local KINDS = { "bush", "chunks", "dead", "junk", "pine", "rock", "tree", "wall" }
local YARD = { "yardCrane", "yardDebris", "yardHeap", "yardLamp", "yardStack2", "yardStack3" }
local ALL = table.clone(KINDS)
for _, k in YARD do
	table.insert(ALL, k)
end
table.sort(ALL)

test("every picked kind is in the data", function()
	eq(table.concat(GemKit.kinds(), ","), table.concat(ALL, ","))
end)

test("every triangle points at real vertices and has three different corners", function()
	for _, set in { data, yard } do
		for kind, pieces in set do
			for _, piece in pieces do
				eq(#piece.color, 3, kind .. " colour")
				for _, t in piece.f do
					for i = 1, 3 do
						truthy(piece.v[t[i]] ~= nil, `{kind}/{piece.name}: corner {t[i]} missing`)
					end
					truthy(
						t[1] ~= t[2] and t[2] ~= t[3] and t[1] ~= t[3],
						`{kind}/{piece.name}: flat triangle`
					)
				end
			end
		end
	end
end)

test("each prop stays cheap for a phone (under 700 triangles)", function()
	for _, kind in KINDS do
		local n = GemKit.triangles(kind)
		truthy(n > 20 and n <= 700, `{kind}: {n} triangles`)
	end
end)

test(
	"each yard piece stays cheap (heap 4000, the rest 500) and the whole yard under 5500",
	function()
		local total = 0
		for _, kind in YARD do
			local n = GemKit.triangles(kind)
			truthy(
				n > 20 and n <= (if kind == "yardHeap" then 4000 else 500),
				`{kind}: {n} triangles`
			)
			total += n
		end
		truthy(total <= 5500, `yard total {total}`)
	end
)

test("props stand on the ground: the lowest vertex is near 0, nothing is buried", function()
	for _, kind in KINDS do
		local low = math.huge
		for _, piece in data[kind] do
			for _, p in piece.v do
				low = math.min(low, p[2])
			end
		end
		truthy(low > -0.5 and low < 1.2, `{kind}: lowest vertex {low}`)
		truthy(GemKit.height(kind) > 1, kind .. " has height")
	end
end)

test("yard pieces stand on the ground (the heap's foot may sink 2 studs)", function()
	for _, kind in YARD do
		local low = math.huge
		for _, piece in yard[kind] do
			for _, p in piece.v do
				low = math.min(low, p[2])
			end
		end
		truthy(low > -2 and low < 1.2, `{kind}: lowest vertex {low}`)
		truthy(GemKit.height(kind) > 2, kind .. " has height")
	end
end)

test("only the lamp face glows, and it hangs high up", function()
	for kind, pieces in yard do
		for _, piece in pieces do
			eq(
				piece.glow == true,
				kind == "yardLamp" and piece.name == "glow",
				`{kind}/{piece.name} glow flag`
			)
		end
	end
	for _, piece in yard.yardLamp do
		if piece.glow then
			local lowest = math.huge
			for _, p in piece.v do
				lowest = math.min(lowest, p[2])
			end
			truthy(lowest > 10, `lamp face at {lowest}`)
		end
	end
end)

test("no EditableMesh on the server: build returns nil, never errors", function()
	local folder = roblox.Instance.new("Folder")
	eq(GemKit.build(folder, "tree", roblox.Vector3.new(0, 0, 0), 20, 0.5), nil)
	eq(GemKit.build(folder, "yardHeap", roblox.Vector3.new(0, 0, 0), 20, 0.5), nil)
	eq(GemKit.build(folder, "nope", roblox.Vector3.new(0, 0, 0), 20), nil)
	eq(#folder:GetChildren(), 0)
end)

test("no EditableMesh: craneYard returns nil and leaves nothing in the parent", function()
	local folder = roblox.Instance.new("Folder")
	eq(GemKit.craneYard(folder, roblox.Vector3.new(0, 0, 0), 1, 0.5), nil)
	eq(#folder:GetChildren(), 0)
end)
