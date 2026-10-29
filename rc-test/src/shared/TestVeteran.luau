--!strict
-- Studio-only "veteran" switch (Lead R9-3): Studio plays a fresh save every time, so the player
-- is always a rookie (bots go easy, new-kid safety). With this on, the round counts them as a
-- player with that many matches played (BOTS' skill ramp reads it too: full skill at match 10).
-- Only MatchRunner's round-start read changes; the save itself is never touched. NEVER on in a
-- live game: needs Studio AND workspace attribute TestVeteran = true or a number.
-- Studio: workspace:SetAttribute("TestVeteran", true)   (= VETERAN matches)
--         workspace:SetAttribute("TestVeteran", 11)     (= 11 matches)
--         (from the next round on; false/nil = off)

local TestVeteran = {}

TestVeteran.ATTR = "TestVeteran"
TestVeteran.VETERAN = 5 -- matches played, as the round sees it, for `true`
TestVeteran.MOST = 1000

-- The matches the round counts this player as having played (nil = off: their own save).
function TestVeteran.wanted(isStudio: boolean, attr: unknown): number?
	if isStudio ~= true then
		return nil
	end
	if attr == true then
		return TestVeteran.VETERAN
	end
	if type(attr) == "number" and attr == attr and attr >= 0 and attr < math.huge then
		return math.floor(math.min(attr, TestVeteran.MOST))
	end
	return nil
end

function TestVeteran.allowed(isStudio: boolean, attr: unknown): boolean
	return TestVeteran.wanted(isStudio, attr) ~= nil
end

-- The matches played the round counts for a player who has played `played` (nil = no save yet):
-- `want` when the switch is on, else their own.
function TestVeteran.matches(played: number?, want: number?): number?
	if want then
		return want
	end
	return played
end

return TestVeteran
