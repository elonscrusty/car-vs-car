--!strict
-- NameTagLook: the rules for the name tag over a kart in a Smash match (carter's pick: "New
-- Classic", nametag-preview/nametag-pick.html, 2026-10-29): the level star's color grows with
-- the level, the health bar's fill and low-health throb, the crown on the leader, long names cut.
-- Pure numbers and rules, so Lune can test them; client/MatchNameTag draws it.

local NameTagLook = {}

NameTagLook.TIER_AT = { 10, 25 } -- the level where the star turns purple, then gold
NameTagLook.LOW = 0.35 -- the health bar throbs red under this
NameTagLook.NAME_MAX = 12 -- letters on a tag; a longer name ends in "…"

-- star colors by tier {top, bottom}
NameTagLook.STAR = {
	{ { 89, 184, 255 }, { 31, 111, 224 } }, -- blue
	{ { 197, 139, 255 }, { 122, 53, 224 } }, -- purple
	{ { 255, 226, 122 }, { 245, 163, 19 } }, -- gold
} :: { { { number } } }

-- 1 (blue), 2 (purple) or 3 (gold) for a level; a missing or junk level is 1.
function NameTagLook.tier(level: number?): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	local t = 1
	for i, from in NameTagLook.TIER_AT do
		if level >= from then
			t = i + 1
		end
	end
	return t
end

-- Health as 0..1 of the most it can be (junk is 1: a tag never shows a dead bar by mistake).
function NameTagLook.fraction(health: number?, max: number): number
	if type(health) ~= "number" or health ~= health or max <= 0 then
		return 1
	end
	return math.clamp(health / max, 0, 1)
end

-- True when the bar should throb: alive but low.
function NameTagLook.isLow(frac: number): boolean
	return frac > 0 and frac < NameTagLook.LOW
end

-- The name as it shows: at most NAME_MAX letters, a longer one cut to NAME_MAX - 1 and "…".
function NameTagLook.shortName(name: string): string
	local n = utf8.len(name)
	if not n then
		-- (not valid text: cut by bytes so it can never error)
		return if #name > NameTagLook.NAME_MAX
			then string.sub(name, 1, NameTagLook.NAME_MAX)
			else name
	end
	if n <= NameTagLook.NAME_MAX then
		return name
	end
	local cut = utf8.offset(name, NameTagLook.NAME_MAX) :: number
	return string.sub(name, 1, cut - 1) .. "…"
end

-- Who wears the crown: every kart with the most smashes, if that is at least 1 (a tie shares it).
function NameTagLook.leaders(smashes: { [number]: number }): { [number]: boolean }
	local best = 0
	for _, n in smashes do
		if n > best then
			best = n
		end
	end
	local out: { [number]: boolean } = {}
	if best >= 1 then
		for id, n in smashes do
			if n == best then
				out[id] = true
			end
		end
	end
	return out
end

return NameTagLook
