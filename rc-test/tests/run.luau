--!strict
-- Runs every test file, then prints a summary. Use (from rc-test/):  lune run tests/run

local Harness = require("./harness")

require("./carmath.test")
require("./laptimer.test")
require("./trackdata.test")

Harness.summary()
