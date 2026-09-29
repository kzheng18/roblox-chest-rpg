--!strict
local Types = require(game.ReplicatedStorage.Shared.Types)

type Entry = {Data: Types.PlayerData, Dirty: {[string]: boolean}}
local entries: {[Player]: Entry} = {}
local RuntimeState = {}

function RuntimeState.Attach(player: Player, data: Types.PlayerData)
	entries[player] = {Data = data, Dirty = {}}
end

function RuntimeState.Get(player: Player): Types.PlayerData?
	local entry = entries[player]
	return if entry then entry.Data else nil
end

function RuntimeState.Commit(player: Player, fields: {string}): number?
	local entry = entries[player]
	if not entry then return nil end
	entry.Data.Revision += 1
	for _, field in fields do entry.Dirty[field] = true end
	return entry.Data.Revision
end

function RuntimeState.ConsumeDirty(player: Player): {[string]: boolean}?
	local entry = entries[player]
	if not entry or next(entry.Dirty) == nil then return nil end
	local dirty = entry.Dirty
	entry.Dirty = {}
	return dirty
end

function RuntimeState.Detach(player: Player)
	entries[player] = nil
end

return RuntimeState

