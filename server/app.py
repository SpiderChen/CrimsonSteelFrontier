#!/usr/bin/env python3
"""Project-local authenticated save service; no system installation required."""
import argparse
import contextlib
import functools
import hashlib
import hmac
import http.server
import json
import os
import pathlib
import re
import secrets
import sqlite3
import threading
import time
import urllib.parse
import uuid
import webbrowser

try:
    from . import economy
except ImportError:
    import economy

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAX_BODY = 4 * 1024 * 1024
SESSION_SECONDS = 30 * 24 * 3600

class ApiError(Exception):
    def __init__(self, status, code, message):
        self.status, self.code, self.message = status, code, message

def json_text(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':'))

class Store:
    def __init__(self, database, clock=time.time):
        self.path = pathlib.Path(database).resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.clock = clock
        with self.connection() as db:
            db.executescript('''
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY, username TEXT UNIQUE NOT NULL,
                    salt TEXT NOT NULL, password_hash TEXT NOT NULL, created REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY, account INTEGER NOT NULL REFERENCES accounts(id), expires REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS saves(account INTEGER PRIMARY KEY REFERENCES accounts(id), revision INTEGER NOT NULL, body TEXT NOT NULL, updated REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS receipts(account INTEGER NOT NULL REFERENCES accounts(id), request_id TEXT NOT NULL,
                    revision INTEGER NOT NULL, body TEXT NOT NULL, PRIMARY KEY(account,request_id));
            ''')
            db.execute('INSERT OR IGNORE INTO meta VALUES(?,?)', ('server_id', str(uuid.uuid4())))
            self.server_id = db.execute('SELECT value FROM meta WHERE key=?', ('server_id',)).fetchone()[0]
        os.chmod(self.path, 0o600)
        self.attempts = {}; self.rate_lock = threading.Lock()

    @contextlib.contextmanager
    def connection(self):
        db = sqlite3.connect(str(self.path), timeout=15, isolation_level=None)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        try:
            yield db
        finally:
            db.close()

    @contextlib.contextmanager
    def transaction(self):
        with self.connection() as db:
            db.execute('BEGIN IMMEDIATE')
            try:
                yield db
                db.execute('COMMIT')
            except Exception:
                db.execute('ROLLBACK')
                raise

    def rate_limit(self, address):
        now = time.monotonic()
        with self.rate_lock:
            entries = [t for t in self.attempts.get(address, []) if now - t < 60]
            if len(entries) >= 12:
                raise ApiError(429, 'rate_limit', '尝试过于频繁，请一分钟后再试')
            entries.append(now); self.attempts[address] = entries
            if len(self.attempts) > 2000:
                self.attempts = {key: rows for key, rows in self.attempts.items() if rows and now - rows[-1] < 60}

    @staticmethod
    def credentials(body):
        username, password = body.get('username'), body.get('password')
        if not isinstance(username, str) or not re.fullmatch(r'[\w-]{3,32}', username):
            raise ApiError(400, 'credentials', '账号需要3—32个字母、数字、汉字、下划线或短横线')
        if not isinstance(password, str) or not 8 <= len(password) <= 128:
            raise ApiError(400, 'credentials', '密码需要8—128个字符')
        return username, password

    @staticmethod
    def password_hash(password, salt):
        return hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600000).hex()

    def authenticate(self, db, token):
        digest = hashlib.sha256(token.encode()).hexdigest()
        account = db.execute('SELECT a.id,a.username FROM sessions s JOIN accounts a ON a.id=s.account WHERE s.token_hash=? AND s.expires>?', (digest, self.clock())).fetchone()
        if account is None:
            raise ApiError(401, 'unauthorized', '登录已失效，请重新登录同一账号')
        return account

    def auth(self, action, body, address):
        self.rate_limit(address)
        username, password = self.credentials(body)
        with self.transaction() as db:
            account = db.execute('SELECT * FROM accounts WHERE username=?', (username,)).fetchone()
            if action == 'register':
                if account is not None:
                    raise ApiError(409, 'account_exists', '此账号已存在，请登录')
                salt = secrets.token_hex(16)
                db.execute('INSERT INTO accounts(username,salt,password_hash,created) VALUES(?,?,?,?)',
                           (username, salt, self.password_hash(password, salt), self.clock()))
                account = db.execute('SELECT * FROM accounts WHERE username=?', (username,)).fetchone()
            else:
                # Perform the expensive hash for unknown accounts too.
                salt = account['salt'] if account else '00' * 16
                computed = self.password_hash(password, salt)
                if account is None or not hmac.compare_digest(computed, account['password_hash']):
                    raise ApiError(401, 'credentials', '账号或密码错误')
            token = secrets.token_urlsafe(32)
            db.execute('DELETE FROM sessions WHERE expires<=?', (self.clock(),))
            db.execute('INSERT INTO sessions VALUES(?,?,?)', (hashlib.sha256(token.encode()).hexdigest(), account['id'], self.clock() + SESSION_SECONDS))
            return dict(token=token, username=username, server_id=self.server_id, server_time=self.clock(), expires=self.clock() + SESSION_SECONDS)

    def envelope(self, account, row):
        state = json.loads(row['body']) if row else None
        revision = row['revision'] if row else 0
        now = self.clock()
        if state is not None:
            economy.catch_up(state['salvage'], now)
            state['cloud_binding'] = dict(account=account['username'], server_id=self.server_id, revision=revision)
            state['last_seen'] = int(now)
        return dict(save=state, revision=revision, username=account['username'], server_id=self.server_id, server_time=now)

    def read(self, token):
        with self.transaction() as db:
            account = self.authenticate(db, token)
            return self.envelope(account, db.execute('SELECT * FROM saves WHERE account=?', (account['id'],)).fetchone())

    def mutate(self, token, body, claiming=False):
        with self.transaction() as db:
            account = self.authenticate(db, token)
            request_id = body.get('request_id', '')
            row = db.execute('SELECT * FROM saves WHERE account=?', (account['id'],)).fetchone()
            if claiming:
                if not isinstance(request_id, str) or not re.fullmatch(r'[a-zA-Z0-9_-]{16,80}', request_id):
                    raise ApiError(400, 'request_id', '结算请求编号无效')
                receipt = db.execute('SELECT * FROM receipts WHERE account=? AND request_id=?', (account['id'], request_id)).fetchone()
                if receipt:
                    result = self.envelope(account, row)
                    result.update(replayed=True, receipt=json.loads(receipt['body']))
                    return result
            expected = body.get('revision')
            if type(expected) not in (int, float) or expected != int(expected) or expected < 0:
                raise ApiError(400, 'revision', '存档版本无效')
            if expected != (row['revision'] if row else 0):
                raise ApiError(409, 'conflict', '另一台设备已更新云档案，请先下载最新进度')
            previous = json.loads(row['body']) if row else None
            now = self.clock()
            state = economy.merge_incoming(body.get('save'), previous, now)
            binding = state.get('cloud_binding', {})
            if binding and (not isinstance(binding, dict) or binding.get('account') != account['username'] or binding.get('server_id') != self.server_id):
                raise ApiError(409, 'different_account', '此本机进度属于其他云账号，请下载当前账号的档案')
            receipt = economy.claim(state) if claiming else None
            revision = (row['revision'] if row else 0) + 1
            state['cloud_binding'] = dict(account=account['username'], server_id=self.server_id, revision=revision)
            db.execute('INSERT INTO saves VALUES(?,?,?,?) ON CONFLICT(account) DO UPDATE SET revision=excluded.revision,body=excluded.body,updated=excluded.updated',
                       (account['id'], revision, json_text(state), now))
            if claiming:
                db.execute('INSERT INTO receipts VALUES(?,?,?,?)', (account['id'], request_id, revision, json_text(receipt)))
            result = dict(save=state, revision=revision, username=account['username'], server_id=self.server_id, server_time=now)
            if claiming:
                result.update(receipt=receipt, replayed=False)
            return result

    def logout(self, token):
        with self.transaction() as db:
            self.authenticate(db, token)
            db.execute('DELETE FROM sessions WHERE token_hash=?', (hashlib.sha256(token.encode()).hexdigest(),))
        return dict(server_time=self.clock())

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}
    server_version = 'CrimsonFront/1'

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        origin = self.headers.get('Origin')
        if origin in self.server.allowed_origins:
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Vary', 'Origin')
            self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
            self.send_header('Access-Control-Allow-Methods', 'GET, PUT, POST, OPTIONS')
        super().end_headers()

    def json_response(self, status, body):
        encoded = json_text(body).encode()
        self.send_response(status); self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(encoded))); self.end_headers(); self.wfile.write(encoded)

    def do_OPTIONS(self):
        self.send_response(204); self.end_headers()

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path
        if path.startswith('/api/'):
            self.api('GET', path)
        else:
            super().do_GET()

    def do_PUT(self):
        self.api('PUT', urllib.parse.urlsplit(self.path).path)

    def do_POST(self):
        self.api('POST', urllib.parse.urlsplit(self.path).path)

    def api(self, method, path):
        store = self.server.store
        try:
            body = {}
            if method in ('POST', 'PUT'):
                try:
                    size = int(self.headers.get('Content-Length', '0'))
                    if not 0 < size <= MAX_BODY:
                        raise ValueError()
                    raw = self.rfile.read(size)
                    body = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
                    if not isinstance(body, dict):
                        raise ValueError()
                except (ValueError, UnicodeError, RecursionError):
                    raise ApiError(400, 'body', '请求需要有效的JSON对象，且不得超过4MB')
            if method == 'GET' and path == '/api/health':
                result = dict(status='ok', protocol=1, server_id=store.server_id, server_time=store.clock())
            elif method == 'POST' and path in ('/api/register', '/api/login'):
                result = store.auth(path.rsplit('/', 1)[1], body, self.client_address[0])
            else:
                auth = self.headers.get('Authorization', '')
                if not auth.startswith('Bearer ') or len(auth) > 512:
                    raise ApiError(401, 'unauthorized', '请先登录云档案账号')
                token = auth[7:]
                if method == 'GET' and path == '/api/state':
                    result = store.read(token)
                elif method == 'PUT' and path == '/api/state':
                    result = store.mutate(token, body)
                elif method == 'POST' and path == '/api/claim':
                    result = store.mutate(token, body, claiming=True)
                elif method == 'POST' and path == '/api/logout':
                    result = store.logout(token)
                else:
                    raise ApiError(404, 'not_found', '接口不存在')
            self.json_response(200, result)
        except economy.Invalid as error:
            self.json_response(400, dict(code='invalid_save', message=str(error), server_time=store.clock()))
        except ApiError as error:
            self.json_response(error.status, dict(code=error.code, message=error.message, server_time=store.clock()))
        except (ValueError, TypeError, KeyError, AttributeError, OverflowError, RecursionError):
            self.json_response(400, dict(code='invalid_save', message='请求中的存档结构无效', server_time=store.clock()))
        except (sqlite3.Error, OSError):
            self.json_response(503, dict(code='storage', message='档案服务暂时不可用，请保留本机进度后重试', server_time=store.clock()))

    def log_message(self, fmt, *args):
        # Request bodies, passwords and Authorization headers never enter logs.
        super().log_message(fmt, *args)

def make_server(database=None, port=8070, host='127.0.0.1', directory=None, allowed_origins=()):
    server = http.server.ThreadingHTTPServer((host, port), functools.partial(Handler, directory=str(directory or ROOT / 'build/web')))
    server.store = Store(database or ROOT / '.local/cloud.sqlite3')
    server.allowed_origins = set(allowed_origins)
    server.daemon_threads = True
    return server

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8070)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--open', action='store_true')
    parser.add_argument('--database', type=pathlib.Path, default=ROOT / '.local/cloud.sqlite3')
    parser.add_argument('--directory', type=pathlib.Path, default=ROOT / 'build/web')
    parser.add_argument('--allow-origin', action='append', default=[])
    args = parser.parse_args()
    server = make_server(args.database, args.port, args.host, args.directory, args.allow_origin)
    print(f'绯红方舟云档案：http://{args.host}:{server.server_port}\n数据库：{args.database}\n按 Ctrl+C 停止。', flush=True)
    if args.open:
        webbrowser.open(f'http://localhost:{server.server_port}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == '__main__':
    main()
