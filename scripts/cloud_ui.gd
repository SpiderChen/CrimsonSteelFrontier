extends RefCounted
const GOLD := Color("e9c78e")
const MUTED := Color("8894a8")
var app: Node
func _init(owner: Node) -> void: app = owner
func text(parent: Node, value: String, y: float, height: float, color: Color = Color("f2f1f3"), font_size: int = 20) -> Label:
	var result: Label = app.label(parent,value,Rect2(30,y,588,height),font_size,color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result
func input(parent: Node, value: String, placeholder: String, rect: Rect2, secret: bool = false) -> LineEdit:
	var field := LineEdit.new()
	field.position = rect.position; field.size = rect.size
	field.text = value; field.placeholder_text = placeholder; field.secret = secret
	field.max_length = 128 if secret else 256
	field.add_theme_font_size_override("font_size",20)
	parent.add_child(field)
	return field
func show_cloud() -> void:
	if not World.docked: app.request_base(); return
	app.rebuilding_cloud_modal = true
	var m: Control = app.modal("云端档案","保存进度 · 更换设备 · 服务器计时领取",1080)
	app.rebuilding_cloud_modal = false
	text(m,"档案服务地址",136,34,MUTED,18)
	app.refs.cloud_endpoint = input(m,Cloud.endpoint,"https://你的档案服务/api",Rect2(30,179,432,52))
	app.refs.cloud_connect = app.button(m,"连接",Rect2(474,179,144,52),func():
		if Cloud.configure(app.refs.cloud_endpoint.text) and Cloud.authenticated(): Cloud.inspect_remote())
	text(m,"账号与密码",259,34,MUTED,18)
	app.refs.cloud_user = input(m,Cloud.username,"账号（3—32字）",Rect2(30,303,282,52))
	app.refs.cloud_password = input(m,"","密码（至少8字）",Rect2(332,303,286,52),true)
	app.refs.cloud_login = app.button(m,"登录",Rect2(30,375,282,56),func(): authenticate(false),true)
	app.refs.cloud_register = app.button(m,"创建账号",Rect2(332,375,286,56),func(): authenticate(true))
	app.refs.cloud_status = text(m,"",461,102,GOLD,23)
	app.refs.cloud_details = text(m,"",583,102,MUTED,18)
	app.refs.cloud_upload = app.button(m,"保存当前进度到云端",Rect2(30,717,588,58),func(): Cloud.upload_current(),true)
	app.refs.cloud_download = app.button(m,"下载云档案 · 自动备份本机",Rect2(30,791,588,58),func(): Cloud.download_current())
	app.refs.cloud_claim = app.button(m,"联网领取回收收益",Rect2(30,865,588,58),func(): Cloud.claim_current())
	app.refs.cloud_refresh = app.button(m,"检查云端更新",Rect2(30,959,282,58),func(): Cloud.inspect_remote())
	app.refs.cloud_logout = app.button(m,"退出账号",Rect2(332,959,286,58),func(): Cloud.logout())
	for child in m.get_children():
		if child is Button and child.text=="×": app.refs.cloud_close = child
	refresh()
func authenticate(register: bool) -> void:
	if not Cloud.configure(app.refs.cloud_endpoint.text): return
	var account: String = app.refs.cloud_user.text
	var password: String = app.refs.cloud_password.text
	app.refs.cloud_password.text = ""
	Cloud.login(account,password,register)
func refresh() -> void:
	if not is_instance_valid(app.refs.get("cloud_status")): return
	var binding: Dictionary = State.cloud_binding
	var account: String = str(binding.get("account","未绑定"))
	var local: int = int(binding.get("revision",0))
	app.refs.cloud_status.text = ("请求处理中…\n" if Cloud.busy else "")+Cloud.status
	app.refs.cloud_details.text = "本机归属：%s · 本机版本 %d / 云端版本 %s\n在母舰保存后，再到其他设备登录下载。\n绑定云端后，回收领取需要联网；关闭游戏也会累计。"%[account,local,str(Cloud.remote_revision) if Cloud.remote_revision>=0 else "待检查"]
	for key in ["cloud_endpoint","cloud_user","cloud_password"]: app.refs[key].editable = not Cloud.busy
	for key in ["cloud_connect","cloud_login"]: app.refs[key].disabled = Cloud.busy
	app.refs.cloud_register.disabled = Cloud.busy or Cloud.pending_claim!=""
	app.refs.cloud_upload.disabled = Cloud.busy or not Cloud.can_upload() or Cloud.pending_claim!=""
	app.refs.cloud_download.disabled = Cloud.busy or not Cloud.authenticated() or not Cloud.remote_exists
	app.refs.cloud_claim.text = "恢复上次联网结算" if Cloud.pending_claim!="" else "联网领取回收收益"
	app.refs.cloud_claim.disabled = Cloud.busy or not Cloud.authenticated() or not Cloud.same_account() or (Cloud.pending_claim=="" and not Cloud.can_upload())
	app.refs.cloud_refresh.disabled = Cloud.busy or not Cloud.authenticated()
	app.refs.cloud_logout.disabled = Cloud.busy or not Cloud.authenticated() or Cloud.pending_claim!=""
	if is_instance_valid(app.refs.get("cloud_close")): app.refs.cloud_close.disabled = Cloud.busy or Cloud.pending_claim!=""
