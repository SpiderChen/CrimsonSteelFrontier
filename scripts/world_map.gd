extends "res://scripts/battlefield.gd"
## A single continuous camera over deterministic chunks, with tap paths and drag/pinch navigation.
const ATTACK_VISUALS = preload("res://scripts/attack_visuals.gd")
const CARRIER = preload("res://scripts/carrier.gd")
const SCENERY = preload("res://scripts/battlefield_scenery.gd")
var scenery = SCENERY.new()
const MAP_FONT = preload("res://assets/fonts/NotoSansSC.otf")
signal carrier_selected
var carrier_button: Button
var radar_visible: bool = false
var camera := Vector2.ZERO
var zoom: float = 0.88
var following: bool = true
var fingers: Dictionary = {}
var pointer_origin := Vector2.ZERO
var pointer_last := Vector2.ZERO
var dragged: bool = false
var pointer_down: bool = false
var joystick: bool = false
var pinch: bool = false
var pinch_distance: float = 0
var stick := Vector2.ZERO
var manual_steering: bool = false
const STICK_RADIUS: float = 66.0
const STICK_DEADZONE: float = 9.0
var stick_origin := Vector2.ZERO
var stick_layer: Node2D
var primary_finger: int = -1
var camera_drag: bool = false
var weapon_effects: Array = []
var trails: Array = []
var trail_clock: float = 0
var last_hit_point := Vector2.ZERO
var mech_motion = preload("res://scripts/mech_motion.gd").new()
var field_feedback = preload("res://scripts/field_feedback.gd").new()
var previous_speed: float = 0
var was_boosting: bool = false

func _ready() -> void:
	camera = World.position
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	State.shot.connect(on_shot)
	State.weapon_fired.connect(on_weapon_fired)
	State.attack_hit.connect(on_attack_hit)
	State.field_effect.connect(on_field_effect)
	State.victory.connect(on_destroyed)
	World.enemy_fired.connect(on_enemy_fired)
	stick_layer = Node2D.new()
	stick_layer.z_index = 30
	add_child(stick_layer)
	stick_layer.draw.connect(draw_stick)
	carrier_button = Button.new()
	carrier_button.name = "CarrierDockButton"
	carrier_button.text = "绯红方舟 · 停泊"
	carrier_button.size = Vector2(176,46)
	carrier_button.focus_mode = Control.FOCUS_NONE
	carrier_button.mouse_filter = Control.MOUSE_FILTER_STOP
	carrier_button.z_index = 10
	carrier_button.add_theme_font_size_override("font_size",18)
	carrier_button.add_theme_color_override("font_color",Color("b4f5e4"))
	for mode in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("163e49") if mode=="hover" else Color("0a202b")
		style.border_color = Color("64b8ba")
		style.set_border_width_all(1); style.set_corner_radius_all(6)
		carrier_button.add_theme_stylebox_override(mode,style)
	carrier_button.pressed.connect(func():
		Sfx.activate(); Sfx.play("click",-27)
		carrier_selected.emit())
	add_child(carrier_button)
	update_carrier_marker()

func carrier_position() -> Vector2:
	return State.carrier.ops.position() if State.expedition.active() else World.START

func update_carrier_marker() -> void:
	if not is_instance_valid(carrier_button): return
	carrier_button.position = to_screen(carrier_position())+Vector2(-carrier_button.size.x*0.5,80*zoom)
	carrier_button.text = "绯红方舟 · 指挥" if State.expedition.active() else "绯红方舟 · 停泊"
	carrier_button.visible = not World.docked and Rect2(Vector2.ZERO,size).intersects(Rect2(carrier_button.position,carrier_button.size))

func _exit_tree() -> void:
	reset_input()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
		reset_input()

func reset_input() -> void:
	var was_manual := manual_steering or joystick
	World.steering = Vector2.ZERO
	fingers.clear()
	primary_finger = -1
	pointer_down = false
	joystick = false
	manual_steering = false
	pinch = false
	camera_drag = false
	stick = Vector2.ZERO
	if was_manual: State.save_game()

func to_screen(p: Vector2) -> Vector2:
	return (p-camera)*zoom+size/2

func to_world(p: Vector2) -> Vector2:
	return (p-size/2)/zoom+camera

func recenter() -> void:
	following = true
	camera = World.position

func zoom_at(value: float, point: Vector2) -> void:
	var anchor := to_world(point)
	zoom = clampf(value,0.38,1.4)
	camera = World.bounded(anchor-(point-size/2)/zoom)

func pointer_press(p: Vector2) -> void:
	Sfx.activate()
	pointer_origin = p
	pointer_last = p
	stick_origin = p
	pointer_down = true
	dragged = false
	joystick = true
	stick = Vector2.ZERO
	manual_steering = true
	following = true
	World.set_patrol(false)
	World.path.clear()
	World.steering = Vector2.ZERO

func pointer_move(p: Vector2) -> void:
	if not pointer_down or not joystick or pinch: return
	var offset := p-stick_origin
	if offset.length()>STICK_RADIUS:
		stick_origin = p-offset.normalized()*STICK_RADIUS
	stick = (p-stick_origin).limit_length(STICK_RADIUS)
	var strength := clampf((stick.length()-STICK_DEADZONE)/(STICK_RADIUS-STICK_DEADZONE),0,1)
	World.steering = stick.normalized()*strength
	dragged = dragged or p.distance_to(pointer_origin)>STICK_DEADZONE
	pointer_last = p

func pointer_release(_p: Vector2) -> void:
	World.steering = Vector2.ZERO
	World.path.clear()
	World.destination = World.position
	manual_steering = false
	stick = Vector2.ZERO
	joystick = false
	pointer_down = false
	State.save_game()

func _input(event: InputEvent) -> void:
	# A lift over a HUD button/outside the map must still stop the original thumb.
	if event is InputEventScreenTouch and not event.pressed and event.index==primary_finger:
		release_fallback.call_deferred(event.index)

func release_fallback(index: int) -> void:
	if fingers.has(index): reset_input()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			if fingers.size()==1 and not pinch:
				primary_finger = event.index
				pointer_press(event.position)
			elif fingers.size()==2:
				pinch = true
				joystick = false
				World.steering = Vector2.ZERO
				manual_steering = false
				following = false
				pinch_distance = fingers.values()[0].distance_to(fingers.values()[1])
		else:
			fingers.erase(event.index)
			if event.index==primary_finger: pointer_release(event.position)
			if fingers.is_empty():
				primary_finger = -1
				pinch = false
		accept_event()
	elif event is InputEventScreenDrag:
		if not fingers.has(event.index): return
		if fingers.size()==2:
			var before := fingers.values()
			var old_mid: Vector2 = (before[0]+before[1])/2
			fingers[event.index] = event.position
			var values := fingers.values()
			var mid: Vector2 = (values[0]+values[1])/2
			camera = World.bounded(camera-(mid-old_mid)/zoom)
			var length: float = values[0].distance_to(values[1])
			if pinch_distance>5: zoom_at(zoom*length/pinch_distance,mid)
			pinch_distance = length
		elif event.index==primary_finger and not pinch:
			fingers[event.index] = event.position
			pointer_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.device!=-1:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_at(zoom*1.13,event.position)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_at(zoom/1.13,event.position)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			camera_drag = event.pressed
			pointer_last = event.position
			following = false
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: pointer_press(event.position)
			else: pointer_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.device!=-1:
		if camera_drag:
			camera = World.bounded(camera-(event.position-pointer_last)/zoom)
			pointer_last = event.position
		else: pointer_move(event.position)
		accept_event()

func draw_stick() -> void:
	if not joystick or pinch: return
	stick_layer.draw_circle(stick_origin,STICK_RADIUS,Color(0.03,0.07,0.1,0.63))
	stick_layer.draw_arc(stick_origin,STICK_RADIUS,0,TAU,64,Color(0.55,0.9,0.85,0.7),2,true)
	stick_layer.draw_line(stick_origin,stick_origin+stick,Color(0.6,0.94,0.86,0.5),4,true)
	stick_layer.draw_circle(stick_origin+stick,27,Color(0.5,0.85,0.78,0.68))
	stick_layer.draw_arc(stick_origin+stick,27,0,TAU,40,Color(0.85,1,0.95,0.9),2,true)

func damage_number(point: Vector2, damage: int, friendly: bool) -> void:
	# Merge only the first 120 ms of one nearby burst; keep the original expiry.
	for f in floats:
		if f.friendly==friendly and f.t>0.88 and Vector2(f.get("anchor",f.p)).distance_to(point)<28:
			f.v = str(int(f.v)+damage)
			return
	floats.append({"p":point,"anchor":point,"t":1.0,"v":str(damage),"friendly":friendly})
	if floats.size()>32: floats.pop_front()

func on_shot(friendly: bool, damage: int) -> void:
	if not friendly:
		field_feedback.push("hit",World.position-Vector2(0,20))
		enemy_flash = 0.2
		weapon_effects.append({"mode":"impact","from":World.position,"target":World.position,"critical":false,"t":0.18,"life":0.18})
		if weapon_effects.size()>64: weapon_effects.pop_front()
		damage_number(World.position,damage,false)

func on_attack_hit(point: Vector2, damage: int, mode: String) -> void:
	last_hit_point = point
	damage_number(point,damage,true)
	field_feedback.push("hit",point-Vector2(0,20))
	# These hits already render from the shared attack stream, including plasma's blast.
	if mode in ["standard","burst","rail","plasma","laser","pulse","missile","blade","gauntlet","hammer"]: return
	weapon_effects.append({"mode":"explosion" if mode in ["plasma","explosion"] else "impact","from":point,"target":point,"critical":false,"color":Color("c189ff") if mode in ["plasma","explosion"] else Color("ffbb73"),"t":0.45})
	if weapon_effects.size()>48: weapon_effects.pop_front()

func on_destroyed() -> void:
	var point: Vector2 = last_hit_point
	field_feedback.push("destroy",point-Vector2(0,20))
	weapon_effects.append({"mode":"explosion","from":point,"target":point,"critical":false,"color":Color("ff9e64"),"t":0.45})

func on_weapon_fired(mode: String, from: Vector2, target: Vector2, critical: bool) -> void:
	if preload("res://scripts/melee.gd").is_mode(mode): return
	if mode!="ultimate": return
	var color := Color("c189ff") if mode=="plasma" else Color("87e5ff") if mode=="rail" else Color("ffbb73")
	if State.parts.has_trait(State.selected_mech,"overdrive"): color = Color("ff6854")
	if State.parts.has_trait(State.selected_mech,"charge"): color = Color("7ddfff")
	weapon_effects.append({"mode":mode,"from":from,"target":target,"critical":critical,"color":color,"t":0.45})

func mech_pose() -> Dictionary:
	var result: Dictionary = mech_motion.pose()
	result.ready_slots = {0:0.0,4:0.0}
	if World.encounter_id!="":
		result.aim_point = (World.encounter_position-World.position+Vector2(0,8))/0.43
		var distance: float = World.position.distance_to(World.encounter_position)
		if State.hp>0 and World.line_clear(World.position,World.encounter_position):
			for slot in [0,4]:
				result.ready_slots[slot] = float(World.target_in_range() if State.weapon_mode(slot)=="hand_shield" else distance<=State.weapon_range(slot)+32)
	return result

func draw_weapon_effects() -> void:
	var mech = preload("res://scripts/mech_art.gd")
	var aim := World.position.direction_to(World.encounter_position) if World.encounter_id!="" else Vector2(-sin(mech_motion.yaw),-cos(mech_motion.yaw)*mech_motion.PROJECTION.GROUND_Y).normalized()
	var muzzle := func(slot): return to_screen(World.position)-Vector2(0,28)*zoom+mech.muzzle_offset(int(State.mechs.units[State.selected_mech].model),mech_pose(),mech.appearance(),World.attacks,aim,slot,0.43*zoom,self)
	ATTACK_VISUALS.render(self,World.attacks,to_screen,zoom,-Vector2(0,20)*zoom,muzzle,true)
	if State.expedition.active():
		var strike: Dictionary = State.expedition.run.support.pending
		if not strike.is_empty():
			var point := to_screen(Vector2(strike.point[0],strike.point[1]))
			var radius: float = float(strike.radius)*zoom
			draw_circle(point,radius,Color(0.4,0.9,1,0.10))
			draw_arc(point,radius,0,TAU,48,Color("7ddfff"),2*zoom,true)
			draw_line(point-Vector2(22,0)*zoom,point+Vector2(22,0)*zoom,Color("7ddfff"),2*zoom,true)
			draw_line(point-Vector2(0,22)*zoom,point+Vector2(0,22)*zoom,Color("7ddfff"),2*zoom,true)
			draw_string(MAP_FONT,point+Vector2(-55,-radius-12),"舰炮落点 %.1fs" % strike.remaining,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("7ddfff"))
	for effect in weapon_effects:
		var point := to_screen(effect.target)-Vector2(0,20)*zoom
		var progress: float = clampf(1-float(effect.t)/float(effect.get("life",0.45)),0,1)
		if effect.mode=="muzzle": CONTENT.fx(self,"fx-kinetic",0,point,Vector2.ONE*42*zoom,progress,(effect.aim-effect.from).angle())
		elif effect.mode=="explosion": CONTENT.fx(self,"fx-kinetic",2,point,Vector2.ONE*135*zoom,progress)
		elif effect.mode=="impact": CONTENT.fx(self,"fx-kinetic",1,point,Vector2.ONE*42*zoom,progress)
		else: CONTENT.fx(self,"fx-support",2,point,Vector2.ONE*145*zoom,progress)
		if effect.critical: draw_string(MAP_FONT,point+Vector2(-25,-22),"暴击",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe0a0"))

func on_enemy_fired(_from: Vector2, _damage: int) -> void:
	weapon_effects.append({"mode":"muzzle","from":_from,"target":_from,"aim":World.position,"critical":false,"t":0.14,"life":0.14})
	if weapon_effects.size()>64: weapon_effects.pop_front()

func _process(delta: float) -> void:
	if State.story_paused: return
	elapsed += delta
	var look := World.position.direction_to(World.encounter_position) if World.encounter_id!="" else Vector2.ZERO
	mech_motion.advance(delta,World.actual_velocity,int(State.mechs.units[State.selected_mech].model),World.drive_mode(),World.drive_mode()=="dash" and World.drive_clock>=2.4,look)
	field_feedback.advance(delta)
	for foot in mech_motion.take_contacts():
		field_feedback.push("step",World.position+Vector2(foot*12,20),World.actual_velocity)
		Sfx.on_field_effect("step",World.position+Vector2(foot*12,20),World.actual_velocity)
	var speed: float = World.actual_velocity.length()
	if previous_speed>70 and speed<5:
		field_feedback.push("brake",World.position+Vector2(0,20),mech_motion.velocity)
		Sfx.on_field_effect("brake",World.position,mech_motion.velocity)
	if mech_motion.boost and not was_boosting:
		field_feedback.push("boost",World.position+Vector2(0,20),World.actual_velocity)
		Sfx.on_field_effect("boost",World.position,World.actual_velocity)
	previous_speed = speed; was_boosting = mech_motion.boost
	if following:
		var focus: Vector2 = World.position.lerp(World.boss.position,0.5)+Vector2(90,-66)/zoom if World.boss.active else World.position
		camera = camera.lerp(focus,1.0-exp(-delta*7))
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction!=Vector2.ZERO:
		World.set_patrol(false)
		World.steering = direction.normalized()
		manual_steering = true
		following = true
	elif manual_steering and not joystick:
		World.steering = Vector2.ZERO
		manual_steering = false
	flash = maxf(0,flash-delta)
	enemy_flash = maxf(0,enemy_flash-delta)
	burst = maxf(0,burst-delta)
	for f in floats:
		f.t -= delta
		f.p.y -= delta*35
	floats = floats.filter(func(f): return f.t>0)
	for effect in weapon_effects: effect.t -= delta
	weapon_effects = weapon_effects.filter(func(e): return e.t>0)
	for trail in trails: trail.t -= delta
	trails = trails.filter(func(e): return e.t>0)
	trail_clock -= delta
	if World.actual_velocity.length()>1 and trail_clock<=0:
		trail_clock = 0.05
		trails.append({"p":World.position,"mode":World.drive_mode(),"boost":World.drive_clock>=2.4,"t":0.5,"angle":World.actual_velocity.angle()})
	update_carrier_marker()
	queue_redraw()
	if is_instance_valid(stick_layer): stick_layer.queue_redraw()

func on_field_effect(kind: String, point: Vector2, target: Vector2) -> void:
	field_feedback.push(kind,point,target)

func world_text(p: Vector2, text_value: String, color: Color, font_size: int = 17) -> void:
	draw_string(MAP_FONT,p,text_value,HORIZONTAL_ALIGNMENT_CENTER,-1,font_size,color)

func terrain_known(point: Vector2) -> bool:
	return not State.expedition.active() or State.expedition.revealed(point)

func terrain_region(point: Vector2) -> int:
	return int(State.expedition.run.region) if State.expedition.active() else World.biome(point)

func terrain_seed() -> int:
	return int(State.expedition.run.seed) if State.expedition.active() else 0

func tile(c: Vector2i) -> void:
	var p := Vector2(c)*World.CELL
	if not terrain_known(p+Vector2.ONE*World.CELL/2.0): return
	var region := terrain_region(p)
	var spacing: int = 4 if State.expedition.active() else 8
	var vertical: bool = posmod(c.x,spacing)==0
	var horizontal: bool = posmod(c.y,spacing)==0
	var column: int = int(vertical)+int(horizontal)*2
	var detail := zoom>=0.6
	var data: Dictionary = scenery.cell_data(c,region,terrain_seed()) if detail else {"shade":0.95,"turn":posmod(c.x+c.y,4)}
	var color := Color.WHITE.lerp(SCENERY.PALETTES[region].wash,0.28)*float(data.shade)
	color.a = 1.0
	CONTENT.quad(self,"terrain",region*4+column,p+Vector2.ONE*64,Vector2.ONE*World.CELL,int(data.turn)*PI/2 if column==0 else 0,color,false)
	scenery.ground(self,c,region,terrain_seed(),column!=0,detail)
	scenery.road_edge(self,c,region,vertical,horizontal,detail)

func draw_scenery(low: Vector2i, high: Vector2i, view: Rect2) -> void:
	var detail := zoom>=0.6
	# Broad landmarks sit beneath props and only use places the mech has discovered.
	var ship := carrier_position()
	if terrain_known(ship) and view.grow(240).has_point(ship): scenery.apron(self,ship,"landing",terrain_region(ship),MAP_FONT)
	if State.expedition.active():
		for site in State.expedition.sites():
			if site.kind not in ["boss_site","cache","supply","cooling"] or not view.grow(180).has_point(site.p): continue
			if terrain_known(site.p): scenery.apron(self,site.p,site.kind,terrain_region(site.p),MAP_FONT)
	# A second pass prevents the next tile from painting over a building's shadow.
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			var p := Vector2(cell)*World.CELL
			if not terrain_known(p+Vector2.ONE*64): continue
			var region := terrain_region(p)
			if World.is_obstacle(cell):
				scenery.foundation(self,cell,region,detail)
				ART.building(self,p,region,World.cell_hash(cell))
				scenery.obstacle_details(self,cell,region,terrain_seed(),elapsed,detail)
			else:
				var spacing: int = 4 if State.expedition.active() else 8
				if posmod(x,spacing)!=0 and posmod(y,spacing)!=0 and World.cell_hash(cell)%4==0:
					SCENERY.ellipse(self,p+Vector2(69,83),Vector2(29,10),Color.BLACK,0.22)
					ART.vegetation(self,p,region,World.cell_hash(cell))
	scenery.air(self,view,terrain_region(camera),elapsed,terrain_known)
	if State.expedition.active(): scenery.fog(self,low,high,terrain_known)

func _draw() -> void:
	var top_left := to_world(Vector2.ZERO)
	var bottom_right := to_world(size)
	var low := World.cell_at(top_left)-Vector2i.ONE
	var high := World.cell_at(bottom_right)+Vector2i.ONE
	draw_rect(Rect2(Vector2.ZERO,size),Color("111d25"))
	draw_set_transform(size/2-camera*zoom,0,Vector2.ONE*zoom)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1): tile(Vector2i(x,y))
	draw_scenery(low,high,Rect2(top_left,bottom_right-top_left))
	if State.expedition.active(): draw_rect(State.expedition.bounds(),Color("4a7b85"),false,5)
	# Show the complete collision cell, including the margins outside the artwork.
	for cell in World.blocked_cells:
		var rect := Rect2(Vector2(cell)*World.CELL,Vector2.ONE*World.CELL)
		draw_rect(rect,Color(1,0.55,0.2,0.12))
		draw_rect(rect.grow(-2),Color(1,0.65,0.3,0.85),false,3)
	# The entire route stays in world space and crosses chunk boundaries continuously.
	if World.is_moving() and World.path.size()>1:
		var points := PackedVector2Array([World.position])
		for i in range(World.path_index,World.path.size()): points.append(World.path[i])
		if points.size()>1: draw_polyline(points,Color(0.6,0.89,0.84,0.65),3,true)
		draw_arc(World.destination,19+sin(elapsed*4)*2,0,TAU,32,Color("8fe3c7"),2,true)
	var chunk_low := World.chunk_at(top_left)-Vector2i.ONE
	var chunk_high := World.chunk_at(bottom_right)+Vector2i.ONE
	var visible_sites: Array = []
	for y in range(chunk_low.y,chunk_high.y+1):
		for x in range(chunk_low.x,chunk_high.x+1):
			visible_sites.append_array(World.sites(Vector2i(x,y)))
	var seen: Dictionary = {}
	for site in visible_sites: seen[site.id] = true
	for id in World.enemy_units:
		if not seen.has(id):
			var unit: Dictionary = World.enemy_units[id]
			visible_sites.append({"id":id,"kind":"enemy","p":unit.home,"name":unit.name})
	if World.boss.active: visible_sites.clear()
	for site in visible_sites:
		if site.id.begins_with("boss:"): continue
		if World.cleared.has(site.id) and site.kind!="beacon": continue
		var p: Vector2 = World.site_position(site)
		if site.kind=="enemy":
			if not Rect2(Vector2.ZERO,size).grow(100).has_point(to_screen(p)): continue
			var elite: bool = World.enemy_units.get(site.id,{}).get("elite",site.get("elite",false))
			draw_texture_rect(CROSSHAIR,Rect2(p-Vector2.ONE*38,Vector2.ONE*76),false,Color(1,0.7,0.6,0.45))
			draw_circle(p,37,Color(0.9,0.25,0.27,0.1))
			draw_arc(p,30,0,TAU,32,Color("f16d69"),2,true)
			draw_set_transform(Vector2.ZERO)
			CONTENT.enemy(self,to_screen(p),str(World.enemy_units.get(site.id,{}).get("role",site.get("role","guard"))),elite,zoom*(1.12 if elite else 1.0),p.x>World.position.x,site.id,p.direction_to(World.position),bool(World.enemy_units.get(site.id,{}).get("moving",false)),elapsed)
			draw_set_transform(size/2-camera*zoom,0,Vector2.ONE*zoom)
			if elite:
				draw_arc(p,43,0,TAU,6,Color("ffd683"),3,true)
				draw_line(p+Vector2(-14,-31),p+Vector2(0,-42),Color("ffd683"),4,true)
				draw_line(p+Vector2(0,-42),p+Vector2(14,-31),Color("ffd683"),4,true)
			var mode := World.enemy_mode(site.id)
			var status: String = "追击" if mode=="chase" else "开火" if mode=="attack" else "返航" if mode=="return" else "敌军"
			world_text(p+Vector2(-35,53),("精英·" if elite else "")+status,Color("ffd683") if elite else Color("f2b484") if mode in ["chase","attack"] else Color("e6a0a0"),16)
			if mode in ["chase","attack"]:
				world_text(p-Vector2(4,43),"!",Color("ffcd7c"),25)
		elif site.kind=="resource":
			draw_circle(p,34,Color(0.4,0.7,0.9,0.09))
			ART.site(self,p,site.kind,Color("a3dce8"))
			world_text(p+Vector2(-35,48),"补给",Color("92c7d8"),16)
		elif site.kind in ["supply","cache","cooling","boss_site"]:
			var color: Color = {"supply":Color("8cdec3"),"cache":Color("e9c78e"),"cooling":Color("7ddfff"),"boss_site":Color("ff7b82")}[site.kind]
			draw_circle(p,42,Color(color,0.1))
			draw_arc(p,40,0,TAU,32,color,2,true)
			ART.site(self,p,site.kind,color,int(State.expedition.run.region) if State.expedition.active() else 0)
			world_text(p+Vector2(-42,64),site.name,color,17)
		else:
			var active: bool = World.cleared.has(site.id)
			var color := Color("8cdec3") if active else Color("e6c88a")
			draw_arc(p,48,0,TAU,40,Color(color,0.45),2)
			ART.site(self,p,"beacon",color)
			draw_line(p+Vector2(0,12),p-Vector2(0,38),color,5)
			draw_arc(p-Vector2(0,36),18,-2.6,-0.5,20,color,2)
			world_text(p+Vector2(-40,66),"已激活" if active else "前线据点",color,16)
	# The capital ship stays at its saved deployment point for the entire sortie.
	var dock := carrier_position()
	var stationed: bool = State.expedition.active() and State.carrier.ops.data().mode=="station"
	draw_arc(dock,160 if stationed else 100,0,TAU,64,Color(0.4,0.75,0.72,0.3),3)
	draw_set_transform(Vector2.ZERO)
	if Rect2(Vector2.ZERO,size).grow(220).has_point(to_screen(dock)):
		CARRIER.render(self,to_screen(dock)+Vector2(0,-90)*zoom,0.7*zoom)
		world_text(to_screen(dock)+Vector2(-82,62)*zoom,"驻舰补给站" if stationed else "战舰定点警戒" if State.expedition.active() else "母舰停泊点",Color("8cdec3"),18)
	draw_carrier_operations()
	var player := to_screen(World.position)
	if World.encounter_id!="" and not World.boss.active:
		draw_arc(player,State.attack_range()*zoom,0,TAU,96,Color(0.5,0.85,0.75,0.12),1,true)
	if World.boss.active: draw_boss()
	draw_weapon_effects()
	for shot in World.hostile.projectiles:
		CONTENT.fx(self,"fx-energy",0,to_screen(shot.p),Vector2(36,16)*zoom,fmod(elapsed*8,1),shot.direction.angle())
	if World.boss.active: draw_boss_warnings()
	for trail in trails:
		var point := to_screen(trail.p)
		if trail.mode=="hover": draw_line(point-Vector2(6,0)*zoom,point+Vector2(6,0)*zoom,Color(0.4,0.8,0.9,trail.t*0.12),zoom,true)
		elif trail.mode=="dash" and trail.boost: CONTENT.fx(self,"fx-kinetic",0,point,Vector2(38,22)*zoom,1-float(trail.t)/0.5,float(trail.get("angle",0))+PI,trail.t*0.7)
	var aim: Vector2 = World.position.direction_to(World.encounter_position) if World.encounter_id!="" else Vector2(-sin(mech_motion.yaw),-cos(mech_motion.yaw)*mech_motion.PROJECTION.GROUND_Y).normalized()
	preload("res://scripts/mech_art.gd").render(self,player-Vector2(0,28)*zoom,0.43*zoom,State.MECHS.MODELS[State.mechs.units[State.selected_mech].model].color,false,elapsed,mech_pose(),{},World.attacks,aim,State.defense)
	preload("res://scripts/hand_shield.gd").render_guard(self,State.defense,player-Vector2(0,20)*zoom,zoom)
	State.pilot_runtime.render(self,World.position,World.attack_targets(),to_screen,zoom,State.selected)
	field_feedback.render(self,to_screen,zoom)
	if World.target_in_range(): State.rig.render_aim(self,to_screen,World.position,World.encounter_position,State.weapon_profiles(),zoom)
	# A flat ground selector must not read as a second shield around the torso.
	draw_set_transform(player+Vector2(0,23)*zoom,0,Vector2(zoom,zoom*0.28))
	draw_arc(Vector2.ZERO,30,0,TAU,40,Color(0.55,0.89,0.82,0.45),2,true)
	draw_set_transform(Vector2.ZERO)
	draw_string(MAP_FONT,player+Vector2(-40,51)*zoom,State.PILOTS[State.selected].name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eaf1f4"))
	for f in floats:
		var at: Vector2 = to_screen(f.p)-Vector2(12,45)
		var tint := Color("ffdb97") if f.friendly else Color("ff6b7c")
		tint.a = minf(1,f.t*3)
		draw_string_outline(MAP_FONT,at,"−"+f.v,HORIZONTAL_ALIGNMENT_LEFT,-1,23,4,Color(0.03,0.05,0.08,tint.a))
		draw_string(MAP_FONT,at,"−"+f.v,HORIZONTAL_ALIGNMENT_LEFT,-1,23,tint)
	if radar_visible: draw_radar()

func draw_carrier_operations() -> void:
	if not State.expedition.active(): return
	var current: Dictionary = State.carrier.ops.data()
	if not current.field.is_empty():
		var center := to_screen(Vector2(current.field.point[0],current.field.point[1]))
		var radius: float = float(current.field.radius)*zoom
		draw_circle(center,radius,Color(0.3,0.9,1,0.08))
		draw_arc(center,radius,0,TAU,64,Color(0.45,0.9,1,0.7),3,true)
		world_text(center+Vector2(-82,-radius-12),"护航屏障 · %.1fs"%current.field.ttl,Color("7ddfff"),18)
	for salvo in current.salvos:
		if not salvo.area: continue
		var point := to_screen(Vector2(salvo.point[0],salvo.point[1]))
		draw_arc(point,float(salvo.radius)*zoom,0,TAU,40,Color(1,0.8,0.4,0.55),2,true)
	for flash in State.carrier.ops.flashes:
		var from := to_screen(flash.from)+Vector2(0,-115)*zoom
		var point := to_screen(flash.to)
		var color := Color(0.4,0.9,1,flash.ttl) if flash.guard else Color(1,0.75,0.3,flash.ttl)
		draw_line(from,point,color,4*zoom,true)
		if not flash.guard: draw_circle(point,24*zoom,Color(color,flash.ttl*0.5))
	if State.carrier.ops.supplying(World):
		var point := to_screen(World.position)
		draw_arc(point,48*zoom,0,TAU,40,Color("8cdec3"),2,true)
		world_text(point+Vector2(-62,-76)*zoom,"母舰补给中",Color("8cdec3"),18)

func draw_radar() -> void:
	var minimap := Rect2(size.x-169,204,145,145)
	draw_rect(minimap,Color(0.035,0.07,0.1,0.92))
	draw_rect(minimap,Color("52656c"),false,1)
	for site in World.nearby(World.position,2):
		if World.cleared.has(site.id) and site.kind!="beacon": continue
		var point: Vector2 = minimap.get_center()+(World.site_position(site)-World.position)*0.05
		if minimap.grow(-5).has_point(point): draw_circle(point,2.2,Color("ff7373") if site.kind=="enemy" else Color("8ed6e4") if site.kind=="resource" else Color("e8c37f"))
	var dock_point := minimap.get_center()+(carrier_position()-World.position)*0.05
	if minimap.grow(-7).has_point(dock_point):
		draw_rect(Rect2(dock_point-Vector2.ONE*4,Vector2.ONE*8),Color("8cdec3"))
		draw_arc(dock_point,7,0,TAU,16,Color("8cdec3"),1.5,true)
	draw_circle(minimap.get_center(),4,Color("f3f6f5"))
	draw_string(MAP_FONT,minimap.position+Vector2(8,138),"战区雷达",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("96aeb7"))

func draw_boss() -> void:
	var boss = World.boss
	var p := to_screen(boss.position)
	var region: int = maxi(0,int(boss.region))
	preload("res://scripts/rig/unit_art.gd").render(self,p-Vector2(0,18)*zoom,Vector2.ONE*220*zoom,"boss","boss",region,false,boss.facing,false,elapsed,{"tracks":boss.parts.tracks,"cannon":boss.parts.cannon,"phase":boss.phase})
	if boss.phase==3: CONTENT.fx(self,"fx-support",3,p,Vector2.ONE*90*zoom,fmod(elapsed*4,1),0,0.7)
	for target in boss.targets():
		var point := to_screen(target.p)
		if target.id.begins_with("boss:drone:"): CONTENT.enemy(self,point,"drone",false,zoom*0.6,false,target.id,target.p.direction_to(World.position),true,elapsed)
		if target.id==boss.target_id(): draw_arc(point,28*zoom,0,TAU,32,Color("8ce6d4"),3,true)
	if boss.parts.tracks<=0: CONTENT.fx(self,"fx-kinetic",2,to_screen(boss.position+Vector2(-35,58).rotated(boss.facing.angle())),Vector2.ONE*58*zoom,fmod(elapsed*0.8,1),0,0.45)
	if boss.parts.cannon<=0: CONTENT.fx(self,"fx-kinetic",2,to_screen(boss.position+Vector2(35,-58).rotated(boss.facing.angle())),Vector2.ONE*58*zoom,fmod(elapsed*0.8,1),0,0.45)

	draw_rect(Rect2(p+Vector2(-70,-100)*zoom,Vector2(140,9)*zoom),Color("273442"))
	draw_rect(Rect2(p+Vector2(-70,-100)*zoom,Vector2(140*maxf(0,boss.hp)/boss.maximum,9)*zoom),Color("ff6c69"))
	world_text(p+Vector2(-85,-112)*zoom,"%s · 阶段 %d" % [boss.display_name(),boss.phase],Color("ffd7a3"),20)

func draw_boss_warnings() -> void:
	for warning in World.boss.warnings:
		var p := to_screen(warning.p)
		var radius: float = warning.radius*zoom
		draw_circle(p,radius,Color(1,0.2,0.15,0.16))
		draw_arc(p,radius,0,TAU,64,Color("ffbc63"),4,true)
		draw_arc(p,radius*clampf(warning.t/warning.duration,0,1),0,TAU,48,Color("ff615b"),2,true)
		world_text(p+Vector2(-16,5),"%.1f" % warning.t,Color("fff1da"),21)
	for blast in World.boss.blasts:
		CONTENT.fx(self,"fx-kinetic",2,to_screen(blast.p),Vector2.ONE*blast.radius*zoom*2.5,clampf(1-float(blast.t)/0.3,0,1))
