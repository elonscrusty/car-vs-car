--!strict
-- Pure session-lock decisions for a stored player record. A record looks like
--   { lock: { jobId: string, t: number }?, data: any }
-- All functions take `now` (os.time seconds) so they are deterministic and testable.
-- Callers run them inside UpdateAsync transforms (which must not yield).

export type Lock = { jobId: string, t: number }
export type Record = { lock: Lock?, data: any }

local SessionLock = {}

-- A lock older than this is considered abandoned (crashed server). Autosave is 60s, so 2x+ margin.
SessionLock.TTL = 150

local function isStale(lock: Lock, now: number, ttl: number): boolean
	local age = now - lock.t
	-- Far-future timestamps (clock skew / corruption) are treated as stale too, so a bad lock can't wedge a player forever.
	return age >= ttl or age < -ttl
end

-- Can this server claim the record? Returns (true) or (false, "locked").
function SessionLock.canClaim(
	record: Record?,
	jobId: string,
	now: number,
	ttl: number?
): (boolean, string?)
	if record == nil or record.lock == nil then
		return true, nil
	end
	local lock = record.lock :: Lock
	if lock.jobId == jobId or isStale(lock, now, ttl or SessionLock.TTL) then
		return true, nil
	end
	return false, "locked"
end

-- New record holding the lock for jobId (also used to refresh the timestamp). `data` replaces the stored data.
function SessionLock.claim(_record: Record?, jobId: string, now: number, data: any): Record
	return { lock = { jobId = jobId, t = now }, data = data }
end

-- Do we still own the lock? Only then may we write. (No lock at all counts as lost: someone else may have run since.)
function SessionLock.owns(record: Record?, jobId: string): boolean
	return record ~= nil and record.lock ~= nil and (record.lock :: Lock).jobId == jobId
end

-- Record to write on autosave (keeps lock, refreshes timestamp) or nil to abort when the lock was lost.
function SessionLock.save(record: Record?, jobId: string, now: number, data: any): Record?
	if not SessionLock.owns(record, jobId) then
		return nil
	end
	return SessionLock.claim(record, jobId, now, data)
end

-- Record to write on release (data saved, lock cleared) or nil to abort when the lock was lost.
function SessionLock.release(record: Record?, jobId: string, data: any): Record?
	if not SessionLock.owns(record, jobId) then
		return nil
	end
	return { lock = nil, data = data }
end

return SessionLock
