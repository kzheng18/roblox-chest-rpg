"""Run exact production Luau modules with explicit Roblox I/O doubles.

Usage: python3 tools/test_local.py /path/to/luau
Does not validate engine physics, replication, ProfileStore or cloud persistence.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HEADER = r'''
local loaders, cache = {}, {}
local function node(parent, name)
    local n = {Parent=parent, Name=name}; parent[name]=n; return n
end
local function require(n)
    if cache[n] ~= nil then return cache[n] end
    assert(loaders[n], "Missing test module: " .. tostring(n and n.Name))
    cache[n] = loaders[n](); return cache[n]
end
local clock = 100
local os = {clock=function() return clock end}
local warningCount = 0
local function warn(...) warningCount += 1 end
local Color3 = {fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local vectorMT = {}
local Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vectorMT) end}
vectorMT.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMT.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMT.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
local cframeMT = {__add=function(cf,v) return {Position=cf.Position+v} end}
local CFrame = {new=function(v) return setmetatable({Position=v},cframeMT) end}
Vector3.zero = Vector3.new(0,0,0)
-- Predictable fallback draws. Probability distribution tests require a separate RNG harness.
local Random = {new=function() return {NextInteger=function(_,_,maximum) return maximum end} end}
local game = {ReplicatedStorage={}, ServerScriptService={}}
local workspace = {Children={}}
function workspace:FindFirstChild(name) return self.Children[name] end
local function signal()
    local listeners = {}
    return {Connect=function(_,fn)
        local c={Connected=true}; function c:Disconnect() self.Connected=false end
        table.insert(listeners,{Connection=c,Callback=fn}); return c
    end, Fire=function(_,...)
        for _,l in listeners do if l.Connection.Connected then l.Callback(...) end end
    end}
end
local delayed = {}
local task = {
    spawn=function(fn,...) fn(...) end,
    delay=function(seconds,fn,...) table.insert(delayed,{At=clock+seconds,Fn=fn,Args=table.pack(...)}) end,
}
local players = {PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
function game:GetService(name)
    if name=="Players" then return players elseif name=="Workspace" then return workspace end
    return self[name]
end
local shared=node(game.ReplicatedStorage,"Shared")
node(shared,"Config"); node(shared,"Util")
local server=node(game.ServerScriptService,"Server")
node(server,"Components"); node(server,"Services")
local events, profiles, saves, touches, snapshots = {}, {}, {}, {}, {}
local remote = {OnServerEvent=signal(), FireClient=function(_,player,kind,payload)
    table.insert(events, {Player=player, Kind=kind, Payload=payload})
end}
cache[node(shared,"Remotes")] = {Get=function() return remote end}
cache[node(server.Services,"DataService")] = {
    Get=function(player) return if player.Parent==players and player.Active then profiles[player] else nil end,
    Touch=function(player)
        touches[player]=(touches[player] or 0)+1
        local data=profiles[player]; if data then data.Revision+=1; return data.Revision end
    end,
    RequestSave=function(player) saves[player]=(saves[player] or 0)+1 end,
    Snapshot=function(player) snapshots[player]=(snapshots[player] or 0)+1 end,
}
local fixture = {}
local nextUserId = 100
function fixture.new()
    clock += 100
    workspace.Children = {}
    local chest = {Anchored=true, Position=Vector3.new(0,2,-18)}
    function chest:IsA(class) return class=="BasePart" end
    local regionNodes = {}
    for _,regionData in require(shared.Config.Regions).List do
        local region = {Name=regionData.Id}
        local spawn = {Parent=region, CFrame=CFrame.new(regionData.Center+Vector3.new(0,0.6,0))}
        function spawn:IsA(class) return class=="SpawnLocation" end
        function region:FindFirstChild(name)
            if name=="PlayerSpawn" then return spawn end
            if name=="TreasureChest_verdant" and region.Name=="verdant" then return chest end
            return nil
        end
        regionNodes[regionData.Id]=region
    end
    workspace.Children.ChestRPGWorld = {FindFirstChild=function(_,name) return regionNodes[name] end}
    local root = {Position=Vector3.new(0,3,-16)}
    function root:IsA(class) return class=="BasePart" end
    local humanoid = {Health=100,Died=signal()}
    function humanoid:IsA(class) return class=="Humanoid" end
    local character = {InWorld=true}
    function character:IsDescendantOf(parent) return parent==workspace and self.InWorld end
    function character:FindFirstChildOfClass(class) return if class=="Humanoid" then humanoid else nil end
    function character:FindFirstChild(name) return if name=="HumanoidRootPart" then root else nil end
    function character:PivotTo(cf) root.Position=cf.Position end
    function character:WaitForChild(name) return if name=="Humanoid" then humanoid else nil end
    nextUserId += 1
    local player = {Parent=players, Character=character, Active=true, UserId=nextUserId}
    player.CharacterAdded=signal()
    player.Attributes={}; player.Signals={}; player.LoadCount=0
    function player:GetAttribute(key) return self.Attributes[key] end
    function player:GetAttributeChangedSignal(key)
        if not self.Signals[key] then self.Signals[key]=signal() end
        return self.Signals[key]
    end
    function player:SetAttribute(key,value)
        self.Attributes[key]=value
        if self.Signals[key] then self.Signals[key]:Fire() end
    end
    function player:Kick(message) self.Kicked=message end
    function player:LoadCharacterAsync()
        self.LoadCount+=1
        if self.FailLoads then error("test load failure") end
        self.Character=character
        self.CharacterAdded:Fire(character)
    end
    local data = require(shared.Util.ProfileSchema).New()
    profiles[player]=data
    return {Player=player, Data=data, Chest=chest, Root=root, Humanoid=humanoid, Character=character}
end
function fixture.events() return events end
function fixture.remote(player,action,payload,...) remote.OnServerEvent:Fire(player,action,payload,...) end
function fixture.saves(player) return saves[player] or 0 end
function fixture.snapshots(player) return snapshots[player] or 0 end
function fixture.warnings() return warningCount end
function fixture.advance(seconds)
    clock += seconds
    local ready=delayed; delayed={}
    for _,entry in ready do
        if entry.At<=clock then entry.Fn(table.unpack(entry.Args,1,entry.Args.n)) else table.insert(delayed,entry) end
    end
end
function fixture.join(player) players.PlayerAdded:Fire(player) end
function fixture.leave(player) player.Parent=nil; players.PlayerRemoving:Fire(player) end
function fixture.position(x,y,z) return Vector3.new(x,y,z) end
'''

chunks = [HEADER]
modules = list((ROOT / 'src/shared').rglob('*.luau'))
modules = [p for p in modules if p.name != 'Remotes.luau']
modules += [ROOT / 'src/server/Components' / (name + '.luau') for name in
            ('IntentGate', 'RequestContext', 'Diagnostics', 'SaveCoordinator', 'RecoveryPlan')]
modules += [ROOT / 'src/server/Services' / (name + '.luau') for name in
            ('ChestService', 'ProgressionService', 'RegionService', 'GameService', 'PlayerService')]
for path in modules:
    relative = path.relative_to(ROOT / 'src')
    parts = list(relative.with_suffix('').parts)
    expr = ('shared' if parts[0] == 'shared' else 'server') + ''.join('.' + p for p in parts[1:])
    parent = expr.rsplit('.', 1)[0]
    chunks.append(f'node({parent}, "{parts[-1]}")')
    chunks.append(f'loaders[{expr}] = function() local script={expr}\n{path.read_text()}\nend')

chunks.append(r'''
local expect={}
function expect.equal(a,b) assert(a==b, `Expected {tostring(b)}, got {tostring(a)}`) end
function expect.truthy(v) assert(v, "Expected truthy") end
function expect.falsy(v) assert(not v, "Expected falsy") end
function expect.near(a,b,t) assert(a==a and math.abs(a-b)<=(t or 1e-6), `Expected {b}, got {a}`) end
local passed,failed=0,0
local t={expect=expect,test=function(name,fn)
    local ok,err=pcall(fn)
    if ok then passed+=1; print("PASS "..name) else failed+=1; print("FAIL "..name..": "..tostring(err)) end
end}
''')
for case in sorted((ROOT / 'tests/Cases').glob('*.luau')) + sorted((ROOT / 'tests/headless').glob('*.luau')):
    chunks.append(f'do local run=(function()\n{case.read_text()}\nend)(); run(t, fixture) end')
chunks.append('print(`SUMMARY: {passed} passed, {failed} failed`); assert(failed==0, "Regression failures")')
with tempfile.TemporaryDirectory(prefix='chest-rpg-tests-') as folder:
    output = Path(folder) / 'tests.luau'
    output.write_text('\n'.join(chunks))
    sys.exit(subprocess.call([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(output)]))
