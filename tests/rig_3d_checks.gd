extends RefCounted
const VIEW = preload("res://scripts/rig/mech_viewport.gd")
const MOTION = preload("res://scripts/mech_motion.gd")

func run(check: Callable, main: Node) -> void:
	var view = VIEW.new(); main.add_child(view)
	var loadout := {"drive":"walk","weapons":[{"slot":0,"mode":"laser","blueprint":15},{"slot":4,"mode":"hand_shield","blueprint":24}]}
	var defense = preload("res://scripts/defense_runtime.gd").new(); defense.configure({"shield":25},true)
	var pose := {"phase":0.5,"blend":1,"velocity":Vector2(80,0),"yaw":-2.1}
	var widths: Array = []; var silhouettes: Array = []; var bodies: Array = []
	for model in range(State.MECHS.MODELS.size()):
		view.update_model(model,pose,loadout,null,Vector2(1,0.6),1,defense)
		var rig = view.rig; widths.append(rig.width)
		check.call(rig.skeleton is Skeleton3D and rig.skeleton.get_bone_count()==15,"chassis %d has a real fifteen-bone 3D hierarchy"%model)
		check.call(rig.skeleton.get_bone_parent(rig.bones.right_knee)==rig.bones.right_hip and rig.attachments.right_wrist is BoneAttachment3D,"chassis %d armor and weapons are attached to actual limb bones"%model)
		var vertices := 0
		for surface in range(rig.body_mesh.mesh.get_surface_count()):
			vertices += rig.body_mesh.mesh.surface_get_array_len(surface)
		silhouettes.append(vertices)
		check.call(rig.body_mesh.skin!=null and rig.body_mesh.mesh.get_surface_count()<=8 and rig.muzzles.has(0) and rig.muzzles.has(4),"chassis %d keeps bounded skinned armor and both real weapon sockets"%model)
		bodies.append({"head":bone_geometry(rig,"head"),"chest":bone_geometry(rig,"chest",false,true),"arm":bone_geometry(rig,"right_elbow"),"leg":bone_geometry(rig,"right_knee",true),"length":rig.UPPER_LEG+rig.LOWER_LEG})
		if model>=3:
			var gait_valid := true
			for frame in range(12):
				var sample := {"phase":frame*TAU/12.0,"blend":1.0,"velocity":Vector2(State.MECHS.MODELS[model].speed,0),"yaw":-2.1}
				view.update_model(model,sample,loadout,null,Vector2(1,0.6),frame/12.0,defense)
				for prefix in ["left","right"]:
					var hip: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_hip"]).origin
					var knee: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_knee"]).origin
					var foot: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_ankle"]).origin
					gait_valid = gait_valid and absf(hip.distance_to(knee)-rig.UPPER_LEG)<0.001 and absf(knee.distance_to(foot)-rig.LOWER_LEG)<0.001 and foot.distance_to(rig.stance_targets[prefix])<0.055
			check.call(gait_valid,"chassis %d walks at its real top speed with its own limb lengths and planted-foot IK"%model)
	check.call(widths[1]<widths[0] and widths[0]<widths[2],"light, assault and heavy chassis have distinct modeled proportions")
	check.call(widths[3]<widths[4] and widths[4]<widths[5] and silhouettes.slice(3).all(func(count): return silhouettes.count(count)==1),"new skirmisher, artillery and fortress have distinct body geometry and proportions, beyond their paint colors")
	check.call(bodies[3].length>bodies[5].length+0.3 and bodies[5].leg.size.x>bodies[3].leg.size.x*1.4,"the agile frame has physically longer legs while the lower fortress has substantially broader shin armor")
	check.call(bodies[5].chest.size.x>bodies[3].chest.size.x*1.4 and bodies[3].arm.size.x<bodies[4].arm.size.x and bodies[4].arm.size.x<bodies[5].arm.size.x,"front torso and forearm volumes differ without including backpack geometry or colors")
	check.call(bodies[5].head.size.y<bodies[3].head.size.y*0.65 and bodies[3].head.count!=bodies[4].head.count and bodies[4].head.count!=bodies[5].head.count,"the blade helmet, targeting head and sunken fortress visor use independently authored head geometry")
	view.update_model(0,pose,loadout,null,Vector2(1,0.6),1,defense)
	var rig = view.rig
	check.call(rig.body_mesh.skin!=null and rig.legs_mesh.skin!=null and rig.body_mesh.mesh.get_surface_count()<=8 and rig.legs_mesh.mesh.get_surface_count()<=8,"armor uses bounded GPU-skinned surfaces instead of hundreds of separate mesh draws")
	var max_foot_error := 0.0; var max_length_error := 0.0
	for speed in [35.0,100.0,235.0]:
		for frame in range(32):
			pose.phase = frame*TAU/32.0; pose.velocity = Vector2(speed,0)
			view.update_model(0,pose,loadout,null,Vector2(1,0.6),frame/32.0,defense)
			for prefix in ["left","right"]:
				var hip: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_hip"]).origin
				var knee: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_knee"]).origin
				var foot: Vector3 = rig.skeleton.get_bone_global_pose(rig.bones[prefix+"_ankle"]).origin
				max_length_error = maxf(max_length_error,maxf(absf(hip.distance_to(knee)-rig.UPPER_LEG),absf(knee.distance_to(foot)-rig.LOWER_LEG)))
				max_foot_error = maxf(max_foot_error,foot.distance_to(rig.stance_targets[prefix]))
	check.call(max_length_error<0.001,"walking and running never stretch a thigh or shin mesh")
	check.call(max_foot_error<0.055,"two-bone IK follows planted and lifted foot targets across walk and run cycles (error %.4f)"%max_foot_error)
	var directions_match := true
	for i in range(8):
		var direction := Vector2.from_angle(i*TAU/8)
		var ground: Vector3 = rig.PROJECTION.ground(direction)
		var projected: Vector2 = view.project(ground)-view.project(Vector3.ZERO)
		if projected.normalized().dot(direction)<0.999: directions_match = false
	check.call(directions_match,"all eight map directions project correctly through the tilted 3D camera")
	var slide_error := 0.0
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized()]:
		var planted = MOTION.new(); planted.blend = 1; planted.velocity = direction*100; planted.phase = 0.10
		planted.yaw = rig.PROJECTION.heading(direction); planted.yaw_initialized = true
		var position := Vector2.ZERO; var first := Vector2.ZERO
		for frame in range(10):
			planted.advance(0.005,direction*100,0,"walk",false,direction); position += direction*0.5
			view.update_model(0,planted.pose(),loadout,null,direction,frame*0.005,defense)
			var foot: Vector3 = rig.global_transform*rig.skeleton.get_bone_global_pose(rig.bones.right_ankle).origin
			var screen: Vector2 = view.project(foot)*0.43+position
			if frame==0: first = screen
			slide_error = maxf(slide_error,first.distance_to(screen))
	check.call(slide_error<0.5,"planted feet remain fixed in world space during horizontal, vertical and diagonal travel (drift %.4f)"%slide_error)
	var motion = MOTION.new(); motion.advance(0.016,Vector2(100,0),0,"walk")
	var before: float = motion.yaw; motion.advance(0.016,Vector2(-100,0),0,"walk")
	check.call(absf(wrapf(motion.yaw-before,-PI,PI))<0.6,"a reversal rotates through intermediate 3D angles instead of mirroring a picture")
	for frame in range(60): motion.advance(0.016,Vector2(-100,0),0,"walk",false,Vector2.RIGHT)
	check.call(absf(wrapf(motion.yaw+PI/2,-PI,PI))<0.02 and motion.velocity.x<0,"backpedaling retains target-facing 3D orientation")
	var previous: Vector2 = view.muzzle(0)
	pose.yaw += PI/2; view.update_model(0,pose,loadout,null,Vector2.DOWN,2,defense)
	check.call(previous.distance_to(view.muzzle(0))>10 and rig.scale==Vector3.ONE,"a quarter-turn changes actual projected gun position without negative sprite scale")
	check.call(view.muzzle(0).distance_to(view.project(rig.muzzles[0].global_position))<0.001,"beam origins are projected from the held 3D weapon's real muzzle marker")
	var aligned := true
	for point in [Vector2(-195,80),Vector2(210,-50),Vector2(80,180)]:
		pose.aim_point = point; pose.weapon_ready = true
		for frame in range(12):
			pose.clock = 3.0+frame*0.03
			view.update_model(0,pose,loadout,null,Vector2.DOWN,3.0+frame*0.03,defense)
		var muzzle: Vector3 = rig.muzzles[0].global_position
		var forward: Vector3 = -rig.muzzles[0].global_basis.z
		var projected: Vector2 = (view.project(muzzle+forward)-view.project(muzzle)).normalized()
		if projected.dot((point-view.muzzle(0)).normalized())<0.999: aligned = false
	check.call(aligned,"the actual 3D barrel and the beam to its screen target stay collinear at different heights and angles")
	pose.erase("aim_point"); pose.erase("weapon_ready"); pose.erase("clock")
	for mode in ["laser","missile","blade","gauntlet","hammer","hand_shield","rail","plasma","burst"]:
		loadout.weapons[0].mode = mode
		view.update_model(0,pose,loadout,null,Vector2.DOWN,2,defense)
		check.call(rig.mounts[0].get_parent()==rig.attachments.right_wrist and rig.muzzles[0] is Marker3D and rig.mounts[0].get_node("BatchedGeometry").mesh.get_surface_count()>1,"%s equips a modeled weapon at the wrist with a physical effect socket"%mode)
	loadout.weapons[0].mode = "blade"
	var engine = preload("res://scripts/attack_system.gd").new()
	engine.launch(Vector2.ZERO,Vector2(60,0),10,"blade","",1,{"slot":0})
	engine.swings[0].age = 0.2
	view.update_model(0,pose,loadout,null,Vector2.DOWN,2,defense)
	var offhand: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.left_shoulder)
	var arm: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)
	view.update_model(0,pose,loadout,engine,Vector2.DOWN,2,defense)
	check.call(arm.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder))>0.2 and offhand.is_equal_approx(rig.skeleton.get_bone_pose_rotation(rig.bones.left_shoulder)),"a real sword swing animates its shoulder and elbow while preserving the shield arm")
	defense.hit(5,{"shield":25,"armor":0},false,{"incoming":Vector2.LEFT})
	view.update_model(0,pose,loadout,engine,Vector2.DOWN,2,defense)
	check.call(rig.shield_material.get_shader_parameter("impact")>0.9 and rig.shield_material.get_shader_parameter("strength")==1.0,"real shield absorption lights the armor-attached 3D outline")
	loadout.drive = "hover"; view.update_model(0,pose,loadout,null,Vector2.DOWN,2,defense)
	check.call(rig.jets.all(func(jet): return jet.visible) and rig.stance_targets.left.y>0.3,"hover folds the 3D legs and starts the modeled thrusters")
	loadout.drive = "treads"; view.update_model(0,pose,loadout,null,Vector2.DOWN,2,defense)
	check.call(rig.tracks.all(func(track): return track.visible) and rig.leg_attachments.all(func(leg): return not leg.visible),"tread drive uses its 3D track chassis instead of walking legs")
	check.call(view.render_target_update_mode==SubViewport.UPDATE_ONCE,"inactive or hidden 3D previews do not render indefinitely")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image: Image = view.get_texture().get_image()
		var pixels := 0
		for y in range(0,image.get_height(),8):
			for x in range(0,image.get_width(),8):
				if image.get_pixel(x,y).a>0.5: pixels+=1
		check.call(image.get_pixel(0,0).a<0.01 and pixels>50,"the real 3D render contains opaque armor over a transparent background")
	var reference: WeakRef = weakref(view.rig); view.queue_free(); await main.get_tree().process_frame
	check.call(reference.get_ref()==null,"closing a preview releases its model, skeleton, weapons and viewport")

	await carry_checks(check,main)

func bone_geometry(rig: Node3D, bone_name: String, legs: bool = false, front_only: bool = false) -> Dictionary:
	var mesh: ArrayMesh = (rig.legs_mesh if legs else rig.body_mesh).mesh
	var bounds := AABB(); var count := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for i in range(vertices.size()):
			if bindings[i*4]!=int(rig.bones[bone_name]) or (front_only and vertices[i].z>=0): continue
			bounds = AABB(vertices[i],Vector3.ZERO) if count==0 else bounds.expand(vertices[i])
			count += 1
	return {"size":bounds.size,"count":count}

func carry_checks(check: Callable, main: Node) -> void:
	var view = VIEW.new(); main.add_child(view)
	var weapons := {"drive":"walk","weapons":[{"slot":0,"mode":"laser"},{"slot":4,"mode":"gauntlet"}]}
	var pose := {"phase":0.0,"blend":0.0,"velocity":Vector2.ZERO,"yaw":-2.5,"clock":0.0,"aim_point":Vector2(195,60),"ready_slots":{0:0.0,4:0.0}}
	var engine = preload("res://scripts/attack_system.gd").new()
	view.update_model(0,pose,weapons,engine,Vector2(1,0.6),0,null)
	var rig = view.rig
	var hand: Vector3 = rig.attachments.right_wrist.global_position
	var idle: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)
	var offhand: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.left_shoulder)
	check.call(hand.y<rig.attachments.right_elbow.global_position.y-0.25 and rig.muzzle_position(0).y<hand.y-0.3 and rig.attachments.left_wrist.global_position.y<rig.attachments.left_elbow.global_position.y-0.25,"equipped rifle and gauntlet rest below their elbows with the rifle pointed down, even when a screen aim point exists")
	check.call(rig.muzzle_position(0).distance_to(hand)>1.35,"the enlarged rifle has a readable physical silhouette without enlarging the mech")
	pose.ready_slots[0] = 1.0; pose.clock = 0.02
	view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	var first: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)
	check.call(first.angle_to(idle)>0.001 and first.angle_to(idle)<0.15,"acquiring a target starts a gradual raise instead of snapping both hands up")
	for frame in range(1,21):
		pose.clock = 0.02+frame*0.02
		view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	check.call(rig.attachments.right_wrist.global_position.y>hand.y+0.4 and offhand.is_equal_approx(rig.skeleton.get_bone_pose_rotation(rig.bones.left_shoulder)),"only the ranged weapon in range raises; the inactive offhand stays relaxed")
	engine.launch(Vector2.ZERO,Vector2(195,60),10,"laser","",1,{"slot":0})
	pose.ready_slots[0] = 0.0; pose.clock = 0.44
	view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	var muzzle: Vector3 = rig.muzzles[0].global_position
	var axis: Vector2 = (view.project(muzzle-rig.muzzles[0].global_basis.z)-view.project(muzzle)).normalized()
	check.call(axis.dot((Vector2(pose.aim_point)-view.muzzle(0)).normalized())>0.999,"a real beam keeps the enlarged barrel aligned with its target throughout firing")
	engine.reset()
	for frame in range(1,25):
		pose.clock = 0.44+frame*0.04
		view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	check.call(rig.attachments.right_wrist.global_position.distance_to(hand)<0.015,"after a brief follow-through the rifle returns to its natural carry position")
	var frozen: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)
	pose.ready_slots[0] = 1.0
	for frame in range(4): view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	check.call(frozen.is_equal_approx(rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)),"redrawing a paused frame cannot advance the arm transition")
	pose.ready_slots[0] = 0.0; weapons.weapons[0].mode = "missile"; weapons.weapons[1].mode = "hand_shield"
	pose.clock = 2.0; engine.launch(Vector2.ZERO,Vector2(195,60),10,"missile","",1,{"slot":0})
	view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null); engine.flashes.clear()
	for frame in range(1,21):
		pose.clock = 2.0+frame*0.05
		view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
	check.call(not engine.projectiles.is_empty() and rig.attachments.right_wrist.global_position.y<rig.attachments.right_elbow.global_position.y-0.25 and rig.attachments.left_wrist.global_position.y<rig.attachments.left_elbow.global_position.y-0.25,"a missile still in flight does not hold the launcher or shield arm permanently raised")
	for mode in ["blade","hammer","gauntlet"]:
		engine.reset(); weapons.weapons[0].mode = mode
		view.update_model(0,pose,weapons,null,Vector2(1,0.6),pose.clock,null)
		var shoulder: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder)
		var wrist: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.bones.right_wrist)
		engine.launch(Vector2.ZERO,Vector2(60,0),10,mode,"",1,{"slot":0})
		var continuous := true
		for age in [0.0,float(rig.MELEE.RULES[mode].duration)-0.0001]:
			engine.swings[0].age = age
			view.update_model(0,pose,weapons,engine,Vector2(1,0.6),pose.clock,null)
			if shoulder.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bones.right_shoulder))>0.02 or wrist.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bones.right_wrist))>0.02: continuous = false
		check.call(continuous,"%s enters and leaves an attack from the natural carry pose without an arm or wrist snap"%mode)
	view.queue_free(); await main.get_tree().process_frame
