"""Server-time idle accounting and drops. Catalog is exported from the Godot source."""
import copy
import json
import math
import pathlib
import random

CATALOG = json.loads(pathlib.Path(__file__).with_name('catalog.json').read_text())
FIELDS = ('credits', 'cores', 'parts', 'research', 'samples')
BASE_RATES = dict(credits=36000.0, cores=120.0, parts=0.0, research=0.0, samples=0.0)
MAX_AGE = 72 * 3600

class Invalid(ValueError):
    pass

def number(value, low=0, high=1_000_000_000, default=0):
    if type(value) not in (int, float) or not math.isfinite(value):
        return default
    return min(high, max(low, value))

def integer(value, low=0, high=1_000_000_000):
    if type(value) not in (int, float) or not math.isfinite(value) or value != int(value) or not low <= value <= high:
        raise Invalid('存档中的整数或范围无效')
    return int(value)

def effective(age):
    return min(max(age, 0), 86400) + .5 * min(max(age - 86400, 0), 172800)

def validate_mechs(raw):
    if not isinstance(raw, dict) or raw.get('schema') != 1 or not isinstance(raw.get('units'), list) or len(raw['units']) not in (3, CATALOG['mech_count']):
        raise Invalid('机库数据无效')
    for index, unit in enumerate(raw['units']):
        if not isinstance(unit, dict):
            raise Invalid('机体编号或型号无效')
        integer(unit.get('id'), index + 1, index + 1)
        integer(unit.get('model'), index, index)
        integer(unit.get('level'), 1, 9999)
        if not isinstance(unit.get('affixes'), list) or len(unit['affixes']) != 2:
            raise Invalid('每台机体需要两条独立词条')
        seen = set()
        for affix in unit['affixes']:
            if not isinstance(affix, dict) or not isinstance(affix.get('stat'), str) or affix['stat'] not in CATALOG['mech_affixes'] or affix['stat'] in seen:
                raise Invalid('机体词条无效或重复')
            seen.add(affix['stat'])
            rule = CATALOG['mech_affixes'][affix['stat']]
            integer(affix.get('value'), rule['min'], rule['max'])
    return raw

def validate_pilots(raw, selection):
    # Legacy three-pilot saves remain valid; clients append the expansion slots on import.
    levels, unlocked = raw.get('levels'), raw.get('unlocked')
    if not isinstance(levels, list) or len(levels) not in (3, CATALOG['pilot_count']) or not isinstance(unlocked, list) or len(unlocked) != len(levels):
        raise Invalid('机师数据无效')
    for level in levels:
        integer(level, 1, 9999)
    if any(type(flag) is not bool for flag in unlocked):
        raise Invalid('机师解锁数据无效')
    integer(raw.get(selection), 0, len(levels) - 1)

def certificates(raw, clears):
    if not isinstance(raw, list) or len(raw) > 256:
        raise Invalid('认证档案数量无效')
    records, seen = [], set()
    for item in raw:
        if not isinstance(item, dict) or item.get('version') != 1:
            raise Invalid('认证档案版本无效')
        region = integer(item.get('region'), 0, 3)
        ident = item.get('id', '')
        if not isinstance(ident, str) or not ident.startswith('cert:') or not ident[5:].isdigit() or len(ident) > 64 or ident in seen:
            raise Invalid('认证档案编号无效')
        seen.add(ident)
        trials = item.get('trials')
        snapshot = item.get('snapshot')
        if not isinstance(trials, list) or len(trials) != 3 or not isinstance(snapshot, dict) or not isinstance(snapshot.get('parts'), dict):
            raise Invalid('需要三次清剿记录和配装快照')
        validate_pilots(snapshot, 'pilot')
        if 'mech' in snapshot or 'mechs' in snapshot:
            validate_mechs(snapshot.get('mechs'))
            integer(snapshot.get('mech'), 0, len(snapshot['mechs']['units']) - 1)
        seconds = sum(number(t.get('seconds'), .05, 120, 120) for t in trials if isinstance(t, dict)) / 3
        if any(not isinstance(t, dict) or not .05 <= number(t.get('seconds'), 0, 120) <= 120 for t in trials):
            raise Invalid('清剿计时无效')
        hp = min(number(item.get('minimum_hp'), 0, 100), *(number(t.get('hp'), 0, 100) for t in trials))
        stability = min(1, max(.55, hp / 60))
        efficiency = min(1.5, max(.5, (8 + 2 * region) / seconds)) * stability
        record = copy.deepcopy(item)
        record.update(name=str(item.get('name', '认证档案'))[:60], seconds=seconds, minimum_hp=hp,
                      rates=dict(credits=(12 + region * 6) * 3600 * efficiency,
                                 cores=(120 + region * 30) * efficiency,
                                 parts=(3 + region * .5) * efficiency,
                                 research=(1 + region * .5) * efficiency, samples=stability))
        records.append(record)
    return records

def validate_save(raw):
    if not isinstance(raw, dict) or raw.get('version') != 1:
        raise Invalid('不支持此存档版本')
    try:
        json.dumps(raw, allow_nan=False)
    except (ValueError, RecursionError):
        raise Invalid('存档含有无效数值或过深结构')
    state = copy.deepcopy(raw)
    validate_pilots(state, 'selected')
    if 'mechs' in state or 'selected_mech' in state:
        validate_mechs(state.get('mechs'))
        integer(state.get('selected_mech'), 0, len(state['mechs']['units']) - 1)
    for key in ('credits', 'cores', 'gems', 'wins', 'upgrades', 'recruits'):
        state[key] = integer(state.get(key, 0))
    carrier = state.setdefault('carrier', {'levels': dict(cannon=1, repair=1, logistics=1)})
    if not isinstance(carrier, dict) or not isinstance(carrier.get('levels'), dict):
        raise Invalid('母舰改造数据无效')
    carrier['levels'] = {key: integer(carrier['levels'].get(key, 1), 1, 5)
                         for key in ('cannon', 'repair', 'logistics')}
    state['stage'] = integer(state.get('stage', 1), 1)
    if not isinstance(state.get('world'), dict) or not isinstance(state.get('claimed', []), list):
        raise Invalid('战区或任务数据无效')
    parts = state.get('parts')
    if not isinstance(parts, dict):
        raise Invalid('部件仓库无效')
    seen = set()
    for field in ('inventory', 'overflow'):
        parts.setdefault(field, [])
        if not isinstance(parts[field], list) or len(parts[field]) > (120 if field == 'inventory' else 20000):
            raise Invalid('部件仓库大小无效')
        for part in parts[field]:
            if not isinstance(part, dict):
                raise Invalid('部件格式无效')
            ident = integer(part.get('id'), 1)
            bp = integer(part.get('blueprint'), 0, len(CATALOG['blueprints']) - 1)
            quality = integer(part.get('quality'), 0, 2)
            integer(part.get('level', 1), 1, 9999)
            if ident in seen or part.get('slot') != CATALOG['blueprints'][bp]['slot']:
                raise Invalid('部件编号或装配位冲突')
            seen.add(ident)
            part['locked'] = bool(part.get('locked', False)) or bool(part.get('favorite', False))
            part['favorite'] = False
            if part.get('mechanism', '') and part['mechanism'] not in CATALOG['mechanism_pools'][bp]:
                raise Invalid('部件机制与标签不兼容')
            affixes = part.get('affixes')
            if not isinstance(affixes, list) or len(affixes) > 3:
                raise Invalid('部件词条无效')
            stats = set()
            for affix in affixes:
                if not isinstance(affix, dict) or affix.get('stat') not in CATALOG['affixes'] or affix['stat'] in stats:
                    raise Invalid('部件数值词条无效')
                stats.add(affix['stat'])
                integer(affix.get('value'), 0, CATALOG['affixes'][affix['stat']]['max'] * (quality + 1))
    parts['next_id'] = max(integer(parts.get('next_id', 1), 1), max(seen, default=0) + 1)
    if not isinstance(parts.get('loadouts'), list) or len(parts['loadouts']) not in (3, CATALOG['mech_count']):
        raise Invalid('配装档案无效')
    for loadout in parts['loadouts']:
        if not isinstance(loadout, dict):
            raise Invalid('配装档案无效')
        for slot, ident in loadout.items():
            if slot not in ('0', '1', '2', '3', '4', '5') or integer(ident, 1) not in seen:
                raise Invalid('配装引用了不存在的部件')
    parts['research_materials'] = integer(parts.get('research_materials', 0))
    if not isinstance(parts.get('research', {}), dict):
        raise Invalid('机制研究数据无效')
    area = state.setdefault('expedition', {})
    if not isinstance(area, dict):
        raise Invalid('探索记录无效')
    for field in ('clears', 'samples'):
        area.setdefault(field, [0, 0, 0, 0])
        if not isinstance(area[field], list) or len(area[field]) != 4:
            raise Invalid('区域数据无效')
        area[field] = [integer(v) for v in area[field]]
    state['salvage'] = clean_ledger(state.get('salvage'), area['clears'])
    return state

def clean_ledger(raw, clears):
    raw = raw if isinstance(raw, dict) else {}
    records = certificates(raw.get('certificates', []), clears)
    active = raw.get('active_id', 'base')
    valid = {r['id']: r for r in records}
    if active != 'base' and (active not in valid or not clears[valid[active]['region']]):
        raise Invalid('回收区域尚未控制或认证不存在')
    ledger = dict(version=1, cursor=number(raw.get('cursor'), 0, 100_000_000_000),
                  age=number(raw.get('age'), 0, MAX_AGE), sequence=int(number(raw.get('sequence'))),
                  claims=int(number(raw.get('claims'))), active_id=active, certificates=records,
                  rows=[], last_claim=raw.get('last_claim', {}), auto_recycle=raw.get('auto_recycle') is True)
    rows = raw.get('rows', [])
    if not isinstance(rows, list) or len(rows) > 2048:
        raise Invalid('回收分账无效')
    seen = set()
    for item in rows:
        if not isinstance(item, dict) or not isinstance(item.get('id'), str) or item['id'] in seen:
            raise Invalid('重复或无效的回收来源')
        seen.add(item['id'])
        row = dict(id=item['id'][:64], name=str(item.get('name', '回收结余'))[:60],
                   region=integer(item.get('region', -1), -1, 3),
                   raw_seconds=number(item.get('raw_seconds'), 0, MAX_AGE),
                   effective_seconds=number(item.get('effective_seconds'), 0, MAX_AGE))
        rates = item.get('rates', {})
        rates = rates if isinstance(rates, dict) else {}
        source = valid.get(row['id'])
        row['rates'] = copy.deepcopy(BASE_RATES if row['id'] == 'base' else source['rates'] if source else {key: number(rates.get(key)) for key in FIELDS})
        row.update({key: number(item.get(key)) for key in FIELDS})
        ledger['rows'].append(row)
    return ledger

def catch_up(ledger, now):
    cursor = ledger['cursor']
    gap = max(0, now - cursor) if cursor > 0 else 0
    ledger['cursor'] = max(cursor, now)
    before = ledger['age']
    ledger['age'] = min(MAX_AGE, before + gap)
    weighted = effective(ledger['age']) - effective(before)
    if weighted <= 0:
        return
    record = next((r for r in ledger['certificates'] if r['id'] == ledger['active_id']),
                  dict(id='base', name='基础回收队', region=-1, rates=BASE_RATES))
    row = next((r for r in ledger['rows'] if r['id'] == record['id']), None)
    if row is None:
        row = dict(id=record['id'], name=record['name'], region=record['region'], rates=copy.deepcopy(record['rates']),
                   raw_seconds=0, effective_seconds=0, **{key: 0.0 for key in FIELDS})
        ledger['rows'].append(row)
    row['raw_seconds'] += ledger['age'] - before
    row['effective_seconds'] += weighted
    for key in FIELDS:
        row[key] += row['rates'][key] * weighted / 3600

def merge_incoming(incoming, previous, now):
    state = validate_save(incoming)
    if previous is None:
        if sum(row['parts'] for row in state['salvage']['rows']) > 4096:
            raise Invalid('待领装备数量超过单次结算范围，请先整理本机回收记录')
        # Migration preserves already-earned local balances, then anchors future time to the server.
        state['salvage']['cursor'] = now
    else:
        ledger = copy.deepcopy(previous['salvage'])
        catch_up(ledger, now)
        old_records = {r['id']: r for r in ledger['certificates']}
        requested = state['salvage']
        ledger['certificates'] = [old_records.get(r['id'], r) for r in requested['certificates']]
        ledger['active_id'] = requested['active_id']
        ledger['auto_recycle'] = requested['auto_recycle']
        ledger['sequence'] = max(ledger['sequence'], requested['sequence'])
        active = next((r for r in ledger['certificates'] if r['id'] == ledger['active_id']), None)
        if active and not state['expedition']['clears'][active['region']]:
            raise Invalid('回收区域尚未控制')
        state['salvage'] = ledger
    state['last_seen'] = int(now)
    return state

def pending(ledger):
    result = {key: math.floor(sum(r[key] for r in ledger['rows']) + 1e-8) for key in ('credits', 'cores', 'research')}
    result.update(parts=0, samples=0, regions=[])
    for region in range(4):
        row = dict(region=region, **{key: math.floor(sum(r[key] for r in ledger['rows'] if r['region'] == region) + 1e-8) for key in ('parts', 'samples')})
        result['parts'] += row['parts']; result['samples'] += row['samples']; result['regions'].append(row)
    return result

def roll_part(parts, region, rng):
    blueprint = rng.choice(CATALOG['regions'][region]['pool'])
    model = CATALOG['blueprints'][blueprint]
    chance = rng.random(); quality = 2 if chance < .1 else 1 if chance < .4 else 0
    stats = rng.sample(list(CATALOG['affixes']), quality + 1)
    affixes = [dict(stat=key, value=rng.randint(CATALOG['affixes'][key]['min'], CATALOG['affixes'][key]['max']) * (quality + 1)) for key in stats]
    mechanism = ''; pool = CATALOG['mechanism_pools'][blueprint]
    if pool and (model['slot'] == 0 or rng.random() < .35 + quality * .3):
        mechanism = rng.choice(pool)
    part = dict(id=parts['next_id'], blueprint=blueprint, slot=model['slot'], quality=quality,
                level=1, locked=False, favorite=False, reforge_slot=-1, affixes=affixes, mechanism=mechanism)
    parts['next_id'] += 1
    return part

def claim(state, rng=None):
    rng = rng or random.SystemRandom()
    ledger = state['salvage']; result = pending(ledger)
    if not any(result[key] for key in FIELDS):
        return {}
    ledger['claims'] += 1
    result.update(receipt=ledger['claims'], seconds=ledger['age'], effective_seconds=effective(ledger['age']),
                  sources=copy.deepcopy(ledger['rows']), recycled=0, saved_part_ids=[])
    def deduct(field, amount, region=None):
        for row in ledger['rows']:
            if region is not None and row['region'] != region:
                continue
            used = min(amount, row[field]); row[field] = max(0, row[field] - used); amount -= used
            if amount <= 1e-8:
                break
    for key in ('credits', 'cores', 'research'):
        deduct(key, result[key])
    for area in result['regions']:
        for key in ('parts', 'samples'):
            deduct(key, area[key], area['region'])
    for row in ledger['rows']:
        row['raw_seconds'] = 0; row['effective_seconds'] = 0
    ledger['rows'] = [r for r in ledger['rows'] if any(r[k] > 1e-8 for k in FIELDS)]
    ledger['age'] = 0
    state['credits'] += result['credits']; state['cores'] += result['cores']
    parts = state['parts']; parts['research_materials'] += result['research']
    for area in result['regions']:
        state['expedition']['samples'][area['region']] += area['samples']
        for _ in range(area['parts']):
            part = roll_part(parts, area['region'], rng)
            if ledger['auto_recycle'] and part['quality'] == 0:
                result['recycled'] += 1; state['cores'] += 6
                mechanism = part['mechanism']
                if mechanism:
                    research = parts.setdefault('research', {})
                    research[mechanism] = min(CATALOG['research_target'], int(research.get(mechanism, 0)) + 1)
            else:
                dest = parts['inventory'] if len(parts['inventory']) < CATALOG['inventory_limit'] else parts['overflow']
                dest.append(part); result['saved_part_ids'].append(part['id'])
    ledger['last_claim'] = copy.deepcopy(result)
    state['pending_credits'] = 0; state['pending_cores'] = 0
    return result
