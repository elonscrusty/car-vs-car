--!strict
-- Level badge on a car: shinier at higher levels, plus a small badge on the roof. Visual only.
-- Owned by the progression worker. CarBuilder calls `apply` after Appearance.apply.

local Badge = {}

function Badge.apply(_model: Model, _body: BasePart, _level: number?)
	-- stub: filled in by progression
end

return Badge
