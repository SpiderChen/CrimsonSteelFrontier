#!/usr/bin/env python3
"""Start or reuse this project's local preview, independently of the terminal window."""
import argparse
import json
import pathlib
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
import webbrowser

ROOT = pathlib.Path(__file__).resolve().parent.parent

def health(url):
    try:
        with urllib.request.urlopen(url + '/api/health', timeout=1) as response:
            data = json.loads(response.read(4096))
        return data if isinstance(data, dict) else None
    except (OSError, ValueError, urllib.error.URLError):
        return None

def database_id():
    path = ROOT / '.local/cloud.sqlite3'
    if not path.exists():
        return None
    try:
        with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
            row = db.execute('SELECT value FROM meta WHERE key=?', ('server_id',)).fetchone()
            return row[0] if row else None
    except sqlite3.Error:
        return None

def matches(data):
    return data is not None and data.get('status') == 'ok' and data.get('protocol') == 1 and data.get('server_id') == database_id()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8060)
    parser.add_argument('--open', action='store_true')
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error('port must be between 1024 and 65535')
    if not (ROOT / 'build/web/index.html').exists():
        raise SystemExit('请先在项目目录运行 ./export.command')
    url = f'http://localhost:{args.port}'
    if matches(health(url)):
        print(f'试玩已在运行：{url}', flush=True)
    else:
        folder = ROOT / '.local'; folder.mkdir(exist_ok=True)
        log = folder / f'preview-{args.port}.log'
        with log.open('ab') as output:
            process = subprocess.Popen([sys.executable, str(ROOT / 'server/app.py'), '--port', str(args.port)],
                                       cwd=str(ROOT), stdin=subprocess.DEVNULL, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline and process.poll() is None:
            if matches(health(url)):
                (folder / f'preview-{args.port}.pid').write_text(str(process.pid))
                print(f'试玩已启动：{url}\n服务在后台运行，关闭此窗口不影响游戏。', flush=True)
                break
            time.sleep(.1)
        else:
            # Only the process started by this invocation may be stopped here.
            if process.poll() is None:
                process.terminate(); process.wait(timeout=5)
            raise SystemExit(f'试玩未能启动，端口可能已被占用。查看项目日志：{log}')
    if args.open:
        webbrowser.open(url)

if __name__ == '__main__':
    main()
