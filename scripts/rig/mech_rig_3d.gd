extends Node3D
## Rigid armor attached to a genuine Skeleton3D. Two-bone legs keep their soles planted.
const GEO = preload("res://scripts/rig/mech_geometry.gd")
const MELEE = preload("res://scripts/melee.gd")
const SHIELD_SHADER = preload("res://assets/models/armor_shield.gdshader")
const PROJECTION = preload("res://scripts/rig/mech_projection.gd")
const FORMS = preload("res://scripts/rig/chassis_forms.gd")
var skeleton := Skeleton3D.new()
var bones: Dictionary = {}
var attachments: Dictionary = {}
var materials: Dictionary = {}
var shield_material := ShaderMaterial.new()
var mounts: Dictionary = {}
var muzzles: Dictionary = {}
var weapon_keys: Dictionary = {}
var jets: Array[MeshInstance3D] = []
var tracks: Array[Node3D] = []
var leg_attachments: Array[Node3D] = []
var model: int = 0
var width: float = 1
var hip_height: float = 1.58
var UPPER_LEG: float = 0.78
var LOWER_LEG: float = 0.82
var UPPER_ARM: float = 0.48
var LOWER_ARM: float = 0.46
var stance_targets: Dictionary = {}
var track_bridge := Node3D.new()
var tread_pads: Array[MeshInstance3D] = []
var trails: Dictionary = {}
var trail_samples: Dictionary = {}
var equipment_mount: Node3D
var equipment_key: String = ""
var body_mesh: MeshInstance3D
var legs_mesh: MeshInstance3D
var arm_ready: Dictionary = {0:0.0,4:0.0}
var arm_hold: Dictionary = {0:-100.0,4:-100.0}
var pose_time: float = -1.0

func build(which: int) -> void:
	model = which; width = [1.0,0.83,1.20,0.78,1.12,1.48][model]
	if model==3:
		hip_height = 1.78; UPPER_LEG = 0.88; LOWER_LEG = 0.92; UPPER_ARM = 0.50; LOWER_ARM = 0.48
	elif model==5:
		hip_height = 1.35; UPPER_LEG = 0.68; LOWER_LEG = 0.70; UPPER_ARM = 0.46; LOWER_ARM = 0.43
	materials = {"armor":GEO.material([Color("af253b"),Color("51426f"),Color("385980"),Color("28745b"),Color("a97728"),Color("20515c")][model]),"dark":GEO.material(Color("202630"),0.72),"metal":GEO.material(Color("73808a"),0.88),"white":GEO.material([Color("dfded5"),Color("c6c7d7"),Color("e3e7e9"),Color("c1d8cb"),Color("e3d9b8"),Color("4f626d")][model],0.35),"light":GEO.material([Color("7bffff"),Color("ffc167"),Color("57d9ff"),Color("b9ff69"),Color("ffc85a"),Color("5effea")][model],0,true),"gold":GEO.material(Color("dfb747")),"fire":GEO.material(Color("61cfff"),0,true)}
	materials.laser = GEO.material(Color("ff5c72"),0,true)
	materials.plasma = GEO.material(Color("be78ff"),0,true)
	materials.blade = GEO.material(Color("ff79bc"),0,true)
	shield_material.shader = SHIELD_SHADER
	skeleton.name = "Skeleton3D"; add_child(skeleton)
	bone("pelvis","",Vector3(0,hip_height,0))
	bone("chest","pelvis",Vector3(0,0.50 if model in [3,5] else 0.58,0))
	bone("head","chest",Vector3(0,0.50 if model==3 else 0.44 if model==5 else 0.54 if model==4 else 0.58,0))
	for side in [-1,1]:
		var prefix := "left" if side<0 else "right"
		bone(prefix+"_hip","pelvis",Vector3(side*0.30*width,0,0))
		bone(prefix+"_knee",prefix+"_hip",Vector3(0,-UPPER_LEG,0))
		bone(prefix+"_ankle",prefix+"_knee",Vector3(0,-LOWER_LEG,0))
		bone(prefix+"_shoulder","chest",Vector3(side*0.66*width,0.14 if model in [3,4] else 0.24,0))
		bone(prefix+"_elbow",prefix+"_shoulder",Vector3(0,-UPPER_ARM,0))
		bone(prefix+"_wrist",prefix+"_elbow",Vector3(0,-LOWER_ARM,0))
	build_hull()
	for side in [-1,1]: build_limbs(side)
	add_child(track_bridge)
	part(track_bridge,Vector3(0.85,0.38,0.72),Vector3(0,0.58,0),"dark")
	skeleton.force_update_all_bone_transforms()
	sync_attachments()
	body_mesh = skin_armor(false)
	legs_mesh = skin_armor(true)
	for track in tracks: GEO.batch(track)
	GEO.batch(track_bridge)

func skin_armor(legs: bool) -> MeshInstance3D:
	var groups: Dictionary = {}; var originals: Array = []
	for id in attachments:
		var is_leg: bool = id.ends_with("_hip") or id.ends_with("_knee") or id.ends_with("_ankle")
		if is_leg!=legs: continue
		var nodes: Array = []; GEO.collect_meshes(attachments[id],nodes)
		for node in nodes:
			var material: Material = node.material_override
			if not groups.has(material): groups[material] = []
			groups[material].append({"node":node,"bone":int(bones[id])})
			originals.append(node)
	var mesh := ArrayMesh.new()
	for material in groups:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in groups[material]:
			var node: MeshInstance3D = item.node
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var transform_value: Transform3D = skeleton.global_transform.affine_inverse()*node.global_transform
			for i in range(indices.size() if not indices.is_empty() else vertices.size()):
				var index: int = indices[i] if not indices.is_empty() else i
				surface.set_bones(PackedInt32Array([item.bone,0,0,0])); surface.set_weights(PackedFloat32Array([1,0,0,0]))
				surface.set_normal((transform_value.basis*normals[index]).normalized()); surface.add_vertex(transform_value*vertices[index])
		surface.commit(mesh); mesh.surface_set_material(mesh.get_surface_count()-1,material)
	for node in originals:
		if is_instance_valid(node): node.free()
	var result := MeshInstance3D.new(); result.name = "LegArmor" if legs else "BodyArmor"
	result.mesh = mesh; add_child(result)
	result.skeleton = result.get_path_to(skeleton)
	result.skin = skeleton.create_skin_from_rest_transforms()
	return result

func bone(id: String, parent: String, rest: Vector3) -> void:
	var index := skeleton.add_bone(id); bones[id] = index
	if not parent.is_empty(): skeleton.set_bone_parent(index,bones[parent])
	skeleton.set_bone_rest(index,Transform3D(Basis.IDENTITY,rest))
	skeleton.set_bone_pose_position(index,rest)
	var attachment := BoneAttachment3D.new(); attachment.name = id+"_armor"
	attachment.bone_name = id; skeleton.add_child(attachment); attachments[id] = attachment

func part(parent: Node3D, size: Vector3, position_value: Vector3, color: String = "armor", rotation_value: Vector3 = Vector3.ZERO, shield: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); mesh.mesh = GEO.plate(size)
	mesh.material_override = materials[color]; mesh.position = position_value; mesh.rotation = rotation_value
	parent.add_child(mesh)
	if shield and color in ["armor","white"]:
		var edge := MeshInstance3D.new(); edge.mesh = mesh.mesh; edge.material_override = shield_material
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mesh.add_child(edge)
	return mesh

func cylinder(parent: Node3D, radius: float, length_value: float, position_value: Vector3, color: String, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := CylinderMesh.new(); shape.top_radius = radius; shape.bottom_radius = radius; shape.height = length_value; shape.radial_segments = 24; shape.rings = 1
	var mesh := MeshInstance3D.new(); mesh.mesh = shape; mesh.material_override = materials[color]; mesh.position = position_value; mesh.rotation = rotation_value; parent.add_child(mesh)
	return mesh

# Authored profiles: pointed plates, broad shoulder crowns and inset mechanical cores.
func panel(parent: Node3D, points: Array, size: Vector2, depth: float, position_value: Vector3, color: String = "armor", rotation_value: Vector3 = Vector3.ZERO, crown: float = 0.006) -> MeshInstance3D:
	var profile := PackedVector2Array()
	for point in points: profile.append(Vector2(point[0]*size.x,point[1]*size.y))
	var mesh := MeshInstance3D.new(); mesh.mesh = GEO.armor(profile,depth,crown)
	mesh.position = position_value; mesh.rotation = rotation_value; mesh.material_override = materials[color]; parent.add_child(mesh)
	if color in ["armor","white"]:
		var edge := MeshInstance3D.new(); edge.mesh = mesh.mesh; edge.material_override = shield_material
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mesh.add_child(edge)
	return mesh

func lancet(parent: Node3D, size: Vector3, at: Vector3, color: String = "armor", rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return panel(parent,[[-0.28,0.5],[0.28,0.5],[0.5,0.19],[0.30,-0.32],[0,-0.5],[-0.36,-0.26],[-0.5,0.20]],Vector2(size.x,size.y),size.z,at,color,rotation_value)

func ring(parent: Node3D, outer: float, inner: float, at: Vector3, color: String = "metal", rotation_value: Vector3 = Vector3.ZERO) -> void:
	var shape := TorusMesh.new(); shape.inner_radius = inner; shape.outer_radius = outer; shape.rings = 24; shape.ring_segments = 8
	var mesh := MeshInstance3D.new(); mesh.mesh = shape; mesh.position = at; mesh.rotation = rotation_value; mesh.material_override = materials[color]; parent.add_child(mesh)

func joint(parent: Node3D, radius: float, length_value: float, at: Vector3) -> void:
	cylinder(parent,radius,length_value,at,"dark",Vector3(0,0,PI/2))
	for side in [-1,1]:
		cylinder(parent,radius*0.80,0.035,at+Vector3(side*(length_value/2+0.01),0,0),"metal",Vector3(0,0,PI/2))
		cylinder(parent,radius*0.44,0.04,at+Vector3(side*(length_value/2+0.03),0,0),"dark",Vector3(0,0,PI/2))
		cylinder(parent,radius*0.18,0.045,at+Vector3(side*(length_value/2+0.05),0,0),"gold",Vector3(0,0,PI/2))

func vent(parent: Node3D, size: Vector2, at: Vector3, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mount := Node3D.new(); parent.add_child(mount); mount.position = at; mount.rotation = rotation_value
	part(mount,Vector3(size.x,size.y,0.045),Vector3.ZERO,"dark",Vector3.ZERO,false)
	for i in range(4):
		part(mount,Vector3(size.x*0.82,size.y*0.09,0.028),Vector3(0,(i-1.5)*size.y*0.21,-0.035),"gold",Vector3(-0.28,0,0),false)

func build_hull() -> void:
	if model>=3:
		FORMS.build_hull(self)
		return
	var pelvis: Node3D = attachments.pelvis; var chest: Node3D = attachments.chest
	var head := Node3D.new(); attachments.head.add_child(head)
	head.scale = Vector3(0.91,1.0,0.91) if model in [1,3] else Vector3.ONE
	# Narrow exposed waist, layered rib cage, and split skirt armor.
	part(pelvis,Vector3(0.48*width,0.26,0.35),Vector3.ZERO,"dark")
	for i in range(3):
		lancet(pelvis,Vector3(0.43*width-i*0.035,0.17,0.25),Vector3(0,0.13+i*0.115,-0.06),"metal")
	for side in [-1,1]:
		cylinder(pelvis,0.024,0.35,Vector3(side*0.24*width,0.25,-0.16),"metal",Vector3(0,0,side*-0.22))
		lancet(pelvis,Vector3(0.27*width,0.60,0.17),Vector3(side*0.32*width,-0.14,-0.24),"white",Vector3(-0.16,side*-0.16,side*-0.17))
		lancet(pelvis,Vector3(0.23*width,0.55,0.22),Vector3(side*0.48*width,-0.08,0.02),"white",Vector3(0,0,side*-0.25))
		lancet(pelvis,Vector3(0.12,0.32,0.035),Vector3(side*0.35*width,-0.11,-0.35),"armor",Vector3(0,0,side*-0.17))
	lancet(pelvis,Vector3(0.27,0.43,0.21),Vector3(0,-0.12,-0.25),"armor")
	lancet(pelvis,Vector3(0.14,0.18,0.04),Vector3(0,0.015,-0.38),"white")
	lancet(chest,Vector3(0.80*width,0.58,0.47),Vector3(0,0.01,0.01),"dark")
	for side in [-1,1]:
		var chest_profile: Array = [[-0.5,-0.25],[-0.35,0.20],[0.20,0.50],[0.5,0.28],[0.25,-0.30],[-0.25,-0.5]]
		for point in chest_profile: point[0] *= side
		panel(chest,chest_profile,Vector2(0.51*width,0.34),0.24,Vector3(side*0.26*width,0.19,-0.27),"armor",Vector3(0,side*-0.20,side*0.14))
		panel(chest,[[side*-0.5,-0.5],[side*-0.35,0.15],[side*0.5,0.5],[side*0.3,-0.12]],Vector2(0.39*width,0.12),0.025,Vector3(side*0.28*width,0.29,-0.42),"white",Vector3(0,side*-0.2,side*0.12),0)
		vent(chest,Vector2(0.19,0.12),Vector3(side*0.31*width,0.03,-0.405),Vector3(0,side*-0.20,side*0.12))
		lancet(chest,Vector3(0.20,0.34,0.14),Vector3(side*0.38*width,-0.13,-0.17),"armor",Vector3(0,0,side*-0.3))
	lancet(chest,Vector3(0.37,0.51,0.17),Vector3(0,-0.04,-0.30),"armor")
	panel(chest,[[-0.5,0.5],[0.5,0.5],[0.38,-0.32],[0,-0.5],[-0.38,-0.32]],Vector2(0.22,0.18),0.04,Vector3(0,0.025,-0.425),"white")
	part(chest,Vector3(0.11,0.035,0.025),Vector3(0,0.08,-0.46),"dark",Vector3.ZERO,false)
	# Neck and compact helmet: inset visor, sloped brow, separate cheek guards.
	for side in [-1,1]:
		lancet(chest,Vector3(0.14,0.22,0.19),Vector3(side*0.17,0.34,-0.015),"armor",Vector3(0,0,side*-0.35))
	cylinder(chest,0.10,0.18,Vector3(0,0.43,0),"metal")
	# Mobile-suit helmet: white shell, separate eyes, face vents and forehead V-fin.
	lancet(head,Vector3(0.30,0.32,0.29),Vector3(0,0.01,0),"dark")
	panel(head,[[-0.5,-0.15],[-0.44,0.30],[-0.20,0.5],[0.20,0.5],[0.44,0.30],[0.5,-0.15],[0,-0.5]],Vector2(0.35,0.26),0.30,Vector3(0,0.09,-0.025),"white")
	part(head,Vector3(0.27,0.065,0.026),Vector3(0,0.025,-0.192),"dark",Vector3.ZERO,false)
	for side in [-1,1]:
		panel(head,[[-0.5,0.3],[0.5,0.3],[0.3,-0.5],[-0.3,-0.5]],Vector2(0.105,0.032),0.014,Vector3(side*0.070,0.025,-0.213),"light",Vector3(0,0,side*0.25),0)
		lancet(head,Vector3(0.10,0.25,0.15),Vector3(side*0.15,-0.045,-0.07),"white",Vector3(0,side*0.18,side*-0.12))
		part(head,Vector3(0.032,0.085,0.025),Vector3(side*0.17,-0.035,-0.15),"dark",Vector3.ZERO,false)
		panel(head,[[side*-0.5,-0.5],[side*-0.43,-0.22],[side*0.5,0.5],[side*0.32,0.06]],Vector2(0.40,0.30),0.025,Vector3(side*0.22,0.27,-0.225),"gold",Vector3.ZERO,0)
		# A shorter rear pair distinguishes the high-mobility model.
		if model in [1,3]:
			panel(head,[[side*-0.5,-0.5],[side*0.5,0.5],[side*0.05,-0.5]],Vector2(0.17,0.32),0.025,Vector3(side*0.19,0.25,-0.08),"white",Vector3.ZERO,0)
	lancet(head,Vector3(0.12,0.14,0.045),Vector3(0,-0.06,-0.20),"white")
	for x in [-0.027,0.027]: part(head,Vector3(0.012,0.045,0.012),Vector3(x,-0.070,-0.23),"dark",Vector3.ZERO,false)
	lancet(head,Vector3(0.070,0.085,0.05),Vector3(0,-0.14,-0.19),"armor")
	lancet(head,Vector3(0.10,0.16,0.065),Vector3(0,0.14,-0.215),"armor")
	part(head,Vector3(0.042,0.035,0.018),Vector3(0,0.18,-0.256),"light",Vector3.ZERO,false)

	# Distinct angular flight packs, with slim saber hilts behind the shoulders.
	for side in [-1,1]:
		lancet(chest,Vector3(0.27,0.67,0.28),Vector3(side*0.30,-0.01,0.40),"dark")
		lancet(chest,Vector3(0.25,0.44,0.15),Vector3(side*0.30,0.10,0.57),"armor")
		cylinder(chest,0.12,0.16,Vector3(side*0.30,-0.31,0.43),"metal")
		var jet := cylinder(chest,0.065,0.35,Vector3(side*0.30,-0.55,0.43),"fire"); jet.set_meta("dynamic_mesh",true); jets.append(jet)
	build_role_pack(chest,pelvis)

func build_role_pack(chest: Node3D, pelvis: Node3D) -> void:
	for side in [-1,1]:
		if model==0:
			# Armored heat exchangers and deployed radiator blades frame the rifle.
			lancet(chest,Vector3(0.30,0.98,0.38),Vector3(side*0.40,0.24,0.51),"dark",Vector3(0.12,0,side*-0.16))
			lancet(chest,Vector3(0.27,0.76,0.12),Vector3(side*0.43,0.28,0.30),"armor",Vector3(0.12,0,side*-0.16))
			for i in range(3):
				panel(chest,[[side*-0.5,-0.5],[side*0.5,-0.16],[side*0.35,0.5],[side*-0.25,0.30]],Vector2(0.15,1.06-i*0.13),0.10,Vector3(side*(0.58+i*0.14),0.25-i*0.10,0.59+i*0.07),"white" if i==0 else "armor",Vector3(0.15,side*0.1,side*-0.37))
			for i in range(4): part(chest,Vector3(0.16,0.035,0.035),Vector3(side*0.43,0.34-i*0.10,0.225),"metal",Vector3.ZERO,false)
			lancet(pelvis,Vector3(0.21,0.52,0.15),Vector3(side*0.46,-0.10,0.24),"armor",Vector3(0.20,0,side*-0.22))
		elif model==1:
			# Long swept wings make a four-blade silhouette, with open space between them.
			for layer in range(2):
				var angle: float = side*(-0.53 if layer==0 else 0.64)
				var at := Vector3(side*(0.64 if layer==0 else 0.73),0.26 if layer==0 else -0.24,0.55+layer*0.12)
				var shape: Array = [[-0.42,-0.50],[0.46,-0.32],[0.32,0.50],[-0.32,0.27]]
				panel(chest,shape,Vector2(0.30,1.60 if layer==0 else 1.30),0.15,at,"dark",Vector3(0.20,0,angle))
				panel(chest,shape,Vector2(0.24,1.48 if layer==0 else 1.19),0.055,at-Vector3(0,0,0.105),"armor",Vector3(0.20,0,angle))
				lancet(chest,Vector3(0.048,1.10 if layer==0 else 0.85,0.025),at-Vector3(side*0.025,0,0.14),"white",Vector3(0.20,0,angle))
			lancet(pelvis,Vector3(0.16,0.66,0.12),Vector3(side*0.43,-0.17,0.17),"white",Vector3(0.14,0,side*-0.26))
		elif model==2:
			# Layered armored mantle, not a cloth cape or an unequipped weapon.
			lancet(chest,Vector3(0.38,0.90,0.32),Vector3(side*0.43,0.20,0.51),"dark",Vector3(0.12,0,side*-0.20))
			lancet(chest,Vector3(0.32,0.77,0.07),Vector3(side*0.43,0.24,0.29),"white",Vector3(0.12,0,side*-0.20))
			lancet(chest,Vector3(0.11,0.48,0.025),Vector3(side*0.43,0.25,0.23),"armor",Vector3(0.12,0,side*-0.20))
			for layer in range(2):
				var at := Vector3(side*(0.53+layer*0.22),-0.24-layer*0.06,0.58+layer*0.10)
				var angle: float = side*(0.30+layer*0.16)
				lancet(chest,Vector3(0.46,1.26-layer*0.12,0.20),at,"gold",Vector3(0.12,0,angle))
				lancet(chest,Vector3(0.40,1.17-layer*0.12,0.055),at-Vector3(0,0,0.14),"white",Vector3(0.12,0,angle))
				lancet(chest,Vector3(0.15,0.76,0.025),at-Vector3(0,0.04,0.18),"armor",Vector3(0.12,0,angle))
			lancet(pelvis,Vector3(0.33,0.65,0.18),Vector3(side*0.45,-0.20,0.13),"white",Vector3(0,0,side*-0.16))
			lancet(chest,Vector3(0.17,0.28,0.18),Vector3(side*0.22,0.42,0.13),"white",Vector3(0,0,side*-0.20))

		elif model==3:
			# Vector-drive skirmisher: compact swept booms and paired angled jets.
			panel(chest,[[-0.45,-0.5],[0.5,-0.22],[0.33,0.5],[-0.38,0.25]],Vector2(0.25,0.95),0.22,Vector3(side*0.48,0.03,0.50),"armor",Vector3(0.40,0,side*-0.48))
			lancet(chest,Vector3(0.12,0.70,0.06),Vector3(side*0.57,0.02,0.38),"white",Vector3(0.40,0,side*-0.48))
			for j in range(2):
				var thruster := Node3D.new(); chest.add_child(thruster); thruster.position = Vector3(side*(0.32+j*0.20),-0.26,0.56); thruster.rotation = Vector3(0.30,0,side*-0.24)
				cylinder(thruster,0.12,0.29,Vector3.ZERO,"dark")
				ring(thruster,0.12,0.085,Vector3(0,-0.17,0),"metal")
				cylinder(thruster,0.070,0.035,Vector3(0,-0.18,0),"light")
			lancet(pelvis,Vector3(0.16,0.52,0.17),Vector3(side*0.44,-0.13,0.18),"armor",Vector3(0.40,0,side*-0.20))
		elif model==4:
			# Artillery support chassis: tall stabilizers and broad radiator screens.
			panel(chest,[[-0.5,-0.5],[0.5,-0.5],[0.5,0.32],[0.2,0.5],[-0.5,0.5]],Vector2(0.28,1.20),0.22,Vector3(side*0.37,0.28,0.57),"armor",Vector3(0.16,0,side*-0.07))
			lancet(chest,Vector3(0.15,0.93,0.055),Vector3(side*0.37,0.28,0.40),"white",Vector3(0.16,0,side*-0.07))
			part(chest,Vector3(0.42,0.58,0.12),Vector3(side*0.69,0.07,0.62),"dark",Vector3(0,side*0.15,side*-0.22))
			for j in range(5): part(chest,Vector3(0.34,0.035,0.05),Vector3(side*0.69,-0.12+j*0.085,0.52),"gold",Vector3(0,0,side*-0.22),false)
			lancet(pelvis,Vector3(0.27,0.47,0.18),Vector3(side*0.43,-0.12,0.18),"white",Vector3(0,0,side*-0.10))
		elif model==5:
			# Fortress chassis: a broad hexagonal reactor carapace, with no exposed wing fins.
			panel(chest,[[side*-0.5,-0.30],[side*-0.5,0.28],[side*0.10,0.5],[side*0.5,0.18],[side*0.5,-0.36],[side*-0.1,-0.5]],Vector2(0.65,1.08),0.27,Vector3(side*0.36,0.03,0.63),"white")
			lancet(chest,Vector3(0.34,0.84,0.075),Vector3(side*0.36,0.02,0.83),"armor")
			part(chest,Vector3(0.035,0.53,0.03),Vector3(side*0.55,0.05,0.80),"light",Vector3(0,0,side*0.12),false)
			lancet(pelvis,Vector3(0.36,0.48,0.24),Vector3(side*0.47,-0.13,0.17),"white")
	if model==4:
		# Offset fire-control sensor, visibly separate from held weapons.
		cylinder(chest,0.045,0.40,Vector3(-0.49,0.50,0.39),"metal")
		part(chest,Vector3(0.23,0.14,0.18),Vector3(-0.49,0.73,0.39),"dark")
		part(chest,Vector3(0.14,0.045,0.025),Vector3(-0.49,0.73,0.285),"light",Vector3.ZERO,false)

func build_limbs(side: int) -> void:
	if model>=3:
		FORMS.build_limbs(self,side)
		build_track(side)
		return
	var prefix := "left" if side<0 else "right"
	var hip: Node3D = attachments[prefix+"_hip"]; var knee: Node3D = attachments[prefix+"_knee"]; var ankle: Node3D = attachments[prefix+"_ankle"]
	leg_attachments.append_array([hip,knee,ankle])
	joint(hip,0.135,0.25*width,Vector3.ZERO)
	part(hip,Vector3(0.19,0.55,0.21),Vector3(0,-0.38,0),"dark")
	lancet(hip,Vector3(0.32*width,0.63,0.18),Vector3(0,-0.35,-0.12),"white",Vector3(-0.12,0,0))
	lancet(hip,Vector3(0.10,0.47,0.035),Vector3(side*0.095,-0.33,-0.24),"armor")
	cylinder(hip,0.028,0.30,Vector3(side*0.15,-0.35,0.045),"gold",Vector3(0,0,side*0.10))
	joint(knee,0.125,0.25*width,Vector3.ZERO)
	lancet(knee,Vector3(0.24*width,0.29,0.13),Vector3(0,-0.015,-0.16),"white",Vector3(-0.12,0,0))
	part(knee,Vector3(0.19,0.61,0.22),Vector3(0,-0.40,0.04),"dark")
	lancet(knee,Vector3(0.31*width,0.69,0.22),Vector3(0,-0.40,-0.045),"white",Vector3(0.08,0,0))
	lancet(knee,Vector3(0.15,0.57,0.065),Vector3(0,-0.40,-0.18),"white",Vector3(0.08,0,0))
	lancet(knee,Vector3(0.16*width,0.40,0.27),Vector3(side*0.17*width,-0.25,0.055),"white",Vector3(0,0,side*-0.12))
	part(knee,Vector3(0.027,0.21,0.025),Vector3(side*0.13,-0.29,-0.19),"light",Vector3.ZERO,false)
	vent(knee,Vector2(0.10,0.15),Vector3(side*0.13,-0.43,-0.16),Vector3(0,side*-0.20,0))
	cylinder(knee,0.027,0.25,Vector3(side*0.11,-0.63,0.11),"gold")
	joint(ankle,0.09,0.25,Vector3(0,0.045,0))
	part(ankle,Vector3(0.31*width,0.12,0.57),Vector3(0,-0.035,-0.16),"dark")
	panel(ankle,[[-0.5,-0.38],[-0.34,0.5],[0.34,0.5],[0.5,-0.38],[0.26,-0.5],[-0.26,-0.5]],Vector2(0.31*width,0.45),0.14,Vector3(0,0.055,-0.23),"armor",Vector3(PI/2-0.18,0,0))
	lancet(ankle,Vector3(0.18,0.24,0.06),Vector3(0,0.11,-0.12),"white",Vector3(0.65,0,0))
	part(ankle,Vector3(0.14,0.025,0.025),Vector3(0,0.025,-0.45),"light",Vector3.ZERO,false)
	var shoulder: Node3D = attachments[prefix+"_shoulder"]; var elbow: Node3D = attachments[prefix+"_elbow"]; var wrist: Node3D = attachments[prefix+"_wrist"]
	joint(shoulder,0.165,0.27,Vector3.ZERO)
	var shoulder_profile: Array = [[-0.5,-0.15],[-0.35,0.40],[0.12,0.50],[0.5,0.20],[0.30,-0.5],[-0.20,-0.38]]
	if model==1: shoulder_profile = [[-0.5,-0.25],[-0.4,0.22],[0.5,0.5],[0.36,-0.15],[-0.15,-0.5]]
	elif model in [2,5]: shoulder_profile = [[-0.5,0.23],[-0.33,0.5],[0.28,0.5],[0.5,0.20],[0.42,-0.32],[0,-0.5],[-0.4,-0.25]]
	for point in shoulder_profile: point[0] *= side
	var shoulder_size := Vector2(0.65*width,0.32 if model in [1,3] else 0.46 if model in [2,5] else 0.38)
	panel(shoulder,shoulder_profile,shoulder_size,0.44 if model in [2,5] else 0.36,Vector3(side*0.09,0.09,0),"white",Vector3(0,0,side*0.15))
	if model==2:
		panel(shoulder,shoulder_profile,shoulder_size*0.83,0.035,Vector3(side*0.09,0.09,-0.25),"gold",Vector3(0,0,side*0.15))
		panel(shoulder,shoulder_profile,shoulder_size*0.72,0.025,Vector3(side*0.09,0.09,-0.28),"white",Vector3(0,0,side*0.15))
	panel(shoulder,[[side*-0.5,0.22],[side*0.5,0.50],[side*0.25,-0.48],[side*-0.22,-0.26]],Vector2(0.36*width,0.16),0.035,Vector3(side*0.12,0.07,-0.31 if model==2 else -0.225),"armor",Vector3(0,0,side*0.15))
	if model!=2:
		panel(shoulder,[[side*-0.5,-0.5],[side*0.5,0.5],[side*0.32,-0.32]],Vector2(0.26,0.38),0.10,Vector3(side*0.35,0.21,0.07),"armor",Vector3(0,0,side*-0.18))
	vent(shoulder,Vector2(0.15,0.09),Vector3(side*0.15,-0.06,-0.25 if model!=2 else -0.32),Vector3(0,0,side*0.15))
	part(shoulder,Vector3(0.26*width,0.014,0.018),Vector3(side*0.10,0.18,-0.23 if model!=2 else -0.32),"dark",Vector3(0,0,side*0.15),false)
	if model==3:
		lancet(shoulder,Vector3(0.15,0.44,0.12),Vector3(side*0.34,0.07,0.12),"armor",Vector3(0.45,0,side*-0.30))
		lancet(knee,Vector3(0.16,0.35,0.23),Vector3(side*0.19,-0.26,0.13),"armor",Vector3(0.24,0,side*-0.12))
	elif model==4:
		part(shoulder,Vector3(0.35,0.20,0.40),Vector3(side*0.18,0.18,0.10),"armor")
		for j in range(3): part(shoulder,Vector3(0.035,0.16,0.045),Vector3(side*(0.13+j*0.08),0.13,-0.15),"metal",Vector3.ZERO,false)
	elif model==5:
		panel(shoulder,[[-0.5,-0.28],[-0.5,0.3],[0,0.5],[0.5,0.3],[0.5,-0.28],[0,-0.5]],Vector2(0.70,0.45),0.13,Vector3(side*0.12,0.06,-0.28),"armor")
		part(shoulder,Vector3(0.30,0.045,0.035),Vector3(side*0.12,0.06,-0.365),"light",Vector3.ZERO,false)
		lancet(elbow,Vector3(0.38,0.44,0.16),Vector3(side*0.06,-0.23,0.10),"armor")
		lancet(ankle,Vector3(0.43,0.25,0.15),Vector3(0,0.11,-0.10),"armor",Vector3(0.65,0,0))

	part(shoulder,Vector3(0.15,0.31,0.18),Vector3(0,-0.30,0),"dark")
	lancet(shoulder,Vector3(0.21,0.28,0.12),Vector3(0,-0.29,-0.09),"white",Vector3(-0.12,0,0))
	cylinder(shoulder,0.025,0.24,Vector3(side*0.10,-0.30,0.04),"gold")
	joint(elbow,0.10,0.23,Vector3.ZERO)
	part(elbow,Vector3(0.17,0.34,0.21),Vector3(0,-0.23,0),"dark")
	lancet(elbow,Vector3(0.29*width,0.41,0.23),Vector3(0,-0.20,-0.055),"white",Vector3(-0.08,0,0))
	lancet(elbow,Vector3(0.12,0.26,0.035),Vector3(side*0.07,-0.22,-0.20),"armor")
	lancet(elbow,Vector3(0.055,0.13,0.02),Vector3(-side*0.065,-0.22,-0.20),"light")
	part(wrist,Vector3(0.20,0.18,0.19),Vector3.ZERO,"dark")
	lancet(wrist,Vector3(0.18,0.15,0.04),Vector3(0,0,-0.12),"metal")
	for finger in range(4):
		part(wrist,Vector3(0.036,0.06,0.07),Vector3((finger-1.5)*0.045,-0.065,-0.095),"metal",Vector3.ZERO,false)
		part(wrist,Vector3(0.032,0.055,0.04),Vector3((finger-1.5)*0.045,-0.10,-0.07),"dark",Vector3.ZERO,false)
	build_track(side)

func build_track(side: int) -> void:
	var track := Node3D.new(); add_child(track); track.position = Vector3(side*0.48,0.25,0); tracks.append(track)
	part(track,Vector3(0.48,0.42,1.15),Vector3.ZERO,"dark",Vector3.ZERO,false)
	part(track,Vector3(0.44,0.13,1.06),Vector3(0,0.22,0),"armor")
	for z in [-0.37,0.0,0.37]: cylinder(track,0.17,0.52,Vector3(0,0,z),"metal",Vector3(0,0,PI/2))
	for i in range(16):
		var pad := part(track,Vector3(0.52,0.055,0.11),Vector3.ZERO,"metal",Vector3.ZERO,false)
		pad.set_meta("dynamic_mesh",true); tread_pads.append(pad)

func equip(loadout: Dictionary) -> void:
	var key := "%d:%d:%d"%[int(loadout.get("armor",-1)),int(loadout.get("core",-1)),int(loadout.get("backpack",-1))]
	if key!=equipment_key:
		equipment_key = key
		if is_instance_valid(equipment_mount): equipment_mount.free()
		equipment_mount = Node3D.new(); equipment_mount.name = "Equipment"; attachments.chest.add_child(equipment_mount)
		var armor: int = loadout.get("armor",-1)
		if armor==4:
			for side in [-1,1]: lancet(equipment_mount,Vector3(0.28,0.43,0.12),Vector3(side*0.40,-0.06,-0.27),"metal",Vector3(0,side*-0.24,side*-0.18))
		elif armor==5:
			for side in [-1,1]: cylinder(equipment_mount,0.10,0.40,Vector3(side*0.48,-0.08,0.22),"light")
		var core: int = loadout.get("core",-1)
		if core>=0: lancet(equipment_mount,Vector3(0.10,0.14,0.025),Vector3(0,0.035,-0.48),"gold" if core in [9,11] else "light")
		var pack: int = loadout.get("backpack",-1)
		if pack==12:
			for x in [-0.25,0,0.25]: part(equipment_mount,Vector3(0.08,0.76,0.40),Vector3(x,0,0.68),"metal")
		elif pack==13:
			for side in [-1,1]:
				cylinder(equipment_mount,0.18,0.56,Vector3(side*0.40,0.04,0.72),"dark")
				cylinder(equipment_mount,0.12,0.10,Vector3(side*0.40,-0.28,0.72),"light")
		elif pack==14:
			part(equipment_mount,Vector3(0.80,0.56,0.30),Vector3(0,0,0.78),"armor")
			for x in [-0.25,0,0.25]: part(equipment_mount,Vector3(0.09,0.41,0.04),Vector3(x,0,0.96),"light",Vector3.ZERO,false)
		GEO.batch(equipment_mount)
	for slot in [0,4]:
		var mode := ""
		for item in loadout.get("weapons",[]):
			if int(item.slot)==slot: mode = str(item.mode)
		if weapon_keys.get(slot,"unset")==mode: continue
		weapon_keys[slot] = mode
		arm_ready[slot] = 0.0; arm_hold[slot] = -100.0
		if mounts.has(slot): mounts[slot].free(); mounts.erase(slot); muzzles.erase(slot)
		if mode.is_empty(): continue
		var mount := Node3D.new(); mount.name = "Weapon_%d_%s"%[slot,mode]
		attachments["right_wrist" if slot==0 else "left_wrist"].add_child(mount); mounts[slot] = mount
		build_weapon(mount,mode,slot)
		GEO.batch(mount)
		mount.scale = Vector3(1.38,1.25,1.40) if mode not in ["blade","hammer","gauntlet","hand_shield"] else Vector3(1.7,1.3,1.32) if mode=="blade" else Vector3.ONE*1.18 if mode=="hammer" else Vector3.ONE*1.10

func build_weapon(mount: Node3D, mode: String, slot: int) -> void:
	var muzzle := Marker3D.new(); muzzle.name = "Muzzle"; mount.add_child(muzzle); muzzles[slot] = muzzle
	if mode in ["blade","hammer"]:
		cylinder(mount,0.045,0.42,Vector3(0,0,-0.08),"metal",Vector3(PI/2,0,0))
		part(mount,Vector3(0.33,0.10,0.10),Vector3(0,0,-0.27),"gold",Vector3.ZERO,false)
		if mode=="blade":
			panel(mount,[[-0.5,-0.5],[0.5,-0.5],[0.34,0.32],[0,0.5],[-0.34,0.32]],Vector2(0.17,1.0),0.045,Vector3(0,0,-0.80),"metal",Vector3(-PI/2,0,0))
			panel(mount,[[-0.5,-0.5],[0.5,-0.5],[0.30,0.32],[0,0.5],[-0.30,0.32]],Vector2(0.08,0.94),0.02,Vector3(0,0.035,-0.80),"blade",Vector3(-PI/2,0,0))
		else:
			cylinder(mount,0.045,0.75,Vector3(0,0,-0.58),"metal",Vector3(PI/2,0,0))
			part(mount,Vector3(0.66,0.41,0.32),Vector3(0,0,-1.03),"dark",Vector3.ZERO,false)
			for x in [-0.34,0.34]: part(mount,Vector3(0.10,0.42,0.33),Vector3(x,0,-1.03),"gold",Vector3.ZERO,false)
		muzzle.position = Vector3(0,0,-1.3)
	elif mode=="gauntlet":
		part(mount,Vector3(0.43,0.37,0.43),Vector3(0,0,-0.14),"armor")
		for x in [-0.14,0,0.14]: part(mount,Vector3(0.10,0.20,0.13),Vector3(x,0,-0.41),"gold",Vector3.ZERO,false)
		muzzle.position = Vector3(0,0,-0.49)
	elif mode=="hand_shield":
		lancet(mount,Vector3(0.62,1.0,0.16),Vector3(0,0.12,-0.30),"armor")
		lancet(mount,Vector3(0.43,0.77,0.045),Vector3(0,0.15,-0.41),"white")
		part(mount,Vector3(0.07,0.76,0.04),Vector3(0,0.12,-0.40),"light",Vector3.ZERO,false)
		muzzle.position = Vector3(0,0,-0.4)
	elif mode=="missile":
		part(mount,Vector3(0.53,0.46,0.72),Vector3(0,0.14,-0.25),"dark",Vector3.ZERO,false)
		part(mount,Vector3(0.55,0.10,0.66),Vector3(0,0.42,-0.24),"white")
		for x in [-0.14,0.14]:
			for y in [0.03,0.26]:
				cylinder(mount,0.085,0.13,Vector3(x,y,-0.65),"metal",Vector3(PI/2,0,0))
				cylinder(mount,0.05,0.15,Vector3(x,y,-0.70),"gold",Vector3(PI/2,0,0))
		for side in [-1,1]:
			part(mount,Vector3(0.035,0.30,0.30),Vector3(side*0.285,0.14,-0.25),"gold",Vector3.ZERO,false)
		muzzle.position = Vector3(0,0.14,-0.78)
	else:
		var long_barrel: bool = mode in ["rail","laser","pulse"]
		part(mount,Vector3(0.27,0.31,0.65),Vector3(0,0.17,-0.17),"dark",Vector3.ZERO,false)
		lancet(mount,Vector3(0.29,0.62,0.12),Vector3(0,0.32,-0.20),"white",Vector3(PI/2,0,0))
		for side in [-1,1]:
			lancet(mount,Vector3(0.11,0.46,0.06),Vector3(side*0.17,0.18,-0.25),"metal",Vector3(PI/2,side*PI/2,0))
		part(mount,Vector3(0.09,0.08,0.22),Vector3(0,0.42,-0.16),"dark",Vector3.ZERO,false)
		part(mount,Vector3(0.18,0.11,0.42),Vector3(0,0.26,-0.65),"metal",Vector3.ZERO,false)
		cylinder(mount,0.085 if long_barrel else 0.12,0.65 if long_barrel else 0.35,Vector3(0,0.17,-0.68),"metal",Vector3(PI/2,0,0))
		if mode in ["laser","pulse","plasma"]:
			var emitter := "laser" if mode=="laser" else "plasma" if mode=="plasma" else "light"
			for side in [-1,1]:
				lancet(mount,Vector3(0.09,0.48,0.10),Vector3(side*0.12,0.18,-0.72),"white",Vector3(PI/2,0,0))
				part(mount,Vector3(0.02,0.025,0.31),Vector3(side*0.13,0.245,-0.72),emitter,Vector3.ZERO,false)
			part(mount,Vector3(0.07,0.12,0.49),Vector3(0.16,0.18,-0.32),emitter,Vector3.ZERO,false)
			if mode=="plasma": cylinder(mount,0.19,0.30,Vector3(0,0.17,-0.64),"dark",Vector3(PI/2,0,0))
			cylinder(mount,0.14 if mode=="plasma" else 0.065,0.04,Vector3(0,0.17,-1.02 if long_barrel else -0.87),emitter,Vector3(PI/2,0,0))
		elif mode=="rail":
			for side in [-1,1]: part(mount,Vector3(0.08,0.12,0.70),Vector3(side*0.13,0.17,-0.72),"white",Vector3.ZERO,false)
		elif mode in ["standard","burst"]:
			for i in range(3): cylinder(mount,0.055,0.42,Vector3(sin(i*TAU/3)*0.095,0.17+cos(i*TAU/3)*0.095,-0.71),"metal",Vector3(PI/2,0,0))
		muzzle.position = Vector3(0,0.17,-1.03 if long_barrel else -0.88)

func rotation_bone(id: String, value: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bones[id],Quaternion.from_euler(value))

static func heading(direction: Vector2) -> float:
	return PROJECTION.heading(direction)

func animate(pose: Dictionary, loadout: Dictionary, engine: RefCounted, aim: Vector2, elapsed: float, defense: RefCounted) -> void:
	equip(loadout)
	update_arm_readiness(pose,engine,float(pose.get("clock",elapsed)),defense)
	var phase: float = pose.get("phase",0); var blend: float = pose.get("blend",0)
	var drive: String = loadout.get("drive","walk")
	var flying: bool = drive=="hover" or (drive=="dash" and bool(pose.get("boost",false)))
	var walking: bool = drive in ["walk","dash"] and not flying
	var stride: float = blend if walking else 0.0
	rotation.y = float(pose.get("yaw",heading(aim if aim!=Vector2.ZERO else Vector2(1,0.6))))
	var velocity: Vector2 = pose.get("velocity",Vector2(180,0)*blend)
	var travel := PROJECTION.ground(velocity).rotated(Vector3.UP,-rotation.y).normalized()
	var running := smoothstep(55.0,210.0,velocity.length()) if walking else 0.0
	var support := lerpf(0.62,0.44,running)
	var amplitude := lerpf(0.34,0.72,running)*(UPPER_LEG+LOWER_LEG)/1.60
	var quiet: float = (1-blend) if walking else 0.0
	var bob: float = -quiet*0.025-running*0.15-0.035*pow(sin(phase),2)*stride+sin(elapsed*2)*0.008
	var lift: float = 0.22 if flying else 0.0
	skeleton.set_bone_pose_position(bones.pelvis,Vector3(sin(phase)*0.035*stride+quiet*(0.04 if model not in [2,5] else 0.0),(0.82 if drive=="treads" else hip_height)+bob+lift,0))
	rotation_bone("pelvis",Vector3(0,sin(phase)*0.035*stride,sin(phase)*0.025*stride))
	var aim_delta := wrapf(heading(aim)-rotation.y,-PI,PI) if aim.length_squared()>0.01 else 0.0
	rotation_bone("chest",Vector3(-(0.09 if model==3 else 0.035)*quiet-0.04*blend-running*0.12 if not flying else -0.14,clampf(aim_delta,-0.75,0.75)-sin(phase)*0.045*stride-quiet*0.07,-sin(phase)*0.025*stride))
	rotation_bone("head",Vector3(-0.025*quiet,clampf(aim_delta,-0.35,0.35)+quiet*0.07,0))
	for side in [-1,1]:
		var prefix := "left" if side<0 else "right"
		var cycle := fposmod(phase/TAU+(0.5 if side<0 else 0),1)
		var sweep: float; var rise := 0.0
		if cycle<support: sweep = lerpf(amplitude,-amplitude,cycle/support)
		else:
			var t := (cycle-support)/(1-support)
			sweep = lerpf(-amplitude,amplitude,smoothstep(0,1,t)); rise = sin(t*PI)*lerpf(0.18,0.40,running)
		var target := Vector3(side*(0.33+quiet*(0.02 if model not in [2,5] else 0.04))*width,0.10,0.02+side*quiet*(0.12 if model in [1,3] else 0.07))+travel*sweep*stride+Vector3(0,rise*stride,0)
		if flying: target = Vector3(side*0.35*width,0.40,0.25)
		stance_targets[prefix] = target
		solve_leg(prefix,target)
		var slot: int = 4 if side<0 else 0
		animate_arm(prefix,slot,phase,stride,engine)
	for node in leg_attachments: node.visible = drive!="treads"
	legs_mesh.visible = drive!="treads"
	for track in tracks: track.visible = drive=="treads"
	track_bridge.visible = drive=="treads"
	for i in range(tread_pads.size()):
		var t := fposmod(float(i%16)/16.0*3.1+phase*0.42,3.1)
		var pad := tread_pads[i]
		if t<1.1: pad.position=Vector3(0,0.25,t-0.55); pad.rotation.x=0
		elif t<1.55: pad.position=Vector3(0,0.25-(t-1.1),0.55); pad.rotation.x=PI/2
		elif t<2.65: pad.position=Vector3(0,-0.20,0.55-(t-1.55)); pad.rotation.x=0
		else: pad.position=Vector3(0,-0.20+(t-2.65),-0.55); pad.rotation.x=PI/2
	for jet in jets:
		jet.visible = flying
		jet.scale.y = (1.8 if pose.get("boost",false) else 0.7)*(1+sin(elapsed*28)*0.16)
	shield_material.set_shader_parameter("strength",1.0 if defense!=null and defense.total_shield()>0 else 0.0)
	shield_material.set_shader_parameter("impact",clampf(defense.shield_flash/0.22,0,1) if defense!=null else 0.0)
	var incoming := Vector2.from_angle(defense.shield_hit_angle) if defense!=null else Vector2.LEFT
	shield_material.set_shader_parameter("incoming",PROJECTION.ground(incoming).normalized())
	skeleton.force_update_all_bone_transforms(); sync_attachments()
	if pose.has("aim_world"):
		for slot in [0,4]:
			if arm_ready[slot]>0 and weapon_keys.get(slot,"") in ["standard","burst","rail","laser","pulse","missile","plasma"]: aim_weapon(slot,pose.aim_world)
		skeleton.force_update_all_bone_transforms(); sync_attachments()
	update_trails(engine)

func aim_weapon(slot: int, target: Vector3) -> void:
	var prefix := "right" if slot==0 else "left"
	var parent_basis: Basis = global_basis*skeleton.get_bone_global_pose(bones[prefix+"_elbow"]).basis
	var hand: Vector3 = global_transform*skeleton.get_bone_global_pose(bones[prefix+"_wrist"]).origin
	if hand.distance_squared_to(target)<0.00001: return
	var direction := (target-hand).normalized()
	var basis_value := Basis.looking_at(direction,Vector3.FORWARD if absf(direction.y)>0.98 else Vector3.UP)
	var height: float = (0.14 if weapon_keys[slot]=="missile" else 0.17)*mounts[slot].scale.y
	for i in range(4):
		direction = (target-(hand+basis_value*Vector3(0,height,0))).normalized()
		if direction.length_squared()<0.00001: break
		basis_value = Basis.looking_at(direction,Vector3.FORWARD if absf(direction.y)>0.98 else Vector3.UP)
	var aimed := (parent_basis.inverse()*basis_value).orthonormalized().get_rotation_quaternion()
	var carried := skeleton.get_bone_pose_rotation(bones[prefix+"_wrist"])
	skeleton.set_bone_pose_rotation(bones[prefix+"_wrist"],carried.slerp(aimed,smoothstep(0,1,float(arm_ready[slot]))))

func solve_leg(prefix: String, target: Vector3) -> void:
	# Solve in pelvis space, keeping the knee bending forward and the ankle level.
	var pelvis := skeleton.get_bone_global_pose(bones.pelvis)
	var hip_rest: Vector3 = skeleton.get_bone_rest(bones[prefix+"_hip"]).origin
	var local_target: Vector3 = pelvis.affine_inverse()*target-hip_rest
	var distance := clampf(local_target.length(),0.2,UPPER_LEG+LOWER_LEG-0.005)
	var axis := local_target.normalized()
	var bend := (Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)).normalized()
	var along := (UPPER_LEG*UPPER_LEG-LOWER_LEG*LOWER_LEG+distance*distance)/(2*distance)
	var knee := axis*along+bend*sqrt(maxf(0,UPPER_LEG*UPPER_LEG-along*along))
	var upper := Quaternion(Vector3.DOWN,knee.normalized())
	var lower := Quaternion(Vector3.DOWN,(local_target-knee).normalized())
	skeleton.set_bone_pose_rotation(bones[prefix+"_hip"],upper)
	skeleton.set_bone_pose_rotation(bones[prefix+"_knee"],upper.inverse()*lower)
	skeleton.set_bone_pose_rotation(bones[prefix+"_ankle"],lower.inverse()*pelvis.basis.get_rotation_quaternion().inverse())

func update_arm_readiness(pose: Dictionary, engine: RefCounted, now: float, defense: RefCounted) -> void:
	var reset: bool = pose_time<0 or now<pose_time
	var delta: float = 0.0 if reset else clampf(now-pose_time,0,0.1)
	pose_time = now
	for slot in [0,4]:
		if reset: arm_ready[slot] = 0.0; arm_hold[slot] = -100.0
		var mode: String = weapon_keys.get(slot,"")
		var active := false
		if engine!=null:
			for flash in engine.flashes:
				if flash.kind=="muzzle" and int(flash.get("slot",-1))==slot: active = true
			for beam in engine.beams:
				if int(beam.meta.get("slot",-1))==slot: active = true
		var wanted: float = float(pose.get("weapon_ready",false))
		if pose.has("ready_slots"): wanted = float(pose.ready_slots.get(slot,0.0))
		if mode=="hand_shield" and defense!=null and defense.guard_blocked>0 and defense.guard_quiet<0.2: wanted = 1.0
		if mode in ["","blade","hammer","gauntlet"]: wanted = 0.0
		if active:
			# Acquisition normally supplies a lead-in. A real shot must still have
			# its barrel aligned on its first visible frame, including loaded fights.
			arm_ready[slot] = 1.0; arm_hold[slot] = now+0.20
		if now<arm_hold[slot]: wanted = 1.0
		arm_ready[slot] = move_toward(float(arm_ready[slot]),wanted,delta*(6.0 if wanted>arm_ready[slot] else 2.8))

func animate_arm(prefix: String, slot: int, phase: float, stride: float, engine: RefCounted) -> void:
	var mode: String = weapon_keys.get(slot,"")
	var ready := smoothstep(0,1,float(arm_ready[slot]))
	var side := -1.0 if slot==4 else 1.0
	var upper: float = 0.04+sin(phase+(PI if slot==4 else 0))*0.14*stride
	var elbow := 0.18; var pitch := -0.62; var sweep := side*0.16*(1-ready)
	if mode=="hand_shield":
		upper = lerpf(upper,0.52,ready); elbow = lerpf(elbow,0.95,ready); pitch = -0.08; sweep = 0
	elif mode not in ["","blade","hammer","gauntlet"]:
		upper = lerpf(upper,0.82,ready); elbow = lerpf(elbow,0.74,ready); pitch = lerpf(-0.62,0,ready)
	elif mode=="gauntlet" or mode=="": pitch = 0.0
	var carry := Vector4(upper,elbow,pitch,sweep)
	if engine!=null:
		for swing in engine.swings:
			if int(swing.meta.get("slot",-1))!=slot or swing.mode!=mode: continue
			if mode=="gauntlet":
				var punch := 0.0
				for timing in MELEE.RULES.gauntlet.timings:
					var t := clampf((swing.age-float(timing)+0.07)/0.18,0,1)
					punch = maxf(punch,pow(sin(t*PI),2))
				upper = 0.65+punch*0.83; elbow = 1.3-punch*1.2
			else:
				var angle := MELEE.swing_angle(mode,swing.age)
				var envelope := sin(clampf(swing.age/float(MELEE.RULES[mode].duration),0,1)*PI)
				upper = lerpf(0.15,1.18,envelope); elbow = 0.35
				if mode=="hammer": pitch = angle; upper += maxf(0,-angle)*0.40
				else: pitch = lerpf(-0.75,0,envelope); sweep = angle
			var duration: float = MELEE.RULES[mode].duration
			var action_weight: float = smoothstep(0,0.06,float(swing.age))*(1-smoothstep(duration-0.10,duration,float(swing.age)))
			upper = lerpf(carry.x,upper,action_weight); elbow = lerpf(carry.y,elbow,action_weight)
			pitch = lerpf(carry.z,pitch,action_weight); sweep = lerpf(carry.w,sweep,action_weight)
		for flash in engine.flashes:
			if flash.kind=="muzzle" and int(flash.get("slot",-1))==slot: upper -= float(flash.t)/float(flash.life)*0.09
	rotation_bone(prefix+"_shoulder",Vector3(upper,sweep*0.65,side*0.12*(1-ready)))
	rotation_bone(prefix+"_elbow",Vector3(elbow,0,0))
	rotation_bone(prefix+"_wrist",Vector3(pitch-upper-elbow,sweep*0.35,0))

func sync_attachments() -> void:
	for id in attachments: attachments[id].transform = skeleton.get_bone_global_pose(bones[id])

func muzzle_position(slot: int) -> Vector3:
	return muzzles[slot].global_position if muzzles.has(slot) else global_position+Vector3(0,1.7,0)

func update_trails(engine: RefCounted) -> void:
	var contact: float = MELEE.RULES.blade.timings[0]
	var release: float = contact+float(MELEE.RULES.blade.window)
	for slot in [0,4]:
		var swing: Dictionary = {}
		if engine!=null:
			for candidate in engine.swings:
				if int(candidate.meta.get("slot",-1))==slot and candidate.mode=="blade" and candidate.age>=contact and candidate.age<release+0.1: swing = candidate
		if swing.is_empty() or not muzzles.has(slot):
			trail_samples[slot] = []
			if trails.has(slot): trails[slot].visible = false
			continue
		if not trails.has(slot):
			var ribbon := MeshInstance3D.new(); ribbon.name = "BladeTrail%d"%slot
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.vertex_color_use_as_albedo = true
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			ribbon.material_override = material; add_child(ribbon); trails[slot] = ribbon
		var samples: Array = trail_samples.get(slot,[])
		if not samples.is_empty() and float(swing.age)<samples.back().age: samples.clear()
		if swing.active and (samples.is_empty() or float(swing.age)>samples.back().age+0.001):
			var tip := to_local(muzzle_position(slot))
			var wrist := to_local(mounts[slot].global_position)
			samples.append({"tip":tip,"base":wrist.lerp(tip,0.40),"age":float(swing.age)})
		while samples.size()>7: samples.pop_front()
		trail_samples[slot] = samples
		trails[slot].visible = samples.size()>1
		if samples.size()<2: continue
		var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var fade := 1-smoothstep(release,release+0.1,float(swing.age))
		for i in range(1,samples.size()):
			for vertex in [Vector2i(i-1,0),Vector2i(i-1,1),Vector2i(i,1),Vector2i(i-1,0),Vector2i(i,1),Vector2i(i,0)]:
				var alpha := float(vertex.x+1)/samples.size()*fade
				mesh.surface_set_color(Color(1,0.70,0.91,alpha*0.85) if vertex.y==1 else Color(1,0.16,0.5,alpha*0.04))
				mesh.surface_add_vertex(samples[vertex.x].tip if vertex.y==1 else samples[vertex.x].base)
		mesh.surface_end(); trails[slot].mesh = mesh
