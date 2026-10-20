--!strict
-- Plays the gumball machine's drop on the server so every player in the lobby sees it:
-- the knob turns, a ball rolls down inside, drops out of the chute and bounces once in the tray.
-- The prize is already decided by the caller; this is only the show. (The file keeps its old
-- name because LobbyService and the lobby handle call it "claw".)

local RunService = game:GetService("RunService")

local DROP_NAME = "GumballDrop" -- the hidden ball inside the machine
local CRANK_NAME = "GumballCrank"
local SECONDS = 2.4

export type Anim = {
	busy: () -> boolean,
	-- Starts the show; `onDone` runs when the ball has dropped. Returns false if already running.
	play: (onDone: () -> ()) -> boolean,
	-- Seconds a show lasts (so callers can time their reveal).
	duration: () -> number,
}

local ClawAnim = {}

local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return a + (b - a) * t
end

function ClawAnim.new(model: Model): Anim
	local drop = model:FindFirstChild(DROP_NAME)
	local crank = model:FindFirstChild(CRANK_NAME)
	local ball: BasePart? = if drop and drop:IsA("BasePart") then drop else nil
	local knob: BasePart? = if crank and crank:IsA("BasePart") then crank else nil
	local home: Vector3? = if ball then ball.Position else nil
	local chuteAttr: any = if ball then ball:GetAttribute("Chute") else nil
	local chute: Vector3? = if typeof(chuteAttr) == "Vector3" then chuteAttr else nil
	local knobHome: CFrame? = if knob then knob.CFrame else nil
	local running = false

	return {
		busy = function()
			return running
		end,
		duration = function()
			return SECONDS
		end,
		play = function(onDone: () -> ()): boolean
			if running or ball == nil or home == nil or chute == nil then
				return false
			end
			local b: BasePart = ball
			local from: Vector3 = home
			local to: Vector3 = chute
			running = true
			b.Transparency = 0
			local t = 0
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function(dt: number)
				t += dt
				if t >= SECONDS or model.Parent == nil then
					conn:Disconnect()
					b.Transparency = 1
					b.Position = from
					if knob and knobHome then
						knob.CFrame = knobHome
					end
					running = false
					onDone()
					return
				end
				local u = t / SECONDS
				-- The first half the ball rolls down the inside (straight down), then it drops out
				-- through the chute and settles with a small bounce.
				local pos = lerp(from, to, u * u)
				if u > 0.8 then
					local bounce = math.abs(math.sin((u - 0.8) / 0.2 * math.pi)) * 0.5
					pos += Vector3.new(0, bounce, 0)
				end
				b.Position = pos
				if knob and knobHome then
					knob.CFrame = knobHome * CFrame.Angles(math.min(u * 1.5, 1) * math.pi * 2, 0, 0)
				end
			end)
			return true
		end,
	}
end

return ClawAnim
