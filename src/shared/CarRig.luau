--!strict
-- Where one car body's four wheels and its three weapon snap spots are, and the wheel maths.
-- Every number is in body lengths (L) from the floor-middle of the body: x right, y up, z toward
-- the tail (the nose points -Z). All cars share ONE wheel model: the rig only says where the four
-- copies go and how big they are. Weapons are separate models that snap onto a spot.

local CarRig = {}

export type Spot = { number } -- { x, y, z } in body lengths

export type Wheel = {
	name: string,
	at: Spot,
	front: boolean, -- front wheels steer
}

export type Rig = {
	wheelRadius: number, -- in body lengths
	wheels: { Wheel },
	snaps: { roof: Spot, front: Spot, back: Spot },
}

CarRig.MaxSteer = math.rad(30) -- most a front wheel turns
CarRig.SteerPerYaw = 0.25 -- seconds: wheel angle (radians) per radian/second of body yaw

-- Measured on RedTruck_lowpoly.fbx (1.09 long, 0.52 wide, 0.44 tall). The wheel arches are about
-- 0.19 L tall and 0.25-0.3 L long, so the tire (0.18 L across) fills about 90% of an arch. The "roof" spot is in the
-- truck bed behind the cab (the truck has no roof to bolt a turret on).
CarRig.Rigs = {
	RedTruck = {
		wheelRadius = 0.09,
		wheels = {
			{ name = "FL", at = { -0.165, 0.09, -0.33 }, front = true },
			{ name = "FR", at = { 0.165, 0.09, -0.33 }, front = true },
			{ name = "RL", at = { -0.165, 0.09, 0.25 }, front = false },
			{ name = "RR", at = { 0.165, 0.09, 0.25 }, front = false },
		},
		snaps = {
			roof = { 0, 0.23, 0.35 },
			front = { 0, 0.11, -0.5 },
			back = { 0, 0.12, 0.5 },
		},
	},
} :: { [string]: Rig }

function CarRig.of(modelId: string): Rig?
	return CarRig.Rigs[modelId]
end

-- The wheel's spin angle after `dt` seconds rolling at `speed` (studs/s forward) on a wheel of
-- `radiusStuds`. Kept inside one turn so it never grows large.
function CarRig.spin(angle: number, speed: number, radiusStuds: number, dt: number): number
	if radiusStuds <= 0 then
		return angle
	end
	return (angle + speed / radiusStuds * dt) % (2 * math.pi)
end

-- How far the front wheels turn for a body yaw rate (radians/s, + is a left turn about +Y) at a
-- forward speed. Backing up turns them the other way, like a real car.
function CarRig.steer(yawRate: number, forwardSpeed: number): number
	local a = math.clamp(yawRate * CarRig.SteerPerYaw, -CarRig.MaxSteer, CarRig.MaxSteer)
	if forwardSpeed < -0.5 then
		a = -a
	end
	return a
end

return CarRig
