extends RefCounted
const MOTION = preload("res://scripts/mech_motion.gd")
const MECH = preload("res://scripts/mech_art.gd")
const SHIELD = preload("res://scripts/shield_visual.gd")
const ATTACK = preload("res://scripts/attack_system.gd")
const VISUAL = preload("res://scripts/attack_visuals.gd")
class Arena extends Node:
	var target := Vector2(240,0)
	func attack_targets() -> Array: return [{"id":"target","p":target,"hp":100000.0}]
	func player_position() -> Vector2: return Vector2.ZERO
	func player_alive() -> bool: return true
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(point: Vector2) -> Vector2i: return Vector2i(point/128)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func apply_attack_event(event: Dictionary) -> float: return float(event.damage)
class Gallery extends Control:
	var phase: float = PI/2
	var draws: int = 0
	var engines: Array = []
	var shield = preload("res://scripts/defense_runtime.gd").new()
	var feedback = preload("res://scripts/field_feedback.gd").new()
	func _draw() -> void:
		draws += 1
		draw_rect(Rect2(0,0,720,1280),Color("101927"))
		var font = preload("res://assets/fonts/NotoSansSC.otf")
		draw_string(font,Vector2(25,40),"3D 骨骼机甲 / 关节步态 / 武器动作",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		for model in range(3):
			var motion = MOTION.new(); motion.phase = phase; motion.blend = 1; motion.velocity = Vector2(80,0)
			var loadout := {"drive":"walk","weapons":[],"backpack":-1,"armor":-1,"core":-1}
			MECH.render(self,Vector2(120+240*model,180),1,MECH.COLORS[model],false,0,motion.pose(),loadout,null,Vector2(1,0.6),shield,"chassis%d"%model)
			draw_string(font,Vector2(70+240*model,325),["赤鸢 · 迈步","夜莺 · 迈步","白隼 · 迈步"][model],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
		for i in range(engines.size()):
			var y := 400+i*160
			var mode: String = ["laser","missile","blade","gauntlet","hammer"][i]
			var loadout := {"drive":"walk","weapons":[{"slot":0,"mode":mode,"blueprint":MECH.CONTENT.WEAPONS[mode]}]}
			MECH.render(self,Vector2(110,y+20),0.55,MECH.COLORS[0],false,0,{},loadout,engines[i],Vector2(1,0.4),null,"weapon%d"%i)
			VISUAL.render(self,engines[i],func(point): return point+Vector2(140,y+20),1)
			draw_string(font,Vector2(475,y+20),["持续激光","追踪导弹","能量剑横斩","拳套连击","重锤震击"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		feedback.render(self,func(point): return point,1)

func run(check: Callable, main: Node) -> void:
	var motion = MOTION.new()
	for i in range(5): motion.advance(0.1,Vector2(200,0),0,"walk")
	var pose: Dictionary = motion.pose()
	check.call(pose.stride==1 and pose.velocity.x>0 and pose.phase>0,"actual movement drives the 3D gait clock and velocity")
	var phase: float = motion.phase
	for i in range(5): motion.advance(0.1,Vector2.ZERO,0,"walk")
	check.call(motion.phase==phase and motion.pose().stride==0,"blocked motion or released input stops the step cycle and settles to idle")
	motion.advance(0.1,Vector2(-200,0),0,"walk")
	check.call(motion.facing==-1 and motion.lean<0,"turning left changes facing and banks the body into motion")
	motion.advance(0.1,Vector2(200,0),0,"hover")
	check.call(motion.pose().stride==0 and motion.pose().left.y<0 and motion.pose().bob<0,"hover drive tucks its legs and glides instead of playing a walking cycle")
	motion.advance(0.1,Vector2(400,0),0,"dash",true)
	check.call(motion.pose().boost and motion.pose().stride==0,"active dash switches from footsteps to a thrust pose")
	motion.advance(0.1,Vector2(160,0),2,"treads")
	check.call(motion.pose().stride==0 and motion.phase!=phase,"treads roll without alternating humanoid feet")
	motion.drive = "walk"; motion.boost = false; motion.phase = PI/2; motion.blend = 1
	var defense = preload("res://scripts/defense_runtime.gd").new()
	var stats := {"armor":0,"shield":20}
	defense.configure(stats,true); defense.hit(10,stats,false,{"incoming":Vector2.LEFT})
	check.call(defense.shield==10 and defense.hp==100 and is_equal_approx(defense.shield_flash,0.22) and is_equal_approx(absf(defense.shield_hit_angle),PI),"real absorbed damage triggers a short directional shield edge flash without changing damage rules")
	defense.advance(0.3,stats,false)
	check.call(defense.shield_flash==0 and SHIELD.IDLE_ALPHA<0.3,"shield impact glow fades and passive edge opacity stays low")
	await load("res://tests/rig_3d_checks.gd").new().run(check,main)
	var effects = preload("res://scripts/field_feedback.gd").new()
	for i in range(100): effects.push("hit",Vector2(i*30,0))
	check.call(effects.events.size()==effects.LIMIT,"dense combat cannot grow the secondary effects pool without bound")
	effects.advance(2)
	check.call(effects.events.is_empty(),"all secondary particles expire instead of leaving persistent visual clutter")
	var arena := Arena.new(); main.add_child(arena)
	var gallery := Gallery.new(); gallery.size = Vector2(720,1280); gallery.z_index = 100; main.add_child(gallery)
	gallery.shield.configure(stats,true)
	var effect_index := 0
	for kind in gallery.feedback.LIFETIMES:
		gallery.feedback.push(kind,Vector2(70+effect_index*60,350),Vector2(600,350))
		effect_index += 1
	gallery.feedback.advance(0.1)
	for mode in ["laser","missile","blade","gauntlet","hammer"]:
		var engine = ATTACK.new()
		arena.target = Vector2(240,0) if mode in ["laser","missile"] else Vector2(55,0)
		engine.launch(Vector2.ZERO,arena.target,100,mode,"",1,{"slot":0,"range":300,"target_id":"target"})
		engine.advance(arena,0.2 if mode=="blade" else 0.12 if mode=="gauntlet" else 0.38 if mode=="hammer" else 0.25)
		gallery.engines.append(engine)
		if mode=="laser": check.call(not engine.beams.is_empty() and engine.beams[0].lit and engine.projectiles.is_empty(),"laser visuals are driven by a sustained hit-tested ray, not a flying projectile")
		elif mode=="missile":
			check.call(engine.projectiles[0].trail.size()>2 and engine.projectiles[0].trail.size()<=9,"missile exhaust follows bounded real flight samples")
			arena.target = Vector2(200,100); engine.advance(arena,0.2)
			check.call(engine.projectiles[0].direction.y>0 and engine.projectiles[0].trail.back().y>0,"tracking missiles bend their visible trail toward a moving target")
		else:
			var action: Dictionary = MECH.attack_pose(engine,0)
			var was_active: bool = engine.swings[0].active
			engine.advance(arena,0.04)
			var later: Dictionary = MECH.attack_pose(engine,0)
			check.call(was_active and (absf(action.angle-later.angle)>0.1 or absf(action.extension-later.extension)>1),"%s held weapon moves through its contact window, including its neutral crossing"%mode)
			check.call(MECH.attack_pose(engine,4)=={"angle":0.0,"extension":0.0},"%s cannot animate an uninvolved offhand"%mode)
	for frame in range(2):
		gallery.phase = PI/2+frame*PI; gallery.queue_redraw()
		await main.get_tree().process_frame; await main.get_tree().process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png("res://.local/motion-preview-%d.png"%frame)
	check.call(gallery.draws>=2,"three articulated chassis, open-center shields and five weapon families execute real draw callbacks")
	gallery.queue_free(); arena.queue_free()
	var saved: Dictionary = State.save_payload().duplicate(true)
	main.show_motion_review()
	var review = main.overlay.find_child("MotionReview",true,false)
	review.set_process(false); review._process(0.1); review.impact()
	var review_draws: Array = [0]
	review.draw.connect(func(): review_draws[0]+=1)
	review.queue_redraw()
	await main.get_tree().process_frame; await main.get_tree().process_frame
	check.call(review_draws[0]>0,"the actual in-game review draws the moving chassis, fitted shield and weapon effects")
	for frame in range(10): review._process(0.1)
	check.call(not review.attack_demo and review.engine.stats.fired==0,"the review starts with natural carry and movement instead of automatic attacks")
	review.set_attack_demo(true)
	for frame in range(10): review._process(0.1)
	check.call(review.engine.stats.fired>0,"the explicit attack demo plays real attacks after a preparation window")
	review.set_attack_demo(false)
	for frame in range(10): review._process(0.1)
	check.call(review.engine.stats.fired==0 and review.engine.swings.is_empty() and review.engine.beams.is_empty(),"turning the attack demo off stops new shots and clears active preview attacks")
	var time_before: float = review.clock; review.paused = true; review.impact(); review._process(0.1)
	check.call(review.clock==time_before and review.defense.shield_flash>0,"the in-game review can freeze the exact pose and shield impact")
	review.paused = false; review.rate = 0.5; review._process(0.1)
	var after: Dictionary = State.save_payload(); after.erase("last_seen")
	var before: Dictionary = saved.duplicate(true); before.erase("last_seen")
	check.call(is_equal_approx(review.clock-time_before,0.05) and after==before,"half-speed viewing and demonstration hits cannot mutate actual equipment, armor or resources")
	main.close_modal()
	var enabled: bool = World.enabled
	State.expedition = State.EXPEDITION.new(); State.recovery = 0
	World.import_save({"docked":true}); State.expedition.begin(World,0)
	var received: Array = []
	var collect := func(kind,point,target): received.append({"kind":kind,"p":point,"target":target})
	State.field_effect.connect(collect)
	var supply: Dictionary = State.expedition.locations.filter(func(site): return site.kind=="supply")[0]
	World.position = supply.p; State.expedition.reveal(supply.p); received.clear()
	var mission: int = State.expedition.run.id
	check.call(State.expedition.interact(World,supply.id,1,mission) and received.any(func(item): return item.kind=="loot" and item.p==supply.p and item.target==World.position),"successful facility recovery emits a world-anchored collection effect")
	received.clear()
	check.call(not State.expedition.interact(World,supply.id,1,mission) and received.is_empty(),"a used or rejected facility cannot replay success particles")
	State.field_effect.disconnect(collect)
	State.import_game(saved); World.enabled = enabled
