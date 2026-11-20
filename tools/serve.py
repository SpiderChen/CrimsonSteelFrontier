#!/usr/bin/env python3
"""Project-local H5 server. No installation or system changes required."""
import argparse, functools, http.server, pathlib, webbrowser
parser=argparse.ArgumentParser()
parser.add_argument('--port',type=int,default=8060)
parser.add_argument('--directory',default='build/web')
parser.add_argument('--open',action='store_true')
parser.add_argument('--lan',action='store_true')
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent
folder=root/args.directory
class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map={**http.server.SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.pck':'application/octet-stream'}
    def end_headers(self):
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
server=http.server.ThreadingHTTPServer(('0.0.0.0' if args.lan else '127.0.0.1',args.port),functools.partial(Handler,directory=str(folder)))
url=f'http://localhost:{args.port}'
print(f'绯红战线 H5: {url}\n按 Ctrl+C 停止服务。',flush=True)
if args.open: webbrowser.open(url)
try: server.serve_forever()
except KeyboardInterrupt: server.server_close()
