--!strict
-- Phone buzz (phone-pc plan #10): a tiny shake when you take a hit and a bigger one when you smash
-- someone. Pure (Lune tests it): the strengths and the gap; client/Buzz plays them.
local Buzz = {}

Buzz.HIT = { strength = 0.35, seconds = 0.05 } -- you took a hit
Buzz.SMASH = { strength = 0.8, seconds = 0.12 } -- you smashed a kart
Buzz.GAP = 0.08 -- seconds between buzzes (a gun burst is many hits: one buzz, not a hum)
Buzz.ATTR = "Buzz" -- player attribute set by Settings: false = buzz is off

export type Kind = { strength: number, seconds: number }

-- true when a buzz may play at `now` (last one at `last`)
function Buzz.ready(last: number, now: number, off: boolean): boolean
	return not off and now - last >= Buzz.GAP
end

return Buzz
