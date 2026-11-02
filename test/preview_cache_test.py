"""Check a versioned preview with a stale worker already controlling the tab.

Uses a temporary HTTP port and isolated browser profile, never the user's browser.
No production account, email, or VPN requests are made.
"""
import argparse
import json
from io import BytesIO
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WORKER = b"""
self.addEventListener('install', event => {
  event.waitUntil(caches.open('flutter-app-cache').then(cache =>
    cache.put('/', new Response('<html><body>STALE_YELLOW_PREVIEW</body></html>',
      {headers: {'Content-Type': 'text/html'}}))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => {
  if (new URL(event.request.url).pathname === '/') {
    event.respondWith(caches.open('flutter-app-cache').then(cache => cache.match('/')));
  }
});
"""


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/fixture-worker.js':
            body, content_type = WORKER, 'text/javascript'
        elif path == '/fixture-seed.html':
            body, content_type = b'<html><body>Cache test fixture</body></html>', 'text/html'
        else:
            return super().do_GET()
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', default='preview-transparent-20261102-v3')
    args = parser.parse_args()
    web_root = ROOT / 'build/web'
    assert (web_root / args.revision / 'index.html').is_file(), 'Build preview first'
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(web_root)))
    Thread(target=server.serve_forever, daemon=True).start()
    origin = f'http://127.0.0.1:{server.server_port}'
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe', headless=True)
            context = browser.new_context(viewport={'width': 390, 'height': 852})
            page = context.new_page()
            errors, assets = [], []
            page.on('pageerror', lambda e: errors.append(str(e)))
            page.on('request', lambda r: assets.append(urlparse(r.url).path)
                    if '/branding/' in r.url or 'main.dart.js' in r.url else None)
            page.goto(origin + '/fixture-seed.html')
            page.evaluate("""async () => {
              localStorage.setItem('preview-test-business-data', 'keep-me');
              const cache = await caches.open('unrelated-business-cache');
              await cache.put('/fixture-data', new Response('keep-me-too'));
              await navigator.serviceWorker.register('/fixture-worker.js', {scope:'/'});
              await navigator.serviceWorker.ready;
            }""")
            page.wait_for_function('navigator.serviceWorker.controller !== null')
            page.goto(origin + '/?v=transparent-logo')
            assert 'STALE_YELLOW_PREVIEW' in page.locator('body').inner_text(), 'Fixture must reproduce stale root page'
            page.goto(origin + '/' + args.revision + '/', wait_until='networkidle')
            page.wait_for_selector('flutter-view', timeout=60000)
            page.wait_for_timeout(1500)
            prefix = '/' + args.revision + '/'
            assert prefix + 'main.dart.js' in assets, assets
            assert prefix + 'assets/assets/branding/pikayun_brand_mark.png' in assets, assets
            assert not any(path.endswith('pikayun_app_icon_256.png') for path in assets), assets
            favicon_url = page.locator('link[rel="icon"]').evaluate('(link) => link.href')
            assert urlparse(favicon_url).path == prefix + 'favicon-mark.png'
            favicon_response = context.request.get(favicon_url)
            assert favicon_response.ok
            with Image.open(BytesIO(favicon_response.body())) as favicon:
                assert favicon.mode == 'RGBA'
                assert favicon.getchannel('A').getpixel((0, 0)) == 0
            assert page.evaluate("localStorage.getItem('preview-test-business-data')") == 'keep-me'
            assert page.evaluate("""async () => {
              const cache = await caches.open('unrelated-business-cache');
              return await (await cache.match('/fixture-data')).text();
            }""") == 'keep-me-too'
            assert not errors, errors
            page.screenshot(path=str(ROOT / 'artifacts/implemented_ui/versioned-preview-stale-cache-test.png'))
            print(json.dumps({'stale_root_reproduced': True, 'versioned_preview_passed': True,
                              'browser_favicon_transparent': True,
                              'business_data_preserved': True, 'loaded_assets': assets,
                              'page_errors': errors}))
            browser.close()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    main()
