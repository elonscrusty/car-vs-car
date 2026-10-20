--!strict
-- The first-time tutorial as a small state machine (pure: no Roblox calls, so the tests run every
-- step). The client feeds it events ("portal", "gas", "boxes", "prompt", "pulled"...) and shows
-- what `view()` says. Carter's picks are L1-L20 and L53-L60 in docs/LOBBY_POLISH.md; the numbers
-- and the words are in TutorialConfig.
--
-- Steps, in order:
--   portal       walk into the blue portal (a doorway to the practice yard)
--   gas          practice yard: hold GAS (phone) or W (PC)
--   steer        practice yard: steer
--   smash        practice yard: smash 3 boxes, then the yard closes
--   gumballWalk  back at the spawn: follow the green line to the gumball machine
--   gumballTap   near the machine: tap it
--   gumballPull  the claw screen: pull (the first one is free), then the sprint to DONE
--   gumballReveal the new car: DONE, then close the screen
--   play         follow the green line to a PLAY pad (or tap PLAY)
--   done         the coin gift bubble; the tutorial is over
-- Skip ends everything at any time, without the gift. Stepping onto a pad or tapping PLAY before
-- the last step also ends it (the player chose to play).

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Config = sibling("TutorialConfig")

local Tutorial = {}

Tutorial.Order = {
	"portal",
	"gas",
	"steer",
	"smash",
	"gumballWalk",
	"gumballTap",
	"gumballPull",
	"gumballReveal",
	"play",
	"done",
}

-- One place a bubble can stand next to a named button (the first one that is on screen wins).
export type Target = { find: string, text: string }

export type View = {
	id: string,
	text: string,
	-- where the bubble stands when none of `targets` is on screen: "top" (under SKIP), "keys" (bottom
	-- middle: the PC keys) or the name of a practice control
	anchor: string,
	targets: { Target }?,
	path: string?, -- the green path to draw: "gumball" or "pad"
	practice: boolean, -- the player is in the practice yard in this step
	boxes: number?, -- smashed so far (smash step)
}

export type Result = {
	done: string?, -- the step this event finished (the UI shows a check and confetti)
	now: string?, -- the step that is current now (nil when the tutorial ended)
	finished: boolean, -- the tutorial is over (done or skipped)
}

export type Machine = {
	current: () -> string?,
	view: () -> View?,
	event: (name: string, value: any?) -> Result,
	isFinished: () -> boolean,
	wasSkipped: () -> boolean,
	boxes: () -> number,
	-- the first gumball pull is free: the claw bubble says so
	setFree: (free: boolean) -> (),
}

local PRACTICE = { gas = true, steer = true, smash = true }

local function fill(text: string, values: { [string]: any }): string
	return (
		string.gsub(text, "{(%w+)}", function(key: string): string
			local v = values[key]
			return if v == nil then "{" .. key .. "}" else tostring(v)
		end)
	)
end

-- The words of a step for a phone or a PC.
function Tutorial.text(id: string, touch: boolean, values: { [string]: any }?): string
	local entry = Config.text[id]
	if entry == nil then
		return ""
	end
	local v = values or {}
	local raw = if touch then entry.phone else entry.pc
	return fill(raw, {
		n = v.n or 0,
		total = v.total or Config.boxesNeeded,
		coins = v.coins or Config.giftCoins,
	})
end

-- A brand new player: the tutorial never started and the old "tap PLAY" hint was never shown.
-- `seenList` is what the server sends in the profile (profile.hintsSeen as a list of ids).
function Tutorial.isNew(seenList: any): boolean
	if type(seenList) ~= "table" then
		return true
	end
	for _, id in seenList do
		if id == "tutorial" or id == "pad" then
			return false
		end
	end
	return true
end

function Tutorial.new(touch: boolean): Machine
	local step: string? = "portal"
	local finished = false
	local skipped = false
	local boxes = 0
	local gasTime, steerTime = 0.0, 0.0
	local free = true

	local self = {} :: Machine

	local function result(done: string?): Result
		return { done = done, now = step, finished = finished }
	end

	local function go(nextStep: string?, done: string?): Result
		step = nextStep
		if nextStep == "done" then
			finished = true
		end
		return result(done)
	end

	local function stop(wasSkipped: boolean): Result
		finished = true
		skipped = wasSkipped
		step = nil
		return result(nil)
	end

	self.current = function()
		return step
	end

	self.isFinished = function()
		return finished
	end

	self.wasSkipped = function()
		return skipped
	end

	self.boxes = function()
		return boxes
	end

	self.setFree = function(isFree: boolean)
		free = isFree
	end

	self.view = function(): View?
		local id = step
		if id == nil then
			return nil
		end
		local v: View = {
			id = id,
			text = Tutorial.text(id, touch, { n = boxes }),
			anchor = "top",
			practice = PRACTICE[id] == true,
		}
		local names = Config.names
		if id == "gas" then
			v.anchor = if touch then names.gas else "keys"
		elseif id == "steer" then
			v.anchor = if touch then names.stick else "keys"
		elseif id == "smash" then
			v.boxes = boxes
		elseif id == "gumballWalk" then
			v.path = "gumball"
		elseif id == "gumballPull" then
			v.targets = {
				{ find = names.confirm, text = Tutorial.text("gumballConfirm", touch) },
				{
					find = names.pull,
					text = Tutorial.text(if free then "gumballPullFree" else "gumballPull", touch),
				},
			}
		elseif id == "gumballReveal" then
			v.targets = {
				{ find = names.revealDone, text = Tutorial.text("gumballReveal", touch) },
				{ find = names.close, text = Tutorial.text("gumballClose", touch) },
			}
		elseif id == "play" then
			v.anchor = names.play
			v.path = "pad"
			v.targets = { { find = names.play, text = v.text } }
		end
		return v
	end

	self.event = function(name: string, value: any?): Result
		if finished then
			return result(nil)
		end
		if name == "skip" then
			return stop(true)
		end
		local id = step
		-- the player chose to play before the last step: that ends the tutorial (no gift)
		if name == "pad" then
			if id == "play" then
				return go("done", "play")
			end
			return stop(true)
		end
		-- the yard could not be built (no models, an error): carry on with the gumball machine
		if name == "practiceFailed" and (id == "portal" or PRACTICE[id or ""] == true) then
			return go("gumballWalk", nil)
		end
		if id == "portal" then
			if name == "portal" then
				return go("gas", "portal")
			end
		elseif id == "gas" then
			if name == "gas" and type(value) == "number" then
				gasTime += value
				if gasTime >= Config.gasSeconds then
					return go("steer", "gas")
				end
			end
		elseif id == "steer" then
			if name == "steer" and type(value) == "number" then
				steerTime += value
				if steerTime >= Config.steerSeconds then
					return go("smash", "steer")
				end
			end
		elseif id == "smash" then
			if name == "boxes" and type(value) == "number" then
				boxes = math.max(boxes, math.floor(value))
				if boxes >= Config.boxesNeeded then
					return go("gumballWalk", "smash")
				end
			end
		elseif id == "gumballWalk" then
			if name == "nearMachine" then
				return go("gumballTap", "gumballWalk")
			elseif name == "prompt" then
				return go("gumballPull", "gumballWalk")
			end
		elseif id == "gumballTap" then
			if name == "prompt" then
				return go("gumballPull", "gumballTap")
			end
		elseif id == "gumballPull" then
			if name == "pulled" then
				return go("gumballReveal", "gumballPull")
			elseif name == "menuClosed" then
				if free then
					return go("gumballTap", nil) -- closed the machine without the free pull: tap it again
				end
				-- a replay (the free pull is gone): pulls cost coins, so no pull is forced; going back
				-- from the machine is enough to have seen it
				return go("play", "gumballPull")
			end
		elseif id == "gumballReveal" then
			if name == "menuClosed" then
				return go("play", "gumballReveal")
			end
		end
		return result(nil)
	end

	return self
end

return Tutorial
