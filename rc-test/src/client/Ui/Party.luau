--!strict
-- The win party (carter 10-29, try A): paper from two corner guns and a light rain over the end
-- screen, and the karts cheer (the winner hops 3 times, the 2nd and 3rd clap). A fixed pool of
-- WinParty.POOL frames is reused; the numbers come from shared/WinParty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WinParty = require(Shared:WaitForChild("WinParty"))
local Base = require(script.Parent:WaitForChild("Base"))
local Anim = require(script.Parent:WaitForChild("Anim"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Party = {}

local PAPER = { "danger", "go", "lime", "blue", "pink", "boost" }
local GOLD = "ffd93b"

type Piece = { frame: Frame, bit: WinParty.Bit? }

-- layer: a see-through frame over the screen's design space; cars[place]: the kart on that step
function Party.start(layer: GuiObject, cars: { [number]: GuiObject })
	if Base.reduced() then
		return
	end
	local pool: { Piece } = {}
	for i = 1, WinParty.POOL do
		local f = Instance.new("Frame")
		f.Name = "Bit"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = 1
		f.Parent = layer
		Base.outline(f, 1.5)
		pool[i] = { frame = f, bit = nil }
	end
	local function take(bit: WinParty.Bit, color: Color3)
		for _, pc in pool do
			if not pc.bit then
				pc.bit = bit
				pc.frame.BackgroundColor3 = color
				pc.frame.Visible = true
				return
			end
		end
	end
	local alive = 0
	local rng = Random.new()
	local t0 = Anim.now()
	local last = 0
	local fired = false
	local homes: { [number]: UDim2 } = {}
	for place, car in cars do
		homes[place] = car.Position
	end
	Anim.tick(layer, function(now)
		local t = now - t0
		local dt = math.min(0.05, t - last)
		last = t
		-- (the guns go off once)
		if not fired and t >= WinParty.GUN_AT then
			fired = true
			for side = 1, -1, -2 do
				for i = 1, WinParty.GUN_BITS do
					local bit = WinParty.shot(side, i)
					take(
						bit,
						if bit.kind == "star"
							then Kit.hex(GOLD)
							else Base.color(PAPER[(i % #PAPER) + 1])
					)
				end
			end
		end
		if
			t >= WinParty.RAIN_FROM
			and alive < WinParty.ALIVE_MAX
			and rng:NextNumber() < dt * WinParty.RAIN_RATE
		then
			take(
				WinParty.drop(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
				Base.color(PAPER[rng:NextInteger(1, #PAPER)])
			)
		end
		alive = 0
		for _, pc in pool do
			local b = pc.bit
			if not b then
				continue
			end
			WinParty.step(b, dt)
			if WinParty.gone(b) then
				pc.bit = nil
				pc.frame.Visible = false
				continue
			end
			alive += 1
			local f = pc.frame
			local k = Base.k
			f.Position = UDim2.fromScale(b.x / WinParty.W, b.y / WinParty.H)
			f.Rotation = math.deg(b.rot)
			if b.kind == "star" then
				-- a gold diamond
				f.Size = UDim2.fromOffset(13 * k, 13 * k)
				f.Rotation += 45
			else
				-- paper that flips as it falls
				f.Size = UDim2.fromOffset((3 + 7 * math.abs(math.cos(b.ph))) * k, 14 * k)
			end
		end
		-- (the karts cheer)
		for place, car in cars do
			local y, s
			if place == 1 then
				y, s = WinParty.winnerPose(t)
			else
				y, s = WinParty.clapPose(place, t)
			end
			if y and s then
				car.Position = homes[place] + UDim2.fromOffset(0, y * Base.k)
				Anim.scaler(car).Scale = s
			end
		end
	end)
end

return Party
