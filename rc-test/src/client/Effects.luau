--!strict
-- Tyre smoke, skid marks and car sounds (motor and tyre squeal). Only on this player's screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundLevels = require(ReplicatedStorage.Shared.SoundLevels)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local RCCar = require(script.Parent.RCCar)

export type Effects = {
	update: (dt: number) -> (),
	quiet: () -> (),
	clear: () -> (),
	destroy: () -> (),
	setSmokeColor: (color: Color3) -> (),
}

local Effects = {}

local SLIDE_START = 7 -- sideways tyre speed (studs/s) where smoke and marks begin
local SMOKE_PER_SECOND = 70
local FRONT_SMOKE = 0.5 -- front tyres put out this share of the rear smoke
local smokeColor = Color3.fromRGB(235, 235, 235) -- the player's pick (looks only)
-- Skid marks are Trails lying flat between two points across the tyre: one smooth ribbon that
-- fades out (playtest u30: the old row of boxes drew jagged zig-zags). Each slide takes the next
-- of MARK_RIGS ribbons per tyre, so the last few slides stay on the road while they fade.
local MARK_LIFE = 12 -- seconds a skid mark lasts (Trails top out at 20)
local MARK_RIGS = 4
local MARK_WIDTH = 0.8 -- across the tyre (car sizes); carter picked "Classic" (10-29): bold black lines
-- no marks where a tyre can't leave one (playtest u12: dark stripes on the water)
local NO_MARKS: { [Enum.Material]: boolean } = {
	[Enum.Material.Water] = true,
	[Enum.Material.Glass] = true, -- the race maps' puddles and milk
}
local NO_MARK_SURFACES: { [string]: boolean } = { Puddle = true, OilPatch = true }
-- Sound ids (free Creator Store sounds, checked to load in Studio). Empty = no sound.
local MOTOR_SOUND = "rbxassetid://137730930796096" -- "ENV Electric Motor Steady"
local SQUEAL_SOUND = "rbxassetid://109487442763183" -- "Tire Squealing / Screeching Loop"

-- What flies off the tyres on each track-tile surface (by part name), and how much per second at
-- top speed. Grit falls back down; dust floats.
type Spray = { color: Color3, rate: number, size: number, up: number, fall: number }
local SPRAYS: { [string]: Spray } = {
	Puddle = { color = Color3.fromRGB(190, 225, 255), rate = 90, size = 0.9, up = 9, fall = 40 },
	MudPatch = { color = Color3.fromRGB(96, 66, 38), rate = 60, size = 0.7, up = 7, fall = 45 },
	SandPatch = { color = Color3.fromRGB(230, 205, 145), rate = 70, size = 1.6, up = 3, fall = 4 },
	OilPatch = { color = Color3.fromRGB(30, 30, 36), rate = 30, size = 0.5, up = 4, fall = 45 },
	BoostPad = { color = Color3.fromRGB(255, 220, 60), rate = 80, size = 0.5, up = 6, fall = 10 },
}
local LAND_DUST = Color3.fromRGB(200, 195, 185)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST = "rbxasset://textures/particles/smoke_main.dds"
local BOOST_SPARK = Color3.fromRGB(255, 210, 60)

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

	-- one skid mark ribbon: a flat Trail between two points either side of the tyre
	type Rig = { trail: Trail, a: Attachment, b: Attachment }
	local function newRig(): Rig
		local a = Instance.new("Attachment")
		a.Parent = anchor
		local b = Instance.new("Attachment")
		b.Parent = anchor
		local trail = Instance.new("Trail")
		trail.Attachment0 = a
		trail.Attachment1 = b
		trail.FaceCamera = false
		trail.Enabled = false
		trail.Lifetime = MARK_LIFE
		trail.MinLength = 0.1 * S
		trail.Color = ColorSequence.new(Color3.fromRGB(4, 4, 6))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.65, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.LightEmission = 0
		trail.LightInfluence = 1
		trail.Parent = folder
		return { trail = trail, a = a, b = b }
	end

	type Track = {
		emitter: ParticleEmitter,
		attach: Attachment,
		owed: number,
		last: Vector3?, -- the tyre's last mark point (nil = not marking)
		side: Vector3, -- across the tyre's path, flat on the road
		rigs: { Rig },
		rig: number, -- the ribbon being drawn now
	}
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
		e.Color = ColorSequence.new(smokeColor)
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
		local rigs: { Rig } = {}
		for k = 1, MARK_RIGS do
			rigs[k] = newRig()
		end
		tracks[i] = {
			emitter = e,
			attach = attach,
			owed = 0,
			last = nil,
			side = Vector3.xAxis,
			rigs = rigs,
			rig = 1,
		}
	end

	-- splashes, dust and sparks: one emitter per tyre, set up for the surface under it
	type SprayFx = { emitter: ParticleEmitter, attach: Attachment, owed: number, kind: string }
	local sprays: { SprayFx } = {}
	local function setSpray(
		sp: SprayFx,
		kind: string,
		color: Color3,
		size: number,
		up: number,
		fall: number
	)
		if sp.kind == kind then
			return
		end
		sp.kind = kind
		local e = sp.emitter
		-- (sparkle stars only for BOOST: dust in sparkle stars covered the car after each put-back,
		-- audit L5, studio/pr842/01)
		e.Texture = if kind == "boost" or kind == "BoostPad" then SPARKLE else DUST
		e.Color = ColorSequence.new(color)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * S),
			NumberSequenceKeypoint.new(1, size * 0.4 * S),
		})
		e.Speed = NumberRange.new(up * 0.6 * S, up * S)
		e.Acceleration = Vector3.new(0, -fall * S, 0)
	end
	for i = 1, #telemetry.wheels do
		local attach = Instance.new("Attachment")
		attach.Parent = anchor
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARKLE
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.35, 0.7)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Top
		e.Drag = 1
		e.Rotation = NumberRange.new(0, 360)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Parent = attach
		sprays[i] = { emitter = e, attach = attach, owed = 0, kind = "" }
	end

	-- lay the ribbon's two edges either side of the tyre's contact point
	local function place(rig: Rig, at: Vector3, normal: Vector3, side: Vector3)
		local lift = normal * 0.03 * S
		local half = side * (MARK_WIDTH / 2 * S)
		rig.a.WorldPosition = at - half + lift
		rig.b.WorldPosition = at + half + lift
	end

	local motor = loopSound(MOTOR_SOUND, folder)
	local squeal = loopSound(SQUEAL_SOUND, folder)
	local squealLevel = 0

	local fx = {} :: Effects

	function fx.setSmokeColor(color: Color3)
		smokeColor = color
		for _, t in tracks do
			t.emitter.Color = ColorSequence.new(color)
		end
	end

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
			motor.Volume = SoundLevels.MOTOR_MIN
				+ (SoundLevels.MOTOR_MAX - SoundLevels.MOTOR_MIN) * share
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
			squeal.Volume = SoundLevels.SQUEAL_MAX * squealLevel
			squeal.PlaybackSpeed = 0.9 + 0.2 * squealLevel
		end
		-- tile surfaces: splash, mud, sand, oil drips; boost sparks off the back; dust on landing
		for i, info in telemetry.wheels do
			local sp = sprays[i]
			local look = if info.touching then SPRAYS[info.surface] else nil
			local rate = 0
			if look then
				setSpray(sp, info.surface, look.color, look.size, look.up, look.fall)
				rate = look.rate * math.clamp(telemetry.speed / (Tuning.topSpeed * 0.6), 0.15, 1)
			elseif telemetry.boost > 0 and info.rear and info.touching then
				setSpray(sp, "boost", BOOST_SPARK, 0.45, 8, 6)
				rate = 70
			end
			if info.touching then
				sp.attach.WorldPosition = info.contact + info.normal * 0.2 * S
			end
			if telemetry.landed > 0 and info.touching then
				-- (a low puff at the tyres, not a cloud over the car: audit L5)
				setSpray(sp, "land", LAND_DUST, 0.7, 3, 3)
				sp.emitter:Emit(math.floor(2 + 4 * telemetry.landed))
			end
			if rate > 0 then
				sp.owed += rate * dt
				local n = math.floor(sp.owed)
				if n > 0 then
					sp.emitter:Emit(n)
					sp.owed -= n
				end
			else
				sp.owed = 0
			end
		end

		local fast = telemetry.speed > 12 * S
		for i, info in telemetry.wheels do
			local t = tracks[i]
			local sliding = fast and info.touching and info.slide > SLIDE_START * S
			if sliding then
				local strength = math.clamp((info.slide - SLIDE_START * S) / (20 * S), 0, 1)
				t.attach.WorldPosition = info.contact + info.normal * 0.3 * S
				do -- the front tyres puff too, half as much (Classic look)
					local share = if info.rear then 1 else FRONT_SMOKE
					t.owed += SMOKE_PER_SECOND * share * (0.3 + strength) * dt
					local n = math.floor(t.owed)
					if n > 0 then
						t.emitter:Emit(n)
						t.owed -= n
					end
				end
				local markable = not NO_MARKS[info.material] and not NO_MARK_SURFACES[info.surface]
				local last = t.last
				if markable and last and (info.contact - last).Magnitude > 6 * S then
					-- jumped (put back, a ramp): end this ribbon, start the next
					t.rigs[t.rig].trail.Enabled = false
					last = nil
				end
				if markable then
					if last then
						local step = info.contact - last
						local across = info.normal:Cross(step)
						if across.Magnitude > 0.02 * S then
							t.side = across.Unit
						end
					else
						-- a new slide: the next ribbon, cleared and put down here first
						t.rig = t.rig % MARK_RIGS + 1
						local rig = t.rigs[t.rig]
						rig.trail.Enabled = false
						place(rig, info.contact, info.normal, t.side)
						rig.trail:Clear()
					end
					local rig = t.rigs[t.rig]
					place(rig, info.contact, info.normal, t.side)
					rig.trail.Enabled = last ~= nil
					t.last = info.contact
				elseif last then
					t.rigs[t.rig].trail.Enabled = false
					t.last = nil
				end
			else
				if t.last then
					t.rigs[t.rig].trail.Enabled = false
				end
				t.last = nil
				t.owed = 0
			end
		end
	end

	function fx.clear()
		for _, t in tracks do
			t.last = nil
			for _, rig in t.rigs do
				rig.trail.Enabled = false
				rig.trail:Clear()
			end
		end
	end

	function fx.destroy()
		folder:Destroy()
	end

	return fx
end

return Effects
