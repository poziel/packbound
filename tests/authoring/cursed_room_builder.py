"""Deterministic native 3D scene candidate; never overwrites production art."""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests/output/cursed-depths"
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(17031)
resources, nodes, meshes, names = [], [], {}, {}

def vec(values):
    return "Vector3(%s)" % ", ".join(f"{x:.6f}" for x in values)

def node(name, parent=".", kind="Node3D", extra="", instance=None):
    key = (parent, name)
    names[key] = names.get(key, 0) + 1
    if names[key] > 1:
        name += str(names[key])
    heading = f'[node name="{name}" parent="{parent}"'
    heading += f' instance=ExtResource("{instance}")]' if instance else f' type="{kind}"]'
    nodes.append(heading + "\n" + extra)
    return name if parent == "." else parent + "/" + name

def material(name, color):
    c = tuple(int(color[i:i+2], 16) / 255 for i in (0, 2, 4))
    resources.append(f'[sub_resource type="StandardMaterial3D" id="{name}"]\nalbedo_color = Color({c[0]:.5f}, {c[1]:.5f}, {c[2]:.5f}, 1)\nroughness = 1.0\n')

for index, color in enumerate(["34303f", "40394b", "302d39", "494151", "3b3745", "514857"]):
    material(f"stone{index}", color)
for name, color in (("mortar","18151f"),("edge","5c506a"),("iron","24212c"),("rubble","494150"),("abyss","08050d")):
    material(name, color)
for name, color in (("curse", "0.36,0.11,0.58,1"),("rune","0.48,0.24,0.68,1")):
    resources.append(f'[sub_resource type="ShaderMaterial" id="{name}"]\nshader = ExtResource("curse_shader")\nshader_parameter/curse_color = Color({color})\n')
resources.append('[sub_resource type="ShaderMaterial" id="dust"]\nshader = ExtResource("dust_shader")\n')

def box(name, pos, size, mat, parent=".", rotation=None, basis=None):
    size = tuple(round(x, 5) for x in size)
    if size not in meshes:
        identifier = "mesh" + str(len(meshes))
        meshes[size] = identifier
        resources.append(f'[sub_resource type="BoxMesh" id="{identifier}"]\nsize = {vec(size)}\n')
    extra = f'position = {vec(pos)}\n'
    if basis is not None:
        extra = 'transform = Transform3D(%s)\n' % ', '.join(f'{x:.6f}' for x in (*basis, *pos))
    elif rotation:
        extra += f'rotation = {vec(rotation)}\n'
    extra += f'mesh = SubResource("{meshes[size]}")\nmaterial_override = SubResource("{mat}")\n'
    if mat in ("curse", "rune", "dust"):
        extra += 'cast_shadow = 0\n'
    return node(name, parent, "MeshInstance3D", extra)

def beam(name, a, b, width, mat, parent):
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(x*x for x in d))
    y = [x / length for x in d]
    reference = (0, 0, 1) if abs(y[2]) < .9 else (1, 0, 0)
    def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    x = cross(y, reference)
    norm = math.sqrt(sum(v*v for v in x))
    x = [v / norm for v in x]
    z = cross(x, y)
    return box(name, [(a[i]+b[i])*.5 for i in range(3)], (width,length,width), mat,parent,basis=(*x,*y,*z))

floor = node("FracturedFloor")
box("Foundation", (-6.4,-.25,3), (12.8,.4,23), "mortar", floor)
for row in range(14):
    for col in range(8):
        x, z = -12+col*1.6, -7.2+row*1.6
        chipped = col in (0,7) and rng.random() < .35
        box("Slab", (x,-.025 if not chipped else -.12,z), (1.51 if not chipped else 1.14,.16,1.49), f"stone{rng.randrange(6)}", floor,
            (0,rng.uniform(-.02,.02),0) if chipped else None)
        if rng.random() < .22:
            box("Fracture", (x-.35,.06,z), (.035,.01,.55), "abyss",floor)
            box("FractureTurn", (x-.21,.06,z+.27), (.3,.01,.035), "abyss",floor)

walls = node("RuinedWalls")
for side in (-1,1):
    x = -6.4+side*6.15
    box("WallCore", (x,3.8,3), (.5,7.8,22.6), "mortar",walls)
    for row in range(7):
        for col in range(14):
            z = -7.25+col*1.55+(.7 if row%2 else 0)
            if rng.random() < .13: continue
            box("FacingStone", (x-side*.29,row*1.02+.51,z), (.18,.94,1.46), f"stone{rng.randrange(6)}",walls)
    for z in (-4.6,2.5,9.4):
        height = rng.choice((2.3,3.4,5.8))
        box("BrokenButtress", (x-side*.46,height*.5,z), (.66,height,.85), "stone3",walls)
        box("FracturedCapital", (x-side*.52,height+.13,z), (.95,.26,1.1), "edge",walls,(0,.06*side,.08*side))

far = node("ShatteredArch")
for row in range(8):
    for col in range(9):
        x = -12.4+col*1.5
        if abs(x+6.4) < 2.6 and row < 6: continue
        box("BackStone", (x,row*.92+.46,-8.2), (1.43,.86,.65), f"stone{rng.randrange(6)}",far)
for side in (-1,1):
    for row in range(5):
        box("Jamb", (-6.4+side*2.44,row*.92+.46,-7.83), (.7,.86,1.05), "stone3" if row%2 else "edge",far)
    for i,(x,y) in enumerate(((2.0,4.92),(1.43,5.48),(.72,5.78))):
        box("ArchVoussoir", (-6.4+side*x,y,-7.83), (.78,.78,1.02), "edge",far,(0,0,-side*(.15+i*.17)))
box("CrackedKeystone", (-6.4,5.92,-7.8), (.64,.9,1.05), "stone5",far,(0,0,.08))

vault = node("CollapsedVault")
for z in (-5.7,1.4,8.5):
    for side in (-1,1):
        for i in range(4):
            if z == 1.4 and side == 1 and i > 1: continue
            box("VaultRib", (-6.4+side*(5.65-i*1.15),6.7+i*.5,z), (1.5,.48,.55), "edge",vault,(0,0,-side*.38))
for side in (-1,1):
    for row in range(9):
        for col in range(2):
            if rng.random() < .23: continue
            box("RemainingVaultStone", (-6.4+side*(5.35-col*1.4),7.6+col*.35,-6.4+row*2.35), (1.45,.25,2.22), f"stone{rng.randrange(6)}",vault,(0,0,-side*.22))
box("DarkRoofCavity", (-6.4,10.5,3), (13,.4,24), "abyss",vault)

debris = node("FallenMasonry")
for side in (-1,1):
    for i in range(38):
        x,z = -6.4+side*rng.uniform(3.4,5.5),rng.uniform(-6.6,12)
        size = (rng.uniform(.22,.85),rng.uniform(.15,.6),rng.uniform(.25,.9))
        box("Rubble", (x,size[1]*.4,z), size, "rubble" if i%3 else "stone2",debris,(rng.uniform(-.3,.3),rng.uniform(-2,2),rng.uniform(-.3,.3)))
for side,z in ((-1,-2.8),(1,5.2)):
    for i in range(4):
        box("FallenPillarDrum", (-6.4+side*(4.0-i*.14),.45,z+i*.79), (1.05,.85,.72), "stone3",debris,(0,.13*side,.12*side))
    box("BrokenPillarBase", (-6.4+side*4.4,.2,z-.9), (1.4,.4,1.4), "edge",debris,(0,.12,0))

veins = node("WallCurses")
for side in (-1,1):
    x = -6.4+side*5.73
    for branch in range(5):
        a = (x,rng.uniform(.4,1.2),-5.5+branch*3.8+rng.uniform(-.4,.4))
        for segment in range(5):
            b = (x-side*.025,a[1]+rng.uniform(.45,.85),a[2]+rng.uniform(-.55,.55))
            beam("BlackFissure",a,b,.15,"abyss",veins)
            inner_a,inner_b = (a[0]-side*.065,a[1],a[2]),(b[0]-side*.065,b[1],b[2])
            beam("VioletSeep",inner_a,inner_b,.043 if segment%2 else .063,"curse",veins)
            if segment in (1,3):
                beam("Branch",inner_b,(b[0]-side*.065,b[1]+.3,b[2]+(.6 if branch%2 else -.65)),.035,"curse",veins)
            a = b

runes = node("BrokenSeals")
for side in (-1,1):
    x = -6.4+side*5.63
    for z,h in ((-2.8,3.1),(5.3,3.7)):
        points = [(h+.8,z),(h+.35,z+.6),(h-.5,z+.6),(h-.85,z),(h-.4,z-.6),(h+.4,z-.6)]
        for i in (0,1,3,4,5):
            a,b = points[i],points[(i+1)%len(points)]
            beam("SealSegment",(x,a[0],a[1]),(x,b[0],b[1]),.075,"rune",runes)
        beam("SealStaff",(x,h-.55,z),(x,h+.55,z),.07,"rune",runes)
        beam("SealBar",(x,h+.12,z-.3),(x,h+.12,z+.3),.07,"rune",runes)

altar = node("ShatteredWard")
for side in (-1,1):
    x = -6.4+side*3.3
    box("WardPlinth",(x,.3,-6.2),(1.15,.6,1.15),"stone2",altar)
    box("SplitWardStone",(x,1.35,-6.2),(.7,1.65,.64),"stone4",altar,(0,.12*side,.1*side))
    beam("WardScar",(x-.13,.72,-5.83),(x+.15,1.95,-5.83),.06,"rune",altar)
    for i in range(3): box("BrokenIronBand",(x,.9+i*.45,-5.82),(.81,.075,.08),"iron",altar)

lights = node("CurseLights")
for i,(x,y,z,energy,radius) in enumerate([(-10.8,3,-3,1.0,7),(-2,3,3,.85,7),(-6.4,4.6,-6.5,.8,8),(-10,2,9,.55,6)]):
    node(f"VioletLight{i+1}",lights,"OmniLight3D",f'position = {vec((x,y,z))}\nlight_color = Color(0.48,0.22,0.78,1)\nlight_energy = {energy}\nomni_range = {radius}\n')
node("MonsterFill",lights,"OmniLight3D",'position = Vector3(-6.4,4,2)\nlight_color = Color(0.68,0.48,0.9,1)\nlight_energy = 2.2\nlight_cull_mask = 2\nomni_range = 12.0\n')
for side in (-1,1):
    node("CursedBrazier",extra=f'position = {vec((-6.4+side*2.8,1.9,-6.8))}\nrotation = Vector3(0,0,{side*.12})\nhandle_length = 0.65\nhandle_color = Color(0.16,0.14,0.2,1)\ncollar_color = Color(0.33,0.27,0.39,1)\nflame_color = Color(0.43,0.18,0.7,1)\nflame_core_color = Color(0.78,0.61,0.93,1)\nflame_size = Vector3(0.22,0.4,0.18)\nlight_color = Color(0.55,0.29,0.82,1)\nlight_energy = 0.55\nlight_range = 5.0\n',instance="torch")

dust = node("DustMotes")
for i in range(45):
    s = rng.choice((.018,.025,.035))
    box("Mote",(rng.uniform(-11.4,-1.4),rng.uniform(.8,5.6),rng.uniform(-6.4,11)),(s,s,s),"dust",dust)
node("CameraStart",kind="Marker3D",extra='position = Vector3(-5.8607135,3,8)\nrotation = Vector3(-0.093477,0,0)\n')
slots = node("EnemySlots")
node("Slot1",slots,"Marker3D",'position = Vector3(-6.4,0.06,-2)\n')
node("EntryStairs",extra='position = Vector3(-5.8607135,0,10.8)\n',instance="entry")
node("ExitStairs",extra='position = Vector3(-6.4,0,-8)\n',instance="exit")

header = '''[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/gameplay/rooms/cursed_room.gd" id="room"]
[ext_resource type="Environment" path="res://scenes/gameplay/rooms/cursed/cursed_environment.tres" id="environment"]
[ext_resource type="PackedScene" path="res://scenes/gameplay/rooms/cursed/stairs/entrance_stairs.tscn" id="entry"]
[ext_resource type="PackedScene" path="res://scenes/gameplay/rooms/cursed/stairs/exit_stairs.tscn" id="exit"]
[ext_resource type="PackedScene" path="res://components/torch/torch.tscn" id="torch"]
[ext_resource type="Shader" path="res://scenes/gameplay/rooms/cursed/curse.gdshader" id="curse_shader"]
[ext_resource type="Shader" path="res://scenes/gameplay/rooms/cursed/dust.gdshader" id="dust_shader"]
'''
root = '[node name="CursedDepths" type="Node3D"]\nscript = ExtResource("room")\nenvironment = ExtResource("environment")\n'
(OUT/'cursed_room.tscn').write_text(header+'\n'+'\n'.join(resources)+'\n'+root+'\n'+'\n'.join(nodes),encoding='utf-8')
source = (ROOT/'components/staircase/stone_visuals.tscn').read_text(encoding='utf-8')
source = source.replace('Color(0.22, 0.26, 0.32, 1)','Color(0.19, 0.16, 0.24, 1)').replace('Color(0.32, 0.36, 0.41, 1)','Color(0.32, 0.27, 0.38, 1)')
(OUT/'stair_visuals.tscn').write_text(source,encoding='utf-8')
print(f'Cursed room candidate: {len(nodes)} saved nodes, {len(meshes)} shared mesh sizes')
