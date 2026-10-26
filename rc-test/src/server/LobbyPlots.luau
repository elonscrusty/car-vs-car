--!strict
-- Who owns, drives and has opened each lobby plot (the one place that knows). Every joining
-- player gets their own plot (the first free one) until they leave. A plot has one driver at a
-- time: anyone while it's open (every plot is, unless its owner shut it: carter 10-25, so
-- visiting other plots is the thing to do), and its owner always: the owner tapping DRIVE on
-- their own plot sends a visitor back to walking (not in the server race).
-- Each plot model (workspace.Plots.<slot>_<id>) carries the same as attributes for other
-- scripts: PlotType, Slot, OwnerId, DriverId (0 = none) and Open. `changed` fires (slot) on any
-- change. Main hooks `onDrive` (what starting a drive does: the car, the camera).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotOwners = require(ReplicatedStorage.Shared.PlotOwners)

local LobbyPlots = {}

local slots = LobbyLayout.slots()
-- owners and the line of plotless joiners (first plot, race plots first: those are the ones you
-- build your own track on)
local own: PlotOwners.Owners<Player> = PlotOwners.new(LobbyLayout.claimOrder())
local owners = own.owners
local ownSlot = own.ownSlot
local drivers: { [number]: Player } = {}
local driving: { [Player]: number } = {}
local opened: { [number]: boolean } = {}

local changedEvent = Instance.new("BindableEvent")
LobbyPlots.changed = changedEvent.Event

-- Set by Main: start this player driving this plot (after the claim).
LobbyPlots.onDrive = nil :: ((player: Player, slot: number) -> ())?
-- Set by Main: a visitor's turn ends because the owner wants to drive (walk them off).
LobbyPlots.onBump = nil :: ((player: Player, slot: number) -> ())?

local function model(slot: number): Instance?
	if slots[slot] == nil then
		return nil -- a race map (LobbyLayout.mapAt), not a plot
	end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(slot .. "_" .. slots[slot].id)
end

-- open: a plot nobody owns is open to all; an owned one unless its owner shut it
function LobbyPlots.isOpen(slot: number): boolean
	return owners[slot] == nil or opened[slot] ~= false
end

-- The server race holds this plot now (nobody gets bumped off it).
local function racing(slot: number): boolean
	return workspace:GetAttribute("RaceSlot") == slot
end

-- Someone else on my own plot that I may send off (the owner comes first).
local function visitorOn(player: Player, slot: number): Player?
	local driver = drivers[slot]
	if driver and driver ~= player and owners[slot] == player and not racing(slot) then
		return driver
	end
	return nil
end

local function refresh(slot: number)
	if slots[slot] == nil then
		return -- a race map: no plot model, nobody listening
	end
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

-- Give a joining player the first plot nobody owns (none when all are taken: they wait, and get
-- the next plot someone leaves).
function LobbyPlots.addPlayer(player: Player): number?
	local had = ownSlot[player]
	local slot = PlotOwners.add(own, player)
	if slot and slot ~= had then
		opened[slot] = true
		refresh(slot)
	end
	return slot
end

-- Driven just for fun with the tycoon plan on (players' plots are garages): the drift plot.
function LobbyPlots.freePlay(slot: number): boolean
	local s = slots[slot]
	return s ~= nil and s.id == "drift"
end

function LobbyPlots.canDrive(player: Player, slot: number): boolean
	if slots[slot] == nil or driving[player] ~= nil then
		return false
	end
	if not LobbyPlots.freePlay(slot) then
		return false
	end
	local owner = owners[slot]
	return LobbyLayout.canDrive(
		if owner then owner.UserId else nil,
		player.UserId,
		LobbyPlots.isOpen(slot),
		drivers[slot] ~= nil and visitorOn(player, slot) == nil
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

-- Leaving: stop driving and give the plot back (to the first one waiting for a plot, if any).
function LobbyPlots.removePlayer(player: Player)
	LobbyPlots.release(player)
	local slot = PlotOwners.remove(own, player)
	if slot then
		opened[slot] = true
		refresh(slot)
	end
end

-- Claim and start driving, the same as a tap on that plot's pad (without having to stand
-- there). False when the plot is busy, closed, or the player is already driving.
function LobbyPlots.sendTo(player: Player, slot: number): boolean
	if not LobbyPlots.canDrive(player, slot) then
		return false
	end
	local visitor = visitorOn(player, slot)
	if visitor then
		local bump = LobbyPlots.onBump
		if bump then
			bump(visitor, slot)
		end
		if drivers[slot] == visitor then
			LobbyPlots.release(visitor)
		end
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
