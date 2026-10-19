--!strict
-- Fairness switch for matches between 2+ real players. Pure data.
-- neutralizeHumanMatches = true: when two or more HUMANS fight each other, car level bonuses
-- (HP + damage) and ability rarity scaling are ignored so skill decides. Bots keep every bonus.
return {
	neutralizeHumanMatches = true,
	humansNeeded = 2, -- this many humans in one match turns the rule on
	neutralRarity = "Common", -- ability strength used instead of the car's rarity
	neutralLevel = 1, -- car level used instead of the real one
}
