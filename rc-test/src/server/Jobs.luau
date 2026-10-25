--!strict
-- One door for daily job events from any server script (race runner, car shop, track build).
-- Stars.server owns the jobs and sets the handler; until it does, events are dropped.

local Jobs = {}

local handler: ((Player, string, number?) -> ())? = nil

function Jobs.setHandler(fn: (Player, string, number?) -> ())
	handler = fn
end

-- Something a daily job may want happened to `player` (`n` times, default 1).
function Jobs.fire(player: Player, event: string, n: number?)
	local h = handler
	if h then
		task.spawn(h, player, event, n)
	end
end

return Jobs
