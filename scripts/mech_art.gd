extends RefCounted
## Live 3D battle models. Original transparent paintings remain available for collection cards.
const TEXTURES = [
	preload("res://assets/generated/vehicles/mech-crimson.png"),
	preload("res://assets/generated/vehicles/mech-nightingale.png"),
	preload("res://assets/generated/vehicles/mech-falcon.png")
]
const COLORS = [Color("ff5467"),Color("b49aff"),Color("7ddfff"),Color("72e6b0"),Color("f5c764"),Color("47bfca")]
const MELEE = preload("res://scripts/melee.gd")
const CONTENT = preload("res://scripts/production_art.gd")

static func model_for(color: Color, enemy: bool) -> int:
	if enemy: return 2 if color.g>0.65 else 0
	var chosen := 0
	var closest := INF
	for i in range(COLORS.size()):
		var difference: Color = COLORS[i]-color
		var distance: float = difference.r*difference.r+difference.g*difference.g+difference.b*difference.b
		if distance<closest:
			closest = distance; chosen = i
	return chosen

static func appearance() -> Dictionary:
	var result := {"drive":World.drive_mode(),"weapons":[],"backpack":-1,"armor":-1,"core":-1}
	for slot in [0,4]:
		var part: Dictionary = State.parts.equipped(State.selected_mech,slot)
		if not part.is_empty(): result.weapons.append({"slot":slot,"mode":State.weapon_mode(slot),"blueprint":int(part.blueprint)})
	for slot in [1,3,5]:
		var part: Dictionary = State.parts.equipped(State.selected_mech,slot)
		if not part.is_empty(): result[{1:"armor",3:"core",5:"backpack"}[slot]] = int(part.blueprint)
	return result

static func attack_pose(engine: RefCounted, slot: int) -> Dictionary:
	var result := {"angle":0.0,"extension":0.0}
	if engine==null: return result
	for swing in engine.swings:
		if int(swing.meta.get("slot",-1))!=slot: continue
		var rule: Dictionary = MELEE.RULES[swing.mode]
		var age: float = swing.age
		if swing.mode=="gauntlet":
			for timing in rule.timings:
				var t := clampf((age-float(timing)+0.07)/0.18,0,1)
				result.extension = maxf(result.extension,24*pow(sin(t*PI),2))
		else:
			result.angle = MELEE.swing_angle(swing.mode,age)
		return result
	for flash in engine.flashes:
		if flash.kind=="muzzle" and int(flash.get("slot",-1))==slot:
			result.extension = -7*clampf(float(flash.t)/float(flash.life),0,1)
	return result

static func muzzle_offset(model: int, pose: Dictionary, loadout: Dictionary, engine: RefCounted, aim: Vector2, slot: int, scale_value: float, canvas: CanvasItem) -> Vector2:
	var view = view_for(canvas,model)
	if view.touched_frame!=Engine.get_process_frames(): view.update_model(model,pose,loadout,engine,aim,float(pose.get("clock",0)),null)
	return view.muzzle(slot)*scale_value

static func view_for(canvas: CanvasItem, model: int, key: String = "main") -> SubViewport:
	var views: Dictionary = canvas.get_meta("mech_3d_views",{})
	var id := key+":"+str(model)
	if not views.has(id) or not is_instance_valid(views[id]):
		var view = preload("res://scripts/rig/mech_viewport.gd").new()
		view.name = "Mech3D_"+key+"_"+str(model)
		canvas.add_child(view)
		views[id] = view
		canvas.set_meta("mech_3d_views",views)
	return views[id]

static func render(canvas: CanvasItem, pos: Vector2, scale_value: float, color: Color, enemy: bool, elapsed: float, pose: Dictionary = {}, loadout: Dictionary = {}, engine: RefCounted = null, aim: Vector2 = Vector2(1,0.65), defense: RefCounted = null, instance_key: String = "main") -> void:
	var model := model_for(color,enemy)
	if loadout.is_empty(): loadout = {"drive":"walk","weapons":[{"slot":0,"mode":"standard","blueprint":0}]} if enemy else appearance()
	var view = view_for(canvas,model,instance_key)
	var resolution: int = 256 if scale_value<0.65 else 512
	if view.size.x!=resolution: view.size = Vector2i(resolution,resolution)
	view.update_model(model,pose,loadout,engine,aim,elapsed,defense)
	canvas.draw_set_transform(pos+Vector2(0,119*scale_value),0,Vector2(scale_value,scale_value*0.22))
	canvas.draw_circle(Vector2.ZERO,45,Color(0.02,0.04,0.06,0.3))
	canvas.draw_arc(Vector2.ZERO,44,0,TAU,48,Color(color,0.18),2,true)
	canvas.draw_set_transform(Vector2.ZERO)
	var rect: Rect2 = view.drawing_rect()
	canvas.draw_texture_rect(view.get_texture(),Rect2(pos+rect.position*scale_value,rect.size*scale_value),false)
