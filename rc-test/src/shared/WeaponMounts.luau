--!strict
-- Weapon mount points: where a weapon part clicks onto ANY car (carter 10-29 22:35: cars only look
-- different, weapons are shared parts on the roof or the front). A mount is a spot on the car's
-- Body given as fractions of the body's size, so it fits every car whatever its shape. Plain numbers
-- only, so tests can check them; client/WeaponPart turns them into real parts and welds.
--
-- Fractions run from the body's middle: x of its width (+ to the side), y of its height (+ up),
-- z of its length (+ toward the nose). From the preview car (9.9 long, 4.9 wide, 2.64 tall body,
-- roof top at 3.0, hood at 1.7, body middle at 1.68; see weapon-mount-preview/).

local WeaponMounts = {}

WeaponMounts.NAMES = { "Roof", "Front" }
-- the preview car's length: weapon looks are drawn at this size and grow or shrink with the body
WeaponMounts.DESIGN_LENGTH = 9.9
WeaponMounts.DESIGN_HEIGHT = 2.64

export type Place = { x: number, y: number, z: number }

WeaponMounts.PLACE = {
	-- on top of the roof, a little behind the middle
	Roof = { x = 0, y = 0.5, z = -0.35 / 9.9 },
	-- on the hood, between the fenders
	Front = { x = 0, y = (1.7 - 1.68) / 2.64, z = 3.2 / 9.9 },
} :: { [string]: Place }

function WeaponMounts.isMount(x: any): boolean
	return type(x) == "string" and WeaponMounts.PLACE[x] ~= nil
end

-- How big a weapon is on a car this long (1 = drawn size).
function WeaponMounts.scale(bodyLength: number): number
	if bodyLength ~= bodyLength or bodyLength <= 0 then
		return 1
	end
	return bodyLength / WeaponMounts.DESIGN_LENGTH
end

-- The mount's spot from the body's middle, in studs, for a body of this size. `nose` is +1 when the
-- body's nose is along its own +Z and -1 when it is turned around. nil for a name that isn't a mount.
function WeaponMounts.offset(
	mount: any,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	nose: number
): Place?
	if not WeaponMounts.isMount(mount) then
		return nil
	end
	local p = WeaponMounts.PLACE[mount]
	local sign = if nose < 0 then -1 else 1
	return { x = p.x * sizeX, y = p.y * sizeY, z = sign * p.z * sizeZ }
end

-- Where a shot leaves a weapon: `muzzle` is the barrel tip from the mount's saddle (design units,
-- from WeaponLooks). Returns how far ahead of the kart's middle and how high above it, in kart
-- lengths (a kart is 1 long whatever its size). The server's weapon fires from here.
function WeaponMounts.muzzle(mount: string, muzzle: { number }): (number, number)
	local p = WeaponMounts.PLACE[mount]
	local len = WeaponMounts.DESIGN_LENGTH
	return (p.z * len + muzzle[3]) / len, (p.y * WeaponMounts.DESIGN_HEIGHT + muzzle[2]) / len
end

-- How far a muzzle sits to the side of the kart's middle (+ = right), in kart lengths. The Missile
-- Rack's six tubes sit side by side, so each rocket leaves from its own tube.
function WeaponMounts.side(muzzle: { number }): number
	return muzzle[1] / WeaponMounts.DESIGN_LENGTH
end

return WeaponMounts
