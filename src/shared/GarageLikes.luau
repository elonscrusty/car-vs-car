--!strict
-- Garage likes (pure). A player can like another player's garage once, ever. `received` is how
-- many likes this player's garage has; `given` remembers whose garages this player already liked
-- (keys are the owner's UserId as text). Both live in the profile (profile.garage).

export type Data = {
	received: number,
	given: { [string]: boolean },
}

local GarageLikes = {}

GarageLikes.MaxGiven = 300 -- most garages one player can ever like (keeps the save small)
GarageLikes.MaxReceived = 1e9

function GarageLikes.default(): Data
	return { received = 0, given = {} }
end

-- Never errors. Accepts anything, returns clean data.
function GarageLikes.clean(raw: any): Data
	local out = GarageLikes.default()
	if type(raw) ~= "table" then
		return out
	end
	local r = raw.received
	if type(r) == "number" and r == r then
		out.received = math.clamp(math.floor(r), 0, GarageLikes.MaxReceived)
	end
	local g = raw.given
	if type(g) == "table" then
		local count = 0
		for key, v in g do
			if v == true and type(key) == "string" and tonumber(key) ~= nil then
				if count >= GarageLikes.MaxGiven then
					break
				end
				out.given[key] = true
				count += 1
			end
		end
	end
	return out
end

local function givenCount(d: Data): number
	local n = 0
	for _ in d.given do
		n += 1
	end
	return n
end

-- Can `giver` like the garage of `ownerId`? Reason when not: "self" | "already" | "full" | "unknown".
function GarageLikes.canLike(giver: Data, giverId: number, ownerId: number): (boolean, string?)
	if giverId == ownerId then
		return false, "self"
	end
	if type(ownerId) ~= "number" or ownerId ~= ownerId or ownerId <= 0 then
		return false, "unknown"
	end
	if giver.given[tostring(ownerId)] then
		return false, "already"
	end
	if givenCount(giver) >= GarageLikes.MaxGiven then
		return false, "full"
	end
	return true, nil
end

-- Does the like: remembers it on the giver, adds one to the owner. Returns (ok, reason).
function GarageLikes.like(
	giver: Data,
	owner: Data,
	giverId: number,
	ownerId: number
): (boolean, string?)
	local ok, reason = GarageLikes.canLike(giver, giverId, ownerId)
	if not ok then
		return false, reason
	end
	giver.given[tostring(ownerId)] = true
	owner.received = math.min(owner.received + 1, GarageLikes.MaxReceived)
	return true, nil
end

-- Short text for the garage name sign: "0 LIKES", "1 LIKE", "1.2K LIKES".
function GarageLikes.label(count: number): string
	local n = math.max(0, math.floor(count))
	if n == 1 then
		return "1 LIKE"
	end
	if n >= 1000000 then
		return string.format("%.1fM LIKES", math.floor(n / 100000) / 10)
	end
	if n >= 1000 then
		return string.format("%.1fK LIKES", math.floor(n / 100) / 10)
	end
	return `{n} LIKES`
end

return GarageLikes
