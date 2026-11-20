extends RefCounted
## Artwork follows the simulator's real projectile, ray, swing and hit state.
const MELEE = preload("res://scripts/melee.gd")
const ART = preload("res://scripts/production_art.gd")
const VFX = preload("res://scripts/weapon_vfx.gd")
static func render(canvas: CanvasItem,engine: RefCounted,project: Callable,scale_value: float,lift: Vector2 = Vector2.ZERO,muzzle: Callable = Callable(),rigged: bool = false) -> void:
	var clock: float = engine.visual_time
	for swing in engine.swings:
		if rigged and swing.mode=="blade": continue
		var rule: Dictionary = MELEE.RULES[swing.mode]
		if not swing.active and swing.age>=float(rule.timings.back())+float(rule.window): continue
		var center: Vector2 = project.call(swing.from)+lift
		var radius: float = float(rule.range)*scale_value
		if swing.active:
			var stage_time: float = float(rule.timings[int(swing.stage)])
			var progress: float = clampf((float(swing.age)-stage_time)/float(rule.window),0,1)
			if swing.mode=="blade":
				var angle: float = swing.direction.angle()+MELEE.swing_angle(swing.mode,float(swing.age))
				canvas.draw_arc(center,radius*0.82,angle-0.65,angle,20,Color(1,0.47,0.18,0.85),5*scale_value,true)
				canvas.draw_arc(center,radius*0.86,angle-0.45,angle,16,Color(1,0.92,0.65,0.95),2*scale_value,true)
			else:
				var tip: Vector2 = center+swing.direction*radius*0.75
				if swing.mode=="gauntlet":
					var side: Vector2 = swing.direction.orthogonal()*7*scale_value
					for offset in [-1,0,1]: canvas.draw_line(tip-swing.direction*35*scale_value+side*offset,tip+side*offset,Color(0.65,1,0.88,1-progress*0.6),(3 if offset==0 else 1.2)*scale_value,true)
					canvas.draw_arc(tip,12*scale_value,0,TAU,16,Color(0.84,1,0.94,1-progress),2*scale_value,true)
					VFX.streak(canvas,tip-swing.direction*45*scale_value,tip,10*scale_value,VFX.tint("gauntlet"),1-progress)
					VFX.glow(canvas,tip,20*scale_value,VFX.tint("gauntlet"),(1-progress)*0.7)
				else:
					canvas.draw_arc(tip,(16+progress*42)*scale_value,0,TAU,32,Color(1,0.72,0.3,1-progress),3*scale_value,true)
					for i in range(6):
						var ray := Vector2.from_angle(i*TAU/6)
						canvas.draw_line(tip+ray*12*scale_value,tip+ray*(24+progress*25)*scale_value,Color(1,0.82,0.5,1-progress),2*scale_value,true)
					VFX.explosion(canvas,tip,55,"hammer",progress,scale_value)
		else:
			canvas.draw_arc(center,radius*0.65,swing.direction.angle()-0.35,swing.direction.angle()+0.35,12,Color(1,0.75,0.4,0.22),scale_value,true)
	for zone in engine.zones:
		var center: Vector2 = project.call(zone.p)+lift
		ART.fx(canvas,"fx-kinetic",2,center,Vector2.ONE*zone.radius*scale_value*2.5,fmod(clock*2,1),0,0.5)
		# The outline states the actual damage boundary independently of the painted fire.
		canvas.draw_arc(center,zone.radius*scale_value,0,TAU,40,Color("7ddfff") if bool(zone.meta.get("ion",false)) else Color("d5763e"),1.5*scale_value,true)
	for effect in engine.effects:
		var center: Vector2 = project.call(effect.p)+lift
		var progress: float = clampf(1-float(effect.t)/0.35,0,1)
		var healing: bool = effect.get("mode","")=="repair"
		if healing: ART.fx(canvas,"fx-support",1,center,Vector2.ONE*effect.radius*scale_value*2.5,progress)
		else:
			ART.fx(canvas,"fx-kinetic",2,center,Vector2.ONE*effect.radius*scale_value*1.8,progress,0,(1-progress)*0.55)
			VFX.explosion(canvas,center,effect.radius,str(effect.get("mode","missile")),progress,scale_value,bool(effect.get("ion",false)))
	for wake in engine.wakes:
		VFX.wake(canvas,wake.points,project,lift,scale_value,wake.mode,pow(float(wake.t)/0.18,2))
	for shot in engine.projectiles:
		var point: Vector2 = project.call(shot.p)+lift
		var direction: Vector2 = shot.direction
		var color := VFX.tint(shot.mode)
		var trail: Array = shot.get("trail",[])
		if shot.mode=="missile":
			for i in range(1,trail.size()):
				var u: float = float(i)/trail.size()
				var at: Vector2 = project.call(trail[i])+lift
				VFX.glow(canvas,at,(4+(1-u)*8)*scale_value,Color("8d98aa"),u*0.23)
				canvas.draw_line(project.call(trail[i-1])+lift,at,Color(0.65,0.7,0.78,u*0.25),(3+(1-u)*6)*scale_value,true)
			VFX.streak(canvas,point-direction*(28+sin(shot.distance*0.5)*4)*scale_value,point,7*scale_value,color)
			VFX.glow(canvas,point-direction*9*scale_value,20*scale_value,color,0.65)
			ART.fx(canvas,"fx-energy",3,point,Vector2(32,16)*scale_value,fmod(shot.distance/70.0,1),direction.angle())
		elif shot.mode=="plasma":
			VFX.wake(canvas,trail,project,lift,scale_value,"plasma",0.8)
			VFX.glow(canvas,point,29*scale_value,color,0.8)
			ART.fx(canvas,"fx-energy",2,point,Vector2(35,31)*scale_value,fmod(shot.distance/65.0,1),direction.angle())
			VFX.glow(canvas,point,8*scale_value,VFX.HOT,0.95)
			canvas.draw_arc(point,11*scale_value,shot.distance*0.04,shot.distance*0.04+PI*1.5,20,Color(color,0.8),1.4*scale_value,true)
		elif shot.mode=="rail":
			VFX.wake(canvas,trail,project,lift,scale_value,"rail")
			VFX.streak(canvas,point-direction*minf(90,shot.distance)*scale_value,point,6*scale_value,color)
			VFX.glow(canvas,point,15*scale_value,color,0.8)
		else:
			VFX.streak(canvas,point-direction*minf(32,shot.distance)*scale_value,point,4.5*scale_value,color)
			VFX.glow(canvas,point,9*scale_value,color,0.6)
	for beam in engine.beams:
		var from: Vector2 = project.call(beam.from)+lift
		if muzzle.is_valid() and int(beam.meta.get("slot",-1))>=0: from = muzzle.call(int(beam.meta.slot))
		var to: Vector2 = project.call(beam.end)+lift
		if not beam.lit:
			var charge: float = clampf(beam.age/0.22,0,1)
			VFX.glow(canvas,from,(8+charge*17)*scale_value,VFX.tint("pulse"),charge*0.8)
			canvas.draw_arc(from,(18-charge*12)*scale_value,beam.age*12,beam.age*12+TAU*0.8,24,Color(0.48,0.9,1,charge),1.5*scale_value,true)
			continue
		VFX.beam(canvas,from,to,beam.age,beam.duration,beam.meta.mode,scale_value)
	for flash in engine.flashes:
		var point: Vector2 = project.call(flash.p)+lift
		if flash.kind=="muzzle" and muzzle.is_valid() and int(flash.get("slot",-1))>=0: point = muzzle.call(int(flash.slot))
		var progress: float = clampf(1-float(flash.t)/float(flash.life),0,1)
		var mode: String = flash.get("mode","standard")
		if flash.kind=="muzzle":
			VFX.muzzle(canvas,point,float(flash.get("angle",0))+(PI if mode=="missile" else 0),mode,progress,scale_value)
		else: VFX.impact(canvas,point,mode,progress,scale_value,float(flash.get("angle",0)))
