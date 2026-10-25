--!strict
-- Picks the cars offered before a match (pure).

local PickChoices = {}

-- No duplicates; returns fewer than `count` if you own fewer. Does not mutate `owned`.
function PickChoices.choose(owned: { string }, count: number, rng: () -> number): { string }
	local pool: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in owned do
		if not seen[id] then
			seen[id] = true
			table.insert(pool, id)
		end
	end
	local result = {}
	while #result < count and #pool > 0 do
		local i = math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)
		table.insert(result, table.remove(pool, i) :: string)
	end
	return result
end

return PickChoices
