--!strict
-- The big gumball machine pull show (server side, so every player in the lobby sees it): the whole
-- machine shakes, the crank spins, a capsule rises out of the chute, pops (the two halves fly
-- apart, spin and fade), then `onDone` runs. The prize is already decided by the caller.
--
-- It looks for these parts inside the machine model: "GumballChute" (where the capsule comes out,
-- its +Z side faces out) and every part whose name starts with "GumballCrank" (spun together
-- round the part named "GumballCrank", on the Z axis). The capsule parts are made for the show
-- and destroyed after. Everything is put back exactly where it was.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CHUTE_NAME = "GumballChute"
local CRANK_NAME = "GumballCrank"
local SECONDS = 3.0
local CRANK_END = 1.5 -- the crank stops turning
local RISE_START = 1.2
local POP_AT = 2.15
local SHAKE_END = 2.3 -- the machine settles
local SHAKE_AMOUNT = 0.32 -- studs, at the strongest

local CAPSULE_COLORS = {
	{ Color3.fromRGB(245, 130, 32), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(37, 141, 221), Color3.fromRGB(255, 205, 64) },
	{ Color3.fromRGB(86, 190, 90), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 205, 64) },
}

export type Anim = {
	busy: () -> boolean,
	-- Starts the show; `onDone` runs when it is over. Returns false if already running.
	play: (onDone: () -> ()) -> boolean,
	-- Seconds a show lasts (so callers can time their reveal).
	duration: () -> number,
}

type Half = {
	dir: number,
	parts: { BasePart },
	rels: { CFrame }, -- each part against the capsule middle
}

local GumballAnim = {}

local function easeOut(t: number): number
	local k = 1 - math.clamp(t, 0, 1)
	return 1 - k * k
end

local function makeHalf(parent: Instance, dir: number, color: Color3): Half
	local d = 2.4
	local cyl = Instance.new("Part")
	cyl.Name = "CapsuleHalfBody"
	cyl.Shape = Enum.PartType.Cylinder
	cyl.Size = Vector3.new(1.2, d, d)
	local ball = Instance.new("Part")
	ball.Name = "CapsuleHalfCap"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(d, d, d)
	local parts: { BasePart } = { cyl, ball }
	for _, p in parts do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Parent = parent
	end
	return {
		dir = dir,
		parts = parts,
		rels = { CFrame.new(dir * 0.6, 0, 0), CFrame.new(dir * 1.2, 0, 0) },
	}
end

function GumballAnim.new(machine: Model): Anim
	local running = false
	local rng = Random.new()
	local pulls = 0

	return {
		busy = function()
			return running
		end,
		duration = function()
			return SECONDS
		end,
		play = function(onDone: () -> ()): boolean
			if running then
				return false
			end
			local chute = machine:FindFirstChild(CHUTE_NAME, true)
			if chute == nil or not chute:IsA("BasePart") then
				return false
			end
			running = true
			pulls += 1

			local home = machine:GetPivot()
			local homeInv = home:Inverse()
			-- crank parts against the machine, and the hub they spin round
			local crankParts: { BasePart } = {}
			local crankRels: { CFrame } = {}
			local hubRel = CFrame.new()
			for _, d in machine:GetDescendants() do
				if d:IsA("BasePart") and string.sub(d.Name, 1, #CRANK_NAME) == CRANK_NAME then
					table.insert(crankParts, d)
					table.insert(crankRels, homeInv * d.CFrame)
					if d.Name == CRANK_NAME then
						hubRel = homeInv * d.CFrame
					end
				end
			end
			local hubInv = hubRel:Inverse()
			-- the chute mouth in machine space; the capsule leaves along its +Z
			local chuteRel = homeInv * (chute :: BasePart).CFrame

			local pair = CAPSULE_COLORS[(pulls - 1) % #CAPSULE_COLORS + 1]
			local holder = Instance.new("Folder")
			holder.Name = "GumballCapsule"
			holder.Parent = machine.Parent or Workspace
			local halves = {
				makeHalf(holder, -1, pair[1]),
				makeHalf(holder, 1, pair[2]),
			}
			for _, h in halves do
				for _, p in h.parts do
					p.Transparency = 1
				end
			end

			local t = 0
			local conn: RBXScriptConnection? = nil

			local function finish()
				if conn then
					conn:Disconnect()
					conn = nil
				end
				if machine.Parent ~= nil then
					machine:PivotTo(home)
					for i, p in crankParts do
						p.CFrame = home * crankRels[i]
					end
				end
				holder:Destroy()
				running = false
				onDone()
			end

			conn = RunService.Heartbeat:Connect(function(dt: number)
				t += dt
				if t >= SECONDS or machine.Parent == nil then
					finish()
					return
				end

				-- 1. the machine shakes (strong, then it settles)
				local amount = 0
				if t < SHAKE_END then
					amount = SHAKE_AMOUNT * (1 - 0.6 * (t / SHAKE_END))
				end
				local shake = CFrame.new(
					(rng:NextNumber() * 2 - 1) * amount,
					(rng:NextNumber() * 2 - 1) * amount * 0.4,
					(rng:NextNumber() * 2 - 1) * amount
				) * CFrame.Angles(0, (rng:NextNumber() * 2 - 1) * amount * 0.01, 0)
				local now = home * shake
				machine:PivotTo(now)

				-- 2. the crank spins, fast then slow
				local spin = easeOut(t / CRANK_END) * math.pi * 6
				for i, p in crankParts do
					p.CFrame = now * hubRel * CFrame.Angles(0, 0, spin) * hubInv * crankRels[i]
				end

				-- 3. the capsule rises out of the chute, then pops
				if t < RISE_START then
					return
				end
				local rise = easeOut((t - RISE_START) / (POP_AT - RISE_START))
				local wobble = math.sin(t * 22) * 0.12 * (1 - rise)
				local mouth = chuteRel * CFrame.new(0, 0.2 + rise * 5.5, 1.2 + rise * 3)
				local grow = 0.35 + 0.65 * rise
				local base = now * mouth
				local orient = CFrame.Angles(0, 0, math.pi / 2 + wobble)
				local tau = math.max(0, t - POP_AT) -- seconds since the pop
				local fade = math.clamp(tau / (SECONDS - POP_AT), 0, 1)
				for _, h in halves do
					local away = Vector3.new(
						h.dir * tau * 4,
						h.dir * tau * 3 + tau * 5 - tau * tau * 12,
						tau * 2
					)
					local twist = CFrame.Angles(h.dir * tau * 9, 0, h.dir * tau * 5)
					for i, p in h.parts do
						local rel = h.rels[i]
						local size = if i == 1
							then Vector3.new(1.2, 2.4, 2.4)
							else Vector3.new(2.4, 2.4, 2.4)
						p.Size = size * grow
						p.CFrame = base
							* CFrame.new(away)
							* orient
							* twist
							* CFrame.new(rel.Position * grow)
						p.Transparency = fade
					end
				end
			end)
			return true
		end,
	}
end

return GumballAnim
