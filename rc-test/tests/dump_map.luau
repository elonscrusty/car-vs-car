--!strict
-- Prints a race map as JSON for the layout picture:  lune run tests/dump_map backyard
local process = require("@lune/process")
local serde = require("@lune/serde")
local name = process.args[1] or "Backyard"
local Map: any = require("../src/shared/Maps/" .. name)
local out = {
	def = Map.def,
	loop = Map.loop(),
	gates = Map.gates,
	spawn = Map.spawn,
	paths = {},
	line = Map.lineSample(),
}
for i = 1, #Map.def.paths do
	out.paths[i] = Map.path(i)
end
print(serde.encode("json", out))
