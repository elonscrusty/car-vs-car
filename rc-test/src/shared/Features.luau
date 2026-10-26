--!strict
-- What's switched on (carter 10-26: RC Car Tycoon + Racing, rc-game/tycoon/PLAN.md). The parts
-- the new plan drops are hidden behind these, not deleted, so they can come back. Saves keep
-- their old fields either way.

local Features = {}

Features.PLOT_RACING = false -- driving and racing on players' plots (plots are garages now)
Features.STARS = false -- stars, medals, the plot boards, visit signs
-- Plots as garages (PlotGarageBuilder): each plot's track is put away and the loop road with the
-- parked cars, coin pile and LEVEL UP sign goes in. On since the server race runs on the race
-- maps (RaceMaps.NAMES has Backyard and Kitchen), so no race needs a plot's track.
Features.GARAGES = true

-- Phone speed, waiting for Studio numbers. Both are off / unchanged until someone flips them.
-- Plot cars are moved this many times a second (60 = every frame, as before; 30 = half the work).
Features.PLOT_CAR_HZ = 60
-- Streaming is the property Workspace.StreamingEnabled in default.project.json (false today).
-- Streaming.persist (server) already keeps the lobby, plots and race maps loaded either way, so
-- turning it on there is one line.

return Features
