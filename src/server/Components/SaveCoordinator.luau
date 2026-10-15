--!strict
-- Scheduling only. ProfileStore owns storage, session locks, and final saves.
local SaveCoordinator = {}

function SaveCoordinator.new(revision: number, config: any, clock: (() -> number)?)
	local now = clock or os.clock
	local current, saved, target = revision, revision, revision
	local due: number? = nil
	local started: number? = nil
	local failures = 0
	local active = true
	local status = "Loaded"
	local queue = {}
	function queue.Dirty(nextRevision: number)
		if not active or nextRevision <= current then return end
		current = nextRevision
		if not started and status ~= "Delayed" and status ~= "Queued" then status = "Pending" end
	end
	function queue.Request()
		if not active then return end
		target = math.max(target, current)
		if target <= saved then return end
		-- First request wins: frequent chest opens cannot push the deadline back.
		if not due and not started then due = now() + config.CriticalSaveDebounce end
		if not started and status ~= "Delayed" then status = "Queued" end
	end
	function queue.Begin()
		if not active then return end
		target = math.max(target, current)
		started = now(); due = nil; status = "Saving"
	end
	function queue.Acknowledge(revisionSaved: number)
		if not active or revisionSaved ~= revisionSaved or revisionSaved % 1 ~= 0
			or revisionSaved < saved or revisionSaved > current then return end
		saved = revisionSaved
		started = nil
		if saved >= target then
			due = nil; failures = 0
			status = if saved >= current then "Saved" else "Pending"
		else
			due = due or (now() + config.CriticalSaveDebounce)
			status = "Queued"
		end
	end
	function queue.Step(canWrite: boolean): boolean
		if not active then return false end
		local t = now()
		if started and t - started >= config.SaveAttemptTimeout then
			started = nil; failures += 1; status = "Delayed"
			due = t + math.min(2 ^ math.min(failures, 10), config.SaveRetryMaxSeconds)
		end
		if started or not due or t < due then return false end
		if not canWrite then status = "Delayed"; return false end
		queue.Begin()
		return true
	end
	function queue.Status(): string return status end
	function queue.SavedRevision(): number return saved end
	function queue.Detach() active = false; due = nil; started = nil end
	return queue
end

return SaveCoordinator
