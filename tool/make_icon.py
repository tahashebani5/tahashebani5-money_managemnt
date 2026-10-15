"""Draws the app icon: a white wallet with a gold coin on a teal gradient.

Usage: python tool/make_icon.py assets/icon   then   dart run flutter_launcher_icons

Outputs (1024x1024) into <out_dir>:
  icon.png             full icon (gradient + wallet), used for iOS / legacy Android / web
  icon_background.png  gradient only, Android adaptive background
  icon_foreground.png  wallet only on transparent, inside the adaptive safe zone
  icon_monochrome.png  white wallet silhouette, Android 13 themed icon
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersampling for smooth edges
TOP = (16, 150, 122)      # #10967A
BOTTOM = (8, 86, 76)      # #08564C
WHITE = (255, 255, 255, 255)
TEAL_DARK = (8, 96, 82, 255)
GOLD = (247, 189, 66, 255)
GOLD_EDGE = (222, 154, 30, 255)


def gradient(size):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.35 + y * 0.65) / size  # diagonal, mostly top -> bottom
            px[x, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)) + (255,)
    return img


def wallet(scale, mono=False):
    """Wallet glyph on a transparent canvas; scale = glyph width / canvas width."""
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = s * scale
    h = w * 0.74
    x0, y0 = (s - w) / 2, (s - h) / 2 + w * 0.06
    r = w * 0.13
    white = WHITE
    cut = (0, 0, 0, 0) if mono else TEAL_DARK

    # Coin peeking out of the top of the wallet
    cr = w * 0.20
    cx, cy = x0 + w * 0.66, y0 - cr * 0.25
    if mono:
        d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=white)
    else:
        d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=GOLD_EDGE)
        inner = cr * 0.80
        d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=GOLD)

    # Wallet body
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r, fill=white)
    # Darker line under the top edge (the opening of the wallet)
    lw = w * 0.045
    d.rounded_rectangle([x0 + w * 0.08, y0 + h * 0.20, x0 + w * 0.70, y0 + h * 0.20 + lw],
                        radius=lw / 2, fill=cut)
    # Clasp tab on the right with a button
    tx0, ty0 = x0 + w * 0.56, y0 + h * 0.40
    tx1, ty1 = x0 + w * 0.92, y0 + h * 0.74
    d.rounded_rectangle([tx0, ty0, tx1, ty1], radius=(ty1 - ty0) / 2, fill=cut)
    br = (ty1 - ty0) * 0.22
    bx, by = tx0 + (ty1 - ty0) / 2, (ty0 + ty1) / 2
    d.ellipse([bx - br, by - br, bx + br, by + br], fill=white)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    bg = gradient(SIZE)
    bg.save(out / "icon_background.png")
    full = bg.copy()
    full.alpha_composite(wallet(0.60))
    full.convert("RGB").save(out / "icon.png")
    # Adaptive icons crop to the centre ~66%, so the glyph is kept smaller
    wallet(0.58).save(out / "icon_foreground.png")
    wallet(0.58, mono=True).save(out / "icon_monochrome.png")
    print("written to", out)


if __name__ == "__main__":
    main(sys.argv[1])
