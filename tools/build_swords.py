"""Author original sword meshes in Blender. No downloaded meshes or textures.

Run: Blender --background --python tools/build_swords.py
Outputs editable blend, individual GLBs, mesh payloads and a rendered gallery.
Blender Z is blade-up; the exported Roblox payload uses Y up and grip at origin.
"""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/swords'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = ROOT / 'docs/swords'
PREVIEW.mkdir(parents=True, exist_ok=True)

# id, name, tier, theme, length, width, curve, guard sweep, design
DESIGNS = [
 ('verdant_iron_sword','Ironleaf Sword','Common','leaf',3.15,.25,.22,.25,'leaf'),
 ('verdant_clover_blade','Clover Greatblade','Epic','leaf',4.15,.43,.36,.65,'thorn'),
 ('verdant_crownblade','Verdant Crownblade','Legendary','leaf',4.0,.33,.12,.80,'crown'),
 ('frost_steel_saber','Froststeel Saber','Common','ice',3.4,.23,.68,.36,'saber'),
 ('frost_winterfang','Winterfang','Epic','ice',4.2,.44,-.20,.68,'fang'),
 ('frost_aurora','Aurora Edge','Legendary','aurora',3.9,.32,.65,.85,'saber'),
 ('frost_sovereign','Frost Sovereign','Mythic','ice',4.65,.48,.08,1.05,'crown'),
 ('ember_ash_sword','Ashforged Sword','Common','ember',3.2,.27,-.30,.30,'ash'),
 ('ember_infernal','Infernal Greatsword','Epic','ember',4.35,.48,-.35,.80,'fang'),
 ('ember_sunbreaker','Sunbreaker','Legendary','sun',4.35,.40,.32,.95,'sun'),
 ('exclusive_azure_oath','Oath of the Azure Crown','Exclusive','royal',4.35,.32,.08,.95,'royal'),
]
PALETTES = {
 'leaf': ((.32,.46,.40),(.82,.59,.21),(.055,.11,.085),(.20,.92,.46)),
 'ice': ((.48,.66,.79),(.22,.39,.60),(.025,.065,.12),(.22,.78,1)),
 'aurora': ((.54,.62,.78),(.57,.32,.78),(.05,.045,.15),(.30,1,.80)),
 'ember': ((.15,.18,.23),(.60,.24,.10),(.06,.035,.035),(1,.22,.045)),
 'sun': ((.46,.38,.24),(.92,.59,.14),(.085,.04,.025),(1,.62,.07)),
 'royal': ((.62,.72,.83),(.94,.68,.25),(.035,.065,.24),(.07,.37,.95)),
}
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version=0
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.world.color=(.09,.09,.09)
scene.view_settings.view_transform='AgX'
materials={}
for theme,colors in PALETTES.items():
    for index,col in enumerate(colors):
        m=bpy.data.materials.new(theme+'_'+str(index)); m.diffuse_color=(*col,1)
        m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=(*col,1)
        p.inputs['Metallic'].default_value=.86 if index<2 else .18
        p.inputs['Roughness'].default_value=.27 if index<2 else .42
        if index==3:
            p.inputs['Emission Color'].default_value=(*col,1)
            p.inputs['Emission Strength'].default_value=.65
        materials[theme,index]=m

def mesh(name,verts,faces,material):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material); return obj

def bevel(obj,width=.018,segments=2):
    mod=obj.modifiers.new('Forged edge bevel','BEVEL'); mod.width=width; mod.segments=segments
    mod.affect='EDGES'
    return obj

def sweep(name,points,radii,material,sides=10):
    verts=[]; faces=[]
    for i,point in enumerate(points):
        p=Vector(point)
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        side=tangent.cross(Vector((0,1,0))).normalized()
        other=tangent.cross(side).normalized()
        for j in range(sides):
            a=2*math.pi*j/sides
            verts.append(p+(side*math.cos(a)+other*math.sin(a))*radii[i])
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    obj=mesh(name,verts,faces,material)
    for poly in obj.data.polygons: poly.use_smooth=True
    return obj

def jewel(name,pos,radius,material,elongation=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=radius,location=pos)
    o=bpy.context.object; o.name=name; o.scale=(1,.60,elongation); o.data.materials.append(material)
    return o

def blade_center(t,length,curve): return curve*t*t, .80+length*t

def blade_width(t,width,design):
    taper=(1-t**5)**.65
    if design=='leaf': taper *= .76+.34*math.sin(math.pi*t)
    if design=='thorn': taper *= 1+.16*math.sin(t*math.pi*5)**2
    if design=='fang': taper *= 1+.18*math.sin(t*math.pi*4)**4
    if design=='sun': taper *= .86+.18*math.sin(t*math.pi*3)
    return max(.004,width*taper)

def make_sword(spec):
    ident,name,tier,theme,length,width,curve,sweep_size,design=spec
    collection=bpy.data.collections.new(ident); scene.collection.children.link(collection)
    old=set(bpy.data.objects)
    steel,gold,leather,energy=[materials[theme,i] for i in range(4)]
    # Six bevel faces per cross-section: thin cutting edges, broad polished flats,
    # raised central ridge. Closely spaced tip sections preserve a sharp silhouette.
    verts=[]; faces=[]; count=35
    ring=[(-1,0),(-.77,-.065),(0,-.105),(.77,-.065),(1,0),(.77,.065),(0,.105),(-.77,.065)]
    for i in range(count):
        t=i/(count-1); x,z=blade_center(t,length,curve); w=blade_width(t,width,design)
        for rx,ry in ring: verts.append((x+rx*w,ry*(.5+.5*(1-t)),z))
    for i in range(count-1):
        for j in range(8): faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
    faces.extend([tuple(reversed(range(8))),tuple((count-1)*8+j for j in range(8))])
    mesh(name+' blade',verts,faces,steel)
    # Raised fuller inlay follows the actual blade curvature on both sides.
    for side in (-1,1):
        points=[]; radii=[]
        for i in range(27):
            t=.08+.77*i/26; x,z=blade_center(t,length,curve)
            points.append((x,side*.112*(.5+.5*(1-t)),z))
            radii.append((.012 if tier=='Common' else .024)*math.sin(math.pi*(i+1)/28)**.4)
        sweep('Curved fuller inlay',points,radii,gold if tier=='Common' else energy,6)
    # Sculpted curved wings: no cuboid crossguard.
    for side in (-1,1):
        points=[]; radii=[]
        for i in range(21):
            t=i/20
            x=side*(.12+(sweep_size+.20)*t)
            z=.65 + (.30 if design in ('crown','royal','sun') else -.22)*math.sin(t*math.pi*.85)
            if design in ('fang','thorn'): z=.65+.52*t*t-.22*math.sin(math.pi*t)
            points.append((x,0,z)); radii.append(.12*(1-t)**.55+.012)
        sweep('Swept guard wing',points,radii,gold,12)
        # Accent rail above the guard, separated by a sculpted dark channel.
        if tier!='Common':
            sweep('Guard edge inset',[(x,y-.085,z+.017) for x,y,z in points[:-2]],
                  [r*.24 for r in radii[:-2]],energy,6)
    # Tapered grip with actual helical binding rather than a painted flat texture.
    points=[(0,0,-.57+i*1.15/16) for i in range(17)]
    sweep('Tapered leather grip',points,[.097+.021*math.sin(math.pi*i/16) for i in range(17)],leather,12)
    wrap=[]
    for i in range(241):
        t=i/240; a=t*math.pi*2*9; r=.10+.022*math.sin(math.pi*t)
        wrap.append((r*math.cos(a),r*math.sin(a),-.52+t*1.00))
    sweep('Helical grip binding',wrap,[.014]*len(wrap),gold if theme=='royal' else steel,5)
    for z in (-.57,.56):
        sweep('Grip collar',[(0,0,z-.035),(0,0,z+.035)],[.135,.135],gold,16)
    jewel('Faceted pommel',(0,0,-.77),.21,gold,1.35)
    jewel('Pommel inset',(0,-.13,-.77),.095,energy,1.30)
    jewel('Guard socket',(0,-.035,.68),.235,gold,1.45)
    jewel('Guard gemstone',(0,-.17,.68),.135,energy,1.45)
    if tier!='Common':
        # Bilateral crown tines / fangs add readable silhouette at normal game scale.
        for side in (-1,1):
            points=[(side*.13,0,.70),(side*.31,0,.95),(side*.37,0,1.20),(side*.29,0,1.40)]
            sweep('Crown blade prong',points,[.105,.085,.047,.004],gold,8)
        for side in (-1,1):
            for k in range(2 if tier=='Epic' else 3):
                t=.18+k*.13; x,z=blade_center(t,length,curve); w=blade_width(t,width,design)
                # Beveled relief motifs sit on the broad flats, not floating off blade.
                y=side*.095*(.5+.5*(1-t))
                motif=mesh('Etched heraldic chevron',[(x-w*.58,y,z+.11),(x,y-side*.024,z-.02),
                    (x+w*.58,y,z+.11),(x,y-side*.024,z+.045)],[(0,1,3),(1,2,3)],gold)
                solid=motif.modifiers.new('Inset thickness','SOLIDIFY'); solid.thickness=.009
    if design in ('fang','thorn','ash'):
        # Hooked extensions emerge from the lower cutting edge.
        for k in range(1 if tier=='Common' else 3):
            t=.15+k*.12; x,z=blade_center(t,length,curve); w=blade_width(t,width,design)
            sweep('Hooked edge spur',[(x-w*.8,0,z),(x-w-.18,0,z+.12),(x-w-.25,0,z+.38)],
                  [.075,.06,.004],steel,6)
    if design=='royal':
        # Distinct original heraldry and split crown; not a replica of Excalibur.
        for side in (-1,1):
            sweep('Royal shield outline',[(side*.08,-.12,.45),(side*.24,-.10,.73),
                (side*.16,-.10,1.03),(0,-.12,1.16)],[.029]*4,gold,8)
        jewel('Royal sapphire',(0,-.155,.83),.11,energy,1.9)
        for side in (-1,1):
            sweep('Royal wing crest',[(side*.25,.02,.77),(side*.52,.02,1.01),
                (side*.73,.02,1.02),(side*.91,.02,.90)], [.08,.105,.065,.006],gold,10)
            jewel('Wing sapphire',(side*.51,-.075,.96),.085,energy,1.1)
    if tier=='Mythic':
        for side in (-1,1):
            for k in range(3):
                x=side*(.29+k*.21)
                sweep('Sovereign ice crown',[(x,0,.78),(x+side*.10,0,1.12+k*.06),
                    (x+side*.035,0,1.44+k*.11)], [.085,.056,.003],steel,8)
                jewel('Crown frost crystal',(x,-.08,1.05),.065,energy,1.7)
    objects=list(set(bpy.data.objects)-old)
    for o in objects:
        for col in list(o.users_collection): col.objects.unlink(o)
        collection.objects.link(o)
    return collection

collections=[make_sword(spec) for spec in DESIGNS]

def converted_meshes(collection,spec):
    groups={i:{'v':[],'n':[],'f':[]} for i in range(4)}
    deps=bpy.context.evaluated_depsgraph_get()
    for obj in collection.objects:
        evaluated=obj.evaluated_get(deps); data=evaluated.to_mesh(); data.calc_loop_triangles()
        group=int(obj.data.materials[0].name.rsplit('_',1)[1]); target=groups[group]
        # Flatten per-corner normals; crease highlights survive Roblox import.
        for tri in data.loop_triangles:
            ids=[]
            for loop_index in tri.loops:
                loop=data.loops[loop_index]; v=obj.matrix_world@data.vertices[loop.vertex_index].co
                n=(obj.matrix_world.to_3x3()@data.corner_normals[loop_index].vector).normalized()
                target['v'].append([round(v.x,5),round(v.z,5),round(-v.y,5)])
                target['n'].append([round(n.x,5),round(n.z,5),round(-n.y,5)])
                ids.append(len(target['v']))
            target['f'].append(ids)
        evaluated.to_mesh_clear()
    payload=[]
    for i,data in groups.items():
        if not data['f']: continue
        # Deduplicate equal position+normal pairs; preserves sharp seams.
        vertices=[]; normals=[]; remap={}; table={}
        for j,(v,n) in enumerate(zip(data['v'],data['n']),1):
            key=tuple(v+n)
            if key not in table:
                table[key]=len(vertices)+1; vertices.append(v); normals.append(n)
            remap[j]=table[key]
        payload.append({'name':['ForgedSteel','GuardMetal','Grip','Inlays'][i],
            'color':list(PALETTES[spec[3]][i]),'material':'Neon' if i==3 else ('Metal' if i<2 else 'SmoothPlastic'),
            'vertices':vertices,'normals':normals,'triangles':[[remap[j] for j in face] for face in data['f']]})
    return payload

manifest=[]
for col,spec in zip(collections,DESIGNS):
    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(spec[0]+'.glb')),use_selection=True,
                              export_format='GLB',export_apply=True)
    groups=converted_meshes(col,spec)
    payload={'id':spec[0],'name':spec[1],'tier':spec[2],'parts':groups}
    (OUT/(spec[0]+'.mesh.json')).write_text(json.dumps(payload,separators=(',',':')))
    manifest.append({'id':spec[0],'name':spec[1],'tier':spec[2],
        'triangles':sum(len(g['triangles']) for g in groups),'parts':len(groups),
        'boundsHeight':round(spec[4]+1.84,2),'exclusive':spec[2]=='Exclusive'})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

# Gallery staging is separate from the export coordinates.
for index,(col,spec) in enumerate(zip(collections,DESIGNS)):
    x=(index%6-2.5)*2.9; z=7.6 if index<6 else 0
    for obj in col.objects: obj.location += Vector((x,0,z))
    # Typography is presentation only and never exported with the weapons.
    for text,zoff,size,color in [(spec[2].upper(),-.98,.20,(.89,.69,.28,1)),
                                (spec[1],-1.35,.19,(.85,.90,.98,1))]:
        curve=bpy.data.curves.new('Gallery label','FONT'); curve.body=text
        curve.align_x='CENTER'; curve.size=size; curve.extrude=0
        obj=bpy.data.objects.new('Label '+spec[0],curve); scene.collection.objects.link(obj)
        obj.location=(x,-.35,z+zoff); obj.rotation_euler=(math.pi/2,0,0)
        mat=bpy.data.materials.get('Type '+str(color))
        if mat is None:
            mat=bpy.data.materials.new('Type '+str(color)); mat.diffuse_color=color; mat.use_nodes=True
            p=mat.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=color
            p.inputs['Emission Color'].default_value=color; p.inputs['Emission Strength'].default_value=.8
        obj.data.materials.append(mat)

def light(name,location,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=location
    obj.rotation_euler=(Vector((0,0,6))-obj.location).to_track_quat('-Z','Y').to_euler()
light('Cool key',(-7,-8,16),2400,10,(.68,.82,1))
light('Warm fill',(8,-5,8),1900,8,(1,.78,.52))
light('Broad frontal polish',(0,-10,4),1700,9,(.76,.87,1))
light('Rim',(0,3,12),2600,8,(.32,.55,1))
camera_data=bpy.data.cameras.new('Sword gallery camera'); camera=bpy.data.objects.new('Sword gallery camera',camera_data)
scene.collection.objects.link(camera); camera.location=(0,-30,7.25)
camera.rotation_euler=(Vector((0,0,6.7))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.location=(0,-30,6.15)
camera.rotation_euler=(Vector((0,0,5.60))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'; camera_data.ortho_scale=18.8; scene.camera=camera
scene.render.resolution_x=2400; scene.render.resolution_y=2000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.render.filepath=str(PREVIEW/'sword-gallery.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'SwordCollection.blend'))
bpy.ops.render.render(write_still=True)
print('SWORD_BUILD_COMPLETE '+json.dumps(manifest))
