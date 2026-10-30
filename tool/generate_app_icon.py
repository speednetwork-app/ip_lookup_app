"""Generate platform app icons from the Pikayun brand master.

The master is intentionally kept separate from generated platform assets so
the complete icon set can be reproduced without redrawing or resampling an
already-small icon.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "branding" / "pikayun_app_icon_master.png"
SERVER_LOGO = ROOT / "assets" / "branding" / "pikayun_server_logo.png"
IOS_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"


def lerp(start: tuple[int, int, int], end: tuple[int, int, int], t: float):
    return tuple(round(a + (b - a) * t) for a, b in zip(start, end))


def build_master() -> Image.Image:
    """Build an opaque app icon from the server's existing brand mark."""
    size = 1024
    top_color = (56, 130, 246)
    bottom_color = (15, 79, 184)
    image = Image.new("RGB", (size, size), top_color)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        draw.line((0, y, size, y), fill=lerp(top_color, bottom_color, y / size))

    # A restrained connection ring ties the icon to the app's home console.
    draw.ellipse(
        (126, 126, 898, 898),
        outline=(67, 149, 232),
        width=5,
    )

    # The lower wordmark is intentionally excluded at app-icon sizes. The
    # cloud-and-lightning mark remains exactly the same as the server brand.
    source = Image.open(SERVER_LOGO).convert("RGBA")
    # The source PNG contains a few stray semi-transparent pixels on its very
    # first row. Excluding that row keeps the server artwork intact while
    # preventing those pixels from becoming visible after icon upscaling.
    mark = source.crop((0, 1, source.width, 219))
    bounds = mark.getbbox()
    if bounds is not None:
        mark = mark.crop(bounds)
    target_width = 720
    target_height = round(mark.height * target_width / mark.width)
    mark = mark.resize((target_width, target_height), Image.Resampling.LANCZOS)
    x = (size - mark.width) // 2
    y = (size - mark.height) // 2
    image = Image.alpha_composite(image.convert("RGBA"), Image.new("RGBA", image.size))
    image.alpha_composite(mark, (x, y))
    image = image.convert("RGB")
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
    resize(image, ROOT / "web" / "favicon.png", 32)

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
    main()
