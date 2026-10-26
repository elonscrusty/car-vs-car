--!strict
-- What's switched on (carter 10-26: RC Car Tycoon + Racing, rc-game/tycoon/PLAN.md). The parts
-- the new plan drops are hidden behind these, not deleted, so they can come back. Saves keep
-- their old fields either way.

local Features = {}

Features.TILES = false -- building your own track with tiles: BUILD, the build screen, tile shop
Features.PLOT_RACING = false -- driving and racing on players' plots (plots are garages now)
Features.STARS = false -- stars, medals, the plot boards, visit signs

return Features
