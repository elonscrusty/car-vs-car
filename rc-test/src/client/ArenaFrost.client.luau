--!strict
-- Frosty Yard, the client half (shared/FrostYard): when workspace attribute "ArenaTheme" is "frost",
-- re-colour the arena's parts by name toward snow; when it goes back to "yard", put every part's own
-- colour back. Looks only, nothing goes over the network. A part's first colour is remembered (weak
-- table), and a part that shows up later is dressed to match the look that is on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrostYard = require(ReplicatedStorage.Shared.FrostYard)

local originals: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local mixes: { [string]: { c: Color3, a: number } } = {}
for name, rule in FrostYard.RECOLOR do
	mixes[name] = { c = Color3.fromRGB(rule.c[1], rule.c[2], rule.c[3]), a = rule.a }
end

local function theme(): string
	local t = workspace:GetAttribute(FrostYard.ATTR)
	return if t == FrostYard.FROST then FrostYard.FROST else FrostYard.YARD
end

local function dress(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local mix = mixes[inst.Name]
	if not mix then
		return
	end
	local orig = originals[inst]
	if not orig then
		orig = inst.Color
		originals[inst] = orig
	end
	inst.Color = if theme() == FrostYard.FROST
		then (orig :: Color3):Lerp(mix.c, mix.a)
		else orig :: Color3
end

local arena: Instance? = nil
local pass = 0 -- a newer pass stops an older one that is still working through the parts

local function redo()
	local root = arena
	if not root then
		return
	end
	pass += 1
	local mine = pass
	local n = 0
	for _, d in root:GetDescendants() do
		dress(d)
		n += 1
		if n % 400 == 0 then
			task.wait()
			if mine ~= pass then
				return
			end
		end
	end
end

task.spawn(function()
	arena = workspace:WaitForChild("SmashArena", 60)
	if not arena then
		return
	end
	arena.DescendantAdded:Connect(dress)
	redo()
end)

local last = theme()
workspace:GetAttributeChangedSignal(FrostYard.ATTR):Connect(function()
	local now = theme()
	if now ~= last then
		last = now
		task.spawn(redo)
	end
end)
