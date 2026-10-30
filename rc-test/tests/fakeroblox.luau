--!nocheck
-- A pretend Roblox server for Lune, so the real server scripts (src/server, src/shared) can run
-- in a test the way they run in a game: game:GetService, Instance.new, RemoteEvents, Players,
-- task.wait / task.spawn on a pretend clock, os.time / os.clock on that clock, an in-memory
-- DataStore (kept between "servers", so leaving and rejoining works), and a log of every error
-- a thread hits (what would be red in Studio's output) and every warn.
-- Use: local server = Fake.server(store); server.run(path); server.join(userId); server.advance(s)
-- Nothing here is shipped. tests/cvc_loop.test.luau is the test that plays the game through it.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Fake = {}

local START = 1_790_000_000 -- os.time() at the start of a pretend server (a Tuesday)

-- ===== signals =====

local function signal(spawn: (any, ...any) -> ())
	local s = { _fns = {} }
	function s.Connect(_self, fn)
		local c = { Connected = true }
		table.insert(s._fns, c)
		c.fn = fn
		function c.Disconnect()
			c.Connected = false
		end
		return c
	end
	function s.Once(self, fn)
		local c
		c = self:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function s.Wait(self)
		local co = coroutine.running()
		self:Once(function(...)
			spawn(co, ...)
		end)
		return coroutine.yield()
	end
	-- calls each listener on its own thread (as Roblox does)
	function s._fire(...)
		for _, c in table.clone(s._fns) do
			if c.Connected then
				spawn(c.fn, ...)
			end
		end
	end
	return s
end

-- a table that answers any key with another such table (Enum.X.Y, settings...)
local function anything(name: string): any
	return setmetatable({}, {
		__index = function(t, k)
			local v = anything(name .. "." .. tostring(k))
			rawset(t, k, v)
			return v
		end,
		__tostring = function()
			return name
		end,
	})
end

-- A seeded Random (Lune has no Roblox Random): NextNumber, NextInteger.
local function newRandom(seed: number?): any
	local state = math.floor(seed or 12345) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local r = {}
	function r.NextNumber(_self, lo, hi)
		state = (state * 16807) % 2147483647
		local x = (state - 1) / 2147483646
		if lo then
			return lo + x * (hi - lo)
		end
		return x
	end
	function r.NextInteger(self, lo, hi)
		return math.min(hi, lo + math.floor(self:NextNumber() * (hi - lo + 1)))
	end
	function r.Clone()
		return newRandom(state)
	end
	return r
end
Fake.random = newRandom

-- ===== one pretend server =====

export type Store = { [string]: string } -- key -> JSON (shared by every server made with it)

function Fake.store(): Store
	return {}
end

function Fake.server(store: Store, opts: { seed: number?, jobId: string?, at: number? }?)
	local o = opts or {}
	local S = {}
	local now = 0 -- pretend seconds since this server started
	local base = o.at or START
	local rng = newRandom(o.seed or 7)
	S.errors = {} :: { string } -- every error a thread hit
	S.warns = {} :: { string }
	S.prints = {} :: { string }
	S.sent = {} :: { [any]: { { any } } } -- player -> every (remoteName, ...) fired to them
	S.storeCalls = 0
	S.tagged = {} :: { [string]: { [any]: boolean } }
	S.unknown = {} :: { [string]: boolean } -- Class.Member read before anything set it

	-- ----- the clock and threads -----
	local sleeping: { { at: number, co: thread, n: number } } = {}
	local seq = 0

	local function report(co: thread, err: any)
		local msg = tostring(err) .. "\n" .. debug.traceback(co)
		table.insert(S.errors, msg)
	end

	S.prof = nil :: { [string]: number }?
	S.origin = setmetatable({}, { __mode = "k" }) :: { [thread]: string }
	local function resume(co: thread, ...)
		local t0 = if S.prof then os.clock() else 0
		local ok, err = coroutine.resume(co, ...)
		if S.prof then
			local k = S.origin[co] or "?"
			S.prof[k] = (S.prof[k] or 0) + os.clock() - t0
		end
		if not ok then
			report(co, err)
		end
	end

	local function sleep(co: thread, secs: number)
		seq += 1
		table.insert(sleeping, { at = now + math.max(secs, 0), co = co, n = seq, from = now })
	end

	local task = {}
	function task.spawn(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		if type(f) == "function" and S.prof then
			local src, line = debug.info(f, "sl")
			S.origin[co] = `{src}:{line}`
		end
		resume(co, ...)
		return co
	end
	function task.defer(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		local args = table.pack(...)
		seq += 1
		table.insert(sleeping, {
			at = now,
			n = seq,
			from = now,
			co = co,
			args = args,
		})
		return co
	end
	function task.delay(secs, f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		local args = table.pack(...)
		seq += 1
		table.insert(
			sleeping,
			{ at = now + (secs or 0), n = seq, from = now, co = co, args = args }
		)
		return co
	end
	function task.wait(secs)
		local co = coroutine.running()
		sleep(co, secs or 0.03)
		local from = now
		coroutine.yield()
		return now - from
	end
	function task.cancel(co)
		for i = #sleeping, 1, -1 do
			if sleeping[i].co == co then
				table.remove(sleeping, i)
			end
		end
	end
	S.task = task

	local fakeOs = setmetatable({
		time = function(t)
			if t then
				return os.time(t)
			end
			return math.floor(base + now)
		end,
		clock = function()
			return now
		end,
		date = function(fmt, t)
			return os.date(fmt, t or math.floor(base + now))
		end,
	}, { __index = os })

	-- ----- instances -----
	local Instance = {}
	local classes: { [string]: (any) -> () } = {}

	local function newInst(class: string, name: string?): any
		local p = {
			ClassName = class,
			Name = name or class,
			_children = {},
			_attrs = {},
			_parent = nil,
			_attrSignals = {},
		}
		local inst = setmetatable({}, {
			__index = function(_, k)
				if k == "Parent" then
					return p._parent
				elseif k == "Position" then
					return p._position or p.CFrame.Position
				elseif k == "Orientation" or k == "Rotation" then
					-- (a 2D gui object's Rotation is a number)
					if p._gui then
						return p.Rotation or 0
					end
					return roblox.Vector3.zero
				elseif k == "PrimaryPart" then
					return rawget(p, "PrimaryPart")
				end
				local v = p[k]
				if v ~= nil then
					return v
				end
				for _, c in p._children do
					if c.Name == k then
						return c
					end
				end
				-- (a property nobody set: nil, and noted, so a test can still catch a typo)
				S.unknown[`{class}.{k}`] = true
				return nil
			end,
			__newindex = function(self, k, v)
				if k == "Position" and typeof(v) == "Vector3" then
					p.CFrame = roblox.CFrame.new(v) * p.CFrame.Rotation
					return
				elseif k == "Position" then
					p._position = v
					return
				end
				if k == "Parent" then
					local old = p._parent
					if old then
						local list = (getmetatable(old) :: any).p._children
						local i = table.find(list, self)
						if i then
							table.remove(list, i)
						end
					end
					p._parent = v
					if v then
						table.insert((getmetatable(v) :: any).p._children, self)
						local added = (getmetatable(v) :: any).p.ChildAdded
						if added then
							added._fire(self)
						end
					end
				else
					p[k] = v
				end
			end,
			__tostring = function()
				return p.Name
			end,
			p = p,
		})
		p.ChildAdded = signal(task.spawn)
		p.Destroying = signal(task.spawn)
		function p.FindFirstChild(_, n, deep)
			for _, c in p._children do
				if c.Name == n then
					return c
				end
			end
			if deep then
				for _, c in p._children do
					local f = c:FindFirstChild(n, true)
					if f then
						return f
					end
				end
			end
			return nil
		end
		function p.WaitForChild(self, n, timeout)
			local c = self:FindFirstChild(n)
			if c then
				return c
			end
			local waited = 0
			while waited < (timeout or 10) do
				task.wait(0.1)
				waited += 0.1
				c = self:FindFirstChild(n)
				if c then
					return c
				end
			end
			if not timeout then
				table.insert(S.warns, `Infinite yield possible on '{p.Name}:WaitForChild("{n}")'`)
			end
			return nil
		end
		function p.FindFirstChildOfClass(_, cls)
			for _, c in p._children do
				if c.ClassName == cls then
					return c
				end
			end
			return nil
		end
		function p.FindFirstChildWhichIsA(self, cls)
			return self:FindFirstChildOfClass(cls)
		end
		function p.FindFirstAncestor(_, n)
			local a = p._parent
			while a do
				if a.Name == n then
					return a
				end
				a = a.Parent
			end
			return nil
		end
		function p.GetChildren()
			return table.clone(p._children)
		end
		function p.GetDescendants()
			local out = {}
			local function walk(i)
				for _, c in (getmetatable(i) :: any).p._children do
					table.insert(out, c)
					walk(c)
				end
			end
			walk(inst)
			return out
		end
		function p.IsDescendantOf(_, other)
			local a = p._parent
			while a do
				if a == other then
					return true
				end
				a = a.Parent
			end
			return false
		end
		function p.IsA(_, cls)
			return p.ClassName == cls
				or cls == "Instance"
				or (cls == "BasePart" and (p.ClassName == "Part" or p.ClassName == "MeshPart"))
				or (cls == "GuiObject" and p._gui == true)
				or (
					cls == "LuaSourceContainer"
					and (p.ClassName == "ModuleScript" or p.ClassName == "Script")
				)
		end
		function p.GetAttribute(_, k)
			return p._attrs[k]
		end
		function p.GetAttributes()
			return table.clone(p._attrs)
		end
		function p.SetAttribute(_, k, v)
			local t = typeof(v)
			if v ~= nil and t ~= "number" and t ~= "string" and t ~= "boolean" then
				local mt = getmetatable(v :: any)
				if type(v) == "table" or type(v) == "function" or (mt and (mt :: any).p) then
					error(`SetAttribute: {t} is not a supported attribute type ({k})`, 2)
				end
			end
			if type(v) == "number" and v ~= v then
				-- (Roblox stores NaN; still a bug worth seeing)
				table.insert(S.warns, `SetAttribute {k} = NaN on {p.Name}`)
			end
			local old = p._attrs[k]
			p._attrs[k] = v
			if old ~= v and p._attrSignals[k] then
				p._attrSignals[k]._fire()
			end
		end
		function p.GetAttributeChangedSignal(_, k)
			p._attrSignals[k] = p._attrSignals[k] or signal(task.spawn)
			return p._attrSignals[k]
		end
		p.AttributeChanged = signal(task.spawn)
		function p.GetPropertyChangedSignal()
			return signal(task.spawn)
		end
		function p.Destroy(self)
			p.Destroying._fire()
			self.Parent = nil
		end
		function p.ClearAllChildren()
			for _, c in table.clone(p._children) do
				c:Destroy()
			end
		end
		function p.Clone(self)
			local c = newInst(p.ClassName, p.Name)
			for k, v in p._attrs do
				c:SetAttribute(k, v)
			end
			return c
		end
		p._tags = {}
		function p.AddTag(_, t)
			p._tags[t] = true
			S.tagged[t] = S.tagged[t] or {}
			S.tagged[t][inst] = true
		end
		function p.RemoveTag(_, t)
			p._tags[t] = nil
			if S.tagged[t] then
				S.tagged[t][inst] = nil
			end
		end
		function p.HasTag(_, t)
			return p._tags[t] == true
		end
		function p.GetTags()
			local out = {}
			for t in p._tags do
				table.insert(out, t)
			end
			return out
		end
		-- parts and models: where they are
		p.CFrame = roblox.CFrame.new()
		p.Size = roblox.Vector3.new(1, 1, 1)
		p.AssemblyLinearVelocity = roblox.Vector3.zero
		p.AssemblyAngularVelocity = roblox.Vector3.zero
		p.Transparency = 0
		p.Anchored = false
		p.CanCollide = true
		p.Enabled = true
		p.Value = nil
		-- a model moves all its parts (round its PrimaryPart when it has one)
		function p.GetPivot()
			local pp = rawget(p, "PrimaryPart")
			return if pp then pp.CFrame else p.CFrame
		end
		function p.PivotTo(_, cf)
			local from = p.GetPivot()
			p.CFrame = cf
			local move = cf * from:Inverse()
			for _, d in p.GetDescendants() do
				local dp = (getmetatable(d) :: any).p
				dp.CFrame = move * dp.CFrame
			end
		end
		p.SetPrimaryPartCFrame = p.PivotTo
		function p.GetBoundingBox()
			return p.CFrame, p.Size
		end
		function p.GetExtentsSize()
			return p.Size
		end
		function p.ScaleTo() end
		function p.GetScale()
			return 1
		end
		function p.SetNetworkOwner() end
		function p.SetNetworkOwnershipAuto() end
		function p.GetNetworkOwner()
			return nil
		end
		function p.ApplyImpulse() end
		function p.GetMass()
			return 1
		end
		function p.GetConnectedParts()
			return {}
		end
		function p.GetTouchingParts()
			return {}
		end
		function p.BreakJoints() end
		p.Touched = signal(task.spawn)
		p.TouchEnded = signal(task.spawn)
		p.Changed = signal(task.spawn)
		p.DescendantAdded = signal(task.spawn)
		p.DescendantRemoving = signal(task.spawn)
		p.ChildRemoved = signal(task.spawn)
		p.AncestryChanged = signal(task.spawn)
		p.Died = signal(task.spawn)
		p.Triggered = signal(task.spawn)
		p.Seated = signal(task.spawn)
		if classes[class] then
			classes[class](p, inst)
		end
		return inst
	end

	classes.RemoteEvent = function(p, inst)
		p.OnServerEvent = signal(task.spawn)
		p.OnClientEvent = signal(task.spawn)
		function p.FireClient(_, player, ...)
			if player == nil or (getmetatable(player) :: any).p.ClassName ~= "Player" then
				error("FireClient: player argument must be a Player", 2)
			end
			S.sent[player] = S.sent[player] or {}
			table.insert(S.sent[player], { p.Name, ... })
		end
		function p.FireAllClients(_, ...)
			for _, pl in S.players do
				inst:FireClient(pl, ...)
			end
		end
	end
	classes.UnreliableRemoteEvent = classes.RemoteEvent
	classes.RemoteFunction = function(p)
		p.OnServerInvoke = nil
	end
	classes.BindableEvent = function(p)
		p.Event = signal(task.spawn)
		function p.Fire(_, ...)
			p.Event._fire(...)
		end
	end

	function Instance.new(class, parent)
		local i = newInst(class)
		if parent then
			i.Parent = parent
		end
		return i
	end
	S.Instance = Instance

	local function typeofFake(v)
		local mt = getmetatable(v)
		if type(v) == "table" and type(mt) == "table" and rawget(mt, "p") then
			return "Instance"
		end
		return typeof(v)
	end

	-- ----- the data model -----
	local game = newInst("DataModel", "Game")
	local gp = (getmetatable(game) :: any).p
	gp.JobId = o.jobId or ("job-" .. tostring(o.seed or 7))
	gp.PlaceId = 0
	local closers = {}
	function gp.BindToClose(_, fn)
		table.insert(closers, fn)
	end
	local services = {}
	function gp.GetService(_, name)
		local s = services[name]
		if s then
			return s
		end
		s = newInst(name, name)
		s.Parent = game
		services[name] = s
		return s
	end
	gp.FindService = gp.GetService
	function gp.IsLoaded()
		return true
	end
	gp.Loaded = signal(task.spawn)
	local workspace = game:GetService("Workspace")
	gp.Workspace = workspace
	do
		local wp = (getmetatable(workspace) :: any).p
		wp.Gravity = 196.2
		function wp.Raycast()
			return nil
		end
		function wp.GetPartBoundsInBox()
			return {}
		end
		function wp.GetPartBoundsInRadius()
			return {}
		end
		function wp.GetPartsInPart()
			return {}
		end
		function wp.GetServerTimeNow()
			return base + now
		end
	end

	-- Players
	S.players = {} :: { any }
	local Players = game:GetService("Players")
	do
		local pp = (getmetatable(Players) :: any).p
		pp.PlayerAdded = signal(task.spawn)
		pp.PlayerRemoving = signal(task.spawn)
		pp.MaxPlayers = 8
		function pp.GetPlayers()
			return table.clone(S.players)
		end
		function pp.GetPlayerByUserId(_, id)
			for _, pl in S.players do
				if pl.UserId == id then
					return pl
				end
			end
			return nil
		end
		function pp.GetNameFromUserIdAsync(_, id)
			return "Kid" .. id
		end
	end

	-- RunService
	do
		local rp = (getmetatable(game:GetService("RunService")) :: any).p
		rp.Heartbeat = signal(task.spawn)
		rp.Stepped = signal(task.spawn)
		rp.PostSimulation = rp.Heartbeat
		rp.RenderStepped = rp.Heartbeat -- (the client draws once per beat)
		function rp.IsStudio()
			return false -- a live server: Studio-only test remotes must stay shut
		end
		function rp.IsServer()
			return true
		end
		function rp.IsClient()
			return false
		end
	end

	-- HttpService
	do
		local hp = (getmetatable(game:GetService("HttpService")) :: any).p
		local n = 0
		function hp.GenerateGUID(_, braces)
			n += 1
			local g = string.format("%08x-0000-4000-8000-%012x", rng:NextInteger(0, 0x7fffffff), n)
			return if braces == false then g else "{" .. g .. "}"
		end
		function hp.JSONEncode(_, v)
			return serde.encode("json", v)
		end
		function hp.JSONDecode(_, s)
			return serde.decode("json", s)
		end
	end

	-- DataStoreService: one table per key, saved as JSON (what Roblox keeps is a copy)
	do
		local dp = (getmetatable(game:GetService("DataStoreService")) :: any).p
		S.storeDown = false
		function dp.GetDataStore(_, storeName)
			local ds = {}
			local function k(key)
				return storeName .. "/" .. key
			end
			local function copy(raw)
				return if raw then serde.decode("json", raw) else nil
			end
			function ds.UpdateAsync(_, key, fn)
				S.storeCalls += 1
				if S.storeDown then
					error("502: DataStore request failed (pretend outage)")
				end
				local new = fn(copy(store[k(key)]))
				if new ~= nil then
					store[k(key)] = serde.encode("json", new)
				end
				return copy(store[k(key)])
			end
			function ds.GetAsync(_, key)
				S.storeCalls += 1
				if S.storeDown then
					error("502: DataStore request failed (pretend outage)")
				end
				return copy(store[k(key)])
			end
			function ds.SetAsync(_, key, v)
				S.storeCalls += 1
				store[k(key)] = serde.encode("json", v)
			end
			function ds.RemoveAsync(_, key)
				store[k(key)] = nil
			end
			return ds
		end
		function dp.GetOrderedDataStore(_, storeName)
			local ods = dp.GetDataStore(_, "ordered:" .. storeName)
			function ods.GetSortedAsync()
				return {
					IsFinished = true,
					GetCurrentPage = function()
						return {}
					end,
					AdvanceToNextPageAsync = function() end,
				}
			end
			return ods
		end
		function dp.GetRequestBudgetForRequestType()
			return 100
		end
	end

	do
		local cp = (getmetatable(game:GetService("CollectionService")) :: any).p
		function cp.GetTagged(_, tag)
			local out = {}
			for d in S.tagged[tag] or {} do
				if d:IsDescendantOf(game) then
					table.insert(out, d)
				end
			end
			return out
		end
		function cp.HasTag(_, i, tag)
			return i:HasTag(tag)
		end
		function cp.AddTag(_, i, tag)
			i:AddTag(tag)
		end
		function cp.RemoveTag(_, i, tag)
			i:RemoveTag(tag)
		end
		function cp.GetInstanceAddedSignal()
			return signal(task.spawn)
		end
		function cp.GetInstanceRemovedSignal()
			return signal(task.spawn)
		end
	end

	-- MarketplaceService, TextService, etc.: present, and quiet
	do
		local mp = (getmetatable(game:GetService("MarketplaceService")) :: any).p
		mp.PromptProductPurchaseFinished = signal(task.spawn)
		mp.PromptGamePassPurchaseFinished = signal(task.spawn)
		function mp.UserOwnsGamePassAsync()
			return false
		end
	end

	-- ----- scripts from the Rojo tree -----
	local modules: { [any]: any } = {}
	local loading: { [any]: boolean } = {}
	local makeEnv

	local function fakeRequire(target)
		if type(target) == "string" then
			error("string require in a Roblox script: " .. target, 2)
		end
		if modules[target] ~= nil then
			return modules[target]
		end
		local p = (getmetatable(target) :: any).p
		if p.ClassName ~= "ModuleScript" then
			error(`require: {p.Name} is not a ModuleScript`, 2)
		end
		if loading[target] then
			error(`require loop: {p.Name}`, 2)
		end
		loading[target] = true
		local fn = luau.load(p._source, { debugName = p._path, environment = makeEnv(target) })
		local result = fn()
		loading[target] = nil
		modules[target] = result
		return result
	end

	local Vector3, Color3 = roblox.Vector3, roblox.Color3
	-- in real Roblox the built-in `vector` IS Vector3; Lune's are two types, so turn one into
	-- the other where game code hands a `vector` to CFrame
	local function v3(x: any): any
		return if type(x) == "vector" then Vector3.new(x.x, x.y, x.z) else x
	end
	local CFrame = setmetatable({
		new = function(a: any, ...)
			return roblox.CFrame.new(v3(a), ...)
		end,
		lookAt = function(a: any, b: any, up: any?)
			return roblox.CFrame.lookAt(v3(a), v3(b), v3(up))
		end,
	}, { __index = roblox.CFrame })
	function makeEnv(script)
		return setmetatable({
			game = game,
			workspace = workspace,
			Workspace = workspace,
			script = script,
			require = fakeRequire,
			Instance = Instance,
			task = task,
			os = fakeOs,
			tick = function()
				return base + now
			end,
			time = function()
				return now
			end,
			wait = task.wait,
			spawn = task.spawn,
			delay = task.delay,
			typeof = typeofFake,
			Random = { new = newRandom },
			warn = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					table.insert(parts, tostring((select(i, ...))))
				end
				table.insert(S.warns, table.concat(parts, " "))
			end,
			print = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					table.insert(parts, tostring((select(i, ...))))
				end
				table.insert(S.prints, table.concat(parts, " "))
			end,
			Vector3 = Vector3,
			Vector2 = roblox.Vector2,
			CFrame = CFrame,
			Color3 = Color3,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			BrickColor = roblox.BrickColor,
			NumberRange = roblox.NumberRange,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			Rect = roblox.Rect,
			Region3 = roblox.Region3,
			PhysicalProperties = roblox.PhysicalProperties,
			Faces = roblox.Faces,
			Axes = roblox.Axes,
			Font = roblox.Font,
			PathWaypoint = roblox.PathWaypoint,
			RaycastParams = {
				new = function()
					return {}
				end,
			},
			OverlapParams = {
				new = function()
					return {}
				end,
			},
			TweenInfo = {
				new = function(...)
					return { ... }
				end,
			},
			Enum = anything("Enum"),
			settings = function()
				return anything("settings")
			end,
			DateTime = {
				now = function()
					return {
						UnixTimestamp = math.floor(base + now),
						UnixTimestampMillis = (base + now) * 1000,
					}
				end,
			},
		}, { __index = _G })
	end

	-- builds a folder from a source folder: ModuleScripts (*.luau), Scripts (*.server.luau)
	local function mount(dir: string, parent: any, name: string)
		local folder = newInst("Folder", name)
		folder.Parent = parent
		for _, f in fs.readDir(dir) do
			local path = dir .. "/" .. f
			if fs.isDir(path) then
				local init = path .. "/init.luau"
				if fs.isFile(init) then
					local m = newInst("ModuleScript", f)
					local mp = (getmetatable(m) :: any).p
					mp._source, mp._path = fs.readFile(init), init
					m.Parent = folder
					-- (children of a module folder)
					for _, sub in fs.readDir(path) do
						if sub ~= "init.luau" and string.sub(sub, -5) == ".luau" then
							local c = newInst("ModuleScript", string.sub(sub, 1, -6))
							local cp = (getmetatable(c) :: any).p
							cp._source, cp._path =
								fs.readFile(path .. "/" .. sub), path .. "/" .. sub
							c.Parent = m
						end
					end
				else
					mount(path, folder, f)
				end
			elseif string.sub(f, -12) == ".server.luau" then
				local s = newInst("Script", string.sub(f, 1, -13))
				local sp = (getmetatable(s) :: any).p
				sp._source, sp._path = fs.readFile(path), path
				s.Parent = folder
			elseif string.sub(f, -12) == ".client.luau" then
				local s = newInst("LocalScript", string.sub(f, 1, -13))
				s.Parent = folder
			elseif string.sub(f, -5) == ".luau" then
				local m = newInst("ModuleScript", string.sub(f, 1, -6))
				local mp = (getmetatable(m) :: any).p
				mp._source, mp._path = fs.readFile(path), path
				m.Parent = folder
			end
		end
		return folder
	end

	local Shared = mount("src/shared", game:GetService("ReplicatedStorage"), "Shared")
	local Server = mount("src/server", game:GetService("ServerScriptService"), "Server")
	S.game, S.workspace, S.Shared, S.Server = game, workspace, Shared, Server

	S.classes = classes -- (a test can give a class its own starting properties)

	-- The client's modules (src/client, LocalScripts left out) for a layout test: a LocalPlayer
	-- with a PlayerGui, and require("Ui.Screens.Hud") by dotted path from src/client.
	function S.client(userId: number): (string) -> any
		local pl = S.join(userId)
		local gui = newInst("PlayerGui", "PlayerGui")
		gui.Parent = pl;
		(getmetatable(game:GetService("Players")) :: any).p.LocalPlayer = pl
		local starter = game:GetService("StarterPlayer")
		local scripts = starter:FindFirstChild("StarterPlayerScripts")
		if not scripts then
			scripts = newInst("Folder", "StarterPlayerScripts")
			scripts.Parent = starter
		end
		-- (client services the UI touches: tweens jump to the end, no touch screen)
		local ts = (getmetatable(game:GetService("TweenService")) :: any).p
		function ts.Create(_, obj, _info, goal)
			local tw = { Completed = signal(task.spawn), PlaybackState = "Begin" }
			function tw.Play()
				for k, v in goal do
					obj[k] = v
				end
				tw.Completed._fire("Completed")
			end
			function tw.Cancel() end
			function tw.Pause() end
			function tw.Destroy() end
			return tw
		end
		local uis = (getmetatable(game:GetService("UserInputService")) :: any).p
		uis.TouchEnabled = uis.TouchEnabled or false
		local gs = (getmetatable(game:GetService("GuiService")) :: any).p
		function gs.GetGuiInset()
			return roblox.Vector2.new(0, 58), roblox.Vector2.new(0, 0)
		end
		-- (gui events: present, never fired)
		for _, cls in
			{
				"Frame",
				"TextLabel",
				"TextButton",
				"ImageLabel",
				"ImageButton",
				"ScrollingFrame",
				"CanvasGroup",
				"ViewportFrame",
				"TextBox",
			}
		do
			local before = classes[cls]
			classes[cls] = function(p, inst)
				for _, ev in
					{
						"InputBegan",
						"InputEnded",
						"InputChanged",
						"Activated",
						"MouseButton1Click",
						"MouseButton1Down",
						"MouseButton1Up",
						"MouseEnter",
						"MouseLeave",
						"FocusLost",
					}
				do
					p[ev] = signal(task.spawn)
				end
				-- (Base's safe-area probe reads this once, for its stroke scale k)
				p.AbsoluteSize = roblox.Vector2.new(756, 390)
				p.AnchorPoint = roblox.Vector2.new(0, 0)
				p._position = roblox.UDim2.new()
				p.Size = roblox.UDim2.new()
				p.Visible = true
				p.ZIndex = 1
				p._gui = true
				if before then
					before(p, inst)
				end
			end
		end
		-- (sounds: Play does nothing, the clip never ends)
		do
			local before = classes.Sound
			classes.Sound = function(p, inst)
				p.Play = function() end
				p.Stop = function() end
				p.Ended = signal(task.spawn)
				if before then
					before(p, inst)
				end
			end
		end
		local Client = mount("src/client", scripts, "Client")
		S.Client = Client
		return function(path: string): any
			local at = Client
			for part in string.gmatch(path, "[^%.]+") do
				at = at:FindFirstChild(part)
				assert(at, "no client module " .. path)
			end
			local out
			local co = coroutine.create(function()
				out = fakeRequire(at)
			end)
			resume(co)
			return out
		end
	end

	-- require a server or shared module by name ("TrainingServer", "Shared.CvcRules")
	function S.require(name: string): any
		local where = Server
		if string.sub(name, 1, 7) == "Shared." then
			where, name = Shared, string.sub(name, 8)
		end
		local m = where:FindFirstChild(name)
		assert(m, "no module " .. name)
		local out
		local co = coroutine.create(function()
			out = fakeRequire(m)
		end)
		resume(co)
		return out
	end

	-- runs a Script (Foo.server.luau) the way Roblox starts it: on its own thread
	function S.run(name: string)
		local s = Server:FindFirstChild(name)
		assert(s and s.ClassName == "Script", "no script " .. name)
		local p = (getmetatable(s) :: any).p
		local fn = luau.load(p._source, { debugName = p._path, environment = makeEnv(s) })
		task.spawn(fn)
	end

	-- ----- players -----
	function S.join(userId: number): any
		local pl = newInst("Player", "Kid" .. userId)
		local pp = (getmetatable(pl) :: any).p
		pp.UserId = userId
		pp.DisplayName = "Kid" .. userId
		pp.Character = nil
		pp.CharacterAdded = signal(task.spawn)
		pp.CharacterRemoving = signal(task.spawn)
		pp.AccountAge = 30
		pp.MembershipType = anything("Enum.MembershipType.None")
		function pp.Kick(_, why)
			table.insert(S.warns, `kicked {userId}: {why}`)
		end
		function pp.LoadCharacter() end
		function pp.GetJoinData()
			return {}
		end
		function pp.IsInGroup()
			return false
		end
		function pp.GetRankInGroup()
			return 0
		end
		function pp.GetFriendsOnline()
			return {}
		end
		function pp.IsFriendsWith()
			return false
		end
		pl.Parent = Players
		table.insert(S.players, pl)
		local Pp = (getmetatable(Players) :: any).p
		Pp.PlayerAdded._fire(pl)
		return pl
	end

	function S.leave(pl: any)
		local i = table.find(S.players, pl)
		if i then
			table.remove(S.players, i)
		end
		local Pp = (getmetatable(Players) :: any).p
		Pp.PlayerRemoving._fire(pl)
		pl.Parent = nil
	end

	-- The player's screen sends (args...) on ReplicatedStorage[remoteName] (a RemoteEvent).
	function S.send(pl: any, remoteName: string, ...)
		local r = game:GetService("ReplicatedStorage"):FindFirstChild(remoteName)
		assert(r, "no remote " .. remoteName)
		local rp = (getmetatable(r) :: any).p
		rp.OnServerEvent._fire(pl, ...)
	end

	-- What the server sent this player on `remoteName` since `from` (an index into S.sent).
	function S.got(pl: any, remoteName: string, kind: string?): { { any } }
		local out = {}
		for _, m in S.sent[pl] or {} do
			if m[1] == remoteName and (kind == nil or m[2] == kind) then
				table.insert(out, m)
			end
		end
		return out
	end

	-- ----- time -----
	-- Runs every thread that is due, in order, until `secs` pretend seconds have passed.
	-- Heartbeat fires every `beat` seconds (0 = never).
	function S.advance(secs: number, beat: number?)
		local stop = now + secs
		local nextBeat = if beat and beat > 0 then now + beat else math.huge
		local RunService = game:GetService("RunService")
		local hb = (getmetatable(RunService) :: any).p.Heartbeat
		while true do
			local best, bi = nil, nil
			for i, s in sleeping do
				if best == nil or s.at < best.at or (s.at == best.at and s.n < best.n) then
					best, bi = s, i
				end
			end
			local at = if best then best.at else math.huge
			if nextBeat <= at and nextBeat <= stop then
				now = nextBeat
				hb._fire(beat)
				nextBeat += beat :: number
			elseif best and at <= stop then
				table.remove(sleeping, bi)
				now = math.max(now, at)
				if best.args then
					resume(best.co, table.unpack(best.args, 1, best.args.n))
				elseif coroutine.status(best.co) == "suspended" then
					resume(best.co)
				end
			else
				break
			end
		end
		now = stop
	end

	function S.now(): number
		return now
	end

	-- the game shuts down (BindToClose runs)
	function S.close()
		for _, fn in closers do
			task.spawn(fn)
		end
		S.advance(30)
	end

	return S
end

-- a player's attribute (players are pretend Instances)
function Fake.attr(inst: any, name: string): any
	return inst:GetAttribute(name)
end

return Fake
