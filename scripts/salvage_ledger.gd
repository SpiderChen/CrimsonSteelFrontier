extends RefCounted
## Time is integrated once across all schemes; changing a build never resets the tier budget.
const VERSION = 1
const MAX_SECONDS = 72.0*3600
const FIELDS = ["credits","cores","parts","research","samples"]
const BASE_RATES = {"credits":36000.0,"cores":120.0,"parts":0.0,"research":0.0,"samples":0.0}
const PARTS = preload("res://scripts/parts.gd")
const TACTICS = preload("res://scripts/tactics.gd")
const MECHS = preload("res://scripts/mechs.gd")
const PILOT_RUNTIME = preload("res://scripts/pilot_runtime.gd")
var cursor: float = 0
var age: float = 0
var sequence: int = 0
var certificates: Array = []
var active_id: String = "base"
var rows: Array = []
var claims: int = 0
var last_claim: Dictionary = {}
var auto_recycle: bool = false

static func effective(seconds: float) -> float:
	return minf(maxf(0,seconds),86400)+0.5*minf(maxf(0,seconds-86400),172800)

func active_record() -> Dictionary:
	for record in certificates:
		if record.id==active_id: return record
	return {"id":"base","name":"基础回收队","region":-1,"rates":BASE_RATES.duplicate()}

func row_for(record: Dictionary) -> Dictionary:
	for row in rows:
		if row.id==record.id: return row
	var row := {"id":record.id,"name":record.name,"region":record.region,"raw_seconds":0.0,"effective_seconds":0.0,"rates":record.rates.duplicate(true)}
	for field in FIELDS: row[field] = 0.0
	rows.append(row)
	return row

func accrue(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	var before := age
	age = minf(MAX_SECONDS,age+seconds)
	var weighted := effective(age)-effective(before)
	if weighted<=0: return
	var row := row_for(active_record())
	row.raw_seconds += age-before; row.effective_seconds += weighted
	for field in FIELDS: row[field] += float(row.rates.get(field,0))*weighted/3600.0

func catch_up(now: float) -> int:
	if not is_finite(now) or now<0: return 0
	if cursor<=0: cursor = now; return 0
	var gap := maxf(0,now-cursor)
	cursor = maxf(cursor,now)
	accrue(gap)
	return mini(int(MAX_SECONDS),int(gap))

func anchor(now: float) -> void:
	if is_finite(now): cursor = maxf(cursor,now)

func add_certificate(result: Dictionary, pilot_name: String) -> String:
	sequence += 1
	var record: Dictionary = result.duplicate(true)
	record.id = "cert:%d" % sequence
	record.name = "%s · %s级认证 %d" % [pilot_name,record.grade,sequence]
	certificates.append(record)
	return record.id

func activate(id: String, now: float) -> bool:
	var exists := id=="base"
	for record in certificates:
		if record.id==id: exists = true
	if not exists: return false
	catch_up(now)
	active_id = id
	return true

func pending() -> Dictionary:
	var result := {"credits":0,"cores":0,"research":0,"parts":0,"samples":0,"regions":[]}
	var sums := {"credits":0.0,"cores":0.0,"research":0.0}
	for row in rows:
		for field in sums: sums[field] += float(row.get(field,0))
	for field in sums: result[field] = int(floor(float(sums[field])+0.00000001))
	for region in range(4):
		var parts := 0.0; var samples := 0.0
		for row in rows:
			if int(row.region)==region: parts += float(row.parts); samples += float(row.samples)
		var area := {"region":region,"parts":int(floor(parts+0.00000001)),"samples":int(floor(samples+0.00000001))}
		result.parts += area.parts; result.samples += area.samples
		result.regions.append(area)
	return result

func deduct(field: String, amount: float, region: int = -1) -> void:
	for row in rows:
		if region>=0 and int(row.region)!=region: continue
		var used := minf(amount,float(row[field]))
		row[field] = maxf(0,float(row[field])-used); amount -= used
		if amount<=0.00000001: return

func claim() -> Dictionary:
	var result := pending()
	if int(result.credits)+int(result.cores)+int(result.research)+int(result.parts)+int(result.samples)<=0: return {}
	claims += 1
	result.receipt = claims; result.seconds = age; result.effective_seconds = effective(age)
	result.sources = rows.duplicate(true)
	for field in ["credits","cores","research"]: deduct(field,float(result[field]))
	for area in result.regions:
		deduct("parts",float(area.parts),int(area.region)); deduct("samples",float(area.samples),int(area.region))
	for row in rows: row.raw_seconds = 0.0; row.effective_seconds = 0.0
	rows = rows.filter(func(row): return FIELDS.any(func(field): return float(row[field])>0.00000001))
	age = 0
	last_claim = result.duplicate(true)
	return result

func override_legacy(field: String, value: int) -> void:
	if field not in ["credits","cores"]: return
	for row in rows: row[field] = 0.0
	var row := row_for({"id":"legacy","name":"原补给余额","region":-1,"rates":BASE_RATES.duplicate()})
	row[field] = maxf(0,value)

func export_save() -> Dictionary:
	return {"version":VERSION,"cursor":cursor,"age":age,"sequence":sequence,"certificates":certificates.duplicate(true),"active_id":active_id,"rows":rows.duplicate(true),"claims":claims,"last_claim":last_claim.duplicate(true),"auto_recycle":auto_recycle}

func number(value: Variant, fallback: float, maximum: float) -> float:
	return clampf(float(value),0,maximum) if (value is int or value is float) and is_finite(float(value)) else fallback

func clean_rates(raw: Variant) -> Dictionary:
	var result: Dictionary = BASE_RATES.duplicate()
	var maximums := {"credits":1000000.0,"cores":2000.0,"parts":20.0,"research":10.0,"samples":5.0}
	for field in FIELDS: result[field] = number(raw.get(field,0),0,maximums[field]) if raw is Dictionary else 0.0
	return result

func clean_row(item: Variant) -> Dictionary:
	if not item is Dictionary or not item.get("id") is String: return {}
	var raw_region = item.get("region",-1)
	if not (raw_region is int or raw_region is float) or not is_finite(float(raw_region)) or raw_region< -1 or raw_region>3 or floorf(float(raw_region))!=float(raw_region): return {}
	var row := {"id":str(item.id).left(64),"name":str(item.get("name","回收结余")).left(60),"region":int(raw_region),"rates":clean_rates(item.get("rates")),"raw_seconds":number(item.get("raw_seconds"),0,MAX_SECONDS),"effective_seconds":number(item.get("effective_seconds"),0,172800)}
	for field in FIELDS: row[field] = number(item.get(field),0,1000000000 if field=="credits" else 1000000)
	return row

func import_save(raw: Variant) -> void:
	cursor = 0; age = 0; sequence = 0; certificates.clear(); active_id = "base"; rows.clear(); claims = 0; last_claim.clear(); auto_recycle = false
	if not raw is Dictionary: return
	cursor = number(raw.get("cursor"),0,100000000000.0)
	age = number(raw.get("age"),0,MAX_SECONDS)
	sequence = int(number(raw.get("sequence"),0,100000000))
	claims = int(number(raw.get("claims"),0,100000000))
	auto_recycle = raw.get("auto_recycle",false)==true
	var records = raw.get("certificates",[])
	if records is Array:
		for item in records.slice(0,256):
			if not item is Dictionary or int(number(item.get("version"),0,100))!=VERSION or not item.get("id") is String or not item.id.begins_with("cert:"): continue
			if not item.get("snapshot") is Dictionary or not item.get("trials") is Array or item.trials.size()!=3 or item.get("grade") not in ["A","B","C"]: continue
			var region := int(number(item.get("region"),9,9))
			if region>=4 or not item.snapshot.get("parts") is Dictionary or not item.snapshot.get("levels") is Array or item.snapshot.levels.size() not in [3,PILOT_RUNTIME.ABILITIES.size()]: continue
			var pilot = item.snapshot.get("pilot")
			if not (pilot is int or pilot is float) or not is_finite(float(pilot)) or float(pilot)!=floorf(float(pilot)) or pilot<0 or pilot>=item.snapshot.levels.size(): continue
			if not item.snapshot.get("unlocked") is Array or item.snapshot.unlocked.size()!=item.snapshot.levels.size(): continue
			if certificates.any(func(record): return record.id==item.id): continue
			var record: Dictionary = item.duplicate(true)
			var equipment = PARTS.new(); equipment.import_save(item.snapshot.parts)
			record.snapshot.parts = equipment.export_save(); record.snapshot.pilot = int(pilot)
			record.snapshot.mech = int(number(item.snapshot.get("mech",pilot),int(pilot),MECHS.MODELS.size()-1))
			if item.snapshot.get("mechs") is Dictionary:
				var chassis = MECHS.new()
				chassis.import_save(item.snapshot.mechs)
				record.snapshot.mechs = chassis.export_save()
			record.snapshot.tactics = TACTICS.sanitize(item.snapshot.get("tactics"))
			for i in range(item.snapshot.levels.size()):
				record.snapshot.levels[i] = maxi(1,int(number(item.snapshot.levels[i],1,9999)))
				record.snapshot.unlocked[i] = item.snapshot.unlocked[i]==true
			while record.snapshot.levels.size()<PILOT_RUNTIME.ABILITIES.size(): record.snapshot.levels.append(1)
			while record.snapshot.unlocked.size()<PILOT_RUNTIME.ABILITIES.size(): record.snapshot.unlocked.append(false)
			record.name = str(item.get("name","认证档案")).left(60); record.region = region; record.rates = clean_rates(item.get("rates"))
			record.seconds = number(item.get("seconds"),120,120); record.minimum_hp = number(item.get("minimum_hp"),0,100)
			certificates.append(record)
			sequence = maxi(sequence,int(str(record.id).get_slice(":",1)))
	var id = raw.get("active_id","base")
	if id is String and certificates.any(func(record): return record.id==id): active_id = id
	var saved_rows = raw.get("rows",[])
	if saved_rows is Array:
		for item in saved_rows:
			var row := clean_row(item)
			if row.is_empty() or rows.any(func(existing): return existing.id==row.id): continue
			rows.append(row)
	if raw.get("last_claim") is Dictionary:
		for field in ["receipt","credits","cores","research","parts","samples","recycled"]: last_claim[field] = int(number(raw.last_claim.get(field),0,1000000000))
		last_claim.seconds = number(raw.last_claim.get("seconds"),0,MAX_SECONDS)
		last_claim.effective_seconds = number(raw.last_claim.get("effective_seconds"),0,172800)
		last_claim.sources = []
		if raw.last_claim.get("sources") is Array:
			for item in raw.last_claim.sources:
				var row := clean_row(item)
				if not row.is_empty(): last_claim.sources.append(row)
