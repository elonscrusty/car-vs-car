--!strict
-- Every kart's one special charge (shared/Charge has the numbers). The server alone changes it:
-- a gold box adds a third (BoxServer's `charge` option is `SpecialCharge.add`), and the SPECIAL
-- button will spend it with `use`. A player's kart id is their UserId; bots can use any other id.
--
-- What a screen reads: the Player attributes "SpecialBase" (the level at "SpecialAt") and
-- "SpecialAt" (workspace:GetServerTimeNow() when it last changed). The level now is
-- `Charge.level({ base = SpecialBase, at = SpecialAt }, workspace:GetServerTimeNow())`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charge = require(ReplicatedStorage.Shared.Charge)

local SpecialCharge = {}

local slots: { [any]: Charge.Slot } = {}

-- the same clock the clients read (GetServerTimeNow), so the slow fill matches on every screen
local function now(): number
	local ok, t = pcall(function(): number
		return workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function slotOf(id: any): Charge.Slot
	local s = slots[id]
	if not s then
		s = Charge.slot(now())
		slots[id] = s
	end
	return s
end

local function publish(id: any, s: Charge.Slot)
	if type(id) ~= "number" or id <= 0 then
		return -- a bot has no screen
	end
	local p = Players:GetPlayerByUserId(id)
	if p then
		p:SetAttribute("SpecialBase", s.base)
		p:SetAttribute("SpecialAt", s.at)
	end
end

-- A box: adds `amount` (default a third). Returns the new level, or nil when it is full.
function SpecialCharge.add(id: any, amount: number?): number?
	local s = slotOf(id)
	local level = Charge.add(s, now(), amount)
	if level ~= nil then
		publish(id, s)
	end
	return level
end

function SpecialCharge.level(id: any): number
	return Charge.level(slotOf(id), now())
end

-- The SPECIAL button: spends a full special. false = not full.
function SpecialCharge.use(id: any): boolean
	local s = slotOf(id)
	if not Charge.use(s, now()) then
		return false
	end
	publish(id, s)
	return true
end

-- A kart leaves the match.
function SpecialCharge.drop(id: any)
	slots[id] = nil
	publish(id, Charge.slot(now())) -- a player's screen shows it empty
end

-- A new match: every special empty.
function SpecialCharge.reset()
	for id in slots do
		local s = Charge.slot(now())
		slots[id] = s
		publish(id, s)
	end
end

return SpecialCharge
