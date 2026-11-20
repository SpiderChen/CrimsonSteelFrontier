extends SubViewport
## One transparent 3D render per visible mech, owned and freed by its CanvasItem.
const RIG = preload("res://scripts/rig/mech_rig_3d.gd")
const PROJECTION = preload("res://scripts/rig/mech_projection.gd")
const DRAW_SIZE = PROJECTION.DRAW_SIZE
var rig = RIG.new()
var camera := Camera3D.new()
var model: int = -1
var touched_frame: int = -1
var initialized: bool = false

func _ready() -> void:
	size = Vector2i(320,320); transparent_bg = true; own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("web") else Viewport.MSAA_2X
	positional_shadow_atlas_size = 0
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a9bfd5")
	environment.environment.ambient_light_energy = 0.5
	add_child(environment)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35,-35,0); key.light_energy = 1.25; key.shadow_enabled = true; key.directional_shadow_max_distance = 16; key.shadow_bias = 0.03; add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20,145,0); rim.light_color = Color("8bc7ff"); rim.light_energy = 0.75; add_child(rim)
	add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = PROJECTION.CAMERA_SIZE
	camera.position = PROJECTION.CAMERA_POSITION; camera.look_at(PROJECTION.CAMERA_TARGET); camera.current = true
	initialized = true

func update_model(which: int, pose: Dictionary, loadout: Dictionary, engine: RefCounted, aim: Vector2, elapsed: float, defense: RefCounted) -> void:
	if not initialized: return
	if which!=model:
		if rig.is_inside_tree(): rig.free(); rig = RIG.new()
		add_child(rig); rig.build(which); model = which
	if pose.has("aim_point"):
		pose = pose.duplicate()
		var screen: Vector2 = (Vector2(pose.aim_point)-Vector2(0,119))*Vector2(size)/DRAW_SIZE+camera.unproject_position(Vector3.ZERO)
		var origin := camera.project_ray_origin(screen); var direction := camera.project_ray_normal(screen)
		pose.aim_world = origin+direction*((1.8-origin.y)/direction.y)
	rig.animate(pose,loadout,engine,aim,elapsed,defense)
	touched_frame = Engine.get_process_frames()
	render_target_update_mode = SubViewport.UPDATE_ONCE

func project(point: Vector3) -> Vector2:
	return (camera.unproject_position(point)-camera.unproject_position(Vector3.ZERO))*DRAW_SIZE/Vector2(size)+Vector2(0,119)

func drawing_rect() -> Rect2:
	return Rect2(Vector2(0,119)-camera.unproject_position(Vector3.ZERO)*DRAW_SIZE/Vector2(size),DRAW_SIZE)

func muzzle(slot: int) -> Vector2:
	return project(rig.muzzle_position(slot))
