--!strict
-- Pure, server-only recovery preparation. No datastore writes or recovery remote.
local Schema = require(game.ReplicatedStorage.Shared.Util.ProfileSchema)
local RecoveryPlan = {}
function RecoveryPlan.Prepare(current: any, archive: any, ownerUserId: number): any
	local live = Schema.Migrate(current)
	local restored = Schema.Migrate(archive)
	assert(live.OwnerUserId == ownerUserId, "Current profile owner mismatch")
	assert(restored.OwnerUserId == 0 or restored.OwnerUserId == ownerUserId, "Archived profile owner mismatch")
	-- Restoring old inventory must never reopen old transaction sequences.
	restored.OwnerUserId = ownerUserId
	restored.ChestSequence = live.ChestSequence
	restored.LastChestReceipt = live.LastChestReceipt
	restored.Revision = live.Revision + 1
	local valid, reason = Schema.Validate(restored)
	assert(valid, reason)
	return restored
end
return RecoveryPlan
