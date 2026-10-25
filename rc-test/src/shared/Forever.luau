--!strict
-- One round of a loop that must never stop (the server race clock, the pads, the daily gift):
-- an error in one round used to end the loop for the rest of the server's life. Now it's
-- reported (once a minute per loop, so the log stays readable) and the next round runs.

local Forever = {}

Forever.QUIET = 60 -- seconds between reports of the same loop

local lastWarn: { [string]: number } = {}

function Forever.step(name: string, fn: () -> (), now: number?): boolean
	local ok, err = pcall(fn)
	if not ok then
		local t = now or os.clock()
		local before = lastWarn[name]
		if before == nil or t - before >= Forever.QUIET then
			lastWarn[name] = t
			warn(`[{name}] {err} (still running)`)
		end
	end
	return ok
end

-- forget past reports (tests)
function Forever.reset()
	table.clear(lastWarn)
end

return Forever
