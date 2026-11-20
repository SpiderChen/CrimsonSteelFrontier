extends RefCounted
## Original low-poly hard-surface geometry. All armor is rigid, never stretched artwork.
static var meshes: Dictionary = {}

static func armor(profile: PackedVector2Array, depth: float, crown: float = 0.025) -> ArrayMesh:
	# Beveled, shaped armor casting. The silhouette is authored in the XY plane;
	# a shallow crowned face catches light without turning every panel into a box.
	var key := str(profile)+str(depth)+str(crown)
	if meshes.has(key): return meshes[key]
	var center := Vector2.ZERO
	for point in profile: center += point
	center /= profile.size()
	var rings: Array = []
	for level in range(4):
		var ring: Array[Vector3] = []
		var scale_value: float = [0.90,1.0,1.0,0.87][level]
		var z: float = [depth*0.5,depth*0.32,-depth*0.30,-depth*0.5][level]
		for point in profile:
			var p: Vector2 = center+(point-center)*scale_value
			ring.append(Vector3(p.x,p.y,z))
		rings.append(ring)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(3):
		for i in range(profile.size()):
			var j := (i+1)%profile.size()
			triangle(surface,rings[level][i],rings[level][j],rings[level+1][j])
			triangle(surface,rings[level][i],rings[level+1][j],rings[level+1][i])
	for i in range(profile.size()):
		var j := (i+1)%profile.size()
		triangle(surface,Vector3(center.x,center.y,depth*0.5),rings[0][i],rings[0][j])
		triangle(surface,Vector3(center.x,center.y,-depth*0.5-crown),rings[3][i],rings[3][j])
	var result := surface.commit(); meshes[key] = result
	return result

static func plate(size: Vector3, bevel: float = 0.06) -> ArrayMesh:
	var key := str(size)+str(bevel)
	if meshes.has(key): return meshes[key]
	var half := size*0.5
	var b := minf(bevel,minf(half.x,minf(half.y,half.z))*0.65)
	var rings: Array = []
	for level in range(4):
		var inset: float = b if level in [0,3] else 0.0
		var x := half.x-inset; var z := half.z-inset
		var cut := minf(b,minf(x,z)*0.4)
		var y: float = [-half.y,-half.y+b,half.y-b,half.y][level]
		var ring: Array[Vector3] = []
		for p in [Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut)]: ring.append(Vector3(p.x,y,p.y))
		rings.append(ring)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(3):
		for i in range(8):
			var j := (i+1)%8
			triangle(surface,rings[level][i],rings[level][j],rings[level+1][j])
			triangle(surface,rings[level][i],rings[level+1][j],rings[level+1][i])
	for level in [0,3]:
		for i in range(8): triangle(surface,Vector3(0,rings[level][0].y,0),rings[level][i],rings[level][(i+1)%8])
	var result := surface.commit(); meshes[key] = result
	return result

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0)<0: var swap := b; b=c; c=swap; normal = -normal
	# Godot's front winding is clockwise.
	for point in [a,c,b]: surface.set_normal(normal); surface.add_vertex(point)

static func material(color: Color, metal: float = 0.55, glow: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color; result.metallic = metal; result.roughness = 0.32 if metal>0.7 else 0.48
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.metallic_specular = 0.65
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true; result.emission = color
	return result

static func collect_meshes(node: Node, result: Array) -> void:
	if node.get_meta("dynamic_mesh",false): return
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): collect_meshes(child,result)

static func batch(root: Node3D) -> void:
	var nodes: Array = []; collect_meshes(root,nodes)
	var groups: Dictionary = {}
	for node in nodes:
		var material: Material = node.material_override
		if not groups.has(material): groups[material] = []
		groups[material].append(node)
	var mesh := ArrayMesh.new()
	for material in groups:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in groups[material]: surface.append_from(node.mesh,0,root.global_transform.affine_inverse()*node.global_transform)
		surface.commit(mesh); mesh.surface_set_material(mesh.get_surface_count()-1,material)
	for node in nodes:
		if is_instance_valid(node): node.free()
	if mesh.get_surface_count()>0:
		var combined := MeshInstance3D.new(); combined.name = "BatchedGeometry"; combined.mesh = mesh; root.add_child(combined)
