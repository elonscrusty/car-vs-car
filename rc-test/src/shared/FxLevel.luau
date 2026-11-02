--!strict
-- Auto quality (phone-pc plan #15): nobody sees a menu. A slow screen gets fewer dust puffs,
-- sparks and box sparkles; it comes back slowly once the screen is fast again. Pure (Lune tests it).
-- level 1 = everything, 0.5 = half, 0.25 = a quarter.
local FxLevel = {}

FxLevel.LEVELS = { 1, 0.5, 0.25 }
FxLevel.SLOW_FPS = 30 -- below this for DROP_AFTER seconds: one step down
FxLevel.VERY_SLOW_FPS = 20
FxLevel.FAST_FPS = 50 -- above this for RISE_AFTER seconds: one step up
FxLevel.DROP_AFTER = 2
FxLevel.RISE_AFTER = 8
FxLevel.SMOOTH = 0.1 -- how fast the fps average follows (0..1 per frame)
FxLevel.MAX_DT = 0.5 -- a frame this long is a hitch (loading), not slowness: skipped

export type State = { fps: number, step: number, slow: number, fast: number }

function FxLevel.new(): State
	return { fps = 60, step = 1, slow = 0, fast = 0 }
end

function FxLevel.level(s: State): number
	return FxLevel.LEVELS[s.step]
end

-- One frame of `dt` seconds. Returns true when the level changed.
function FxLevel.tick(s: State, dt: number): boolean
	if dt ~= dt or dt <= 0 or dt > FxLevel.MAX_DT then
		return false
	end
	s.fps += (1 / dt - s.fps) * FxLevel.SMOOTH
	local before = s.step
	local limit = if s.step == 1 then FxLevel.SLOW_FPS else FxLevel.VERY_SLOW_FPS
	if s.fps < limit and s.step < #FxLevel.LEVELS then
		s.slow += dt
		s.fast = 0
		if s.slow >= FxLevel.DROP_AFTER then
			s.step += 1
			s.slow = 0
		end
	elseif s.fps > FxLevel.FAST_FPS and s.step > 1 then
		s.fast += dt
		s.slow = 0
		if s.fast >= FxLevel.RISE_AFTER then
			s.step -= 1
			s.fast = 0
		end
	else
		s.slow, s.fast = 0, 0
	end
	return s.step ~= before
end

-- A whole number of particles at this level (never below 1 while n > 0, so a hit still sparks).
function FxLevel.count(n: number, level: number): number
	if n <= 0 then
		return 0
	end
	return math.max(1, math.floor(n * level + 0.5))
end

return FxLevel
