--!strict
-- A `local function` called on a line above where it is made is nil there: the call errors at
-- run time ("attempt to call a nil value"). Studio found one in CvcPlot.client (10-28: `total`
-- used by `cars` above it, so the podium never filled). Lune never runs client scripts, so check
-- every script's text instead. Comments don't count.
local fs = require("@lune/fs")
local H = require("./harness")

local test, truthy = H.test, H.truthy

print("Use before define")

local function files(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			files(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

test("no local function is called above the line that makes it", function()
	local list = {}
	files("src", list)
	for _, path in list do
		local lines = string.split(fs.readFile(path), "\n")
		local code = {}
		for i, l in lines do
			code[i] = (string.split(l, "--"))[1]
		end
		for i, l in lines do
			local name = string.match(l, "^local function ([%w_]+)%(")
			if name then
				for j = 1, i - 1 do
					local t = code[j]
					local s = string.find(t, name .. "(", 1, true)
					if s and not string.match(t, "^%s*local " .. name .. "[^%w_]") then
						local before = if s > 1 then string.sub(t, s - 1, s - 1) else " "
						truthy(
							string.match(before, "[%w_%.:]") ~= nil,
							`{path}:{j} calls {name} before line {i} makes it`
						)
					end
				end
			end
		end
	end
end)
