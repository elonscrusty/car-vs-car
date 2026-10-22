--!strict
-- Tyre smoke, skid marks and car sounds (motor and tyre squeal). Only on this player's screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Shared.Tuning)

local RCCar = require(script.Parent.RCCar)

export type Effects = {
	update: (dt: number) -> (),
	quiet: () -> (),
	clear: () -> (),
	destroy: () -> (),
}

local Effects = {}

local SLIDE_START = 7 -- sideways tyre speed (studs/s) where smoke and marks begin
local SMOKE_PER_SECOND = 70
local MARK_STEP = 0.8 -- studs between skid mark pieces
local MAX_MARKS = 600 -- oldest marks go first past this, so phones stay smooth
local MARK_LIFE = 25 -- seconds a skid mark stays dark
local MARK_FADE = 5 -- then it fades away over this long
-- Sound ids (free Creator Store sounds, checked to load in Studio). Empty = no sound.
local MOTOR_SOUND = "rbxassetid://137730930796096" -- "ENV Electric Motor Steady"
local SQUEAL_SOUND = "rbxassetid://109487442763183" -- "Tire Squealing / Screeching Loop"

local function loopSound(id: string, parent: Instance): Sound?
	if id == "" then
		return nil
	end
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Looped = true
	snd.Volume = 0
	snd.Parent = parent
	snd:Play()
	return snd
end

function Effects.new(telemetry: RCCar.Telemetry): Effects
	local S = Tuning.scale -- effects are made for the car size at the time
	local folder = Instance.new("Folder")
	folder.Name = "RCEffects"
	folder.Parent = workspace

	local anchor = Instance.new("Part")
	anchor.Name = "SmokeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = folder

	type Track = { emitter: ParticleEmitter, attach: Attachment, owed: number, last: Vector3? }
	local tracks: { Track } = {}
	for i = 1, #telemetry.wheels do
		local attach = Instance.new("Attachment")
		attach.Parent = anchor
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.9, 1.6)
		e.Speed = NumberRange.new(2 * S, 5 * S)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Drag = 2
		e.Acceleration = Vector3.new(0, 4 * S, 0)
		e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2 * S),
			NumberSequenceKeypoint.new(1, 5 * S),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Parent = attach
		tracks[i] = { emitter = e, attach = attach, owed = 0, last = nil }
	end

	-- oldest first, each with when it was made and how dark it started
	type Mark = { part: BasePart, born: number, alpha: number }
	local marks: { Mark } = {}

	local function addMark(a: Vector3, b: Vector3, normal: Vector3, strength: number)
		local len = (b - a).Magnitude
		if len < 0.05 * S then
			return
		end
		local mid = (a + b) / 2 + normal * 0.03 * S
		local p = Instance.new("Part")
		p.Name = "Skid"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(25, 25, 28)
		local alpha = 0.55 - 0.4 * strength
		p.Transparency = alpha
		p.Size = Vector3.new(0.65 * S, 0.02, len + 0.1 * S)
		p.CFrame = CFrame.lookAt(mid, b + normal * 0.03 * S, normal)
		p.Parent = folder
		table.insert(marks, { part = p, born = os.clock(), alpha = alpha })
		if #marks > MAX_MARKS then
			table.remove(marks, 1).part:Destroy()
		end
	end

	local motor = loopSound(MOTOR_SOUND, folder)
	local squeal = loopSound(SQUEAL_SOUND, folder)
	local squealLevel = 0

	local fx = {} :: Effects

	function fx.quiet()
		if motor then
			motor.Volume = 0
		end
		if squeal then
			squeal.Volume = 0
		end
		squealLevel = 0
	end

	function fx.update(dt: number)
		-- motor buzz rises with speed; squeal follows the hardest sliding back tyre
		local share = math.clamp(telemetry.speed / math.max(Tuning.topSpeed, 0.01), 0, 1)
		if motor then
			motor.PlaybackSpeed = 0.7 + 1.1 * share
			motor.Volume = 0.15 + 0.35 * share
		end
		if squeal then
			local slide = 0
			for _, info in telemetry.wheels do
				if info.rear and info.touching then
					slide = math.max(slide, info.slide)
				end
			end
			local want = if telemetry.speed > 12 * S
				then math.clamp((slide - SLIDE_START * S) / (20 * S), 0, 1)
				else 0
			squealLevel += (want - squealLevel) * (1 - math.exp(-10 * dt))
			squeal.Volume = 0.5 * squealLevel
			squeal.PlaybackSpeed = 0.9 + 0.2 * squealLevel
		end
		-- old marks fade out, oldest first
		local now = os.clock()
		while marks[1] and now - marks[1].born > MARK_LIFE + MARK_FADE do
			table.remove(marks, 1).part:Destroy()
		end
		for _, m in marks do
			local age = now - m.born
			if age <= MARK_LIFE then
				break
			end
			m.part.Transparency = m.alpha + (1 - m.alpha) * (age - MARK_LIFE) / MARK_FADE
		end
		local fast = telemetry.speed > 12 * S
		for i, info in telemetry.wheels do
			local t = tracks[i]
			local sliding = fast and info.touching and info.slide > SLIDE_START * S
			if sliding then
				local strength = math.clamp((info.slide - SLIDE_START * S) / (20 * S), 0, 1)
				t.attach.WorldPosition = info.contact + info.normal * 0.3 * S
				if info.rear then
					t.owed += SMOKE_PER_SECOND * (0.3 + strength) * dt
					local n = math.floor(t.owed)
					if n > 0 then
						t.emitter:Emit(n)
						t.owed -= n
					end
				end
				local last = t.last
				if last == nil then
					t.last = info.contact
				elseif (info.contact - last).Magnitude >= MARK_STEP * S then
					if (info.contact - last).Magnitude < 6 * S then
						addMark(last, info.contact, info.normal, strength)
					end
					t.last = info.contact
				end
			else
				t.last = nil
				t.owed = 0
			end
		end
	end

	function fx.clear()
		for _, m in marks do
			m.part:Destroy()
		end
		table.clear(marks)
		for _, t in tracks do
			t.last = nil
		end
	end

	function fx.destroy()
		folder:Destroy()
	end

	return fx
end

return Effects
