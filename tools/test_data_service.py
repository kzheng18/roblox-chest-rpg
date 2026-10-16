"""Run production DataService with deterministic ProfileStore/Roblox I/O doubles.

This verifies our lifecycle wiring, not Roblox cloud availability/session locks.
Usage: python3 tools/test_data_service.py /path/to/luau
"""
import ast
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
tree = ast.parse((ROOT / 'tools/test_local.py').read_text())
header = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
              and any(isinstance(t, ast.Name) and t.id == 'HEADER' for t in n.targets))
header = header.replace('local n = {Parent=parent, Name=name}',
                        'if parent[name] then return parent[name] end; local n = {Parent=parent, Name=name}')
header = header.replace('spawn=function(fn,...) fn(...) end,', '''spawn=function(fn,...)
        local thread=coroutine.create(fn)
        local function resume(...)
            local ok,wait=coroutine.resume(thread,...); assert(ok,wait)
            if coroutine.status(thread)~="dead" then
                table.insert(delayed,{At=clock+(wait or 0),Fn=resume,Args=table.pack()})
            end
        end
        resume(...); return thread
    end,
    wait=function(seconds) return coroutine.yield(seconds or 0) end,''')
chunks = [header, r'''
local function deepCopy(raw)
    if type(raw)~="table" then return raw end
    local result={}; for key,value in raw do result[key]=deepCopy(value) end; return result
end
local records, activeProfiles = {}, {}
local backend = {IsClosing=false,Period=0,DataStoreState="Access"}
function backend.SetConstant(key,value) backend.Period=value end
local store={}
store.Mock=store
local template
function backend.New(_,defaults) template=defaults; return store end
function store:StartSessionAsync(key,options)
    if options.Cancel() or activeProfiles[key] then return nil end
    local profile={Data=deepCopy(records[key] or template),Key=key,Active=true,SaveCalls=0,
        OnSave=signal(),OnAfterSave=signal(),OnSessionEnd=signal()}
    activeProfiles[key]=profile
    function profile:IsActive() return self.Active end
    function profile:AddUserId(id) self.AssociatedUserId=id end
    function profile:Save()
        self.SaveCalls+=1; self.OnSave:Fire()
        if self.FailSaves then return end
        local snapshot=deepCopy(self.Data)
        local function finish()
            if activeProfiles[key]==self and self.Active then
                records[key]=deepCopy(snapshot); self.OnAfterSave:Fire(snapshot)
            end
        end
        if self.Delay then task.delay(self.Delay,finish) else finish() end
    end
    function profile:EndSession()
        records[key]=deepCopy(self.Data)
        self.Active=false; activeProfiles[key]=nil; self.OnSessionEnd:Fire()
    end
    local function autosave()
        if profile.Active then profile:Save(); task.delay(backend.Period,autosave) end
    end
    task.delay(backend.Period,autosave)
    return profile
end
cache[node(node(server,"Packages"),"ProfileStore")]=backend
local runtime=node(server.Components,"RuntimeState")
local coordinator=node(server.Components,"SaveCoordinator")
local productionData=node(server.Services,"DataService")
cache[productionData]=nil
cache[node(server.Components,"StateReplicator")]={
    Start=function() end,
    Flush=function(player) end,
    Snapshot=function(player)
        local data=require(runtime).Get(player)
        if data then remote:FireClient(player,"State",require(shared.Util.StateView).Snapshot(data)) end
    end,
}
game.RunService={IsStudio=function() return false end}
game.DataStoreService={Budget=5,GetRequestBudgetForRequestType=function(self) return self.Budget end}
local Enum={DataStoreRequestType={UpdateAsync="UpdateAsync"}}
local Instance={new=function(class)
    return {ClassName=class,Destroy=function() end}
end}
local originalNew=fixture.new
function fixture.new()
    local f=originalNew()
    function f.Player:FindFirstChild() return nil end
    return f
end
function fixture.seed(player,data) records["Player_"..player.UserId]=deepCopy(data) end
function fixture.record(player) return records["Player_"..player.UserId] end
function fixture.profile(player) return activeProfiles["Player_"..player.UserId] end
function fixture.tick(seconds) for _=1,seconds do fixture.advance(1) end end
''']
modules = [p for p in (ROOT / 'src/shared').rglob('*.luau') if p.name != 'Remotes.luau']
modules += [ROOT / 'src/server/Components' / (n + '.luau') for n in ('RuntimeState', 'SaveCoordinator')]
modules += [ROOT / 'src/server/Services/DataService.luau']
for path in modules:
    parts = list(path.relative_to(ROOT / 'src').with_suffix('').parts)
    expr = ('shared' if parts[0] == 'shared' else 'server') + ''.join('.' + p for p in parts[1:])
    parent = expr.rsplit('.', 1)[0]
    chunks += [f'node({parent}, "{parts[-1]}")',
               f'loaders[{expr}]=function() local script={expr}\n{path.read_text()}\nend']
chunks.append(r'''
local Data=require(productionData)
Data.Start()
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed+=1; print("PASS "..name) else failed+=1; print("FAIL "..name..": "..tostring(err)) end
end
test("autosave is always configured at sixty seconds",function() assert(backend.Period==60) end)
test("live sessions cannot silently fall back to an unsaved mock profile",function()
    local f=fixture.new(); backend.DataStoreState="NoAccess"
    fixture.join(f.Player); backend.DataStoreState="Access"
    assert(f.Player.Kicked and not Data.Get(f.Player) and not fixture.profile(f.Player))
    assert(fixture.record(f.Player)==nil)
end)
test("actual DataService isolates two players and persists ownership",function()
    local a,b=fixture.new(),fixture.new(); fixture.join(a.Player); fixture.join(b.Player)
    local da,db=Data.Get(a.Player),Data.Get(b.Player)
    assert(da and db and da~=db and da.OwnedWeapons~=db.OwnedWeapons)
    assert(da.OwnerUserId==a.Player.UserId and db.OwnerUserId==b.Player.UserId)
    da.OwnedWeapons.verdant_iron_sword=4; Data.Touch(a.Player,{"OwnedWeapons"}); Data.RequestSave(a.Player)
    fixture.tick(5)
    assert(fixture.record(a.Player).OwnedWeapons.verdant_iron_sword==4)
    assert(fixture.record(b.Player).OwnedWeapons.verdant_iron_sword==nil)
end)
test("owner mismatch cannot load another inventory or replace it with defaults",function()
    local f=fixture.new(); local raw=require(shared.Util.ProfileSchema).New()
    raw.OwnerUserId=f.Player.UserId+1; raw.OwnedWeapons.verdant_crownblade=7
    fixture.seed(f.Player,raw); fixture.join(f.Player)
    assert(f.Player.Kicked and not Data.Get(f.Player))
    assert(fixture.record(f.Player).OwnedWeapons.verdant_crownblade==7)
    assert(fixture.record(f.Player).OwnerUserId==raw.OwnerUserId)
end)
test("competing sessions cannot acquire the same player's inventory",function()
    local a,b=fixture.new(),fixture.new(); b.Player.UserId=a.Player.UserId
    fixture.join(a.Player); fixture.join(b.Player)
    assert(Data.Get(a.Player) and not Data.Get(b.Player) and b.Player.Kicked)
    Data.Get(a.Player).OwnedWeapons.verdant_crownblade=8
    Data.Touch(a.Player,{"OwnedWeapons"}); Data.RequestSave(a.Player); fixture.tick(5)
    assert(fixture.record(a.Player).OwnedWeapons.verdant_crownblade==8)
end)
test("corrupt inventory is preserved for recovery instead of silently emptied",function()
    local f=fixture.new(); fixture.seed(f.Player,{Version=2,Gold=800,OwnedWeapons={verdant_iron_sword=.5}})
    fixture.join(f.Player)
    assert(f.Player.Kicked and not Data.Get(f.Player))
    assert(fixture.record(f.Player).Gold==800 and fixture.record(f.Player).OwnedWeapons.verdant_iron_sword==.5)
end)
test("legacy migration retains items and queues an owner-bound checkpoint",function()
    local f=fixture.new(); fixture.seed(f.Player,{Version=2,OwnedWeapons={verdant_iron_sword=3,retired_blade=9},Gold=500})
    fixture.join(f.Player); fixture.tick(5)
    local saved=fixture.record(f.Player)
    assert(saved.OwnerUserId==f.Player.UserId and saved.Version==4 and saved.Gold==500)
    assert(saved.OwnedWeapons.verdant_iron_sword==3 and saved.OwnedWeapons.retired_blade==9)
end)
test("ordinary progression autosaves without a manual save request",function()
    local f=fixture.new(); fixture.join(f.Player); fixture.tick(5)
    local data=Data.Get(f.Player); data.Power=1234; Data.Touch(f.Player,{"Power"})
    assert(f.Player:GetAttribute("SaveStatus")=="Pending")
    fixture.tick(60); assert(fixture.record(f.Player).Power==1234)
    assert(f.Player:GetAttribute("SaveStatus")=="Saved")
end)
test("delayed save only acknowledges its captured revision",function()
    local f=fixture.new(); fixture.join(f.Player); fixture.tick(5)
    local profile=fixture.profile(f.Player); profile.Delay=6
    local data=Data.Get(f.Player); data.Gold=50; local revision=Data.Touch(f.Player,{"Gold"})
    Data.RequestSave(f.Player); fixture.tick(4)
    assert(f.Player:GetAttribute("SaveStatus")=="Saving")
    data.Power=999; Data.Touch(f.Player,{"Power"}); fixture.tick(6)
    assert(f.Player:GetAttribute("SavedRevision")==revision)
    assert(f.Player:GetAttribute("SaveStatus")=="Pending")
    assert(fixture.record(f.Player).Power~=999)
end)
test("failed checkpoints retry and recover automatically",function()
    local f=fixture.new(); fixture.join(f.Player); fixture.tick(5)
    local profile=fixture.profile(f.Player); profile.FailSaves=true
    Data.Get(f.Player).OwnedWeapons.verdant_crownblade=1
    Data.Touch(f.Player,{"OwnedWeapons"}); Data.RequestSave(f.Player); fixture.tick(19)
    assert(f.Player:GetAttribute("SaveStatus")=="Delayed")
    profile.FailSaves=false; fixture.tick(3)
    assert(f.Player:GetAttribute("SaveStatus")=="Saved")
    assert(fixture.record(f.Player).OwnedWeapons.verdant_crownblade==1)
end)
test("budget exhaustion queues instead of writing or claiming saved",function()
    local f=fixture.new(); fixture.join(f.Player); fixture.tick(5)
    local profile=fixture.profile(f.Player); local calls=profile.SaveCalls
    game.DataStoreService.Budget=0
    Data.Get(f.Player).Gold=777; Data.Touch(f.Player,{"Gold"}); Data.RequestSave(f.Player); fixture.tick(5)
    assert(profile.SaveCalls==calls and f.Player:GetAttribute("SaveStatus")=="Delayed")
    game.DataStoreService.Budget=5; fixture.tick(1)
    assert(fixture.record(f.Player).Gold==777)
end)
test("departure saves final inventory and revokes access",function()
    local f=fixture.new(); fixture.join(f.Player)
    Data.Get(f.Player).OwnedWeapons.frost_steel_saber=2; Data.Touch(f.Player,{"OwnedWeapons"})
    fixture.leave(f.Player)
    assert(not Data.Get(f.Player) and fixture.record(f.Player).OwnedWeapons.frost_steel_saber==2)
end)
test("lost profile session immediately removes progression authority",function()
    local f=fixture.new(); fixture.join(f.Player); fixture.profile(f.Player):EndSession()
    assert(not Data.Get(f.Player) and f.Player.Kicked and f.Player:GetAttribute("DataReady")==false)
end)
test("snapshot goes only to its owner and rejects departed players",function()
    local f=fixture.new(); fixture.join(f.Player); local before=#events
    Data.Snapshot(f.Player)
    assert(#events==before+1 and events[#events].Player==f.Player)
    fixture.leave(f.Player); Data.Snapshot(f.Player); assert(#events==before+1)
end)
backend.IsClosing=true
print(`SUMMARY: {passed} passed, {failed} failed`)
assert(failed==0,"Persistence wiring failures")
''')
with tempfile.TemporaryDirectory(prefix='chest-data-service-') as folder:
    path = Path(folder) / 'tests.luau'
    path.write_text('\n'.join(chunks))
    sys.exit(subprocess.call([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(path)]))
