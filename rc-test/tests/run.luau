--!strict
-- Runs every test file, then prints a summary. Use (from rc-test/):  lune run tests/run

local Harness = require("./harness")

require("./carmath.test")
require("./laptimer.test")
require("./plots.test")
require("./plot_drift.test")
require("./plot_race.test")
require("./plot_rock.test")
require("./plot_show.test")
require("./lobby.test")
require("./lobby_water.test")
require("./lobby_sky.test")
require("./plaza.test")
require("./garage.test")
require("./lobby_scenery.test")

Harness.summary()
