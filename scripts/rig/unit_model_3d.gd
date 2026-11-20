extends Node3D
## Original hard-surface fleet and hostile models. Moving assemblies remain separate.
const GEO = preload("res://scripts/rig/mech_geometry.gd")
var legs: Array[Node3D] = []
var cannon: Node3D
var tracks: Node3D
var core: MeshInstance3D
var kind: String
var metal: Material
var armor: Material
var trim: Material
var light: Material

func part(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); mesh.mesh = GEO.plate(dimensions,0.10)
	mesh.material_override = material; mesh.position = at; parent.add_child(mesh)
	return mesh

func joint(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new(); node.position = at; parent.add_child(node); return node

func build(type: String, variant: int, elite: bool) -> void:
	kind = type
	metal = GEO.material(Color("202b3a"),0.85)
	armor = GEO.material(Color("b69a59") if elite else Color("c5534d") if type=="guard" else Color("aaaec0") if type=="rusher" else Color("627d91"),0.65)
	trim = GEO.material(Color("e1d9c3"),0.6)
	light = GEO.material(Color("ffb54d") if elite else Color("ff614c"),0.1,true)
	if type=="carrier": build_carrier()
	elif type=="boss": build_boss(variant)
	elif type=="drone": build_drone()
	else: build_soldier(type)
	# Each assembly is merged by material, keeping draw calls bounded.
	for leg in legs: batch_assembly(leg)
	if cannon!=null: batch_assembly(cannon)
	if tracks!=null: batch_assembly(tracks)
	GEO.batch(self)

func batch_assembly(node: Node3D) -> void:
	node.set_meta("dynamic_mesh",false); GEO.batch(node); node.set_meta("dynamic_mesh",true)

func build_carrier() -> void:
	armor = GEO.material(Color("aebac8"),0.8)
	trim = GEO.material(Color("a42d44"),0.6)
	light = GEO.material(Color("70e5ff"),0.1,true)
	part(self,Vector3(0,0.65,0),Vector3(6.6,0.65,1.5),metal)
	part(self,Vector3(0.15,0.98,0),Vector3(5.9,0.45,1.65),armor)
	# Tapered prow and layered flight deck.
	var prow := part(self,Vector3(2.9,0.82,0),Vector3(1.5,0.55,1.15),armor); prow.rotation.z = -0.14
	part(self,Vector3(0.2,1.24,0),Vector3(4.3,0.10,0.76),metal)
	part(self,Vector3(0.3,1.31,0),Vector3(4.0,0.04,0.09),trim)
	part(self,Vector3(-1.15,1.48,0),Vector3(1.25,0.68,0.8),armor)
	part(self,Vector3(-0.98,1.85,0),Vector3(1.0,0.18,1.0),metal)
	part(self,Vector3(-0.91,1.86,0.51),Vector3(0.72,0.10,0.035),light)
	part(self,Vector3(-1.25,2.15,0),Vector3(0.10,0.65,0.12),metal)
	part(self,Vector3(-1.25,2.4,0),Vector3(0.65,0.09,0.12),trim)
	for side in [-1,1]:
		part(self,Vector3(-0.8,0.7,side*1.10),Vector3(4.1,0.58,0.55),armor)
		part(self,Vector3(-1.0,1.02,side*1.1),Vector3(3.3,0.10,0.21),trim)
		part(self,Vector3(-2.95,0.69,side*1.1),Vector3(0.08,0.27,0.32),light)
		for x in [-1.5,0.0,1.5]:
			part(self,Vector3(x,1.08,side*0.72),Vector3(0.46,0.30,0.42),metal)
			part(self,Vector3(x+0.32,1.15,side*0.72),Vector3(0.66,0.10,0.13),armor)
		for x in [-2.0,-1.6,-1.2,-0.8]: part(self,Vector3(x,0.68,side*1.39),Vector3(0.18,0.24,0.035),metal)
	rotation.y = -0.22

func build_soldier(role: String) -> void:
	var heavy := role=="cannon"
	if heavy:
		tracks = joint(self,Vector3.ZERO); tracks.set_meta("dynamic_mesh",true)
		for side in [-1,1]:
			part(tracks,Vector3(side*0.65,0.35,0),Vector3(0.45,0.6,1.75),metal)
			for z in [-0.6,-0.2,0.2,0.6]: part(tracks,Vector3(side*0.88,0.35,z),Vector3(0.06,0.3,0.25),trim)
	else:
		for side in [-1,1]:
			var leg := joint(self,Vector3(side*0.37,1.05,0)); leg.set_meta("dynamic_mesh",true); legs.append(leg)
			part(leg,Vector3(0,-0.27,0),Vector3(0.38,0.56,0.42),metal)
			part(leg,Vector3(0,-0.64,0),Vector3(0.44,0.48,0.5),armor)
			part(leg,Vector3(0,-0.9,-0.14),Vector3(0.46,0.18,0.7),metal)
	part(self,Vector3(0,1.25,0),Vector3(0.85,0.42,0.65),metal)
	part(self,Vector3(0,1.72,0),Vector3(1.28 if heavy else 1.05,0.72,0.75),armor)
	part(self,Vector3(0,1.77,-0.41),Vector3(0.43,0.27,0.08),metal)
	part(self,Vector3(0,2.3,0),Vector3(0.57,0.48,0.57),trim)
	part(self,Vector3(0,2.32,-0.3),Vector3(0.42,0.10,0.04),light)
	for side in [-1,1]:
		part(self,Vector3(side*0.72,1.92,0),Vector3(0.46,0.43,0.65),armor)
		part(self,Vector3(side*0.74,1.42,-0.13),Vector3(0.30,0.65,0.36),metal)
	cannon = joint(self,Vector3(0.72,1.36,-0.22)); cannon.set_meta("dynamic_mesh",true)
	part(cannon,Vector3(0,0,-0.40),Vector3(0.33,0.36,0.95),armor)
	part(cannon,Vector3(0,0,-1.05),Vector3(0.15,0.16,0.65),metal)
	part(cannon,Vector3(0,0,-1.39),Vector3(0.16,0.15,0.04),light)
	if heavy:
		part(self,Vector3(-0.65,2.06,-0.55),Vector3(0.40,0.45,1.6),metal)
	elif role=="rusher":
		var blade := part(self,Vector3(-0.78,1.18,-0.85),Vector3(0.08,0.30,1.45),trim); blade.rotation.x = -0.25
		part(self,Vector3(0,1.75,0.55),Vector3(0.8,0.68,0.38),metal)
	else: part(self,Vector3(-0.83,1.32,-0.38),Vector3(0.65,0.9,0.2),armor)

func build_drone() -> void:
	part(self,Vector3(0,1.0,0),Vector3(0.85,0.48,0.85),armor)
	part(self,Vector3(0,1.02,-0.45),Vector3(0.42,0.15,0.06),light)
	for side in [-1,1]:
		part(self,Vector3(side*0.72,1.1,0),Vector3(0.78,0.14,0.52),metal)
		part(self,Vector3(side*1.03,1.0,0),Vector3(0.25,0.37,0.58),trim)
		part(self,Vector3(side*1.03,0.79,0),Vector3(0.18,0.06,0.4),light)
	part(self,Vector3(0,0.72,-0.5),Vector3(0.19,0.18,0.65),metal)

func build_boss(region: int) -> void:
	armor = GEO.material([Color("b47e46"),Color("76b4c4"),Color("c5ad75"),Color("8076ac")][clampi(region,0,3)],0.75)
	light = GEO.material(Color("ff9d44") if region==0 else Color("7ff6ff") if region==1 else Color("ff584b") if region==2 else Color("cf91ff"),0.1,true)
	tracks = joint(self,Vector3.ZERO); tracks.set_meta("dynamic_mesh",true)
	for side in [-1,1]:
		part(tracks,Vector3(side*1.35,0.45,0),Vector3(0.8,0.85,3.1),metal)
		part(tracks,Vector3(side*1.35,0.89,0),Vector3(0.83,0.16,2.7),armor)
		for z in [-1.1,-0.55,0.0,0.55,1.1]: part(tracks,Vector3(side*1.77,0.45,z),Vector3(0.06,0.48,0.35),trim)
	part(self,Vector3(0,1.1,0),Vector3(2.5,1.0,2.1),armor)
	part(self,Vector3(0,1.65,0.25),Vector3(1.65,0.42,1.25),metal)
	part(self,Vector3(0,1.65,-0.65),Vector3(1.15,0.7,0.45),trim)
	core = part(self,Vector3(0,1.65,-0.89),Vector3(0.63,0.34,0.08),light); core.set_meta("dynamic_mesh",true)
	cannon = joint(self,Vector3(0,1.95,0.3)); cannon.set_meta("dynamic_mesh",true)
	for side in [-1,1]:
		part(cannon,Vector3(side*0.96,0.15,-0.2),Vector3(0.7,0.65,1.15),armor)
		part(cannon,Vector3(side*0.96,0.15,-1.18),Vector3(0.28,0.26,1.2),metal)
		part(cannon,Vector3(side*0.96,0.15,-1.8),Vector3(0.29,0.27,0.08),light)
	if region==1:
		for side in [-1,1]:
			for z in [0.2,0.65,1.1]: part(self,Vector3(side*1.1,1.6,z),Vector3(0.12,1.2,0.18),light)
	elif region==2:
		for side in [-1,1]:
			var fin := part(self,Vector3(side*1.65,1.18,0.5),Vector3(0.14,1.6,1.2),armor); fin.rotation.z = side*0.6
	elif region==3:
		for side in [-1,1]:
			part(self,Vector3(side*1.8,1.4,-0.4),Vector3(0.35,0.4,1.8),trim)
			part(self,Vector3(side*1.8,1.4,-1.4),Vector3(0.48,0.68,0.32),metal)
	else:
		part(self,Vector3(0,0.85,-1.4),Vector3(1.8,0.45,0.55),metal)
		for x in [-0.65,-0.22,0.22,0.65]: part(self,Vector3(x,0.78,-1.72),Vector3(0.25,0.38,0.3),trim)

func animate(direction: Vector2, moving: bool, elapsed: float, state: Dictionary) -> void:
	if kind!="carrier" and direction.length_squared()>0.01:
		rotation.y = preload("res://scripts/rig/mech_projection.gd").heading(direction)
	for i in range(legs.size()): legs[i].rotation.x = sin(elapsed*7+i*PI)*0.36 if moving else 0.0
	if kind=="drone": position.y = sin(elapsed*2.6)*0.10
	if kind=="boss":
		tracks.visible = float(state.get("tracks",1))>0
		cannon.visible = float(state.get("cannon",1))>0
		cannon.rotation.y = sin(elapsed*0.5)*0.08
		core.scale = Vector3.ONE*(1.15+sin(elapsed*7)*0.12 if int(state.get("phase",1))==3 else 1.0)
