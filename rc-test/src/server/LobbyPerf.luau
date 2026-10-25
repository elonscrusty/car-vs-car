--!strict
-- Phone speed pass for the walking lobby, run once after everything is built.
-- - Small copies of the plots (Mini_*): pure looks, nobody stands on them (the grass is right
--   under), so no shadows, no collisions, no queries, no touches. The two rock copies alone are
--   ~11k parts, so this is most of the physics in the lobby.
-- - Everywhere else: small bits (under SMALL studs) drop their shadow and touch events, and tiny
--   ones (under TINY) stop colliding. Seats, prompts' pads and the ground are left alone.

local LobbyPerf = {}

LobbyPerf.SMALL = 2.5 -- shadow + touch off below this (largest side, studs)
LobbyPerf.TINY = 1.2 -- collisions off below this too

local function looksOnly(p: BasePart)
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

export type Report = { parts: number, shadows: number, collide: number }

local function count(root: Instance): Report
	local r = { parts = 0, shadows = 0, collide = 0 }
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			r.parts += 1
			if d.CastShadow then
				r.shadows += 1
			end
			if d.CanCollide then
				r.collide += 1
			end
		end
	end
	return r
end

-- Returns the counts before and after, for the log.
function LobbyPerf.apply(lobby: Instance): (Report, Report)
	local before = count(lobby)
	for _, child in lobby:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Mini_" then
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					looksOnly(d)
				end
			end
		end
	end
	for _, d in lobby:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Seat") then
			local big = math.max(d.Size.X, d.Size.Y, d.Size.Z)
			if big < LobbyPerf.SMALL then
				d.CastShadow = false
				d.CanTouch = false
				if big < LobbyPerf.TINY then
					d.CanCollide = false
				end
			end
		end
	end
	return before, count(lobby)
end

-- The plots (workspace.Plots) get the same small-bits pass, now and whenever a part is added
-- later (an owner's tile track, their cars on the stands, new looks). Inside a plot's "Track"
-- the cars drive, so there only the shadow and touch events go: every bit still collides.
local function inTrack(d: Instance, plots: Instance): boolean
	local node = d.Parent
	while node and node ~= plots do
		if node.Name == "Track" then
			return true
		end
		node = node.Parent
	end
	return false
end

local function smallBit(d: Instance, plots: Instance)
	if not d:IsA("BasePart") or d:IsA("Seat") then
		return
	end
	local big = math.max(d.Size.X, d.Size.Y, d.Size.Z)
	if big < LobbyPerf.SMALL then
		d.CastShadow = false
		d.CanTouch = false
		if big < LobbyPerf.TINY and not inTrack(d, plots) then
			d.CanCollide = false
		end
	end
end

function LobbyPerf.plots(plots: Instance): (Report, Report)
	local before = count(plots)
	for _, d in plots:GetDescendants() do
		smallBit(d, plots)
	end
	plots.DescendantAdded:Connect(function(d: Instance)
		smallBit(d, plots)
	end)
	return before, count(plots)
end

return LobbyPerf
