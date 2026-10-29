--!strict
-- The Smash arena: a kart nosed into a wall with the gas on gets a short bounce back and a turn
-- toward open space (round 8 audit R8-1: stuck or crawling 27-42% of a round), instead of grinding
-- there until the stuck reset sends it to a spawn. No words; it should feel like a bump. Numbers
-- only; Main.client does the rays and the push.

local WallNudge = {}

WallNudge.WAIT = 1.5 -- seconds of gas on, crawling, wall ahead before the bounce
WallNudge.SLOW = 2 -- studs/s at full size (times Tuning.scale): slower than this = crawling
WallNudge.TIME = 0.5 -- seconds the bounce lasts (the gas waits)
WallNudge.TURN = math.pi / 4 -- how far it turns in that time (45 degrees)
WallNudge.MAX = 3 -- bounces this close together (within GAP s) = it isn't working: leave it to
WallNudge.GAP = 10 -- the stuck reset

-- One frame: `held` = seconds it has been grinding so far. `gas` = gas held, `slow` = crawling,
-- `blocked` = something solid just ahead. Returns the new seconds, and true = bounce now.
function WallNudge.tick(
	held: number,
	dt: number,
	gas: boolean,
	slow: boolean,
	blocked: boolean
): (number, boolean)
	if not (gas and slow and blocked) then
		return 0, false
	end
	held += dt
	if held >= WallNudge.WAIT then
		return 0, true
	end
	return held, false
end

-- Which way to turn: toward the side with more room (distances to the first wall 45 degrees left
-- and right of the nose; nil = nothing there). 1 = right, -1 = left.
function WallNudge.side(left: number?, right: number?): number
	if right == nil then
		return 1
	elseif left == nil then
		return -1
	end
	return if left > right then -1 else 1
end

-- May it bounce again? `times` = when the last bounces were (os.clock), oldest first; drops old ones.
function WallNudge.allowed(times: { number }, now: number): boolean
	while times[1] and now - times[1] > WallNudge.GAP do
		table.remove(times, 1)
	end
	return #times < WallNudge.MAX
end

return WallNudge
