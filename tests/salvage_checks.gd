extends RefCounted

func run(check: Callable, _main: Node) -> void:
	var ledger = State.SALVAGE.new()
	for hours in [24,25,48,72,100]:
		ledger = State.SALVAGE.new(); ledger.accrue(hours*3600)
		var effective := minf(hours,24)+0.5*minf(maxf(0,hours-24),48)
		check.call(ledger.pending().credits==int(effective*36000) and ledger.pending().cores==int(effective*120),"idle tiers integrate %d hours without exceeding the seventy-two-hour limit" % hours)
	ledger = State.SALVAGE.new(); ledger.cursor = 1000; ledger.catch_up(4600)
	var credited: int = ledger.pending().credits
	ledger.catch_up(4600); ledger.catch_up(500)
	check.call(ledger.pending().credits==credited and ledger.cursor==4600,"duplicate or backward clock observations cannot credit the same interval again")
	ledger.claim(); ledger.catch_up(4600)
	check.call(ledger.pending().credits==0 and ledger.age==0,"claiming cannot reset the high-water timestamp and replay a previous interval")
	var old_parts = State.parts
	var old_rig = State.rig
	var old_defense = State.defense
	var old_salvage = State.salvage
	var old_expedition = State.expedition
	var old_job = State.certification_job
	var levels: Array = State.levels.duplicate()
	var unlocked: Array = State.unlocked.duplicate()
	var tactics: Array = State.tactics.duplicate(true)
	var world: Dictionary = World.export_save().duplicate(true)
	var values := [State.selected,State.hp,State.recovery,State.energy,State.stage,State.wins,State.credits,State.cores,State.gems,State.auto,State.auto_skill,World.enabled,State.certification_committed,State.certification_result_id,State.settlement_clock_override]
	State.parts = State.PARTS.new()
	for index in range(6):
		var part: Dictionary = State.parts.roll([0,1,5,8,10,12][index],0)
		part.affixes = [{"stat":"attack","value":3}]; part.mechanism = "pierce" if index<2 else ""
		State.parts.equip(0,part.id,[0,4,1,2,3,5][index])
	State.selected = 0; State.levels = [1,1,1]; State.unlocked = [true,true,false]
	State.tactics = [State.TACTICS.defaults(),State.TACTICS.defaults(),State.TACTICS.defaults()]
	State.expedition = State.EXPEDITION.new(); State.salvage = State.SALVAGE.new(); State.salvage.cursor = 1000
	State.settlement_clock_override = 1000
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	State.defense.configure(State.parts.stats(0),true)
	State.hp = 100; State.recovery = 0; State.energy = 25; State.stage = 1; State.auto_skill = true
	World.enabled = true; World.import_save({"docked":true})
	check.call(not State.start_certification(0),"an uncontrolled region cannot be certified or simulated as a first boss kill")
	State.expedition.clears[0] = 1
	var simulator = load("res://scripts/certification.gd")
	var snapshot: Dictionary = simulator.capture(State)
	var job = simulator.new(snapshot,0)
	check.call(job.actor.weapon_profiles()==State.weapon_profiles() and job.actor.combat_configuration()==State.combat_configuration(),"certification is an instance of the actual combat controller with the same weapon and thermal configuration")
	var live := {"parts":State.parts.export_save(),"world":World.export_save(),"credits":State.credits,"cores":State.cores,"stage":State.stage,"hp":State.hp,"wins":State.wins,"region_clears":State.expedition.clears.duplicate()}
	seed(20261110); var expected := randf(); seed(20261110)
	for _i in range(600):
		job.advance(24)
		if job.done: break
	print("SALVAGE CERT success=%s reason=%s seconds=%.2f hp=%.2f trials=%d" % [job.success,job.reason,job.total_elapsed,job.lowest_hp,job.trials.size()])
	check.call(job.done and job.success and job.trials.size()==3 and job.total_elapsed>0 and job.trials.all(func(trial): return trial.hits>0 and trial.damage>0),"three real automatic cleanups measure actual hits, damage, elapsed time and survival")
	check.call(randf()==expected,"the detached simulator uses private RNG and cannot perturb the live combat or loot stream")
	check.call(live=={"parts":State.parts.export_save(),"world":World.export_save(),"credits":State.credits,"cores":State.cores,"stage":State.stage,"hp":State.hp,"wins":State.wins,"region_clears":State.expedition.clears.duplicate()},"simulated movement, enemy rewards, damage and deaths cannot modify the live player, world, inventory or progression")
	var result: Dictionary = job.result()
	# New roster entries must survive the same detached simulation and persisted certificate path.
	for pilot in range(3,State.PILOTS.size()):
		var expanded: Dictionary = snapshot.duplicate(true)
		expanded.pilot = pilot; expanded.mech = pilot
		expanded.levels = [1,1,1,1,1,1]; expanded.unlocked = [true,true,true,true,true,true]
		expanded.parts.loadouts[pilot] = expanded.parts.loadouts[0].duplicate(true)
		expanded.parts.loadouts[0] = {}
		var expanded_job = simulator.new(expanded,0)
		expanded_job.advance(16)
		check.call(expanded_job.actor.selected==pilot and expanded_job.actor.selected_mech==pilot and expanded_job.actor.tactics.size()==State.MECHS.MODELS.size() and not expanded_job.actor.weapon_profiles().is_empty(),"expanded pilot/chassis %d enters real detached certification with its own build" % pilot)
		expanded_job.dispose()
		var expanded_result: Dictionary = result.duplicate(true)
		expanded_result.snapshot = expanded
		var expanded_ledger = State.SALVAGE.new()
		var expanded_id: String = expanded_ledger.add_certificate(expanded_result,State.PILOTS[pilot].name)
		expanded_ledger.activate(expanded_id,1000)
		var reloaded = State.SALVAGE.new(); reloaded.import_save(JSON.parse_string(JSON.stringify(expanded_ledger.export_save())))
		check.call(reloaded.certificates.size()==1 and reloaded.active_id==expanded_id and reloaded.certificates[0].snapshot.pilot==pilot and reloaded.certificates[0].snapshot.mech==pilot and reloaded.certificates[0].snapshot.parts.loadouts[pilot]==expanded.parts.loadouts[pilot],"expanded certification %d preserves pilot, chassis and equipment through JSON reload" % pilot)
	var legacy_result: Dictionary = result.duplicate(true)
	legacy_result.snapshot.levels = [4,2,1]; legacy_result.snapshot.unlocked = [true,true,false]
	var legacy_ledger = State.SALVAGE.new(); legacy_ledger.add_certificate(legacy_result,"旧档")
	var migrated_ledger = State.SALVAGE.new(); migrated_ledger.import_save(legacy_ledger.export_save())
	check.call(migrated_ledger.certificates[0].snapshot.levels==[4,2,1,1,1,1] and migrated_ledger.certificates[0].snapshot.unlocked==[true,true,false,false,false,false],"legacy three-pilot certificates append locked level-one pilots without rewriting old progress")
	var solo_snapshot: Dictionary = snapshot.duplicate(true)
	solo_snapshot.parts.loadouts[0].erase("0")
	var solo = simulator.new(solo_snapshot,0)
	var edge_path: PackedVector2Array = solo.arena.build_path(Vector2(1088,814),Vector2(1626,374))
	var bounded_path := not edge_path.is_empty()
	for point in edge_path: bounded_path = bounded_path and point==solo.arena.bounded(point)
	check.call(bounded_path,"automatic paths keep every cell-center waypoint inside the playable arena bounds")
	for _i in range(600):
		solo.advance(24)
		if solo.done: break
	print("SALVAGE SOLO success=%s reason=%s details=%s" % [solo.success,solo.reason,JSON.stringify(solo.failure_details)])
	check.call(solo.success and solo.trials.size()==3,"a single legal ranged weapon completes all three cleanups without getting trapped at arena edges")
	var regional: Dictionary = snapshot.duplicate(true)
	regional.levels = [4,4,1]; regional.stage = 20
	for part in regional.parts.inventory:
		part.quality = 1; part.level = 4; part.affixes = [{"stat":"attack","value":6},{"stat":"haste","value":4}]
	for region in range(1,4):
		var local_job = simulator.new(regional,region)
		for _i in range(600):
			local_job.advance(24)
			if local_job.done: break
		print("SALVAGE REGION %d success=%s seconds=%.2f hp=%.2f" % [region,local_job.success,local_job.total_elapsed,local_job.lowest_hp])
		check.call(local_job.success and local_job.trials.size()==3,"regional certification %d completes its actual enemy profiles and environmental conditions" % region)
	var failed = simulator.new(snapshot,0)
	failed.actor.hp = 1; failed.actor.tactics[0].survival = "withdraw"; failed.advance()
	check.call(failed.done and not failed.success and failed.result().is_empty(),"an actual tactical withdrawal fails certification instead of issuing a favorable snapshot")
	failed = null
	var cancelled = simulator.new(snapshot,0); cancelled = null
	check.call(State.hp==live.hp and State.credits==live.credits,"cancelling and disposing a detached cleanup has no real resource side effects")
	if result.is_empty():
		result = {"version":1,"region":0,"snapshot":snapshot,"grade":"C","seconds":120.0,"minimum_hp":1.0,"trials":[{},{},{}],"rates":{"credits":36000.0,"cores":120.0,"parts":3.0,"research":1.0,"samples":1.0}}
	var a: String = ledger.add_certificate(result,"测试机师")
	ledger = State.SALVAGE.new(); a = ledger.add_certificate(result,"方案A")
	var second: Dictionary = result.duplicate(true)
	second.rates = {"credits":18000.0,"cores":60.0,"parts":2.0,"research":2.0,"samples":1.0}
	var b: String = ledger.add_certificate(second,"方案B")
	ledger.activate(a,1000); ledger.catch_up(4600); ledger.activate(b,4600); ledger.catch_up(8200)
	check.call(ledger.rows.size()==2 and ledger.rows[0].effective_seconds==3600 and ledger.rows[1].effective_seconds==3600 and ledger.pending().credits==int(result.rates.credits)+18000,"switching schemes settles prior time at its original certified rate and keeps separate source accounts")
	ledger = State.SALVAGE.new(); a = ledger.add_certificate(result,"方案A"); b = ledger.add_certificate(second,"方案B")
	ledger.activate(a,1000); ledger.accrue(86400); ledger.activate(b,1000); ledger.accrue(86400)
	check.call(ledger.pending().credits==int(result.rates.credits*24)+18000*12,"changing schemes cannot restart the first twenty-four full-rate hours")
	ledger.activate(a,1000); ledger.accrue(172800)
	check.call(ledger.age==259200 and ledger.rows[0].effective_seconds+ledger.rows[1].effective_seconds==172800,"arbitrary scheme changes still share the seventy-two-hour global capacity")
	ledger = State.SALVAGE.new(); second.rates.parts = 0.25; second.rates.research = 0.25
	a = ledger.add_certificate(second,"小数方案"); ledger.activate(a,1000)
	var equipment := 0; var research := 0
	for _i in range(4):
		ledger.accrue(3600); var receipt: Dictionary = ledger.claim()
		equipment += int(receipt.parts); research += int(receipt.research)
	check.call(equipment==1 and research==1 and ledger.claim().is_empty(),"fractional equipment and research survive frequent claims and mature exactly once")
	var exported: Dictionary = ledger.export_save()
	var restored = State.SALVAGE.new(); restored.import_save(JSON.parse_string(JSON.stringify(exported)))
	check.call(restored.active_id==ledger.active_id and restored.pending()==ledger.pending() and restored.claims==4,"certificates, active scheme, fractional carries and receipt sequence survive JSON roundtrip")
	State.certification_job = null
	check.call(State.start_certification(0),"controlled-region certification starts from the actual current build")
	var original_attack: int = State.parts.equipped(0,0).affixes[0].value
	State.parts.equipped(0,0).affixes[0].value += 1
	for _i in range(600):
		State.advance(0)
		if State.certification_committed: break
	check.call(State.certification_committed and not State.certification_result_id.is_empty() and State.salvage.certificates.size()==1,"completed certification creates one persistent usable certificate")
	var record: Dictionary = State.salvage.certificates[0]
	check.call(record.snapshot.parts.inventory[0].affixes[0].value==original_attack,"changing live equipment while certification runs cannot change its immutable snapshot")
	check.call(State.activate_salvage(record.id),"a successful controlled-region certificate can be enabled independently of live equipment")
	_main.show_certification_progress(); _main.close_modal()
	State.salvage.accrue(3600)
	var due: Dictionary = State.salvage.pending()
	while State.parts.inventory.size()<State.PARTS.LIMIT: State.parts.roll()
	var old_credits: int = State.credits; var old_cores: int = State.cores; var old_samples: int = State.expedition.samples[0]
	var old_overflow: int = State.parts.overflow.size()
	check.call(State.claim_idle() and State.credits==old_credits+int(due.credits) and State.cores==old_cores+int(due.cores),"claim atomically transfers the calculated whole currency rewards")
	check.call(State.parts.overflow.size()==old_overflow+int(due.parts) and State.parts.research_materials==int(due.research) and State.expedition.samples[0]==old_samples+int(due.samples),"offline equipment is real compatible regional loot, retained in overflow alongside usable research materials and samples")
	check.call(State.parts.overflow.all(func(part): return part.blueprint in State.expedition.DATA.REGIONS[0].pool and part.affixes.size()==int(part.quality)+1 and (part.mechanism=="" or part.mechanism in State.parts.mechanism_pool(part.blueprint))),"offline gear uses the same blueprint, affix and optional mechanism compatibility rules as active play")
	old_credits = State.credits; old_overflow = State.parts.overflow.size()
	check.call(not State.claim_idle() and State.credits==old_credits and State.parts.overflow.size()==old_overflow,"a second claim cannot duplicate currency, gear or research")
	var rare: Dictionary = State.parts.roll(0,1,true)
	var common: Dictionary = State.parts.roll(0,0,true)
	check.call(State.parts.recycle_fresh_common(rare.id)==0 and State.parts.recycle_fresh_common(common.id)==6 and not State.parts.find_any(rare.id).is_empty(),"automatic common dismantling also works in overflow and always preserves rare equipment")
	State.parts.research_materials = 6; State.parts.research.pulse = 0
	check.call(State.invest_research("pulse") and State.parts.research_ready("pulse") and State.parts.research_materials==0,"offline research materials can really complete a chosen mechanism's research")
	_main.show_idle(); _main.show_certificates(); _main.salvage_ui.show_certificate_detail(record.id)
	_main.salvage_ui.show_salvage_accounts(); _main.salvage_ui.show_salvage_accounts(true)
	State.parts.research_materials = 1; _main.show_mechanism_research(State.parts.inventory[0].id); _main.close_modal()
	check.call(true,"idle ledger, certificate list/detail/progress, source history and research-material controls build")
	State.salvage.auto_recycle = true; State.salvage.accrue(8*3600); seed(20261110)
	old_cores = State.cores
	check.call(State.claim_idle() and State.salvage.last_claim.recycled>0 and State.salvage.last_claim.saved_part_ids.size()+int(State.salvage.last_claim.recycled)==int(State.salvage.last_claim.parts),"enabled automatic dismantling accounts for every rolled offline component once")
	check.call(State.salvage.last_claim.saved_part_ids.all(func(id): return State.parts.find_any(int(id)).quality>0) and State.cores==old_cores+int(State.salvage.last_claim.cores)+6*int(State.salvage.last_claim.recycled),"automatic claim dismantling preserves every rare item and awards the exact common salvage materials")
	State.save_override = ProjectSettings.globalize_path("res://tests/salvage_save_fixture.json")
	State.save_game(); var certificate_id: String = State.salvage.active_id; State.salvage = State.SALVAGE.new(); State.load_game()
	check.call(State.salvage.active_id==certificate_id and State.salvage.certificates.size()==1 and not State.claim_idle(),"an actual disk reload preserves the certified scheme and cannot replay a completed reward receipt")
	DirAccess.remove_absolute(State.save_path()); State.save_override = ""
	State.certification_job = old_job; State.salvage = old_salvage; State.expedition = old_expedition; State.parts = old_parts; State.rig = old_rig; State.defense = old_defense
	State.levels = levels; State.unlocked = unlocked; State.tactics = tactics
	State.selected = values[0]; State.hp = values[1]; State.recovery = values[2]; State.energy = values[3]; State.stage = values[4]; State.wins = values[5]; State.credits = values[6]; State.cores = values[7]; State.gems = values[8]; State.auto = values[9]; State.auto_skill = values[10]; State.certification_committed = values[12]; State.certification_result_id = values[13]; State.settlement_clock_override = values[14]
	World.import_save(world); World.enabled = values[11]
