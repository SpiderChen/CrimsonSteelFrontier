extends RefCounted
func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload()
	var world_enabled: bool = World.enabled
	var old_save: String = State.save_override
	var old_endpoint: String = Cloud.endpoint
	var old_session: String = Cloud.session_override
	var old_clock: float = State.settlement_clock_override
	State.save_override = ProjectSettings.globalize_path("res://tests/cloud_save_fixture.json")
	Cloud.session_override = ProjectSettings.globalize_path("res://tests/cloud_session_fixture.json")
	State.settlement_clock_override = -1; State.cloud_binding.clear()
	State.salvage = State.SALVAGE.new(); State.salvage.cursor = Time.get_unix_time_from_system()
	State.pending_credits = 36000; State.pending_cores = 120
	State.parts = State.PARTS.new(); State.parts.starter(); State.expedition = State.EXPEDITION.new()
	State.selected = 0; State.unlocked = [true,true,false]; State.levels = [1,1,1]
	World.enabled = true; World.enter_base(); State.recovery = 0
	var account := "native_%d"%Time.get_ticks_usec()
	check.call(Cloud.configure("http://127.0.0.1:8071/api") and not Cloud.configure("file:///etc/passwd"),"cloud endpoint accepts HTTP services and rejects filesystem or credential URLs")
	await Cloud.login(account,"native-test-password",true)
	check.call(Cloud.authenticated() and Cloud.remote_revision==0 and not Cloud.remote_exists,"real native HTTP registration opens an empty isolated cloud account")
	State.pilot_roster = State.PILOT_ROSTER.new(); State.pilot_roster.trust[0] = 27
	State.pilot_roster.metrics[0] = {"nodes":3.0,"vented":124.0}; State.pilot_roster.claimed[0] = [0]; State.pilot_roster.heard[0] = [0,1]
	State.tactics[0].distance = "far"; State.save_configuration(0)
	var roster: Dictionary = State.pilot_roster.export_save()
	var equipped: Dictionary = State.parts.loadouts[0].duplicate()
	var simulator = load("res://scripts/certification.gd")
	var job = simulator.new(simulator.capture(State),0)
	while not job.done: job.advance(1000)
	check.call(job.success,"cloud switch fixture uses a completed real three-trial certification")
	State.expedition.clears[0] = 1
	var certificate_id: String = State.salvage.add_certificate(job.result(),State.PILOTS[0].name)
	job.dispose(); job = null
	var local_currency: int = State.credits
	await Cloud.upload_current()
	check.call(Cloud.same_account() and Cloud.local_revision()==1 and State.cloud_binding.account==account,"first cloud upload binds the actual game snapshot and optimistic revision")
	check.call(State.pilot_roster.export_save()==roster and State.parts.presets[0][0]==equipped and State.tactic_presets[0][0].distance=="far","cloud round trip preserves nonempty personal tasks, trust, conversations, equipment presets and saved tactics")
	check.call(State.pending_credits>=36000 and absf(State.salvage.cursor-Cloud.trusted_now())<2,"migration preserves accrued local balance and anchors future time to the server")
	var first: Dictionary = State.save_payload()
	State.credits += 7; State.salvage.cursor = 100000000000; State.salvage.age = 72*3600
	await Cloud.upload_current()
	check.call(Cloud.local_revision()==2 and State.credits==local_currency+7 and State.salvage.cursor<100000000000 and State.salvage.age<60,"cloud save preserves real game changes while ignoring forged client clock and tier state")
	var conflict: Dictionary = await Cloud.request_api("/state",HTTPClient.METHOD_PUT,{"revision":1,"save":first})
	check.call(not conflict.ok and conflict.code=="conflict" and State.credits==local_currency+7,"stale native device snapshots receive a conflict without changing local or remote money")
	await Cloud.inspect_remote()
	await Cloud.activate_salvage(certificate_id)
	check.call(State.salvage.active_id==certificate_id and Cloud.local_revision()==3,"enabling a cloud salvage scheme immediately commits its source switch to the backend")
	await Cloud.activate_salvage("base")
	check.call(State.salvage.active_id=="base" and Cloud.local_revision()==4 and State.salvage.rows.any(func(row): return row.id==certificate_id),"switching back retains the server-accounted interval of the prior certified source")
	var before: int = State.credits
	var previous: Dictionary = State.save_payload(); var previous_revision: int = Cloud.local_revision()
	Cloud.claim_current()
	var issued: String = Cloud.pending_claim
	while Cloud.busy: await main.get_tree().create_timer(0.02).timeout
	check.call(issued.length()==32 and Cloud.pending_claim=="" and Cloud.local_revision()==previous_revision+1 and State.credits>=before+36000,"actual native cloud claim consumes an idempotent request and applies the canonical paid snapshot")
	var paid: int = State.credits
	var replay: Dictionary = await Cloud.request_api("/claim",HTTPClient.METHOD_POST,{"revision":previous_revision,"save":previous,"request_id":issued})
	check.call(replay.ok and replay.replayed and int(replay.save.credits)==paid and State.credits==paid,"retrying the same committed native request cannot pay again")
	# Commit a receipt without applying its response, then expire this device's session.
	var interrupted: Dictionary = State.save_payload()
	var interrupted_revision: int = Cloud.local_revision()
	var interrupted_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	Cloud.pending_claim = interrupted_id; Cloud.save_session()
	var committed: Dictionary = await Cloud.request_api("/claim",HTTPClient.METHOD_POST,{"revision":interrupted_revision,"save":interrupted,"request_id":interrupted_id})
	check.call(committed.ok and Cloud.local_revision()==interrupted_revision,"interrupted claim fixture commits only on the backend before client recovery")
	await Cloud.request_api("/logout",HTTPClient.METHOD_POST)
	await Cloud.claim_current()
	check.call(not Cloud.authenticated() and Cloud.pending_claim==interrupted_id and Cloud.holds_combat(),"an expired session keeps the unconfirmed receipt ID and pauses conflicting actions")
	main.cloud_ui.show_cloud()
	check.call(Cloud.configure(Cloud.endpoint) and not Cloud.configure("http://localhost:8999/api"),"an unconfirmed claim allows reconnecting to its original service while blocking a different service")
	await Cloud.login("another_account","native-test-password")
	check.call(not Cloud.authenticated() and Cloud.pending_claim==interrupted_id,"an unconfirmed claim cannot be reassigned to a different cloud account")
	main.refs.cloud_endpoint.text = Cloud.endpoint
	main.refs.cloud_user.text = account; main.refs.cloud_password.text = "native-test-password"
	main.cloud_ui.authenticate(false)
	while Cloud.busy: await main.get_tree().create_timer(0.02).timeout
	main.cloud_ui.refresh()
	check.call(Cloud.authenticated() and Cloud.pending_claim==interrupted_id and main.refs.cloud_register.disabled,"the actual login controls restore the original expired session without replacing its pending request")
	await Cloud.claim_current()
	paid = State.credits
	check.call(Cloud.pending_claim=="" and Cloud.local_revision()==int(committed.revision) and paid==int(committed.save.credits),"reauthentication recovers the committed receipt and its exact wallet without a second payout")
	var recovered_again: Dictionary = await Cloud.request_api("/claim",HTTPClient.METHOD_POST,{"revision":interrupted_revision,"save":interrupted,"request_id":interrupted_id})
	check.call(recovered_again.replayed and int(recovered_again.save.credits)==paid,"the recovered request remains idempotent after an expired-session login")
	check.call(FileAccess.file_exists(State.save_path()+".before_cloud.json") and not FileAccess.get_file_as_string(State.save_path()).contains(Cloud.token),"cloud restore keeps a local progress backup and never writes credentials into the game snapshot")
	var session: Variant = JSON.parse_string(FileAccess.get_file_as_string(Cloud.session_path()))
	check.call(session.token==Cloud.token and not session.has("password"),"persistent cloud session stores the token without the account password")
	main.cloud_ui.show_cloud()
	check.call(is_instance_valid(main.refs.cloud_status) and not main.refs.cloud_upload.disabled,"carrier cloud controls show a valid synchronized native session")
	Cloud.pending_claim = "unconfirmed_request_000001"
	main.cloud_ui.refresh(); main.close_modal()
	check.call(Cloud.holds_combat() and main.refs.cloud_close.disabled and main.overlay.get_child_count()>0,"an unconfirmed claim pauses combat and keeps recovery controls available")
	Cloud.pending_claim = ""; main.close_modal()
	await Cloud.logout()
	State.test_mode = false
	check.call(not State.activate_salvage(certificate_id) and State.salvage.active_id=="base","logged-out cloud schemes cannot switch locally while the server keeps the old scheme")
	var pending: int = State.pending_credits
	check.call(not State.claim_idle() and State.pending_credits==pending and State.credits==paid,"a bound cloud save cannot fall back to local payouts after logout")
	State.test_mode = true
	for path in [State.save_path(),State.save_path()+".before_cloud.json",Cloud.session_path()]: DirAccess.remove_absolute(path)
	Cloud.token = ""; Cloud.username = ""; Cloud.server_id = ""; Cloud.clock_base = -1
	Cloud.remote_revision = -1; Cloud.remote_exists = false; Cloud.endpoint = old_endpoint; Cloud.session_override = old_session
	State.import_game(original); State.save_override = old_save; State.settlement_clock_override = old_clock
	World.enabled = world_enabled
