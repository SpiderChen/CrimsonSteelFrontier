import concurrent.futures
import copy
import json
import pathlib
import random
import secrets
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

from server import app, economy

ROOT = pathlib.Path(__file__).resolve().parent.parent

def fixture():
    parts = dict(inventory=[dict(id=1, blueprint=0, slot=0, quality=0, level=1, affixes=[dict(stat='attack', value=3)], mechanism='pierce')],
                 overflow=[], loadouts=[{'0': 1}, {}, {}], presets=[[], [], []], next_id=2, research={}, research_materials=0)
    return dict(version=1, levels=[1,1,1], unlocked=[True,True,False], selected=0, stage=1, credits=2400, cores=120, gems=900,
                claimed=[], parts=parts, world=dict(docked=True), expedition=dict(clears=[1,1,1,1], samples=[0,0,0,0]),
                salvage=dict(version=1, cursor=1000, age=0, certificates=[], active_id='base', rows=[], sequence=0, claims=0))

def certificate(region=0, ident='cert:1'):
    state = fixture()
    return dict(version=1, id=ident, name='绯夜 · A级认证 1', region=region, grade='A', seconds=12, minimum_hp=80,
                snapshot=dict(pilot=0, pilot_name='绯夜', levels=state['levels'], unlocked=state['unlocked'], parts=state['parts']),
                trials=[dict(seconds=12, hp=80, damage=100, hits=10) for _ in range(3)], rates=dict(credits=999999999))

def mech_fixture():
    return dict(schema=1, units=[dict(id=i+1, model=i, level=i+1,
                affixes=[dict(stat='attack', value=4+i), dict(stat='cooling', value=2)]) for i in range(3)])

class Clock:
    value = 1000000.0
    def __call__(self): return self.value

class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / 'tests', prefix='cloud-')
        self.clock = Clock(); self.store = app.Store(pathlib.Path(self.temp.name) / 'save.sqlite3', self.clock)
        self.token = self.store.auth('register', dict(username='pilot_a', password='long-password-a'), 'A')['token']
    def tearDown(self): self.temp.cleanup()
    def put(self, state=None, revision=0):
        return self.store.mutate(self.token, dict(save=state or fixture(), revision=revision))
    def claim(self, state, revision, ident=None):
        return self.store.mutate(self.token, dict(save=state, revision=revision, request_id=ident or secrets.token_hex(16)), True)

    def test_expanded_roster_preserves_six_pilots_chassis_builds_and_certificates(self):
        self.assertEqual((economy.CATALOG['pilot_count'], economy.CATALOG['mech_count']), (6, 6))
        state = fixture()
        state.update(levels=[7, 4, 2, 5, 3, 8], unlocked=[True] * 6, selected=5, selected_mech=4, mechs=mech_fixture())
        state['parts']['inventory'][0].update(locked=False, favorite=False)
        state['mechs']['units'].extend(dict(id=i+1, model=i, level=i+2,
            affixes=[dict(stat='attack', value=5), dict(stat='supply', value=8)]) for i in range(3, 6))
        state['parts']['loadouts'].extend([{}, {'0': 1}, {}])
        state['parts']['presets'].extend([[], [dict(name='炮击', loadout={'0': 1})], []])
        record = certificate()
        record['snapshot'].update(pilot=5, levels=state['levels'], unlocked=state['unlocked'],
            mech=4, mechs=state['mechs'], parts=state['parts'])
        state['salvage']['certificates'] = [record]
        saved = self.put(state)['save']
        for key in ('levels', 'unlocked', 'selected', 'selected_mech', 'mechs', 'parts'):
            self.assertEqual(saved[key], state[key])
        self.assertEqual(saved['salvage']['certificates'][0]['snapshot'], record['snapshot'])
        self.assertEqual(self.store.read(self.token)['save']['selected'], 5)

    def test_expanded_roster_rejects_partial_or_out_of_range_data(self):
        state = fixture()
        self.put(state)
        for change in ('partial', 'mismatch', 'new_index_legacy', 'invalid_unlock'):
            broken = copy.deepcopy(state)
            if change == 'partial': broken['levels'].append(1); broken['unlocked'].append(False)
            elif change == 'mismatch': broken['levels'].extend([1, 1, 1])
            elif change == 'new_index_legacy': broken['selected'] = 5
            else: broken['unlocked'][1] = 1
            with self.subTest(change=change), self.assertRaises(economy.Invalid): self.put(broken, 1)
        self.assertEqual(self.store.read(self.token)['save']['levels'], [1, 1, 1])

    def test_independent_chassis_and_pilot_preserve_exact_rolls_in_cloud(self):
        state = fixture()
        state.update(selected=1, selected_mech=2, mechs=mech_fixture())
        first = self.put(state)
        self.assertEqual(first['save']['mechs'], state['mechs'])
        self.assertEqual((first['save']['selected'], first['save']['selected_mech']), (1, 2))
        record = certificate()
        record['snapshot'].update(mech=2, mechs=mech_fixture())
        first['save']['salvage']['certificates'] = [record]
        second = self.put(first['save'], 1)
        self.assertEqual(second['save']['salvage']['certificates'][0]['snapshot']['mechs'], state['mechs'])
        self.assertEqual(second['save']['salvage']['certificates'][0]['snapshot']['mech'], 2)

    def test_carrier_migration_and_upgrade_round_trip(self):
        old = self.put()
        self.assertEqual(old['save']['carrier']['levels'], dict(cannon=1, repair=1, logistics=1))
        state = old['save']
        state['carrier']['levels'] = dict(cannon=3, repair=2, logistics=5)
        state['expedition']['run'] = dict(schema=2, id=1, seed=12345, region=0, focus=0,
            phase='explore', visited={'0:3': True}, discovered=['map:1:poi:0'], used=['map:1:poi:0'],
            secured=[], cooling_seconds=50, bounty=80, elapsed=30, overworld={'docked': True},
            support=dict(cannon=1, repair=0, cooldown=12.5,
            pending=dict(point=[1536, 384], remaining=.7, damage=280, radius=200, mission=1)))
        saved = self.put(state, 1)
        self.assertEqual(saved['save']['carrier'], state['carrier'])
        self.assertEqual(saved['save']['expedition']['run']['support'], state['expedition']['run']['support'])
        self.assertEqual(saved['save']['expedition']['run'], state['expedition']['run'])
        for bad in (0, 6, '3', True, None, 1.5):
            broken = copy.deepcopy(saved['save'])
            broken['carrier']['levels']['cannon'] = bad
            with self.subTest(bad=bad), self.assertRaises(economy.Invalid): self.put(broken, 2)
        self.assertEqual(self.store.read(self.token)['save']['carrier'], state['carrier'])

    def test_invalid_chassis_or_affixes_cannot_replace_cloud_progress(self):
        state = fixture()
        state.update(selected_mech=0, mechs=mech_fixture())
        self.put(state)
        for change in ('duplicate', 'out_of_range', 'invalid_model', 'invalid_selection', 'missing_chassis'):
            with self.subTest(change=change):
                broken = copy.deepcopy(state)
                if change == 'duplicate': broken['mechs']['units'][0]['affixes'][1] = dict(stat='attack', value=4)
                elif change == 'out_of_range': broken['mechs']['units'][0]['affixes'][0]['value'] = 999
                elif change == 'invalid_model': broken['mechs']['units'][1]['model'] = 99
                elif change == 'invalid_selection': broken['selected_mech'] = 3
                else: broken.pop('mechs')
                with self.assertRaises(economy.Invalid): self.put(broken, 1)
        self.assertEqual(self.store.read(self.token)['save']['mechs'], state['mechs'])

    def test_melee_catalog_preserves_named_ids_and_cloud_loot_compatibility(self):
        self.assertEqual(economy.CATALOG['blueprints'][17]['signature'], 'pierce')
        self.assertEqual([economy.CATALOG['blueprints'][i]['trait'] for i in (21, 22, 23)], ['blade', 'gauntlet', 'hammer'])
        state = fixture()
        state['parts']['inventory'].append(dict(id=2, blueprint=22, slot=0, quality=0, level=1,
            affixes=[dict(stat='attack', value=3)], mechanism='ion'))
        state['parts']['loadouts'][0]['4'] = 2
        state['parts']['next_id'] = 3
        stored = self.put(state)['save']
        self.assertEqual(stored['parts']['loadouts'][0]['4'], 2)
        self.assertEqual(stored['parts']['inventory'][1]['blueprint'], 22)
        seen = set()
        rng = random.Random(21423)
        for _ in range(100):
            part = economy.roll_part(stored['parts'], 0, rng)
            if part['blueprint'] in (21, 22, 23):
                seen.add(part['blueprint'])
                self.assertIn(part['mechanism'], ('ion', 'hot_drive'))
        self.assertEqual(seen, {22, 23})

    def test_held_shield_and_legacy_favorite_locks_survive_cloud_roundtrip(self):
        state = fixture()
        state['parts']['inventory'][0].update(locked=False, favorite=True)
        state['parts']['inventory'].append(dict(id=2, blueprint=24, slot=0, quality=0, level=1,
            affixes=[dict(stat='armor', value=2)], mechanism='counter', locked=False, favorite=False))
        state['parts']['next_id'] = 3
        state['parts']['loadouts'][0]['4'] = 2
        state.update(guard=12, guard_break=1.5, guard_quiet=.5, guard_facing=[0, -1])
        saved = self.put(state)['save']
        self.assertTrue(saved['parts']['inventory'][0]['locked'])
        self.assertFalse(saved['parts']['inventory'][0]['favorite'])
        self.assertEqual(saved['parts']['inventory'][1]['blueprint'], 24)
        self.assertEqual((saved['guard'], saved['guard_break'], saved['guard_facing']), (12, 1.5, [0, -1]))

    def test_accounts_passwords_tokens_logout_and_isolation(self):
        self.put()
        second = self.store.auth('register', dict(username='pilot_b', password='long-password-b'), 'B')['token']
        self.assertIsNone(self.store.read(second)['save'])
        with self.store.connection() as db:
            row = dict(db.execute('SELECT * FROM accounts LIMIT 1').fetchone())
            self.assertNotIn('long-password-a', json.dumps(row))
            self.assertNotEqual(row['password_hash'], 'long-password-a')
            self.assertNotEqual(db.execute('SELECT token_hash FROM sessions LIMIT 1').fetchone()[0], self.token)
        with self.assertRaises(app.ApiError): self.store.auth('login', dict(username='pilot_a', password='wrong-password'), 'A')
        token = self.store.auth('login', dict(username='pilot_a', password='long-password-a'), 'A')['token']
        self.assertEqual(self.store.read(token)['revision'], 1)
        self.store.logout(token)
        with self.assertRaises(app.ApiError): self.store.read(token)
        self.assertEqual(self.store.read(self.token)['revision'], 1)

    def test_optimistic_save_rejects_stale_cross_device_overwrite(self):
        first = self.put(); altered = copy.deepcopy(first['save']); altered['credits'] += 500
        self.put(altered, 1)
        with self.assertRaises(app.ApiError) as error: self.put(first['save'], 1)
        self.assertEqual(error.exception.code, 'conflict')
        self.assertEqual(self.store.read(self.token)['save']['credits'], 2900)

    def test_server_time_ignores_both_future_and_rollback_client_clocks(self):
        first = self.put()
        self.clock.value += 48 * 3600
        bad = copy.deepcopy(first['save'])
        bad['last_seen'] = 1e11; bad['salvage'].update(cursor=1e11, age=72*3600)
        bad['salvage']['rows'] = [dict(id='base', region=-1, name='fake', credits=999999999, cores=888888, parts=0, research=0, samples=0, rates={})]
        second = self.put(bad, 1)
        earned = economy.pending(second['save']['salvage'])
        self.assertEqual(earned['credits'], 36 * 36000)
        self.assertEqual(earned['cores'], 36 * 120)
        self.assertEqual(second['save']['salvage']['cursor'], self.clock.value)
        self.clock.value += 24 * 3600
        second['save']['salvage']['cursor'] = 1
        third = self.put(second['save'], 2)
        self.assertEqual(economy.pending(third['save']['salvage'])['credits'], 48 * 36000)
        self.clock.value += 99 * 3600
        self.assertEqual(economy.pending(self.store.read(self.token)['save']['salvage'])['credits'], 48 * 36000)

    def test_switch_accounts_for_old_source_and_preserves_fractional_carries(self):
        state = fixture(); state['salvage']['certificates'] = [certificate()]
        first = self.put(state); self.clock.value += 3600
        draft = first['save']; draft['salvage']['active_id'] = 'cert:1'
        second = self.put(draft, 1)
        old = copy.deepcopy(second['save']['salvage']['rows'][0]); self.clock.value += 1800
        third = self.put(second['save'], 2)
        self.assertEqual(third['save']['salvage']['rows'][0], old)
        self.assertEqual(len(third['save']['salvage']['rows']), 2)
        receipt = self.claim(third['save'], 3)['receipt']
        self.assertEqual(receipt['credits'], 36000 + 14400)
        self.assertEqual(len(receipt['sources']), 2)
        self.assertEqual(receipt['parts'], 1)
        self.assertEqual(receipt['research'], 0)
        saved = self.store.read(self.token)['save']
        self.assertAlmostEqual(economy.pending(saved['salvage'])['parts'], 0)
        self.assertTrue(any(r['research'] > 0 for r in saved['salvage']['rows']))

    def test_certificates_are_recomputed_and_existing_snapshot_is_immutable(self):
        state = fixture(); state['salvage']['certificates'] = [certificate()]; state['salvage']['active_id'] = 'cert:1'
        first = self.put(state)
        original = copy.deepcopy(first['save']['salvage']['certificates'][0])
        self.assertEqual(original['rates']['credits'], 28800)
        first['save']['salvage']['certificates'][0].update(minimum_hp=100, seconds=1)
        first['save']['salvage']['certificates'][0]['trials'] = [dict(seconds=1, hp=100)] * 3
        second = self.put(first['save'], 1)
        self.assertEqual(second['save']['salvage']['certificates'][0], original)
        first['save']['expedition']['clears'] = [0,0,0,0]
        with self.assertRaises(economy.Invalid): self.put(first['save'], 2)

    def test_same_request_concurrent_and_retry_after_lost_response_pays_once(self):
        first = self.put(); self.clock.value += 3600
        body = dict(save=first['save'], revision=1, request_id='same_request_00000001')
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.store.mutate(self.token, body, True), range(8)))
        self.assertEqual(sum(not r['replayed'] for r in results), 1)
        self.assertTrue(all(r['revision'] == 2 for r in results))
        self.assertEqual(self.store.read(self.token)['save']['credits'], 2400 + 36000)
        self.clock.value += 3600
        replay = self.store.mutate(self.token, body, True)
        self.assertTrue(replay['replayed']); self.assertEqual(replay['receipt']['credits'], 36000)
        self.assertEqual(replay['save']['credits'], 38400)
        self.assertEqual(economy.pending(replay['save']['salvage'])['credits'], 36000)

    def test_different_concurrent_claims_allow_only_one_revision(self):
        first = self.put(); self.clock.value += 3600
        def attempt(index):
            try: return self.claim(first['save'], 1, 'different_request_%02d' % index)
            except app.ApiError as error: return error.code
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(attempt, range(8)))
        self.assertEqual(sum(isinstance(r, dict) for r in results), 1)
        self.assertEqual(results.count('conflict'), 7)
        self.assertEqual(self.store.read(self.token)['save']['credits'], 38400)

    def test_server_drops_match_catalog_keep_rares_and_overflow(self):
        state = fixture(); state['salvage']['certificates'] = [certificate(region=3)]
        state['salvage']['active_id'] = 'cert:1'; state['salvage']['auto_recycle'] = True
        state = economy.validate_save(state); state['salvage']['cursor'] = self.clock.value
        economy.catch_up(state['salvage'], self.clock.value + 72*3600)
        # Fill the real bag, keeping IDs and original gear intact.
        for ident in range(2,121):
            part = copy.deepcopy(state['parts']['inventory'][0]); part['id'] = ident; state['parts']['inventory'].append(part)
        state['parts']['next_id'] = 121
        result = economy.claim(state, random.Random(1234))
        self.assertGreater(result['parts'], 100)
        self.assertEqual(len(state['parts']['inventory']), 120)
        self.assertEqual(len(state['parts']['overflow']) + result['recycled'], result['parts'])
        self.assertTrue(all(part['quality'] > 0 for part in state['parts']['overflow']))
        self.assertEqual(state['parts']['research_materials'], result['research'])
        self.assertEqual(state['cores'], 120 + result['cores'] + result['recycled'] * 6)
        economy.validate_save(state)
        self.assertEqual(economy.claim(state), {})

    def test_persistence_reopen_and_session_expiry(self):
        self.put(); reopened = app.Store(self.store.path, self.clock)
        self.assertEqual(reopened.server_id, self.store.server_id)
        self.assertEqual(reopened.read(self.token)['save']['credits'], 2400)
        self.clock.value += app.SESSION_SECONDS + 1
        with self.assertRaises(app.ApiError): reopened.read(self.token)

    def test_invalid_migration_cannot_create_unbounded_drop_work_or_nonfinite_saves(self):
        invalid = fixture()
        invalid['salvage']['rows'] = [dict(id='legacy', name='legacy', region=0, parts=5000, rates={})]
        with self.assertRaises(economy.Invalid): self.put(invalid)
        invalid = fixture(); invalid['hp'] = float('inf')
        with self.assertRaises(economy.Invalid): self.put(invalid)
        self.assertEqual(self.store.read(self.token)['revision'], 0)

    def test_validation_and_malformed_data_do_not_mutate(self):
        first = self.put()
        for mutate in (lambda s: s['parts']['inventory'].append(copy.deepcopy(s['parts']['inventory'][0])),
                       lambda s: s['parts']['inventory'][0].update(mechanism='pulse'),
                       lambda s: s.update(credits=-1),
                       lambda s: s['parts'].update(loadouts=[None,{},{}])):
            invalid = copy.deepcopy(first['save']); mutate(invalid)
            with self.assertRaises(economy.Invalid): self.put(invalid, 1)
        self.assertEqual(self.store.read(self.token)['revision'], 1)

class HttpTests(unittest.TestCase):
    def test_real_http_login_save_claim_conflict_and_static_isolation(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'tests', prefix='cloud-http-') as tmp:
            server = app.make_server(pathlib.Path(tmp)/'db.sqlite3', port=0, allowed_origins=['http://localhost:8060'])
            worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
            base = 'http://127.0.0.1:%d' % server.server_port
            def request(path, method='GET', body=None, token=None):
                headers = {'Content-Type':'application/json', 'Origin':'http://localhost:8060'}
                if token: headers['Authorization'] = 'Bearer ' + token
                req = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None, headers=headers, method=method)
                try: response = urllib.request.urlopen(req)
                except urllib.error.HTTPError as error: response = error
                with response:
                    return response.status, response.headers, response.read()
            try:
                self.assertEqual(request('/api/state')[0], 401)
                status, headers, body = request('/api/register','POST', dict(username='http_pilot', password='long-password'))
                self.assertEqual(status, 200); self.assertEqual(headers['Access-Control-Allow-Origin'], 'http://localhost:8060')
                token = json.loads(body)['token']
                status, _, body = request('/api/state','PUT',dict(revision=0,save=fixture()),token)
                self.assertEqual(status, 200); state = json.loads(body)['save']
                status, _, body = request('/api/claim','POST',dict(revision=1,save=state,request_id='http_request_0000001'),token)
                self.assertEqual(status, 200)
                self.assertEqual(request('/api/state','PUT',dict(revision=1,save=state),token)[0],409)
                self.assertEqual(request('/api/state','PUT',dict(revision=2,save=None),token)[0],400)
                self.assertEqual(request('/api/state','PUT',dict(revision=2,save={'version':1,'levels':None}),token)[0],400)
                self.assertEqual(request('/../../.local/cloud.sqlite3')[0],404)
                self.assertEqual(request('/server/app.py')[0],404)
                self.assertEqual(request('/api/logout','POST',{},token)[0],200)
                self.assertEqual(request('/api/state',token=token)[0],401)
            finally:
                server.shutdown(); server.server_close(); worker.join()

if __name__ == '__main__': unittest.main()
