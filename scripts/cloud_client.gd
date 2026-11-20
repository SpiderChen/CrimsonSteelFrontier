extends Node
## Explicit carrier sync; an optimistic revision and idempotent receipts protect other devices.
signal changed
var endpoint: String = "http://127.0.0.1:8070/api"
var token: String = ""
var username: String = ""
var server_id: String = ""
var remote_revision: int = -1
var remote_exists: bool = false
var busy: bool = false
var mutating: bool = false
var status: String = "本机档案 · 可在母舰连接云端"
var last_error: String = ""
var clock_base: float = -1
var clock_tick: int = 0
var pending_claim: String = ""
var session_override: String = ""

func _ready() -> void:
	if OS.has_feature("web"):
		var origin: String = str(JavaScriptBridge.eval("window.location.origin"))
		if origin.begins_with("http"): endpoint = origin+"/api"
	if not State.test_mode:
		load_session()
		if not State.cloud_binding.is_empty(): status = "已绑定云账号 · 登录原账号后可联网领取"
		if token!="": call_deferred("inspect_remote")

func session_path() -> String:
	return session_override if session_override!="" else State.save_path().get_base_dir()+"/cloud_session.json"

func save_session() -> void:
	if State.test_mode and session_override=="": return
	var path := session_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"endpoint":endpoint,"token":token,"username":username,"server_id":server_id,"pending_claim":pending_claim}))
		file.close(); DirAccess.rename_absolute(path+".tmp",path)

func load_session() -> void:
	if not FileAccess.file_exists(session_path()): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path()))
	if not data is Dictionary: return
	endpoint = str(data.get("endpoint",endpoint)).trim_suffix("/")
	token = str(data.get("token","")).left(256); username = str(data.get("username","")).left(32)
	server_id = str(data.get("server_id","")).left(80); pending_claim = str(data.get("pending_claim","")).left(80)

func trusted_now() -> float:
	return maxf(State.salvage.cursor,clock_base+(Time.get_ticks_msec()-clock_tick)/1000.0) if clock_base>=0 else State.salvage.cursor

func holds_combat() -> bool: return (busy and mutating) or pending_claim!=""
func authenticated() -> bool: return token!=""
func same_account() -> bool:
	return not State.cloud_binding.is_empty() and State.cloud_binding.get("account")==username and State.cloud_binding.get("server_id")==server_id
func local_revision() -> int:
	return int(State.cloud_binding.get("revision",0)) if same_account() else 0
func can_upload() -> bool:
	return authenticated() and remote_revision>=0 and ((same_account() and local_revision()==remote_revision) or (not remote_exists and State.cloud_binding.is_empty()))

func configure(url: String) -> bool:
	url = url.strip_edges().trim_suffix("/")
	if busy: return false
	if pending_claim!="" and url!=endpoint:
		status = "请先恢复上次结算，再更换档案服务地址"; changed.emit(); return false
	if not (url.begins_with("http://") or url.begins_with("https://")) or "@" in url or "?" in url or "#" in url:
		status = "请输入有效的档案服务地址"; changed.emit(); return false
	if url!=endpoint:
		endpoint = url; token = ""; username = ""; server_id = ""; remote_revision = -1; remote_exists = false; clock_base = -1
	save_session(); changed.emit(); return true

func request_api(path: String, method: HTTPClient.Method, body: Dictionary = {}) -> Dictionary:
	if busy: return {"ok":false,"code":"busy"}
	busy = true; last_error = ""; changed.emit()
	var request := HTTPRequest.new(); request.timeout = 15; add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token!="": headers.append("Authorization: Bearer "+token)
	var error := request.request(endpoint+path,headers,method,JSON.stringify(body) if method!=HTTPClient.METHOD_GET else "")
	var result: Dictionary
	if error==OK:
		var response: Array = await request.request_completed
		var payload: Variant = null
		if response[0]==HTTPRequest.RESULT_SUCCESS and not response[3].is_empty():
			var parser := JSON.new()
			if parser.parse(response[3].get_string_from_utf8())==OK: payload = parser.data
		if response[0]==HTTPRequest.RESULT_SUCCESS and payload is Dictionary:
			result = payload
			result["http_status"] = int(response[1]); result["ok"] = response[1]>=200 and response[1]<300
			if result.get("server_time") is float or result.get("server_time") is int:
				clock_base = float(result.server_time); clock_tick = Time.get_ticks_msec()
		else: result = {"ok":false,"code":"network","message":"无法连接档案服务，请检查地址和网络后重试"}
	else: result = {"ok":false,"code":"network","message":"档案请求未能发出，请稍后重试"}
	request.queue_free(); busy = false
	if not result.ok:
		last_error = str(result.get("code","network")); status = str(result.get("message","请求未完成"))
		if last_error=="unauthorized": token = ""; save_session()
	changed.emit()
	return result

func login(account: String, password: String, register: bool = false) -> void:
	if busy: return
	account = account.strip_edges()
	if pending_claim!="":
		var original_account: String = str(State.cloud_binding.get("account",username))
		if register or account!=original_account:
			status = "请登录原账号「%s」恢复上次结算"%original_account; changed.emit(); return
	status = "正在建立档案连接…"
	var result: Dictionary = await request_api("/register" if register else "/login",HTTPClient.METHOD_POST,{"username":account.strip_edges(),"password":password})
	if not result.ok: return
	token = result.token; username = result.username; server_id = result.server_id
	save_session()
	await inspect_remote()

func inspect_remote() -> void:
	if busy or token=="": return
	var result: Dictionary = await request_api("/state",HTTPClient.METHOD_GET)
	if not result.ok: return
	remote_revision = int(result.revision); remote_exists = result.get("save") is Dictionary
	server_id = result.server_id; username = result.username
	if pending_claim!="": status = "上次结算待确认 · 请恢复联网结算"
	elif not remote_exists: status = "账号尚无云档案 · 可保存当前本机进度"
	elif same_account() and local_revision()==remote_revision: status = "云端版本一致 · 可保存进度或联网领取"
	else: status = "云端已有更新 · 下载后继续，当前本机进度会自动备份"
	save_session(); changed.emit()

func can_mutate_cloud() -> bool:
	if not World.docked:
		status = "请先回到母舰再同步档案"; changed.emit(); return false
	if State.certification_job!=null and not State.certification_job.done:
		status = "请等待本次认证完成或取消后再同步"; changed.emit(); return false
	return true

func apply_response(result: Dictionary) -> bool:
	if not result.get("save") is Dictionary: return false
	var backup := State.save_path()+".before_cloud.json"
	if not State.test_mode or State.save_override!="":
		DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
		var file := FileAccess.open(backup,FileAccess.WRITE)
		if not file:
			status = "未能备份本机进度，请释放存储空间后重试"; return false
		file.store_string(JSON.stringify(State.save_payload()))
		var stored: bool = file.get_error()==OK
		file.close()
		if not stored: status = "本机备份未完成，进度保持原样"; return false
	if not State.import_game(result.save):
		status = "云档案格式不支持，本机进度已保留"; return false
	State.save_game(); State.changed.emit()
	remote_revision = int(result.revision); remote_exists = true
	State.offline_seconds = 0
	return true

func upload_current() -> void:
	if busy or pending_claim!="" or not can_mutate_cloud(): return
	if not can_upload(): status = "请先登录，并下载其他设备更新的档案"; changed.emit(); return
	mutating = true; status = "正在保存云档案…"
	var result: Dictionary = await request_api("/state",HTTPClient.METHOD_PUT,{"revision":local_revision(),"save":State.save_payload()})
	if result.ok and apply_response(result): status = "云档案已保存 · 版本 %d"%remote_revision
	elif result.get("code")=="conflict": remote_revision = -1
	mutating = false; save_session(); changed.emit()

func activate_salvage(id: String) -> void:
	if busy or pending_claim!="" or not can_mutate_cloud() or not can_upload():
		State.message.emit("请先登录并同步云档案，再切换回收方案"); return
	if id==State.salvage.active_id: return
	if id!="base":
		var record: Dictionary = {}
		for candidate in State.salvage.certificates:
			if candidate.id==id: record = candidate
		if record.is_empty() or State.expedition.clears[int(record.region)]<=0: return
	var before: Dictionary = State.salvage.export_save()
	var revision: int = local_revision()
	if not State.salvage.activate(id,trusted_now()): return
	State.save_game(); State.changed.emit()
	await upload_current()
	if local_revision()>revision and State.salvage.active_id==id:
		State.message.emit("回收方案已同步 · 服务器已按旧方案结账并切换")
	else:
		State.salvage.import_save(before); State.salvage.catch_up(trusted_now())
		State.save_game(); State.changed.emit()
		State.message.emit("切换尚未确认，请联网检查云档案后重试")

func download_current() -> void:
	if busy or token=="" or not can_mutate_cloud(): return
	mutating = true
	var result: Dictionary = await request_api("/state",HTTPClient.METHOD_GET)
	if result.ok:
		if apply_response(result):
			pending_claim = ""; status = "云档案已恢复 · 本机旧进度已备份"
		else: status = "账号尚无可下载的云档案"
	mutating = false; save_session(); changed.emit()

func claim_current() -> void:
	if busy or not can_mutate_cloud(): return
	if token=="": status = "请登录原云账号后联网领取"; State.message.emit(status); changed.emit(); return
	if not same_account(): status = "请先下载当前账号的云档案"; State.message.emit(status); changed.emit(); return
	if pending_claim=="":
		if not can_upload(): status = "其他设备已更新，请下载最新云档案后领取"; State.message.emit(status); changed.emit(); return
		pending_claim = Crypto.new().generate_random_bytes(16).hex_encode(); save_session()
	mutating = true; status = "正在使用服务器时间结算…"
	var result: Dictionary = await request_api("/claim",HTTPClient.METHOD_POST,{"revision":local_revision(),"save":State.save_payload(),"request_id":pending_claim})
	if result.ok and apply_response(result):
		pending_claim = ""
		var receipt: Dictionary = result.get("receipt",{})
		status = "结算已确认 · 信用点 +%d / 部件 %d"%[receipt.get("credits",0),receipt.get("parts",0)]
		State.feedback.emit("reward"); State.message.emit(status)
	elif result.get("code")=="conflict":
		pending_claim = ""; remote_revision = -1
	elif result.get("code") not in ["network","unauthorized"]: pending_claim = ""
	mutating = false; save_session(); changed.emit()

func logout() -> void:
	if busy or pending_claim!="": status = "请先确认待处理的结算"; changed.emit(); return
	if token!="": await request_api("/logout",HTTPClient.METHOD_POST)
	token = ""; remote_revision = -1; remote_exists = false; clock_base = -1
	status = "已退出 · 本机保留云账号绑定，重新登录后可领取"
	save_session(); changed.emit()
