--!strict
-- Fixed-window rate limiter. allow(key, now) says if a call is OK right now.

export type RateLimiter = {
	allow: (key: any, now: number) -> boolean,
	clear: (key: any) -> (),
}

local RateLimiter = {}

function RateLimiter.new(maxPerWindow: number, windowSeconds: number): RateLimiter
	local buckets: { [any]: { start: number, count: number } } = {}

	local function allow(key: any, now: number): boolean
		local b = buckets[key]
		if b == nil or now - b.start >= windowSeconds then
			buckets[key] = { start = now, count = 1 }
			return true
		end
		if b.count >= maxPerWindow then
			return false
		end
		b.count += 1
		return true
	end

	local function clear(key: any)
		buckets[key] = nil
	end

	return { allow = allow, clear = clear }
end

return RateLimiter
