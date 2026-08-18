#!/usr/bin/env python3
"""Generate the MoleUI AppIcon.appiconset — green rounded square + cream mole.
Renders the mole by flattening its SVG cubic-bezier path with Pillow (qlmanage's
SVG support is unreliable)."""
import os, json
from PIL import Image, ImageDraw

ROOT = "/Users/usuario/repos/mole-app/MoleUI"
OUT = os.path.join(ROOT, "MoleUI/Assets.xcassets/AppIcon.appiconset")
os.makedirs(OUT, exist_ok=True)

# Mole path from mole.svg (viewBox 0 0 120 120): start point + cubic segments.
BODY = ((24, 78), [(14,74,10,66,14,60),(17,55,24,55,28,58),(26,49,30,40,40,35),
        (34,33,30,28,31,24),(32,20,37,20,40,23),(42,25,43,29,42,32),
        (48,29,56,28,64,30),(84,34,98,48,100,66),(101,78,94,88,80,90),
        (60,93,40,90,28,84),(27,84,25,82,24,78)])
EYE  = ((46, 44), [(44,44,43,46,44,48),(45,50,48,50,49,48),(50,46,48,44,46,44)])
PAW  = ((20, 74), [(22,78,26,80,30,79),(27,74,24,71,20,71),(18,71,18,72,20,74)])

def flatten(subpath, steps=24):
    (sx, sy), cubics = subpath
    pts = [(sx, sy)]
    for (c1x,c1y,c2x,c2y,ex,ey) in cubics:
        for i in range(1, steps+1):
            t = i/steps; mt = 1-t
            x = mt**3*sx + 3*mt*mt*t*c1x + 3*mt*t*t*c2x + t**3*ex
            y = mt**3*sy + 3*mt*mt*t*c1y + 3*mt*t*t*c2y + t**3*ey
            pts.append((x, y))
        sx, sy = ex, ey
    return pts

def build_mole_mask(art):
    """Return an L-mode mask (255=mole) at art x art, from the 120-unit path."""
    SS = 4  # supersample for smooth edges
    size = art*SS
    scale = size/120.0
    def sc(pts): return [(x*scale, y*scale) for x, y in pts]
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.polygon(sc(flatten(BODY)), fill=255)
    d.polygon(sc(flatten(EYE)), fill=0)   # holes
    d.polygon(sc(flatten(PAW)), fill=0)
    return m.resize((art, art), Image.LANCZOS)

S = 1024
CREAM = (243, 236, 221, 255)
inset, radius = 100, 190

# Green vertical gradient.
top, bot = (74, 107, 78), (42, 66, 52)
bg = Image.new("RGBA", (S, S))
for y in range(S):
    t = y/(S-1)
    bg.paste(Image.new("RGBA", (S, 1),
        (int(top[0]+(bot[0]-top[0])*t), int(top[1]+(bot[1]-top[1])*t),
         int(top[2]+(bot[2]-top[2])*t), 255)), (0, y))

canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rr = Image.new("L", (S, S), 0)
ImageDraw.Draw(rr).rounded_rectangle([inset, inset, S-inset, S-inset], radius=radius, fill=255)
canvas.paste(bg, (0, 0), rr)

# Cream mole, centered in the rounded-rect area.
art = int((S - 2*inset) * 0.72)
mask = build_mole_mask(art)
cream = Image.new("RGBA", (art, art), CREAM)
off = (S - art)//2
canvas.paste(cream, (off, off), mask)

for s in [16, 32, 64, 128, 256, 512, 1024]:
    canvas.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, f"icon_{s}.png"))

contents = {"images": [
    {"idiom":"mac","scale":"1x","size":"16x16","filename":"icon_16.png"},
    {"idiom":"mac","scale":"2x","size":"16x16","filename":"icon_32.png"},
    {"idiom":"mac","scale":"1x","size":"32x32","filename":"icon_32.png"},
    {"idiom":"mac","scale":"2x","size":"32x32","filename":"icon_64.png"},
    {"idiom":"mac","scale":"1x","size":"128x128","filename":"icon_128.png"},
    {"idiom":"mac","scale":"2x","size":"128x128","filename":"icon_256.png"},
    {"idiom":"mac","scale":"1x","size":"256x256","filename":"icon_256.png"},
    {"idiom":"mac","scale":"2x","size":"256x256","filename":"icon_512.png"},
    {"idiom":"mac","scale":"1x","size":"512x512","filename":"icon_512.png"},
    {"idiom":"mac","scale":"2x","size":"512x512","filename":"icon_1024.png"},
], "info": {"author": "xcode", "version": 1}}
with open(os.path.join(OUT, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)
print("AppIcon written.")
