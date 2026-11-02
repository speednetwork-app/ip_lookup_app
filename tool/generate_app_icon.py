"""Generate platform app icons from the Pikayun brand master.

The master is intentionally kept separate from generated platform assets so
the complete icon set can be reproduced without redrawing or resampling an
already-small icon.
"""

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "branding" / "pikayun_app_icon_master.png"
IOS_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
BRAND_MARK = ROOT / "assets" / "branding" / "pikayun_brand_mark.png"


def generate_browser_favicon() -> None:
    """Package the existing transparent logo for browser tabs, not launchers."""
    with Image.open(BRAND_MARK) as source:
        mark = source.convert("RGBA")
    mark.thumbnail((32, 32), Image.Resampling.LANCZOS)
    favicon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    favicon.alpha_composite(mark, ((32 - mark.width) // 2, (32 - mark.height) // 2))
    for name in ("favicon.png", "favicon-mark.png"):
        path = ROOT / "web" / name
        favicon.save(path, "PNG", optimize=True)
        print(f"  {path.relative_to(ROOT)}  32x32 transparent")


def build_master() -> Image.Image:
    """Normalize the approved master, without redrawing its artwork.

    The yellow background is part of the checked-in master. Generating platform
    sizes must never silently reconstruct the previous blue-background icon.
    Apple applies its own icon mask; the master stays full-bleed and opaque.
    """
    size = 1024
    with Image.open(MASTER) as source:
        if source.width != source.height:
            raise ValueError("The approved icon master must be square")
        if source.convert("RGBA").getchannel("A").getextrema() != (255, 255):
            raise ValueError("App icon master must be fully opaque")
        image = source.convert("RGB")
    if image.size != (size, size):
        image = image.resize((size, size), Image.Resampling.LANCZOS)
    image.save(MASTER, "PNG", optimize=True)
    print(f"Brand master\n  {MASTER.relative_to(ROOT)}  {size}x{size}")
    return image


def resize(image: Image.Image, path: Path, pixels: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
        path,
        "PNG",
        optimize=True,
    )
    print(f"  {path.relative_to(ROOT)}  {pixels}x{pixels}")


def generate_asset_catalog(image: Image.Image, directory: Path) -> None:
    metadata = json.loads((directory / "Contents.json").read_text("utf-8"))
    generated: set[str] = set()
    for entry in metadata["images"]:
        filename = entry.get("filename")
        if not filename or filename in generated:
            continue
        side = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        resize(image, directory / filename, round(side * scale))
        generated.add(filename)


def main() -> None:
    image = build_master()

    print("iOS")
    generate_asset_catalog(image, IOS_DIR)

    print("macOS")
    generate_asset_catalog(image, MACOS_DIR)

    print("Android")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for density, pixels in android_sizes.items():
        resize(
            image,
            ROOT / "android" / "app" / "src" / "main" / "res" / density / "ic_launcher.png",
            pixels,
        )

    print("Web")
    for filename, pixels in {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }.items():
        resize(image, ROOT / "web" / "icons" / filename, pixels)
    generate_browser_favicon()

    print("Flutter brand asset")
    resize(image, ROOT / "assets" / "branding" / "pikayun_app_icon_256.png", 256)

    print("Support site")
    resize(image, ROOT / "docs" / "pikayun-icon.png", 192)

    print("Windows")
    windows_icon = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    image.save(
        windows_icon,
        "ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"  {windows_icon.relative_to(ROOT)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--favicon-only", action="store_true",
                        help="Export transparent browser favicons without changing app launchers")
    arguments = parser.parse_args()
    if arguments.favicon_only:
        generate_browser_favicon()
    else:
        main()
