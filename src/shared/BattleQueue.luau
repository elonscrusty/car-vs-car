--!strict
-- The waiting line for 1v1 (pure, unit tested). First in, first paired. A key is a user id.

export type Queue = { list: { number }, joined: { [number]: number } }

local BattleQueue = {}

function BattleQueue.new(): Queue
	return { list = {}, joined = {} }
end

-- False when already waiting.
function BattleQueue.join(q: Queue, id: number, now: number): boolean
	if q.joined[id] ~= nil then
		return false
	end
	q.joined[id] = now
	table.insert(q.list, id)
	return true
end

function BattleQueue.leave(q: Queue, id: number): boolean
	if q.joined[id] == nil then
		return false
	end
	q.joined[id] = nil
	local i = table.find(q.list, id)
	if i then
		table.remove(q.list, i)
	end
	return true
end

function BattleQueue.has(q: Queue, id: number): boolean
	return q.joined[id] ~= nil
end

function BattleQueue.size(q: Queue): number
	return #q.list
end

-- The two who waited longest, removed from the line. nil when fewer than two wait.
function BattleQueue.popPair(q: Queue): (number?, number?)
	if #q.list < 2 then
		return nil, nil
	end
	local a = table.remove(q.list, 1) :: number
	local b = table.remove(q.list, 1) :: number
	q.joined[a] = nil
	q.joined[b] = nil
	return a, b
end

-- Ids that waited longer than `maxSeconds`, removed from the line.
function BattleQueue.expire(q: Queue, now: number, maxSeconds: number): { number }
	local gone: { number } = {}
	for i = #q.list, 1, -1 do
		local id = q.list[i]
		if now - (q.joined[id] :: number) >= maxSeconds then
			table.remove(q.list, i)
			q.joined[id] = nil
			table.insert(gone, id)
		end
	end
	return gone
end

return BattleQueue
