--!strict
-- Daily spin wheel rules (pure). The server rolls with a Random-backed rng; tests pass a fake.
-- profile.spin = { lastDay } (UTC day number of the last spin). One spin per day.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local SpinConfig = sibling("SpinConfig")
local QuestsConfig = sibling("QuestsConfig")

export type Data = { lastDay: number }
export type OddsRow = { label: string, percent: number }
export type Result = { index: number, label: string, coins: number, freePulls: number }

local Spin = {}

function Spin.default(): Data
	return { lastDay = 0 }
end

function Spin.clean(raw: any): Data
	local d = Spin.default()
	if type(raw) == "table" then
		local last = raw.lastDay
		if type(last) == "number" and last == last and last >= 0 and last < 1e9 then
			d.lastDay = math.floor(last)
		end
	end
	return d
end

function Spin.dayNumber(now: number): number
	return math.floor(now / SpinConfig.dayLength)
end

function Spin.canSpin(d: Data, now: number): boolean
	return Spin.dayNumber(now) ~= d.lastDay
end

local function totalWeight(): number
	local total = 0
	for _, seg in SpinConfig.Segments do
		total += seg.weight
	end
	return total
end

-- The odds the player sees BEFORE spinning (same weights the server rolls with).
function Spin.oddsTable(): { OddsRow }
	local total = totalWeight()
	local rows: { OddsRow } = {}
	for _, seg in SpinConfig.Segments do
		table.insert(rows, {
			label = seg.label,
			percent = math.floor(seg.weight / total * 1000 + 0.5) / 10,
		})
	end
	return rows
end

-- Which segment a roll in [0, 1) lands on.
function Spin.pick(roll: number): number
	local target = math.clamp(roll, 0, 0.999999999) * totalWeight()
	local acc = 0
	for i, seg in SpinConfig.Segments do
		acc += seg.weight
		if target < acc then
			return i
		end
	end
	return #SpinConfig.Segments
end

-- Spins once for today. Marks the day used BEFORE paying, so a repeat spin finds nothing.
-- `pay` adds coins; `addFreePull` adds free claw tries (the caller caps them). Returns nil if
-- already spun today.
function Spin.spin(
	d: Data,
	now: number,
	rng: () -> number,
	pay: (number) -> (),
	addFreePull: (number) -> ()
): Result?
	if not Spin.canSpin(d, now) then
		return nil
	end
	d.lastDay = Spin.dayNumber(now)
	local index = Spin.pick(rng())
	local seg = SpinConfig.Segments[index]
	if seg.coins > 0 then
		pay(seg.coins)
	end
	if seg.freePulls > 0 then
		addFreePull(seg.freePulls)
	end
	return { index = index, label = seg.label, coins = seg.coins, freePulls = seg.freePulls }
end

-- Caps stacked free claw tries (same cap as the daily gift).
function Spin.addFreePulls(daily: { freePulls: number }, n: number)
	daily.freePulls = math.min(daily.freePulls + n, QuestsConfig.Daily.maxFreePulls)
end

return Spin
