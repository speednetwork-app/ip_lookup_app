"""Capture the local browser UI; API fixtures exist only inside this test browser.

Run after building web and serving build/web on 127.0.0.1:8081.
No real login, VPN operation, or production API request is sent.
"""
import json
from pathlib import Path
from urllib.parse import urlparse, parse_qs

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'implemented_ui'
OUT.mkdir(parents=True, exist_ok=True)
GiB = 1024 ** 3


def api(route):
    request = route.request
    path = urlparse(request.url).path
    if request.method == 'OPTIONS':
        body = {}
    elif path.endswith('/passport/auth/login'):
        body = {'status': 'success', 'data': {'auth_data': 'ui-test-only-token'}}
    elif path.endswith('/user/mobile-overview'):
        body = {'status': 'success', 'data': {
            'account_status': 'active', 'plan_name': 'UI 验收测试套餐',
            'traffic': {'total_bytes': 100 * GiB, 'used_bytes': 20 * GiB,
                        'remaining_bytes': 80 * GiB, 'usage_percent': 20},
            'subscribe_url': 'https://example.com/sub/ui-test-only',
            'device_limit': 3, 'speed_limit_mbps': 0,
        }}
    elif path.endswith('/user/server/fetch'):
        body = {'data': [dict(id=i, name=f'测试节点 {i:02d}', type='vless',
                             rate=0.1, available_status=2 if i < 12 else 0,
                             load_level=['relaxed', 'moderate', 'busy'][i % 3],
                             load_estimated=False) for i in range(1, 13)]}
    elif path.endswith('/user/mobile-traffic'):
        range_key = parse_qs(urlparse(request.url).query).get('range', ['7d'])[0]
        body = {'status': 'success', 'data': {'range': range_key, 'daily': [],
                                             'used_bytes': 0}}
    elif path.endswith('/user/notice/fetch'):
        body = {'status': 'success', 'data': []}
    else:
        route.abort()
        return
    route.fulfill(status=200, content_type='application/json',
                  headers={'Access-Control-Allow-Origin': 'http://127.0.0.1:8081',
                           'Access-Control-Allow-Credentials': 'true',
                           'Access-Control-Allow-Headers': '*',
                           'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'},
                  body=json.dumps(body))


def tab(page, index):
    # Five equal-width NavigationBar destinations; the viewport stays 390x852.
    page.mouse.click(39 + index * 78, 820)
    page.mouse.move(389, 76)
    page.wait_for_timeout(400)


def ip_fixture(route):
    route.fulfill(status=200, content_type='application/json',
                  headers={'Access-Control-Allow-Origin': '*'},
                  body=json.dumps({'success': True, 'ip': '203.0.113.12',
                                   'country': '示例国家', 'region': '示例地区',
                                   'city': '验收示例城市', 'latitude': 0, 'longitude': 0,
                                   'connection': {'isp': '隔离测试数据'},
                                   'timezone': {'id': 'Etc/UTC'}}))


with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe', headless=True)
    context = browser.new_context(viewport={'width': 390, 'height': 852},
                                  device_scale_factor=1, color_scheme='light')
    context.route('https://api.pikayun.com/**', api)
    context.route('https://ipwho.is/**', ip_fixture)
    context.route('https://ipapi.co/**', ip_fixture)
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda message: errors.append(message.text)
            if any(marker in message.text for marker in (
                'EXCEPTION CAUGHT', 'Incorrect use of ParentDataWidget',
                'RenderFlex overflowed', 'Another exception was thrown',
            )) else None)
    page.goto('http://127.0.0.1:8081', wait_until='networkidle')
    page.wait_for_selector('flutter-view', timeout=60000)
    page.wait_for_timeout(2500)
    page.screenshot(path=str(OUT / 'home-light.png'))
    placeholder = page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(element) => element.click()')
    tab(page, 4)
    page.wait_for_timeout(300)
    fields = page.locator('input')
    if fields.count() < 2:
        print('SEMANTICS', page.locator('body').inner_text()[:2000])
        raise RuntimeError('Login inputs were not available in the browser')
    fields.nth(0).fill('ui-test@example.com')
    fields.nth(1).click()
    page.keyboard.type('test-only-password', delay=40)
    page.wait_for_timeout(300)
    page.get_by_role('button', name='登录', exact=True).click()
    page.wait_for_timeout(2000)
    if page.get_by_role('button', name='登录', exact=True).count():
        page.screenshot(path=str(OUT / 'login-diagnostic.png'))
        raise RuntimeError('Isolated fixture login did not finish; screenshots would be misleading')
    # Watermark every fixture capture so the sample account cannot be mistaken
    # for a real service response or an iOS device screenshot.
    page.evaluate("""() => {
      const note = document.createElement('div');
      note.textContent = '浏览器验收 · 隔离样例数据';
      Object.assign(note.style, {position:'fixed',right:'8px',top:'2px',zIndex:9999,
        fontSize:'10px',background:'#fff0ac',color:'#302d26',padding:'2px 5px',pointerEvents:'none'});
      document.body.appendChild(note);
    }""")
    page.screenshot(path=str(OUT / 'account-light-test-fixture.png'))
    tab(page, 1)
    page.screenshot(path=str(OUT / 'nodes-light-test-fixture.png'))
    tab(page, 2)
    page.screenshot(path=str(OUT / 'ip-empty-light.png'))
    tab(page, 3)
    page.screenshot(path=str(OUT / 'history-empty-light.png'))
    tab(page, 2)
    page.get_by_role('button', name='查询我的公网 IP', exact=True).click()
    page.wait_for_timeout(1000)
    page.mouse.move(389, 76)
    page.screenshot(path=str(OUT / 'ip-result-light-test-fixture.png'))
    page.get_by_role('button', name='查询指定 IP', exact=True).click()
    page.wait_for_timeout(400)
    page.locator('input').first.fill('203.0.113.12')
    page.get_by_role('button', name='开始查询', exact=True).click()
    page.wait_for_timeout(1000)
    page.mouse.click(24, 36)
    page.wait_for_timeout(400)
    tab(page, 3)
    page.screenshot(path=str(OUT / 'history-result-light-test-fixture.png'))
    tab(page, 0)
    page.screenshot(path=str(OUT / 'home-light-test-fixture.png'))
    page.emulate_media(color_scheme='dark')
    page.wait_for_timeout(500)
    page.screenshot(path=str(OUT / 'home-dark-test-fixture.png'))
    tab(page, 1)
    page.screenshot(path=str(OUT / 'nodes-dark-test-fixture.png'))
    tab(page, 4)
    page.screenshot(path=str(OUT / 'account-dark-test-fixture.png'))
    print(json.dumps({'screenshots': str(OUT), 'page_errors': errors}, ensure_ascii=False))
    browser.close()
    if errors:
        raise RuntimeError('Browser reported errors')
