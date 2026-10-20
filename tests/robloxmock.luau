--!nocheck
-- A tiny fake of the parts of Roblox that the server builders use, so a builder (for example
-- Lobby.build) can run under plain Lune: it catches nil errors and typos and lets a test measure
-- what was built (part counts, the highest point, where things stand). It is NOT a physics engine
-- and not complete: unknown properties just store what you set; unknown methods error.
--
--   local Mock = require("./robloxmock")
--   local world = Mock.new()                  -- loads modules from src/server and src/shared
--   local Lobby = world.require("server/Lobby")
--   local handle = Lobby.build()
--   world.workspace:FindFirstChild("Lobby") ...
--   world.step(0.1)                           -- runs Heartbeat connections and task.wait wake-ups

local luau = require("@lune/luau")
local fs = require("@lune/fs")

local Mock = {}

local function newClass(name: string)
	local C: any = { __type = name }
	C.__index = C
	return C
end

-- Vector3 -------------------------------------------------------------------
local V3 = newClass("Vector3")
local function v3(x: number, y: number, z: number): any
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
V3.__index = function(t: any, k: any)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return if m == 0 then v3(0, 0, 0) else v3(t.X / m, t.Y / m, t.Z / m)
	end
	return V3[k]
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return `{a.X}, {a.Y}, {a.Z}`
end
function V3.Dot(a: any, b: any)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a: any, b: any)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a: any, b: any, t: number)
	return a + (b - a) * t
end
function V3.new(x: number?, y: number?, z: number?)
	return v3(x or 0, y or 0, z or 0)
end
V3.zero = v3(0, 0, 0)
V3.one = v3(1, 1, 1)
V3.xAxis = v3(1, 0, 0)
V3.yAxis = v3(0, 1, 0)
V3.zAxis = v3(0, 0, 1)

-- Vector2 / UDim / UDim2 ----------------------------------------------------
local V2 = newClass("Vector2")
function V2.new(x: number?, y: number?)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.zero = V2.new(0, 0)
V2.one = V2.new(1, 1)
V2.__add = function(a, b)
	return V2.new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return V2.new(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(b) == "number" then
		return V2.new(a.X * b, a.Y * b)
	end
	return V2.new(a.X * b.X, a.Y * b.Y)
end
V2.__index = function(t: any, k: any)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y)
	end
	return V2[k]
end

local UD = newClass("UDim")
function UD.new(s: number?, o: number?)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
local UD2 = newClass("UDim2")
function UD2.new(sx: any, ox: any, sy: any, oy: any)
	if type(sx) == "table" then -- UDim2.new(UDim, UDim)
		return setmetatable({ X = sx, Y = ox }, UD2)
	end
	return setmetatable({ X = UD.new(sx, ox), Y = UD.new(sy, oy) }, UD2)
end
function UD2.fromScale(sx: number, sy: number)
	return UD2.new(sx, 0, sy, 0)
end
function UD2.fromOffset(ox: number, oy: number)
	return UD2.new(0, ox, 0, oy)
end

-- Color3 --------------------------------------------------------------------
local C3 = newClass("Color3")
function C3.new(r: number?, g: number?, b: number?)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function C3.fromRGB(r: number, g: number, b: number)
	return C3.new(r / 255, g / 255, b / 255)
end
function C3.fromHSV(h: number, s: number, v: number)
	return C3.new(v, v * (1 - s), v * (1 - s))
end
function C3.Lerp(a: any, b: any, t: number)
	return C3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

-- CFrame --------------------------------------------------------------------
-- Stored as position (x,y,z) and the rotation matrix m (row major, 9 numbers).
local CF = newClass("CFrame")
local function cf(x: number, y: number, z: number, m: { number }): any
	return setmetatable({ x = x, y = y, z = z, m = m }, CF)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matMul(a: { number }, b: { number }): { number }
	local o = table.create(9, 0)
	for r = 0, 2 do
		for c = 0, 2 do
			o[r * 3 + c + 1] = a[r * 3 + 1] * b[c + 1]
				+ a[r * 3 + 2] * b[3 + c + 1]
				+ a[r * 3 + 3] * b[6 + c + 1]
		end
	end
	return o
end
local function rotX(a: number): { number }
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a: number): { number }
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a: number): { number }
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function applyRot(m: { number }, v: any)
	return v3(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end
function CF.new(a: any, b: any, c: any)
	if a == nil then
		return cf(0, 0, 0, IDENT)
	elseif type(a) == "number" then
		return cf(a, b, c, IDENT)
	elseif b ~= nil then
		return CF.lookAt(a, b)
	end
	return cf(a.X, a.Y, a.Z, IDENT)
end
function CF.lookAt(at: any, target: any, up: any?)
	local look = (target - at).Unit
	local upv = up or v3(0, 1, 0)
	local right = look:Cross(upv)
	if right.Magnitude < 1e-6 then
		right = v3(1, 0, 0)
	end
	right = right.Unit
	local u = right:Cross(look)
	-- columns: right, up, back (= -look)
	return cf(at.X, at.Y, at.Z, {
		right.X,
		u.X,
		-look.X,
		right.Y,
		u.Y,
		-look.Y,
		right.Z,
		u.Z,
		-look.Z,
	})
end
function CF.Angles(rx: number, ry: number, rz: number)
	return cf(0, 0, 0, matMul(matMul(rotX(rx), rotY(ry)), rotZ(rz)))
end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.fromEulerAnglesYXZ(rx: number, ry: number, rz: number)
	return cf(0, 0, 0, matMul(matMul(rotY(ry), rotX(rx)), rotZ(rz)))
end
CF.fromOrientation = CF.fromEulerAnglesYXZ
CF.identity = cf(0, 0, 0, IDENT)
CF.__index = function(t: any, k: any)
	if k == "Position" then
		return v3(t.x, t.y, t.z)
	elseif k == "X" then
		return t.x
	elseif k == "Y" then
		return t.y
	elseif k == "Z" then
		return t.z
	elseif k == "RightVector" then
		return v3(t.m[1], t.m[4], t.m[7])
	elseif k == "UpVector" then
		return v3(t.m[2], t.m[5], t.m[8])
	elseif k == "LookVector" then
		return v3(-t.m[3], -t.m[6], -t.m[9])
	elseif k == "Rotation" then
		return cf(0, 0, 0, t.m)
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local p = applyRot(a.m, v3(b.x, b.y, b.z))
		return cf(a.x + p.X, a.y + p.Y, a.z + p.Z, matMul(a.m, b.m))
	end
	local p = applyRot(a.m, b)
	return v3(a.x + p.X, a.y + p.Y, a.z + p.Z)
end
CF.__add = function(a, b)
	return cf(a.x + b.X, a.y + b.Y, a.z + b.Z, a.m)
end
CF.__sub = function(a, b)
	return cf(a.x - b.X, a.y - b.Y, a.z - b.Z, a.m)
end
function CF.Inverse(a: any)
	local m = a.m
	local t = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
	local p = applyRot(t, v3(-a.x, -a.y, -a.z))
	return cf(p.X, p.Y, p.Z, t)
end
function CF.ToWorldSpace(a: any, b: any)
	return a * b
end
function CF.ToObjectSpace(a: any, b: any)
	return a:Inverse() * b
end
function CF.PointToWorldSpace(a: any, v: any)
	return a * v
end
function CF.PointToObjectSpace(a: any, v: any)
	return a:Inverse() * v
end
function CF.VectorToWorldSpace(a: any, v: any)
	return applyRot(a.m, v)
end
function CF.Lerp(a: any, b: any, t: number)
	return if t < 0.5 then a else b
end
function CF.ToEulerAnglesYXZ(a: any)
	local m = a.m
	local x = math.asin(-math.clamp(m[6], -1, 1))
	local y = math.atan2(m[3], m[9])
	local z = math.atan2(m[4], m[5])
	return x, y, z
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.GetComponents(a: any)
	local m = a.m
	return a.x, a.y, a.z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
end

-- Instances -----------------------------------------------------------------
local PARENTS: { [string]: { string } } = {
	Part = { "Part", "BasePart", "PVInstance" },
	WedgePart = { "WedgePart", "BasePart", "PVInstance" },
	CornerWedgePart = { "CornerWedgePart", "BasePart", "PVInstance" },
	TrussPart = { "TrussPart", "BasePart", "PVInstance" },
	MeshPart = { "MeshPart", "BasePart", "PVInstance" },
	SpawnLocation = { "SpawnLocation", "Part", "BasePart", "PVInstance" },
	Model = { "Model", "PVInstance" },
	Folder = { "Folder" },
	TextLabel = { "TextLabel", "GuiLabel", "GuiObject", "GuiBase2d" },
	TextButton = { "TextButton", "GuiButton", "GuiObject", "GuiBase2d" },
	ImageLabel = { "ImageLabel", "GuiLabel", "GuiObject", "GuiBase2d" },
	Frame = { "Frame", "GuiObject", "GuiBase2d" },
	SurfaceGui = { "SurfaceGui", "LayerCollector", "GuiBase2d" },
	BillboardGui = { "BillboardGui", "LayerCollector", "GuiBase2d" },
	PointLight = { "PointLight", "Light" },
	SpotLight = { "SpotLight", "Light" },
	SurfaceLight = { "SurfaceLight", "Light" },
	Script = { "Script", "BaseScript" },
	ModuleScript = { "ModuleScript", "LuaSourceContainer" },
}
local EVENTS = {
	Touched = true,
	TouchEnded = true,
	Triggered = true,
	TriggerEnded = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Changed = true,
	AncestryChanged = true,
	Destroying = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	Heartbeat = true,
	Stepped = true,
	RenderStepped = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Died = true,
	MouseButton1Click = true,
	Activated = true,
	PromptTriggered = true,
	Completed = true,
}

local Signal = newClass("RBXScriptSignal")
local function newSignal(): any
	return setmetatable({ conns = {} }, Signal)
end
function Signal.Connect(s: any, fn: (...any) -> ())
	local conn: any = { fn = fn, Connected = true }
	function conn.Disconnect()
		conn.Connected = false
	end
	table.insert(s.conns, conn)
	return conn
end
Signal.Once = Signal.Connect
function Signal.Wait(_s: any)
	return nil
end
function Signal.Fire(s: any, ...: any)
	for _, c in s.conns do
		if c.Connected then
			c.fn(...)
		end
	end
end

local Inst = newClass("Instance")
local PART_DEFAULTS = function(): { [string]: any }
	return {
		Size = v3(4, 1, 2),
		CFrame = CF.identity,
		Anchored = false,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = true,
		Transparency = 0,
		Massless = false,
		Color = C3.new(0.63, 0.63, 0.63),
		Reflectance = 0,
	}
end

local function isA(self: any, cn: string): boolean
	if cn == "Instance" or cn == self.ClassName then
		return true
	end
	for _, p in PARENTS[self.ClassName] or {} do
		if p == cn then
			return true
		end
	end
	return false
end

local function descendants(self: any, out: { any })
	for _, c in self._children do
		table.insert(out, c)
		descendants(c, out)
	end
end

local function partsOf(self: any): { any }
	local list = {}
	local all = {}
	descendants(self, all)
	if isA(self, "BasePart") then
		table.insert(all, self)
	end
	for _, d in all do
		if isA(d, "BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- World axis-aligned box of a part (its 8 corners).
local function partBox(p: any): (any, any)
	local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
	local s = p.Size
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = p.CFrame * v3(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
				lo = v3(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
				hi = v3(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
			end
		end
	end
	return lo, hi
end
Mock.partBox = partBox

local function boundingBox(self: any): (any, any)
	local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
	for _, p in partsOf(self) do
		local a, b = partBox(p)
		lo = v3(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z))
		hi = v3(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z))
	end
	if lo.X == math.huge then
		return CF.identity, v3(0, 0, 0)
	end
	local mid = (lo + hi) / 2
	return CF.new(mid), hi - lo
end

local function pivotOf(self: any): any
	if isA(self, "BasePart") then
		return self.CFrame
	end
	local primary = self._props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	local c = boundingBox(self)
	return c
end

local function newInstance(className: string): any
	local self: any = setmetatable({}, Inst)
	rawset(self, "_props", {})
	rawset(self, "_children", {})
	rawset(self, "_attrs", {})
	rawset(self, "_signals", {})
	rawset(self, "_tags", {})
	rawset(self, "_parent", nil)
	self._props.ClassName = className
	self._props.Name = className
	if isA(self, "BasePart") then
		for k, v in PART_DEFAULTS() do
			self._props[k] = v
		end
		if className == "SpawnLocation" then
			self._props.Neutral = true
		end
	end
	if className == "Model" then
		self._props.PrimaryPart = nil
	end
	return self
end

Inst.__index = function(t: any, k: any)
	local props = rawget(t, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Parent" then
		return rawget(t, "_parent")
	elseif k == "Position" and isA(t, "BasePart") then
		return props.CFrame.Position
	elseif k == "Orientation" then
		return v3(0, 0, 0)
	elseif Inst[k] ~= nil then
		return Inst[k]
	end
	local signals = rawget(t, "_signals")
	if EVENTS[k] then
		signals[k] = signals[k] or newSignal()
		return signals[k]
	end
	for _, c in rawget(t, "_children") do
		if c.Name == k then
			return c
		end
	end
	return nil
end

Inst.__newindex = function(t: any, k: any, v: any)
	local props = rawget(t, "_props")
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			local i = table.find(old._children, t)
			if i then
				table.remove(old._children, i)
			end
		end
		rawset(t, "_parent", v)
		if v then
			table.insert(v._children, t)
		end
	elseif k == "Position" and isA(t, "BasePart") then
		props.CFrame = cf(v.X, v.Y, v.Z, props.CFrame.m)
	elseif k == "CFrame" and isA(t, "BasePart") then
		props.CFrame = v
	else
		props[k] = v
	end
end

function Inst.new(className: string)
	return newInstance(className)
end
function Inst.IsA(self: any, cn: string)
	return isA(self, cn)
end
function Inst.GetChildren(self: any)
	return table.clone(self._children)
end
function Inst.GetDescendants(self: any)
	local out = {}
	descendants(self, out)
	return out
end
function Inst.FindFirstChild(self: any, name: string, recursive: boolean?)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in self:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
	end
	return nil
end
function Inst.FindFirstChildOfClass(self: any, cn: string)
	for _, c in self._children do
		if c.ClassName == cn then
			return c
		end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(self: any, cn: string)
	for _, c in self._children do
		if isA(c, cn) then
			return c
		end
	end
	return nil
end
function Inst.WaitForChild(self: any, name: string)
	return self:FindFirstChild(name)
end
function Inst.IsDescendantOf(self: any, anc: any)
	local p = self._parent
	while p do
		if p == anc then
			return true
		end
		p = p._parent
	end
	return false
end
function Inst.GetFullName(self: any)
	local parts = { self.Name }
	local p = self._parent
	while p do
		table.insert(parts, 1, p.Name)
		p = p._parent
	end
	return table.concat(parts, ".")
end
function Inst.Destroy(self: any)
	self.Parent = nil
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
end
function Inst.ClearAllChildren(self: any)
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
end
function Inst.Clone(self: any)
	local c = newInstance(self.ClassName)
	for k, v in self._props do
		if k ~= "Parent" then
			c._props[k] = v
		end
	end
	for k, v in self._attrs do
		c._attrs[k] = v
	end
	for _, ch in self._children do
		local cc = ch:Clone()
		cc.Parent = c
	end
	return c
end
function Inst.SetAttribute(self: any, k: string, v: any)
	self._attrs[k] = v
end
function Inst.GetAttribute(self: any, k: string)
	return self._attrs[k]
end
function Inst.GetAttributes(self: any)
	return table.clone(self._attrs)
end
function Inst.GetAttributeChangedSignal(self: any, k: string)
	local key = "attr_" .. k
	self._signals[key] = self._signals[key] or newSignal()
	return self._signals[key]
end
function Inst.GetPropertyChangedSignal(self: any, k: string)
	return self:GetAttributeChangedSignal(k)
end
function Inst.PivotTo(self: any, target: any)
	local from = pivotOf(self)
	local delta = target * from:Inverse()
	for _, p in partsOf(self) do
		p.CFrame = delta * p.CFrame
	end
end
function Inst.GetPivot(self: any)
	return pivotOf(self)
end
function Inst.GetBoundingBox(self: any)
	return boundingBox(self)
end
function Inst.GetExtentsSize(self: any)
	local _, s = boundingBox(self)
	return s
end
function Inst.ScaleTo(self: any, k: number)
	local pivot = pivotOf(self)
	local current = self._props.Scale or 1
	local f = k / current
	for _, p in partsOf(self) do
		local rel = pivot:Inverse() * p.CFrame
		p.Size = p.Size * f
		p.CFrame = pivot * cf(rel.x * f, rel.y * f, rel.z * f, rel.m)
	end
	self._props.Scale = k
end
function Inst.GetScale(self: any)
	return self._props.Scale or 1
end
function Inst.SetPrimaryPartCFrame(self: any, c: any)
	self:PivotTo(c)
end
function Inst.AddTag(self: any, tag: string)
	self._tags[tag] = true
end
function Inst.HasTag(self: any, tag: string)
	return self._tags[tag] == true
end
function Inst.IsAncestorOf(self: any, d: any)
	return d:IsDescendantOf(self)
end
function Inst.GetNetworkOwner()
	return nil
end
function Inst.SetNetworkOwner() end
function Inst.Play() end
function Inst.Stop() end

-- Enum: any Enum.Foo.Bar gives a table with Name and Value.
local EnumProxy = setmetatable({}, {
	__index = function(_, group: string)
		return setmetatable({}, {
			__index = function(_, item: string)
				return { Name = item, EnumType = group, Value = 0 }
			end,
		})
	end,
})

-- The world ------------------------------------------------------------------
function Mock.new(srcRoot: string?)
	local root = srcRoot or "./src"
	local world: any = {}
	local services: { [string]: any } = {}
	local clock = 0
	local waiting: { { co: thread, at: number } } = {}
	local delayed: { { at: number, fn: () -> () } } = {}

	local function service(name: string): any
		if services[name] then
			return services[name]
		end
		local s = newInstance(name == "Workspace" and "Workspace" or "Folder")
		s.Name = name
		services[name] = s
		return s
	end

	local game: any = newInstance("DataModel")
	function game.GetService(_self: any, name: string)
		return service(name)
	end
	world.game = game
	local ws = service("Workspace")
	ws.Terrain = nil
	local terrain = newInstance("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = ws
	world.workspace = ws
	local rs = service("ReplicatedStorage")
	local ss = service("ServerScriptService")
	service("ServerStorage")
	local lighting = service("Lighting")
	world.lighting = lighting
	local shared = newInstance("Folder")
	shared.Name = "Shared"
	shared.Parent = rs
	local server = newInstance("Folder")
	server.Name = "Server"
	server.Parent = ss
	local client = newInstance("Folder")
	client.Name = "Client"
	client.Parent = newInstance("Folder")

	local players = service("Players")
	players._props.GetPlayers = function()
		return {}
	end
	players.GetPlayers = function()
		return world.players or {}
	end
	players.GetPlayerByUserId = function(_self: any, id: number)
		for _, p in world.players or {} do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	local run = service("RunService")
	run.IsStudio = function()
		return true
	end
	run.IsServer = function()
		return true
	end
	run.IsClient = function()
		return false
	end
	local tween = service("TweenService")
	tween.Create = function(_self: any, inst: any, _info: any, goal: any)
		return {
			Play = function()
				for k, v in goal do
					inst[k] = v
				end
			end,
			Cancel = function() end,
			Completed = newSignal(),
		}
	end
	tween.GetValue = function(_self: any, a: number)
		return a
	end
	service("Debris").AddItem = function() end
	local coll = service("CollectionService")
	coll.AddTag = function(_self: any, inst: any, tag: string)
		inst:AddTag(tag)
	end
	coll.GetTagged = function()
		return {}
	end

	-- module loading
	local moduleCache: { [any]: any } = {}
	local envFor: (m: any) -> { [string]: any }
	local function modulePath(inst: any): string
		return inst._props.Path
	end
	local function loadModule(inst: any): any
		if moduleCache[inst] ~= nil then
			return moduleCache[inst].value
		end
		local entry = { value = nil }
		moduleCache[inst] = entry
		local source = fs.readFile(modulePath(inst))
		local fn = luau.load(source, { chunkName = modulePath(inst), environment = envFor(inst) })
		entry.value = fn()
		return entry.value
	end
	local function mockRequire(inst: any): any
		if type(inst) ~= "table" or inst.ClassName ~= "ModuleScript" then
			error("require of a non-module: " .. tostring(inst))
		end
		return loadModule(inst)
	end

	local function addModules(dir: string, parent: any)
		for _, name in fs.readDir(dir) do
			if
				string.sub(name, -5) == ".luau"
				and not string.find(name, "%.server%.")
				and not string.find(name, "%.client%.")
				and name ~= "init.luau"
			then
				local m = newInstance("ModuleScript")
				m.Name = string.sub(name, 1, -6)
				m._props.Path = dir .. "/" .. name
				m.Parent = parent
			end
		end
	end
	addModules(root .. "/shared", shared)
	addModules(root .. "/server", server)
	local sharedBattle = newInstance("Folder")
	sharedBattle.Name = "BattleModels"
	sharedBattle.Parent = rs

	local taskLib = {}
	function taskLib.spawn(fn: any, ...: any)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 0)
		end
		return co
	end
	taskLib.defer = taskLib.spawn
	function taskLib.wait(n: number?)
		local t = n or 0.03
		if coroutine.isyieldable() then
			table.insert(waiting, { co = coroutine.running(), at = clock + t })
			coroutine.yield()
		end
		return t
	end
	function taskLib.delay(n: number, fn: any)
		table.insert(delayed, { at = clock + n, fn = fn })
	end
	function taskLib.cancel() end

	local function makeEnv(m: any): { [string]: any }
		return {
			script = m,
			game = game,
			workspace = ws,
			require = mockRequire,
			task = taskLib,
			Instance = { new = newInstance },
			Vector3 = V3,
			Vector2 = V2,
			CFrame = CF,
			Color3 = C3,
			UDim = UD,
			UDim2 = UD2,
			Enum = EnumProxy,
			typeof = function(v: any)
				local mt = getmetatable(v)
				if type(v) == "table" and mt and mt.__type then
					return mt.__type
				elseif type(v) == "table" and v._props then
					return "Instance"
				end
				return type(v)
			end,
			Random = {
				new = function(seed: number?)
					return {
						NextNumber = function()
							return math.random()
						end,
						NextInteger = function(_s: any, a: number, b: number)
							return math.random(a, b)
						end,
					}
				end,
			},
			TweenInfo = {
				new = function()
					return {}
				end,
			},
			NumberSequence = {
				new = function(...)
					return { ... }
				end,
			},
			NumberRange = {
				new = function(a, b)
					return { Min = a, Max = b or a }
				end,
			},
			ColorSequence = {
				new = function(...)
					return { ... }
				end,
			},
			ColorSequenceKeypoint = {
				new = function(t, c)
					return { Time = t, Value = c }
				end,
			},
			NumberSequenceKeypoint = {
				new = function(t, v)
					return { Time = t, Value = v }
				end,
			},
			PhysicalProperties = {
				new = function(...)
					return { ... }
				end,
			},
			Rect = {
				new = function(...)
					return { ... }
				end,
			},
			Font = {
				new = function()
					return {}
				end,
				fromEnum = function(e)
					return e
				end,
			},
			Region3 = {
				new = function()
					return {}
				end,
			},
			OverlapParams = {
				new = function()
					return {}
				end,
			},
			RaycastParams = {
				new = function()
					return {}
				end,
			},
			tick = function()
				return clock
			end,
			time = function()
				return clock
			end,
			warn = function(...)
				if world.quiet ~= true then
					print("[warn]", ...)
				end
			end,
		}
	end
	envFor = makeEnv

	-- os.clock stays real; the fake clock is for task.wait and Heartbeat.
	function world.require(path: string): any
		-- "server/Lobby" or "shared/LobbyLayout"
		local folderName, name = string.match(path, "^(%w+)/(.+)$")
		local folder = if folderName == "shared" then shared else server
		local m = folder:FindFirstChild(name)
		if not m then
			error("no module " .. path)
		end
		return loadModule(m)
	end
	-- Runs Heartbeat listeners and wakes sleepers for `dt` seconds of fake time.
	function world.step(dt: number)
		clock += dt
		run.Heartbeat:Fire(dt)
		local due = {}
		local keep = {}
		for _, w in waiting do
			if w.at <= clock then
				table.insert(due, w)
			else
				table.insert(keep, w)
			end
		end
		waiting = keep
		for _, w in due do
			local ok, err = coroutine.resume(w.co)
			if not ok then
				error(err, 0)
			end
		end
		local keepD = {}
		for _, d in delayed do
			if d.at <= clock then
				d.fn()
			else
				table.insert(keepD, d)
			end
		end
		delayed = keepD
	end
	function world.service(name: string)
		return service(name)
	end
	function world.newPlayer(name: string, userId: number)
		local p = newInstance("Player")
		p.Name = name
		p.DisplayName = name
		p.UserId = userId
		return p
	end
	world.instance = newInstance
	world.signal = newSignal
	return world
end

Mock.V3 = V3
Mock.CF = CF
Mock.C3 = C3

-- Measuring helpers for tests ------------------------------------------------
-- Highest and lowest point and the x/z extent of every part under `inst`.
function Mock.extent(inst: any): {
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
	parts: number,
}
	local e = {
		minX = math.huge,
		maxX = -math.huge,
		minY = math.huge,
		maxY = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge,
		parts = 0,
	}
	for _, p in partsOf(inst) do
		local a, b = partBox(p)
		e.minX, e.maxX = math.min(e.minX, a.X), math.max(e.maxX, b.X)
		e.minY, e.maxY = math.min(e.minY, a.Y), math.max(e.maxY, b.Y)
		e.minZ, e.maxZ = math.min(e.minZ, a.Z), math.max(e.maxZ, b.Z)
		e.parts += 1
	end
	return e
end

return Mock
