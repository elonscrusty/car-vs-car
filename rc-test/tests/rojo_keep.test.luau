--!strict
-- Rojo must never wipe what carter made in Studio: the imported karts live only in the place
-- (ReplicatedStorage.CarSkins, studio_import_fix.luau) and the map in Workspace. A service Rojo
-- syncs keeps the instances it doesn't know about only with $ignoreUnknownInstances.
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local test, truthy = H.test, H.truthy

test(
	"Rojo keeps Studio-made things in ReplicatedStorage (the karts), Workspace and Lighting",
	function()
		local project = serde.decode("json", fs.readFile("default.project.json"))
		for _, service in { "ReplicatedStorage", "Workspace", "Lighting" } do
			local node = project.tree[service]
			truthy(node ~= nil, `{service} missing from the project`)
			truthy(
				node["$ignoreUnknownInstances"] == true,
				`{service} needs "$ignoreUnknownInstances": true`
			)
			truthy(
				node["$path"] == nil,
				`{service} must not be one $path folder (Rojo would own all of it)`
			)
		end
	end
)
