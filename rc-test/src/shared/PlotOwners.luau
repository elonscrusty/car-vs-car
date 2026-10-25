--!strict
-- Who owns which lobby plot, as plain data (LobbyPlots keeps one of these with Players in it;
-- Lune tests use numbers). Joiners get the first free plot in `order`; with every plot taken they
-- wait in line, and a plot freed by someone leaving goes straight to the first one waiting.

export type Owners<P> = {
	owners: { [number]: P },
	ownSlot: { [P]: number },
	waiting: { P },
	order: { number },
}

local PlotOwners = {}

function PlotOwners.new<P>(order: { number }): Owners<P>
	return { owners = {}, ownSlot = {}, waiting = {}, order = order }
end

local function give<P>(o: Owners<P>, who: P): number?
	for _, i in o.order do
		if o.owners[i] == nil then
			o.owners[i] = who
			o.ownSlot[who] = i
			return i
		end
	end
	return nil
end

-- A joiner: their plot, or nil (all taken: they wait for one).
function PlotOwners.add<P>(o: Owners<P>, who: P): number?
	local mine = o.ownSlot[who]
	if mine then
		return mine
	end
	local slot = give(o, who)
	if slot == nil and not table.find(o.waiting, who) then
		table.insert(o.waiting, who)
	end
	return slot
end

-- Someone leaves: returns the plot they had (now free) and who got it from the line (if anyone).
function PlotOwners.remove<P>(o: Owners<P>, who: P): (number?, P?)
	local at = table.find(o.waiting, who)
	if at then
		table.remove(o.waiting, at)
	end
	local slot = o.ownSlot[who]
	if slot == nil then
		return nil, nil
	end
	o.owners[slot] = nil
	o.ownSlot[who] = nil
	local nextOne = table.remove(o.waiting, 1)
	if nextOne ~= nil then
		o.owners[slot] = nextOne
		o.ownSlot[nextOne] = slot
	end
	return slot, nextOne
end

return PlotOwners
