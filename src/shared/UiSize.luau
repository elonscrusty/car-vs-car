--!strict
-- Pure size rules for phone-friendly UI (no Roblox types, so Lune can test it).

local UiSize = {}

UiSize.MIN_TOUCH = 48 -- smallest tappable side in real pixels
UiSize.PRESS_SCALE = 0.93 -- buttons shrink to this while pressed

-- Smallest button side so it is still >= MIN_TOUCH while pressed.
UiSize.BUTTON_MIN = math.ceil(UiSize.MIN_TOUCH / UiSize.PRESS_SCALE)

-- A requested pixel side, never below MIN_TOUCH.
function UiSize.touchSide(px: number): number
	return math.max(px, UiSize.MIN_TOUCH)
end

function UiSize.isPortrait(width: number, height: number): boolean
	return height > width
end

export type Cards = { width: number, height: number, vertical: boolean }

-- Pixel size of each pick-a-car card. Portrait stacks cards in a column, landscape lines them up
-- in a row. `topBar` is the space kept for the title row, `margin` the gap to the screen edge.
function UiSize.choiceCards(
	viewW: number,
	viewH: number,
	count: number,
	gap: number,
	topBar: number,
	margin: number,
	maxCardW: number
): Cards
	local n = math.max(1, count)
	local areaW = math.max(0, viewW - 2 * margin)
	local areaH = math.max(0, viewH - topBar - margin)
	if UiSize.isPortrait(viewW, viewH) then
		local h = math.floor((areaH - gap * (n - 1)) / n)
		return {
			width = math.min(areaW, maxCardW),
			height = math.max(UiSize.BUTTON_MIN, h),
			vertical = true,
		}
	end
	local w = math.floor((areaW - gap * (n - 1)) / n)
	return {
		width = math.max(UiSize.BUTTON_MIN, math.min(w, maxCardW)),
		height = math.max(UiSize.BUTTON_MIN, areaH),
		vertical = false,
	}
end

return UiSize
