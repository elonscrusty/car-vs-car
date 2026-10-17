--!strict
-- Plays the claw machine's grab on the server so every player in the lobby sees it:
-- carriage and claw glide over a spot, drop, grab, lift, carry to the chute and let go.
-- The prize is already decided by the caller; this is only the show.

local RunService = game:GetService("RunService")

local ClawPath = require(game:GetService("ReplicatedStorage").Shared.ClawPath)

-- Parts that slide sideways with the claw, and the ones that also go up and down with it.
local CARRIAGE = { "X carriage", "Carriage steel face" }
local CLAW_SLIDE = { "Winch" }
local CLAW_DROP = { "Claw hub", "Hub collar", "Finger hinge", "Claw finger" }
local CABLE = "Claw cable"

-- Studs, in the model's own space (the model is imported facing -Z with the chute at +X, -Z).
local DEPTH = 1.5
local CHUTE: ClawPath.Spot = { x = 2.0, z = -1.9 }
local REACH_X = 1.4
local REACH_Z = 1.0

export type Anim = {
	busy: () -> boolean,
	-- Starts the show; `onDone` runs when the claw is back home. Returns false if already running.
	play: (onDone: () -> ()) -> boolean,
	-- Seconds a show lasts (so callers can time their reveal).
	duration: () -> number,
}

type Item = { part: BasePart, home: CFrame, kind: string, homeSizeY: number }

local ClawAnim = {}

local function matches(name: string, list: { string }): boolean
	for _, n in list do
		if name == n or name:sub(1, #n + 1) == n .. " " or name:sub(1, #n + 1) == n .. "." then
			return true
		end
	end
	return false
end

function ClawAnim.new(model: Model): Anim
	local items: { Item } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = ""
			if matches(d.Name, CARRIAGE) then
				kind = "carriage"
			elseif d.Name == CABLE then
				kind = "cable"
			elseif matches(d.Name, CLAW_SLIDE) then
				kind = "slide"
			elseif matches(d.Name, CLAW_DROP) then
				kind = "drop"
			end
			if kind ~= "" then
				table.insert(
					items,
					{ part = d, home = d.CFrame, kind = kind, homeSizeY = d.Size.Y }
				)
			end
		end
	end

	local home = model:GetPivot()
	local running = false
	local random = Random.new()

	local function apply(pose: ClawPath.Pose)
		local side = home:VectorToWorldSpace(Vector3.new(pose.dx, 0, pose.dz))
		local down = home:VectorToWorldSpace(Vector3.new(0, pose.dy, 0))
		local along = home:VectorToWorldSpace(Vector3.new(pose.dx, 0, 0))
		for _, it in items do
			if it.part.Parent == nil then
				continue
			end
			if it.kind == "carriage" then
				it.part.CFrame = it.home + along
			elseif it.kind == "slide" then
				it.part.CFrame = it.home + side
			elseif it.kind == "cable" then
				-- Top stays at the winch; the cable stretches as the claw lowers.
				it.part.Size = Vector3.new(it.part.Size.X, it.homeSizeY - pose.dy, it.part.Size.Z)
				it.part.CFrame = it.home + side + down * 0.5
			else
				it.part.CFrame = it.home + side + down
			end
		end
	end

	local anim: Anim
	anim = {
		busy = function()
			return running
		end,
		duration = function()
			return ClawPath.total()
		end,
		play = function(onDone: () -> ()): boolean
			if running or #items == 0 then
				return false
			end
			running = true
			local target: ClawPath.Spot = {
				x = random:NextNumber(-REACH_X, REACH_X),
				z = random:NextNumber(-REACH_Z, REACH_Z),
			}
			local t = 0
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function(dt: number)
				t += dt
				if t >= ClawPath.total() or model.Parent == nil then
					conn:Disconnect()
					apply(ClawPath.pose(ClawPath.total(), target, CHUTE, DEPTH))
					running = false
					onDone()
					return
				end
				apply(ClawPath.pose(t, target, CHUTE, DEPTH))
			end)
			return true
		end,
	}
	return anim
end

return ClawAnim
