--!strict
-- Runs every test file, then prints a summary. Use:  lune run tests/run

local Harness = require("./harness")

require("./logic.test")
require("./ai.test")
require("./config.test")
require("./limiter.test")
require("./arena.test")
require("./fight.test")
require("./duel.test")
require("./padlogic.test")
require("./saves.test")
require("./lobbylayout.test")
require("./lobby.test")
require("./lobbytext.test")
require("./store.test")
require("./clawpath.test")
require("./uisize.test")

Harness.summary()
