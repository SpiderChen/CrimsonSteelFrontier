extends SubViewport
const MODEL = preload("res://scripts/rig/unit_model_3d.gd")
var model: Node3D
var signature := ""
var touched_frame := -1

func _ready() -> void:
	size = Vector2i(192,192); transparent_bg = true; own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	positional_shadow_atlas_size = 0
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9ccde"); environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-40,-35,0); key.light_energy = 1.5; add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20,145,0); rim.light_color = Color("8bbfff"); rim.light_energy = 0.6; add_child(rim)
	var camera := Camera3D.new(); camera.name = "Camera"; add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.current = true
	camera.position = Vector3(0,7,10); camera.look_at(Vector3(0,1.1,0))

func update_model(kind: String, variant: int, elite: bool, direction: Vector2, moving: bool, elapsed: float, state: Dictionary) -> void:
	var next := "%s:%d:%s"%[kind,variant,elite]
	if next!=signature:
		if is_instance_valid(model): model.free()
		model = MODEL.new(); add_child(model); model.build(kind,variant,elite); signature = next
		get_node("Camera").size = 8.8 if kind=="carrier" else 6.0 if kind=="boss" else 3.8
		var resolution := 512 if kind=="carrier" else 320 if kind=="boss" else 160
		size = Vector2i(resolution,resolution)
	model.animate(direction,moving,elapsed,state)
	touched_frame = Engine.get_process_frames(); render_target_update_mode = SubViewport.UPDATE_ONCE
