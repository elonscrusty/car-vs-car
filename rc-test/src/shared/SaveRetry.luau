--!strict
-- Tries a DataStore call again after a failure, waiting longer each time. Pure (the waiting is
-- passed in) so Lune can test it. A 403 means API access is off (Studio): trying again only makes
-- the player wait, so it stops at once.

local SaveRetry = {}

SaveRetry.TRIES = 4

-- Returns ok, result and (on failure) the last error text. `wait` is task.wait; `onFail` hears each failure (try number, error).
function SaveRetry.run(
	fn: () -> any,
	wait: (number) -> any,
	onFail: ((number, string) -> ())?,
	tries: number?
): (boolean, any, string?)
	local n = tries or SaveRetry.TRIES
	local last: string? = nil
	for i = 1, n do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		last = tostring(result)
		if onFail then
			onFail(i, last)
		end
		if string.find(last, "403", 1, true) then
			break
		end
		if i < n then
			wait(2 ^ i)
		end
	end
	return false, nil, last
end

return SaveRetry
