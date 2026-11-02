"""Read-only browser check against the real public registration configuration.

Never posts credentials, creates an account, or sends an email.
"""
import json
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'registration_ui'
OUT.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        headless=True,
    )
    context = browser.new_context(viewport={'width': 390, 'height': 852},
                                  device_scale_factor=1)
    # Fail closed: all writes to the real API are blocked by this test harness.
    def guard(route):
        if route.request.method not in ('GET', 'HEAD', 'OPTIONS'):
            raise RuntimeError('This visual check must not write to the backend')
        route.continue_()
    context.route('https://api.pikayun.com/**', guard)
    page = context.new_page()
    errors = []
    public_api = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda message: errors.append(message.text)
            if any(marker in message.text for marker in (
                'EXCEPTION CAUGHT', 'Incorrect use of ParentDataWidget',
                'RenderFlex overflowed', 'Another exception was thrown',
            )) else None)
    page.on('response', lambda r: public_api.append(
        {'path': urlparse(r.url).path, 'status': r.status}
    ) if 'api.pikayun.com' in r.url else None)
    page.goto('http://127.0.0.1:8081', wait_until='networkidle')
    page.wait_for_selector('flutter-view', timeout=60000)
    page.wait_for_timeout(1800)
    placeholder = page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(el) => el.click()')
    page.mouse.click(351, 820)
    page.wait_for_timeout(400)
    page.mouse.move(389, 78)
    page.wait_for_timeout(1600)
    page.screenshot(path=str(OUT / 'login-light.png'))
    page.get_by_role('button', name='还没有账号？邮箱注册', exact=True).click()
    page.get_by_role('button', name='创建账号并登录', exact=True).wait_for(timeout=30000)
    page.wait_for_timeout(500)
    page.mouse.move(389, 78)
    page.screenshot(path=str(OUT / 'registration-light.png'))
    page.mouse.wheel(0, 520)
    page.wait_for_timeout(400)
    page.screenshot(path=str(OUT / 'registration-light-bottom.png'))
    page.emulate_media(color_scheme='dark')
    page.mouse.wheel(0, -2000)
    page.wait_for_timeout(500)
    page.screenshot(path=str(OUT / 'registration-dark.png'))
    print(json.dumps({'screenshots': str(OUT), 'public_api': public_api,
                      'page_errors': errors}, ensure_ascii=False))
    browser.close()
    if errors:
        raise RuntimeError('Browser reported errors')
