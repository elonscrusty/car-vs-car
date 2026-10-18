--!strict
-- Look of the floating power-ups (pure numbers). The server turns these specs into parts.

export type Rgb = { number }
export type PartSpec = {
	shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	size: { number }, -- x, y, z studs
	offset: { number }, -- from the pickup center
	yaw: number, -- extra turn around the up axis (degrees)
	color: Rgb,
}

local PickupStyle = {}

PickupStyle.maxIconParts = 5 -- plus glow disc and shadow = 7 parts per pickup at most
PickupStyle.bobHeight = 0.6
PickupStyle.bobSeconds = 1.8
PickupStyle.spinDegPerSecond = 90

local WHITE: Rgb = { 245, 245, 250 }
local DARK: Rgb = { 40, 40, 55 }

local function darker(c: Rgb, k: number): Rgb
	return { math.floor(c[1] * k), math.floor(c[2] * k), math.floor(c[3] * k) }
end

local function spec(
	shape: string,
	size: { number },
	offset: { number },
	color: Rgb,
	yaw: number?
): PartSpec
	return { shape = shape, size = size, offset = offset, yaw = yaw or 0, color = color }
end

-- Width of the name pill (studs) for a label: grows with the text length.
function PickupStyle.pillWidth(text: string): number
	return 1.4 + 0.62 * #text
end

-- Height above the resting spot at time t (seconds): 0 up to 2 * bobHeight.
function PickupStyle.bobOffset(t: number): number
	local phase = (t / PickupStyle.bobSeconds) * 2 * math.pi
	return PickupStyle.bobHeight * (1 - math.cos(phase))
end

function PickupStyle.spinDeg(t: number): number
	return (t * PickupStyle.spinDegPerSecond) % 360
end

-- Parts that make up the icon of one kind. main is the kind's color.
function PickupStyle.iconParts(kind: string, main: Rgb): { PartSpec }
	if kind == "shield" then
		-- Round shield with a pale cross.
		return {
			spec("Ball", { 3, 3, 3 }, { 0, 0, 0 }, main),
			spec("Block", { 0.5, 2.4, 3.4 }, { 0, 0, 0 }, WHITE),
			spec("Block", { 2.4, 0.5, 3.4 }, { 0, 0, 0 }, WHITE),
		}
	elseif kind == "bighit" then
		-- Fist block with a spike on top and a dark wrist.
		return {
			spec("Block", { 2.6, 2.2, 2.6 }, { 0, 0, 0 }, main),
			spec("Wedge", { 1.2, 1.4, 1.2 }, { 0, 1.8, 0 }, WHITE),
			spec("Block", { 1.6, 1.2, 1.6 }, { 0, -1.6, 0 }, DARK),
		}
	elseif kind == "speed" then
		-- Chunky arrow: shaft plus two angled head blocks.
		return {
			spec("Block", { 0.9, 0.9, 3 }, { 0, 0, -0.4 }, main),
			spec("Block", { 0.9, 0.9, 2 }, { 0.8, 0, 1.2 }, main, 40),
			spec("Block", { 0.9, 0.9, 2 }, { -0.8, 0, 1.2 }, main, -40),
		}
	elseif kind == "magnet" then
		-- U shape: red back and two arms with white tips.
		local red = main
		return {
			spec("Block", { 3.2, 1, 1.2 }, { 0, -1.2, 0 }, red),
			spec("Block", { 1, 2.4, 1.2 }, { -1.1, 0.3, 0 }, red),
			spec("Block", { 1, 2.4, 1.2 }, { 1.1, 0.3, 0 }, red),
			spec("Block", { 1.05, 0.7, 1.25 }, { -1.1, 1.3, 0 }, WHITE),
			spec("Block", { 1.05, 0.7, 1.25 }, { 1.1, 1.3, 0 }, WHITE),
		}
	elseif kind == "rocket" then
		-- Body lies along the x axis, rounded nose at +x, three fins at the back.
		return {
			spec("Cylinder", { 3.6, 1.6, 1.6 }, { 0, 0, 0 }, WHITE),
			spec("Ball", { 1.7, 1.7, 1.7 }, { 2.1, 0, 0 }, main),
			spec("Wedge", { 1.2, 1.2, 0.3 }, { -1.5, 0.9, 0 }, main),
			spec("Wedge", { 1.2, 0.3, 1.2 }, { -1.5, 0, 0.9 }, darker(main, 0.8)),
			spec("Wedge", { 1.2, 0.3, 1.2 }, { -1.5, 0, -0.9 }, darker(main, 0.8)),
		}
	end
	return { spec("Ball", { 2.6, 2.6, 2.6 }, { 0, 0, 0 }, main) }
end

return PickupStyle
