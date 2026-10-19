--!strict
-- Pure analytics rules: funnel step names/order, once-per-player-per-step, field sanitising,
-- custom event schema, global send cap. No Roblox services here, so Lune can test it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local TelemetryConfig = sibling("TelemetryConfig")

export type Event = { name: string, value: number?, fields: { [string]: string }? }

export type State = {
	steps: { [number]: { [number]: boolean } }, -- userId -> step number -> already sent
	matches: { [number]: number }, -- userId -> matches started this visit
	sentAt: { number }, -- send times inside the rate window
}

local TelemetryRules = {}

local FieldKeys = { "CustomField01", "CustomField02", "CustomField03" } -- Enum.AnalyticsCustomFieldKeys names

function TelemetryRules.new(): State
	return { steps = {}, matches = {}, sentAt = {} }
end

-- Step number for a name, or nil if unknown.
function TelemetryRules.stepNumber(name: string): number?
	for i, n in TelemetryConfig.Steps do
		if n == name then
			return i
		end
	end
	return nil
end

-- Returns the step number the first time this player reaches this step, otherwise nil.
function TelemetryRules.claimStep(state: State, userId: number, name: string): number?
	local n = TelemetryRules.stepNumber(name)
	if n == nil then
		return nil
	end
	local seen = state.steps[userId]
	if seen == nil then
		seen = {}
		state.steps[userId] = seen
	end
	if seen[n] then
		return nil
	end
	seen[n] = true
	return n
end

-- Count a match start for this player; returns how many they have started.
function TelemetryRules.countMatch(state: State, userId: number): number
	local c = (state.matches[userId] or 0) + 1
	state.matches[userId] = c
	return c
end

function TelemetryRules.clear(state: State, userId: number)
	state.steps[userId] = nil
	state.matches[userId] = nil
end

-- Text safe for a custom field: letters, digits, space, _ - : . only; capped in length.
function TelemetryRules.sanitizeField(v: any): string
	local s = if type(v) == "boolean" then (if v then "true" else "false") else tostring(v)
	s = string.gsub(s, "[^%w _%-:%.]", "")
	return string.sub(s, 1, TelemetryConfig.MaxFieldLength)
end

local function cleanNumber(v: any): number?
	if type(v) ~= "number" or v ~= v then
		return nil
	end
	return math.clamp(v, 0, TelemetryConfig.MaxValue)
end

-- Build a custom event from loose data, following the schema. nil = unknown event name.
-- data keys: the schema's value name and field names. Missing fields become "".
function TelemetryRules.buildEvent(name: string, data: { [string]: any }?): Event?
	local schema = TelemetryConfig.Events[name]
	if schema == nil then
		return nil
	end
	local d = data or {}
	local ev: Event = { name = name }
	if schema.value then
		ev.value = cleanNumber(d[schema.value]) or 0
	end
	if #schema.fields > 0 then
		local fields: { [string]: string } = {}
		for i, key in schema.fields do
			if FieldKeys[i] then
				fields[FieldKeys[i]] =
					TelemetryRules.sanitizeField(if d[key] == nil then "" else d[key])
			end
		end
		ev.fields = fields
	end
	return ev
end

-- Global cap: true if one more event may be sent at `now` (and records it).
function TelemetryRules.allow(state: State, now: number): boolean
	local cfg = TelemetryConfig.RateLimit
	local keep: { number } = {}
	for _, t in state.sentAt do
		if now - t < cfg.windowSeconds then
			table.insert(keep, t)
		end
	end
	state.sentAt = keep
	if #keep >= cfg.maxEvents then
		return false
	end
	table.insert(keep, now)
	return true
end

return TelemetryRules
