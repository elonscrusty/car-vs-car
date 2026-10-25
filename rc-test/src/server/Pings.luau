--!strict
-- "Mia beat your time!" for players who weren't here when it happened: a short list per player
-- in its own DataStore (not the session-locked save, which another server may hold). Added to
-- whenever someone beats an offline player's record; read and emptied when that player joins.
-- No DataStore (Studio without API access): pings to offline players are just dropped.

local DataStoreService = game:GetService("DataStoreService")

local STORE = "RCPings_v1"
local MAX = 20 -- newest kept
local TRIES = 3

export type Ping = { byId: number, by: string, mode: string, t: number }

local Pings = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE)
	end)
	if ok then
		store = result
	end
end

local function update(userId: number, fn: (any) -> any): boolean
	local s = store
	if s == nil then
		return false
	end
	for i = 1, TRIES do
		local ok, err = pcall(function()
			s:UpdateAsync("p_" .. userId, fn)
		end)
		if ok then
			return true
		end
		warn(`[Pings] {userId} try {i}:`, err)
		-- Studio with API access off: trying again can't help (same as PlayerData)
		if string.find(tostring(err), "403", 1, true) then
			break
		end
		if i < TRIES then
			task.wait(2 ^ i)
		end
	end
	return false
end

-- Leave `ping` for `userId` (doesn't wait).
function Pings.send(userId: number, ping: Ping)
	task.spawn(update, userId, function(old: any): any
		local list = if type(old) == "table" then old else {}
		table.insert(list, ping)
		while #list > MAX do
			table.remove(list, 1)
		end
		return list
	end)
end

-- Every ping left for `userId`, oldest first; the list is emptied.
function Pings.take(userId: number): { Ping }
	local got: { Ping } = {}
	update(userId, function(old: any): any
		got = {}
		if type(old) ~= "table" or #old == 0 then
			return nil -- nothing to empty
		end
		for _, p in old do
			if
				type(p) == "table"
				and type(p.byId) == "number"
				and type(p.by) == "string"
				and type(p.mode) == "string"
			then
				table.insert(got, {
					byId = p.byId,
					by = string.sub(p.by, 1, 40),
					mode = p.mode,
					t = if type(p.t) == "number" then p.t else 0,
				})
			end
		end
		return {}
	end)
	return got
end

return Pings
