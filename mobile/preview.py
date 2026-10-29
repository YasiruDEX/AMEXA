"""Local browser preview; only the configured public sheet is proxied."""
import argparse
import json
import shutil
import subprocess
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs, urlencode
import requests

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--no-build', action='store_true')
parser.add_argument('--port', type=int, default=8765)
args = parser.parse_args()
config = root / 'sheet_config.json'
if not config.exists():
    raise SystemExit('Run .venv/bin/python mobile/configure_sheet.py first.')
link = urlparse(json.loads(config.read_text())['MEAL_SHEET_URL'])
if link.hostname != 'docs.google.com' or not link.path.startswith('/spreadsheets/d/'):
    raise SystemExit('Invalid configured Google Sheet URL.')
gid = parse_qs(link.query).get('gid', parse_qs(link.fragment).get('gid', [None]))[0]
url = 'https://docs.google.com' + '/'.join(link.path.split('/')[:4]) + '/export?' + urlencode({'format':'csv', **({'gid':gid} if gid is not None else {})})
if not args.no_build:
    flutter = shutil.which('flutter') or '/private/tmp/amexa-flutter/bin/flutter'
    subprocess.run([flutter, 'build', 'web', '--dart-define-from-file=sheet_config.json'], cwd=root, check=True)

class Preview(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.split('?')[0] != '/menu.csv':
            return super().do_GET()
        try:
            response = requests.get(url, timeout=25)
            response.raise_for_status()
            data = response.content
            self.send_response(200)
            self.send_header('Content-Type', 'text/csv; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(data)
        except Exception:
            self.send_error(502, 'Could not read the public meal sheet')

print(f'AMEXA preview: http://localhost:{args.port} (Ctrl+C to stop)', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), partial(Preview, directory=str(root / 'build' / 'web'))).serve_forever()
