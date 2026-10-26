--!strict
-- What's switched on (carter 10-26: RC Car Tycoon + Racing, rc-game/tycoon/PLAN.md). The parts
-- the new plan drops are hidden behind these, not deleted, so they can come back. Saves keep
-- their old fields either way.

local Features = {}

Features.TILES = false -- building your own track with tiles: BUILD, the build screen, tile shop
Features.PLOT_RACING = false -- driving and racing on players' plots (plots are garages now)
Features.STARS = false -- stars, medals, the plot boards, visit signs
-- Plots as garages (PlotGarageBuilder): each plot's track is put away and the loop road with the
-- parked cars, coin pile and LEVEL UP sign goes in. Off until the server race runs on the race
-- maps, since today's race still drives on a plot's track.
Features.GARAGES = false

return Features
