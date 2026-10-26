--!strict
-- Tries a DataStore call again after a failure, waiting longer each time. Pure (the waiting is
-- passed in) so Lune can test it. A 403 means API access is off (Studio): trying again only makes
-- the player wait, so it stops at once.

local SaveRetry = {}

SaveRetry.TRIES = 4

-- Returns ok, result. `wait` is task.wait; `onFail` hears each failure (try number, error).
function SaveRetry.run(
	fn: () -> any,
	wait: (number) -> any,
	onFail: ((number, string) -> ())?,
	tries: number?
): (boolean, any)
	local n = tries or SaveRetry.TRIES
	for i = 1, n do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if onFail then
			onFail(i, tostring(result))
		end
		if string.find(tostring(result), "403", 1, true) then
			break
		end
		if i < n then
			wait(2 ^ i)
		end
	end
	return false, nil
end

return SaveRetry
