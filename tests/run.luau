--!strict
-- Runs every test file, then prints a summary. Use:  lune run tests/run

local Harness = require("./harness")

require("./logic.test")
require("./ai.test")
require("./config.test")
require("./limiter.test")
require("./arena.test")

Harness.summary()
