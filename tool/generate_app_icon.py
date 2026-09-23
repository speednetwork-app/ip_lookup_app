"""生成 App 图标。

在 4 倍尺寸上绘制再降采样，靠 Pillow 的 LANCZOS 得到平滑边缘——
直接按目标尺寸画圆会出现明显锯齿，在 40px 的小图标上尤其难看。

图形刻意保持简单：一个定位针叠在经纬网格上。图标最小会被缩到 20pt，
任何细节都会糊成一团，所以只保留一个能在那个尺寸下认出来的主体形状。
"""

import json
import os
from PIL import Image, ImageDraw

SS = 4  # 超采样倍数
OUT_DIR = "ios/Runner/Assets.xcassets/AppIcon.appiconset"

BG_TOP = (33, 150, 243)     # Material Blue 500
BG_BOTTOM = (13, 71, 161)   # Material Blue 900
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def draw_master(size):
    """画出 1024 基准图（已含超采样倍数）。"""
    img = Image.new("RGB", (size, size), BG_TOP)
    d = ImageDraw.Draw(img)

    # 垂直渐变背景。iOS 图标不能有透明通道，也不用自己画圆角——
    # 系统会统一套用遮罩，自己画反而会和系统圆角错位。
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / size))

    # 淡淡的经纬网格，暗示"全球定位"而不喧宾夺主
    grid = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    cx = cy = size / 2
    r = size * 0.34
    lw = max(1, int(size * 0.006))
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 46), width=lw)
    for k in (0.42, 0.75):  # 经线：用椭圆模拟球面上的竖直圆弧
        gd.ellipse([cx - r * k, cy - r, cx + r * k, cy + r],
                   outline=(255, 255, 255, 40), width=lw)
    for dy in (-0.52, 0.0, 0.52):  # 纬线
        yy = cy + r * dy
        half = r * (1 - dy * dy) ** 0.5
        gd.line([(cx - half, yy), (cx + half, yy)], fill=(255, 255, 255, 40), width=lw)
    img = Image.alpha_composite(img.convert("RGBA"), grid).convert("RGB")
    d = ImageDraw.Draw(img)

    # 定位针：上方圆 + 下方尖角，二者相切拼成水滴形
    head_r = size * 0.175
    head_cy = size * 0.435
    tip_y = size * 0.735
    # 尖角两侧的切点，让三角形与圆平滑相接而不是硬拼出台阶
    half_w = head_r * 0.74
    join_y = head_cy + (head_r ** 2 - half_w ** 2) ** 0.5

    d.polygon(
        [(cx - half_w, join_y), (cx + half_w, join_y), (cx, tip_y)],
        fill=WHITE,
    )
    d.ellipse(
        [cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
        fill=WHITE,
    )
    # 针身中间挖空，露出背景色，这是地图标记的标志性特征
    hole_r = head_r * 0.40
    d.ellipse(
        [cx - hole_r, head_cy - hole_r, cx + hole_r, head_cy + hole_r],
        fill=lerp(BG_TOP, BG_BOTTOM, head_cy / size),
    )

    return img


def main():
    master = draw_master(1024 * SS)

    meta = json.load(open(os.path.join(OUT_DIR, "Contents.json")))
    wanted = {}
    for entry in meta["images"]:
        if "filename" not in entry:
            continue
        side = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        wanted[entry["filename"]] = round(side * scale)

    for name, px in sorted(wanted.items(), key=lambda kv: -kv[1]):
        master.resize((px, px), Image.LANCZOS).save(
            os.path.join(OUT_DIR, name), "PNG", optimize=True
        )
        print(f"  {name:<34} {px}x{px}")

    print(f"\n共生成 {len(wanted)} 个尺寸")


if __name__ == "__main__":
    main()
