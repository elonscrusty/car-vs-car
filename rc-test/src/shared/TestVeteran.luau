--!strict
-- Studio-only "veteran" switch (Lead R9-3): Studio plays a fresh save every time, so the player
-- is always a rookie (bots go easy, new-kid safety). With this on, the round counts them as a
-- player with VETERAN matches played. Only MatchRunner's round-start read changes; the save itself
-- is never touched. NEVER on in a live game: needs Studio AND workspace attribute TestVeteran = true.
-- Studio: workspace:SetAttribute("TestVeteran", true)   (from the next round on; false/nil = off)

local TestVeteran = {}

TestVeteran.ATTR = "TestVeteran"
TestVeteran.VETERAN = 5 -- matches played, as the round sees it

function TestVeteran.allowed(isStudio: boolean, attr: unknown): boolean
	return isStudio == true and attr == true
end

-- The matches played the round counts for a player who has played `played` (nil = no save yet).
function TestVeteran.matches(played: number?, on: boolean): number?
	if on then
		return math.max(played or 0, TestVeteran.VETERAN)
	end
	return played
end

return TestVeteran
