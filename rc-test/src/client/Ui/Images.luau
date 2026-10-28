--!strict
-- Car VS Car screens: the uploaded pictures. All empty until carter uploads them; every screen
-- draws a stand-in until then, so nothing here needs to be filled for the screens to work.
--
--   * ICONS: the 3D icons from the design system (coin, gem, trophy, bag, gift, crates in 4
--     rarities closed and open, league shields). Transparent PNG, the ink outline baked in.
--   * CARS: carter's car pictures, by car id (CarCatalog). Transparent background, the car
--     filling the picture: `side` is the 3/4 view from the front right, `rear` the race view.
--   * PATTERN: the 44 x 44 sliding pattern tile (pattern-tile.png in project files).
-- Put "rbxassetid://<number>" in a slot; never a made-up number.

local Images = {}

Images.PATTERN = ""

Images.ICONS = {
	coin = "",
	gem = "",
	trophy = "",
	bag = "",
	gift = "",
	lock = "",
	["crate-common"] = "",
	["crate-rare"] = "",
	["crate-epic"] = "",
	["crate-legendary"] = "",
	["crate-common-open"] = "",
	["crate-rare-open"] = "",
	["crate-epic-open"] = "",
	["crate-legendary-open"] = "",
	["badge-bronze"] = "",
	["badge-silver"] = "",
	["badge-gold"] = "",
	["badge-diamond"] = "",
} :: { [string]: string }

-- [car id] = { side = "rbxassetid://...", rear = "rbxassetid://..." }
Images.CARS = {} :: { [string]: { side: string?, rear: string? } }

function Images.icon(name: string): string
	return Images.ICONS[name] or ""
end

function Images.car(id: string?, view: string?): string
	local c = id and Images.CARS[id]
	if not c then
		return ""
	end
	local got = if view == "rear" then c.rear else c.side
	return got or ""
end

return Images
