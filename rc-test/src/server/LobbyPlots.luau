--!strict
-- Who owns, drives and has opened each lobby plot (the one place that knows). Every joining
-- player gets their own plot (the first free one) until they leave. A plot has one driver at a
-- time: its owner, anyone when nobody owns it, or anyone when its owner opened it to friends.
-- Each plot model (workspace.Plots.<slot>_<id>) carries the same as attributes for other
-- scripts: PlotType, Slot, OwnerId, DriverId (0 = none) and Open. `changed` fires (slot) on any
-- change. Main hooks `onDrive` (what starting a drive does: the car, the camera).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyPlots = {}

local slots = LobbyLayout.slots()
local owners: { [number]: Player } = {}
local ownSlot: { [Player]: number } = {}
local drivers: { [number]: Player } = {}
local driving: { [Player]: number } = {}
local opened: { [number]: boolean } = {}

local changedEvent = Instance.new("BindableEvent")
LobbyPlots.changed = changedEvent.Event

-- Set by Main: start this player driving this plot (after the claim).
LobbyPlots.onDrive = nil :: ((player: Player, slot: number) -> ())?

local function model(slot: number): Instance?
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(slot .. "_" .. slots[slot].id)
end

-- open: a plot nobody owns is open to all; an owned one only when its owner says so
function LobbyPlots.isOpen(slot: number): boolean
	return owners[slot] == nil or opened[slot] == true
end

local function refresh(slot: number)
	local m = model(slot)
	if m then
		local owner, driver = owners[slot], drivers[slot]
		m:SetAttribute("PlotType", slots[slot].id)
		m:SetAttribute("Slot", slot)
		m:SetAttribute("OwnerId", if owner then owner.UserId else 0)
		m:SetAttribute("OwnerName", if owner then owner.DisplayName else "")
		m:SetAttribute("DriverId", if driver then driver.UserId else 0)
		m:SetAttribute("Open", LobbyPlots.isOpen(slot))
	end
	changedEvent:Fire(slot)
end
-- Once the plots are built: put the attributes on them.
function LobbyPlots.init()
	for i in slots do
		refresh(i)
	end
end

function LobbyPlots.ownerOf(slot: number): Player?
	return owners[slot]
end
function LobbyPlots.slotOf(player: Player): number?
	return ownSlot[player]
end
function LobbyPlots.driverOf(slot: number): Player?
	return drivers[slot]
end
function LobbyPlots.drivingOf(player: Player): number?
	return driving[player]
end

-- Give a joining player the first plot nobody owns, race plots first: those are the ones you
-- build your own track on (none when all are taken).
local claimOrder = LobbyLayout.claimOrder()
function LobbyPlots.addPlayer(player: Player): number?
	if ownSlot[player] then
		return ownSlot[player]
	end
	for _, i in claimOrder do
		if owners[i] == nil then
			owners[i] = player
			ownSlot[player] = i
			opened[i] = false
			refresh(i)
			return i
		end
	end
	return nil
end

function LobbyPlots.canDrive(player: Player, slot: number): boolean
	if slots[slot] == nil or driving[player] ~= nil then
		return false
	end
	local owner = owners[slot]
	return LobbyLayout.canDrive(
		if owner then owner.UserId else nil,
		player.UserId,
		LobbyPlots.isOpen(slot),
		drivers[slot] ~= nil
	)
end

function LobbyPlots.claim(player: Player, slot: number)
	driving[player] = slot
	drivers[slot] = player
	refresh(slot)
end

-- Stop driving (the plot stays theirs if they own it). Returns the plot they were on.
function LobbyPlots.release(player: Player): number?
	local slot = driving[player]
	if slot then
		drivers[slot] = nil
		driving[player] = nil
		refresh(slot)
	end
	return slot
end

-- The owner lets friends drive their plot (or stops it).
function LobbyPlots.setOpen(player: Player, on: boolean)
	local slot = ownSlot[player]
	if slot then
		opened[slot] = on
		refresh(slot)
	end
end

-- Leaving: stop driving and give the plot back.
function LobbyPlots.removePlayer(player: Player)
	LobbyPlots.release(player)
	local slot = ownSlot[player]
	if slot then
		owners[slot] = nil
		ownSlot[player] = nil
		opened[slot] = nil
		refresh(slot)
	end
end

-- Claim and start driving, the same as a tap on that plot's pad (without having to stand
-- there). False when the plot is busy, closed, or the player is already driving.
function LobbyPlots.sendTo(player: Player, slot: number): boolean
	if not LobbyPlots.canDrive(player, slot) then
		return false
	end
	LobbyPlots.claim(player, slot)
	local start = LobbyPlots.onDrive
	if start then
		start(player, slot)
	end
	return true
end

-- What a plot drives as now: a built plot's owner pick (TrackKind race / drift), else its slot.
local function kindOf(slot: number): string
	local m = model(slot)
	local picked = m and m:GetAttribute("TrackKind")
	return if type(picked) == "string" then picked else slots[slot].id
end

-- The best plot of this kind for this player: their own, else an open one nobody is on.
function LobbyPlots.findOpen(plotType: string, player: Player): number?
	local mine = ownSlot[player]
	if mine and kindOf(mine) == plotType and LobbyPlots.canDrive(player, mine) then
		return mine
	end
	for i in slots do
		if kindOf(i) == plotType and LobbyPlots.canDrive(player, i) then
			return i
		end
	end
	return nil
end

return LobbyPlots
