"""Exercise the production effects controller with Roblox I/O doubles.
This checks reversible quality settings and bounded sampling, not real FPS.
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
chunks = [header, r'''
local f=fixture.new()
players.LocalPlayer=f.Player
game.Players=players
local renders=signal()
game.RunService={RenderStepped=renders}
game.UserInputService={TouchEnabled=false}
local graphicsChanged=signal()
local graphics={SavedQualityLevel={Value=10},GetPropertyChangedSignal=function() return graphicsChanged end}
local function UserSettings() return {GetService=function() return graphics end} end
local world={Name="ChestRPGWorld",Parent=workspace}
local unrelated={Name="UnrelatedLighting",Parent=workspace}
local descendants={}
workspace.DescendantAdded=signal()
function workspace:GetDescendants() return descendants end
local yields=0
task.wait=function() yields+=1 end
task.defer=function(fn,...) fn(...) end
local function effect(class,parent)
    local e={ClassName=class,Name="Fixture",Parent=parent,Rate=100,Shadows=true,CastShadow=true}
    function e:IsA(kind) return kind==self.ClassName or (kind=="Light" and class=="PointLight") end
    function e:GetAttribute() return nil end
    table.insert(descendants,e)
    return e
end
local emitter=effect("ParticleEmitter",world)
local light=effect("PointLight",world)
local part=effect("BasePart",world)
local outside=effect("PointLight",unrelated)
local controllers=node(node(game,"StarterPlayerScripts"),"Controllers")
''']
setup = chunks.pop()
modules = [p for p in (ROOT / 'src/shared').rglob('*.luau') if p.name != 'Remotes.luau']
modules.append(ROOT / 'src/client/Controllers/PerformanceController.luau')
for p in modules:
    parts = list(p.relative_to(ROOT / 'src').with_suffix('').parts)
    if parts[0] == 'client':
        chunks.append(setup)
    expr = ('shared' if parts[0] == 'shared' else 'controllers') + ''.join('.' + x for x in
        (parts[1:] if parts[0] == 'shared' else parts[2:]))
    parent = expr.rsplit('.', 1)[0]
    chunks += [f'node({parent}, "{parts[-1]}")',
               f'loaders[{expr}]=function() local script={expr}\n{p.read_text()}\nend']
chunks.append(r'''
local controller=require(controllers.PerformanceController)
controller.Start()
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed+=1; print("PASS "..name) else failed+=1; print("FAIL "..name..": "..tostring(err)) end
end
test("desktop Auto retains authored effects",function()
    assert(emitter.Rate==100 and light.Shadows and part.CastShadow)
end)
test("Low reduces owned effects and High restores exact originals",function()
    f.Player:SetAttribute("EffectsQuality","Low")
    assert(emitter.Rate==25 and not light.Shadows and not part.CastShadow)
    assert(outside.Shadows)
    f.Player:SetAttribute("EffectsQuality","High")
    assert(emitter.Rate==100 and light.Shadows and part.CastShadow)
end)
test("Auto follows mobile and user graphics preferences",function()
    game.UserInputService.TouchEnabled=true; graphics.SavedQualityLevel.Value=0
    f.Player:SetAttribute("EffectsQuality","Auto"); assert(emitter.Rate==25)
    graphics.SavedQualityLevel.Value=10; graphicsChanged:Fire(); assert(emitter.Rate==100)
    graphics.SavedQualityLevel.Value=2; graphicsChanged:Fire(); assert(emitter.Rate==25)
end)
test("streamed effects inherit the current quality",function()
    local streamed=effect("ParticleEmitter",world)
    workspace.DescendantAdded:Fire(streamed); assert(streamed.Rate==25)
end)
test("large quality changes yield in bounded batches",function()
    for _=1,600 do effect("BasePart",world) end
    local before=yields; f.Player:SetAttribute("EffectsQuality","High")
    assert(yields-before==3)
end)
test("render sampling never changes inventory or sends gameplay events",function()
    local count=#events
    for _=1,241 do renders:Fire(1/240) end
    assert(f.Player:GetAttribute("ClientFPS")==240)
    assert(f.Player:GetAttribute("ClientFrameP95Ms")<=4.5)
    assert(f.Data.Power==0 and f.Data.Gold==100 and #events==count)
end)
test("starting twice does not install duplicate render samplers",function()
    local writes=0; local originalSet=f.Player.SetAttribute
    function f.Player:SetAttribute(key,value)
        if key=="ClientFPS" then writes+=1 end
        originalSet(self,key,value)
    end
    controller.Start()
    for _=1,241 do renders:Fire(1/240) end
    assert(writes==1)
end)
print(`SUMMARY: {passed} passed, {failed} failed`)
assert(failed==0,"Effects controller failures")
''')
with tempfile.TemporaryDirectory(prefix='chest-performance-') as folder:
    path = Path(folder) / 'tests.luau'
    path.write_text('\n'.join(chunks))
    sys.exit(subprocess.call([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(path)]))
