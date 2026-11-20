extends Control
## Presentation only: results have already been committed and saved by State.
const STAR = preload("res://assets/free/icons/star.png")
const TARGET = preload("res://assets/free/ui/crosshair.png")
var app: Node
var results: Array = []
var cards: Array[Control] = []
var age := 0.0
var complete := false
var heading: Label
var subheading: Label
var skip: Button
var confirm: Button

func setup(owner: Node, committed: Array) -> void:
	app=owner; results=committed.duplicate()
	size=Vector2(720,1280); mouse_filter=Control.MOUSE_FILTER_STOP
	app.box(self,Rect2(0,0,720,1280),Color("070e1c"))
	var background := TextureRect.new()
	background.texture=app.CONTENT.SHEETS.hangar
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size=size; background.modulate=Color(0.25,0.35,0.55,0.35)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	# This layer keeps the animated field above the backdrop and behind the cards.
	var field := Control.new();field.name="ResonanceField";field.mouse_filter=Control.MOUSE_FILTER_IGNORE
	field.draw.connect(func(): draw_field(field));add_child(field)
	heading=app.label(self,"信标接入中",Rect2(30,90,660,60),36,app.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	subheading=app.label(self,"RESONANCE / 正在建立同调链路",Rect2(30,156,660,30),17,app.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	skip=app.button(self,"跳过演出",Rect2(514,24,178,52),reveal_all)
	for i in range(results.size()):
		var index := 2
		for pilot in range(State.PILOTS.size()):
			if State.PILOTS[pilot].name in str(results[i]): index=pilot
		var single: bool=results.size()==1
		var rect := Rect2(115,290,490,720) if single else Rect2(34+(i%2)*334,230+int(i/2.0)*170,318,156)
		var card: Panel=app.box(self,rect,Color("1d2a40"))
		app.INTERFACE.panel(card,Color("53647e") if "新机师" not in str(results[i]) else Color("8c7350"))
		card.clip_contents=true;card.pivot_offset=rect.size/2
		var portrait := Rect2(12,12,466,568) if single else Rect2(9,9,98,138)
		app.photo(card,index,portrait)
		var offset := Vector2(26,590) if single else Vector2(119,18)
		app.label(card,"SSR / 新机师" if "新机师" in str(results[i]) else "同调强化",Rect2(offset,Vector2(270,27)),17,app.GOLD)
		app.label(card,State.PILOTS[index].name,Rect2(offset+Vector2(0,34),Vector2(270,40)),32 if single else 27)
		var info: Label=app.label(card,str(results[i]),Rect2(offset+Vector2(0,79),Vector2(436 if single else 182,42)),17,app.MUTED)
		info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		card.modulate.a=0;cards.append(card)
	confirm=app.button(self,"确认归队",Rect2(80,1150,560,78),finish,true)
	confirm.visible=false

func _process(delta: float) -> void:
	age+=delta
	var field=get_node_or_null("ResonanceField")
	if field: field.queue_redraw()
	if complete:return
	if age<0.8: heading.text="信标接入中"
	elif age<1.6: heading.text="同调链路已锁定"
	else: heading.text="同调建立"
	for i in range(cards.size()):
		var progress := clampf((age-1.6-i*0.12)/0.35,0,1)
		cards[i].modulate.a=progress
		cards[i].scale=Vector2.ONE*(0.88+0.12*ease(progress,0.4))
	if age>=1.95+(cards.size()-1)*0.12: reveal_all()

func reveal_all() -> void:
	if complete:return
	Sfx.play("reward",-22)
	complete=true
	for card in cards: card.modulate=Color.WHITE;card.scale=Vector2.ONE
	heading.text="同调建立"
	subheading.text="RESONANCE COMPLETE / %d 次同调结果"%results.size()
	skip.hide();confirm.show();confirm.grab_focus()

func finish() -> void:
	if not complete:return
	confirm.disabled=true
	app.call_deferred("finish_recruit")

func draw_field(canvas: Control) -> void:
	var center := Vector2(360,630)
	var charge := clampf(age/1.6,0,1)
	var fade := 0.12 if complete else 1-clampf((age-1.6)*2,0,0.88)
	for i in range(3):
		var radius := 105+i*65+sin(age*2+i)*8
		canvas.draw_arc(center,radius,age*(0.4+i*0.15),age*(0.4+i*0.15)+TAU*0.78,96,Color(0.45,0.78,1,fade*(0.5-i*0.1)),2,true)
	for i in range(28):
		var phase := fmod(age*0.3+i/28.0,1)
		var angle := i*2.39996+age*0.12
		var point := center+Vector2.from_angle(angle)*(340*(1-phase)+20)
		var span := 5+phase*7
		canvas.draw_texture_rect(STAR,Rect2(point-Vector2.ONE*span/2,Vector2.ONE*span),false,Color(0.65,0.85,1,fade*phase))
	if not complete:
		var width := 4+pow(charge,5)*28
		canvas.draw_rect(Rect2(center.x-width/2,230,width,790),Color(0.55,0.82,1,fade*charge*0.7))
		canvas.draw_set_transform(center,age*0.35,Vector2.ONE*(0.7+charge*0.3))
		canvas.draw_texture_rect(TARGET,Rect2(-70,-70,140,140),false,Color(0.8,0.93,1,fade))
		canvas.draw_set_transform(Vector2.ZERO)
