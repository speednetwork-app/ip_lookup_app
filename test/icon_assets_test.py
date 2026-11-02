"""Validate generated icon packaging; does not redraw any brand artwork."""
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class IconAssetsTest(unittest.TestCase):
    def check_png(self, path, size):
        with Image.open(path) as image:
            self.assertEqual(image.format, 'PNG')
            self.assertEqual(image.size, (size, size))
            self.assertEqual(image.mode, 'RGB', 'Apple icons must not have alpha')
            for point in [(0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)]:
                red, green, blue = image.getpixel(point)
                self.assertGreater(red, 200)
                self.assertGreater(green, 150)
                self.assertLess(blue, 120)

    def test_master_and_app_brand_use_yellow_background(self):
        self.check_png(ROOT / 'assets/branding/pikayun_app_icon_master.png', 1024)
        self.check_png(ROOT / 'assets/branding/pikayun_app_icon_256.png', 256)

    def test_in_app_brand_mark_has_real_transparency(self):
        with Image.open(ROOT / 'assets/branding/pikayun_brand_mark.png') as image:
            self.assertEqual(image.mode, 'RGBA')
            alpha = image.getchannel('A')
            self.assertEqual(alpha.getextrema()[0], 0)
            self.assertGreaterEqual(alpha.getextrema()[1], 240)
            for point in [(0, 0), (image.width - 1, 0),
                          (0, image.height - 1), (image.width - 1, image.height - 1)]:
                self.assertEqual(alpha.getpixel(point), 0)
            self.assertGreaterEqual(image.width, image.height)

    def test_apple_catalog_sizes_and_opacity(self):
        for platform in ['ios', 'macos']:
            directory = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
            entries = json.loads((directory / 'Contents.json').read_text('utf-8'))['images']
            for entry in entries:
                if not entry.get('filename'):
                    continue
                pixels = round(float(entry['size'].split('x')[0]) * int(entry['scale'].rstrip('x')))
                with self.subTest(platform=platform, file=entry['filename']):
                    self.check_png(directory / entry['filename'], pixels)

    def test_web_icons(self):
        for name, size in [('Icon-192.png', 192), ('Icon-512.png', 512),
                           ('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)]:
            self.check_png(ROOT / 'web/icons' / name, size)

    def test_browser_tab_favicons_are_transparent_not_launcher_tiles(self):
        for name in ('favicon.png', 'favicon-mark.png'):
            with Image.open(ROOT / 'web' / name) as icon:
                self.assertEqual(icon.size, (32, 32))
                self.assertEqual(icon.mode, 'RGBA')
                alpha = icon.getchannel('A')
                self.assertEqual(alpha.getpixel((0, 0)), 0)
                self.assertEqual(alpha.getpixel((31, 31)), 0)
                self.assertGreaterEqual(alpha.getextrema()[1], 200)
        html = (ROOT / 'web/index.html').read_text('utf-8')
        self.assertIn('href="favicon-mark.png"', html)


if __name__ == '__main__':
    unittest.main()
