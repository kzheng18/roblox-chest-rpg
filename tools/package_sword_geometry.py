"""Validate authored meshes and package server-only geometry for Rojo.

Run after build_swords.py. Runtime builds 44 MeshParts once per server using
Roblox DataModel-scoped content; there is no upload API or client geometry input.
Also prepares /tmp/chest_verify_sync.json to install the source in connected Studio.
"""
from pathlib import Path
import json
import math
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/swords'

def item(parent,cls,name):
    obj=ET.SubElement(parent,'Item',{'class':cls})
    props=ET.SubElement(obj,'Properties')
    ET.SubElement(props,'string',{'name':'Name'}).text=name
    return obj,props

root=ET.Element('roblox',{'version':'4'})
geometry,_=item(root,'Folder','SwordGeometry')
stats=[]; calls=[]
for path in sorted(OUT.glob('*.mesh.json')):
    data=json.loads(path.read_text()); assert len(data['parts'])==4
    folder,_=item(geometry,'Folder',data['id'])
    meta={k:v for k,v in data.items() if k!='parts'}
    meta['partNames']=[part['name'] for part in data['parts']]
    pieces={'Metadata':meta,**{part['name']:part for part in data['parts']}}
    sources={}
    for name,payload in pieces.items():
        text='return [==['+json.dumps(payload,separators=(',',':'))+']==]'
        assert len(text)<200000, (data['id'],name,len(text))
        sources[name]=text
        module,props=item(folder,'ModuleScript',name)
        ET.SubElement(props,'ProtectedString',{'name':'Source'}).text=text
    code='assert(not game:GetService("RunService"):IsRunning()); '
    code+='local parent=game.ServerStorage:FindFirstChild("SwordGeometry"); if not parent then parent=Instance.new("Folder"); parent.Name="SwordGeometry"; parent.Parent=game.ServerStorage end; '
    code+='local id='+json.dumps(data['id'])+'; local folder=parent:FindFirstChild(id); if not folder then folder=Instance.new("Folder"); folder.Name=id; folder.Parent=parent end; '
    code+='local sources=game:GetService("HttpService"):JSONDecode([====['+json.dumps(sources)+']====]); '
    code+='for name,source in sources do local m=folder:FindFirstChild(name); if not m then m=Instance.new("ModuleScript"); m.Name=name; m.Parent=folder end; m.Source=source end; return id'
    calls.append({'name':'execute_luau','arguments':{'datamodel_type':'Edit','code':code}})
    total=0
    for part in data['parts']:
        vs=part['vertices']; ns=part['normals']; assert len(vs)==len(ns)
        assert all(math.isfinite(v) for p in vs+ns for v in p)
        assert all(abs(sum(x*x for x in n)-1)<.0001 for n in ns)
        for f in part['triangles']:
            assert len(set(f))==3 and all(1<=i<=len(vs) for i in f)
            a,b,c=[vs[i-1] for i in f]
            u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
            cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            assert sum(x*x for x in cross)>1e-16, (data['id'],part['name'],'degenerate triangle')
        total+=len(part['triangles'])
    assert total<=8000
    stats.append({'id':data['id'],'triangles':total,'parts':len(data['parts'])})
ET.indent(root)
(ROOT/'src/assets').mkdir(exist_ok=True)
ET.ElementTree(root).write(ROOT/'src/assets/SwordGeometry.rbxmx',encoding='utf-8',xml_declaration=True)
(ROOT/'docs/swords/geometry-validation.json').write_text(json.dumps({'models':stats,'result':'PASS'},indent=2)+'\n')
Path('/tmp/chest_verify_sync.json').write_text(json.dumps(calls))
obsolete=OUT/'SwordMeshInstaller.rbxmx'
if obsolete.exists(): obsolete.unlink()  # Remove only this run's obsolete generated installer.
print(f'PASS: {len(stats)} models, finite geometry/normals, no degenerate triangles, four material groups each.')
print('Packaged src/assets/SwordGeometry.rbxmx; prepared 11 Studio source-install calls.')
