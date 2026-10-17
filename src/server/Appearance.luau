--!strict
-- How one car LOOKS beyond its base stats: owner-chosen paint and sticker (paint shop) and the level badge.
-- CarBuilder calls `apply` once after building the body. Visual only: never touch physics or mass here.
-- The paint shop worker owns the paint/sticker half, the progression worker owns the badge half (Badge.luau).

export type Appearance = {
	level: number?, -- car level, 1 and up (progression)
	paintColor: Color3?, -- body color override (paint shop)
	sticker: string?, -- sticker id (paint shop)
}

local Appearance = {}

-- Paints/decorates `model` (its heavy part is `body`). Safe to call with nil.
function Appearance.apply(_model: Model, _body: BasePart, _look: Appearance?)
	-- stub: filled in by the paint shop
end

return Appearance
