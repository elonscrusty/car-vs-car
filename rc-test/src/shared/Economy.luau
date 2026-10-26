--!strict
-- Every money number of Car VS Car in one place (carter 10-26, rc-game/cvc-plan.md): race prizes
-- by league, what a league needs, how fast cars train, coins while you train, and the prices of
-- station upgrades, plot levels and crates. League, Training, CvcRules and Crates read these (they
-- keep no money numbers of their own); tests/economy.test.luau plays them and checks carter's
-- biggest worry, "too slow to earn". Pure data. Nothing here is a Robux price (carter gives those).
-- Crate ODDS stay in Crates.luau; car bars (start, top, rate) stay in CarStats.luau.
--
-- The pace this aims for (a race every 3 min, the first on a tap): the first race gives a free
-- crate, a first paid thing comes inside 5 minutes, and something new lands every few minutes in
-- the first hour; Gold takes a while and Diamond is a long goal.

local Economy = {}

-- Races: one every 3 min. Bronze prizes by place (1st..3rd); 4th and later get FINISH_PAY; not
-- finishing pays 0, so an alt that joins and idles earns nothing. A higher league multiplies it.
Economy.RACE_EVERY = 180
Economy.PLACE_PAY = { 100, 70, 50 }
Economy.FINISH_PAY = 25
Economy.PAY_MULT = { 1, 1.5, 2.2, 3 } -- Bronze, Silver, Gold, Diamond

-- League needs: best car strength (speed + turning + boost, 0..300) AND race wins.
Economy.LEAGUE_NEED = {
	{ strength = 0, wins = 0 },
	{ strength = 110, wins = 2 },
	{ strength = 170, wins = 6 },
	{ strength = 230, wins = 15 },
}

-- Training: bar points a minute on a level 1 station with a rate 1 car, and COACH.
Economy.TRAIN_MAIN_PER_MIN = 5 -- the station's own bar
Economy.TRAIN_SIDE_PER_MIN = 2 -- the other two
Economy.STATION_LEVEL_STEP = 0.5 -- each station level past 1 adds this much
Economy.COACH_MULT = 2
Economy.COACH_SECS = 10
Economy.COACH_EVERY = 60

-- Coins while you're here: every car on a station earns this a minute; a win doubles it.
Economy.TRAIN_COINS_PER_MIN = 6
Economy.WIN_BOOST_SECS = 600

-- Spending. Station level 1 -> 2, 2 -> 3, ...; plot level 0 -> 1, ... (each adds a station).
Economy.UPGRADE_COST = { 40, 100, 250, 500 }
Economy.PLOT_COST = { 100, 300, 700, 1300, 2200, 3400, 5000, 7000 }
-- Crates bought with coins (the first race gives a free one).
Economy.CRATE_PRICE = { basic = 100, big = 450, mega = 1500 }

return Economy
