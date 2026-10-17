--!strict
-- Retry with exponential backoff. Pure: the wait function is injected (task.wait on the server, a fake in tests).

export type Options = {
	attempts: number,
	baseDelay: number,
	maxDelay: number,
	wait: (seconds: number) -> (),
	onFail: ((attempt: number, err: any) -> ())?,
}

local Retry = {}

-- Delay to sleep after failed attempt number `attempt` (1-based): base, 2*base, 4*base ... capped.
function Retry.delay(attempt: number, baseDelay: number, maxDelay: number): number
	local d = baseDelay * 2 ^ (math.max(attempt, 1) - 1)
	return math.min(d, maxDelay)
end

-- The full sleep schedule between `attempts` tries (attempts - 1 sleeps).
function Retry.schedule(attempts: number, baseDelay: number, maxDelay: number): { number }
	local out = {}
	for i = 1, attempts - 1 do
		table.insert(out, Retry.delay(i, baseDelay, maxDelay))
	end
	return out
end

-- Runs fn under pcall up to opts.attempts times. Returns (true, result) or (false, lastError).
function Retry.run(fn: () -> any, opts: Options): (boolean, any)
	local lastErr: any = "no attempts"
	for attempt = 1, opts.attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if opts.onFail then
			opts.onFail(attempt, result)
		end
		if attempt < opts.attempts then
			opts.wait(Retry.delay(attempt, opts.baseDelay, opts.maxDelay))
		end
	end
	return false, lastErr
end

return Retry
