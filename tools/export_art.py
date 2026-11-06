#!/usr/bin/env python3
"""Export the Mega Drive version's graphics as PNG atlases for the Godot game.

The pictures are not redrawn here: this imports the Mega Drive tool
(bomb-yard-nes/md/tools/make_gfx.py) and calls its own drawing functions, then paints each
picture in its palette (quantised to the Mega Drive's 3 bits per channel) into assets/.

Usage: tools/export_art.py [path to bomb-yard-nes]

Atlas layouts (the game's art.gd reads them by these positions):
  tiles.png    16x16 cells. One row per arena palette: yard, sand, frost, boss, lava, cloud, sea.
               Columns 0-7: floor [texture 0-1][shadow 0-3] (shadow bit 0 top, bit 1 left),
               8 wall, 9 stone.
  items.png    16x16 cells. Row 0: bomb [spark 0/1, flash 0/1] x4, remote bomb lamp on, lamp off,
               item shoe, fire, bomb, life, penetrator, remote.
               Rows 1-4: flames [size*2 + phase], 16 columns by sides (bit 0 left, 1 right, 2 up, 3 down).
  font.png     8x8 glyphs in FONT_ORDER; row 0 white, row 1 yellow. Panel colour is see-through.
  box.png      8x8: box TL T TR L C R BL B BR, then panel edge left and right.
  bombers.png  16x24 cells. Rows: Bit, Ruby, Sky, Nova, green bomber, green bomber angry.
               Columns: direction (0 down, 1 up, 2 left) * 3 + frame (0 stand, 1-2 steps).
  monsters.png 16x16 cells. One row per level (Krax, asp, yeti, imp, angel, fish), frames left to right.
  bosses.png   32x24 cells. Rows: Krax King, scorpion, mammoth, dragon, storm cloud, shark.
               Columns: frame 0, 1, angry frame 0, 1. All face left.
  logo.png     the title logo.
"""
import importlib.util
import os
import sys
import tempfile

from PIL import Image

SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/bomb-yard-nes"))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

# make_gfx.py runs on import and writes C files to argv[1]: send those to a throwaway folder
tmp = tempfile.mkdtemp()
sys.argv = ["make_gfx.py", tmp]
spec = importlib.util.spec_from_file_location("make_gfx", os.path.join(SRC, "md", "tools", "make_gfx.py"))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)


def md_rgb(h):
    """A colour as the Mega Drive shows it: 8 levels per channel."""
    return tuple(round(round(v / 255 * 7) / 7 * 255) for v in g.hexrgb(h))


def paint(img, pic, ox, oy, pal, clear=(0,)):
    px = img.load()
    for y in range(pic.h):
        for x in range(pic.w):
            c = pic.p[y][x]
            if c not in clear:
                px[ox + x, oy + y] = md_rgb(pal[c]) + (255,)


def grid(pic_rows, w, h, pal_rows, clear=(0,)):
    cols = max(len(r) for r in pic_rows)
    img = Image.new("RGBA", (cols * w, len(pic_rows) * h), (0, 0, 0, 0))
    for j, row in enumerate(pic_rows):
        for i, pic in enumerate(row):
            paint(img, pic, i * w, j * h, pal_rows[j], clear)
    return img


def save(img, name):
    img.save(os.path.join(OUT, name))
    print(f"{name}: {img.size[0]}x{img.size[1]}")


class T:      # an 8x8 tile as a picture
    def __init__(self, t):
        self.w = self.h = 8
        self.p = t


os.makedirs(OUT, exist_ok=True)

# arena cells
THEMES = ("yard", "sand", "frost", "boss", "lava", "cloud", "sea")
cells = [g.floor_cell(17 + tex * 101, s & 1, s & 2) for tex in range(2) for s in range(4)] + [g.wall_cell(), g.stone_cell()]
save(grid([cells] * len(THEMES), 16, 16, [g.pal0(t) for t in THEMES], clear=()), "tiles.png")

# bombs, power-ups and flames
row0 = [g.bomb_pic(s, f) for f in (False, True) for s in (0, 1)] + [g.remote_bomb_pic(1), g.remote_bomb_pic(0)] + \
       [g.item_skate(), g.item_fire(), g.item_bomb(), g.heart_pic(), g.item_pen(), g.item_remote()]
flames = [[g.flame_pic(sides, size, phase) for sides in range(16)] for size in range(2) for phase in range(2)]
save(grid([row0] + flames, 16, 16, [g.PAL1] * 5), "items.png")

# font: white and yellow; the panel colour (12) is see-through so text sits on anything
save(grid([[T(g.glyph_tile(ch, ink)) for ch in g.FONT_ORDER] for ink in (14, 15)], 8, 8,
          [g.pal0("yard")] * 2, clear=(0, 12)), "font.png")
with open(os.path.join(OUT, "font_order.txt"), "w") as f:
    f.write(g.FONT_ORDER)

# message box and panel edges
box = [T(g.box_tile((tb[0], tb[1], lr[0], lr[1]))) for tb in ((1, 0), (0, 0), (0, 1)) for lr in ((1, 0), (0, 0), (0, 1))]
box += [T([[12] * 6 + [13, 1] for _ in range(8)]), T([[1, 13] + [12] * 6 for _ in range(8)])]
save(grid([box], 8, 8, [g.pal0("yard")]), "box.png")

# the bombers
suits = ("p1", "p2", "sky", "nova")
rows = [[g.bomber(d, fr) for d in range(3) for fr in range(3)] for _ in suits]
rows += [[g.bomber(d, fr, boss=True) for d in range(3) for fr in range(3)] for _ in range(2)]
save(grid(rows, 16, 24, [g.sprite_pal(s) for s in suits] + [g.sprite_pal("boss_yard"), g.sprite_pal("angry_yard")]),
     "bombers.png")

# each level's monster, in that level's monster colours
mons = [[g.krax(f) for f in range(3)]]
mons += [[g.creature_pic(n, 16, 16, f, (11, 12, 13), (14,), 15) for f in range(2)] for n in g.creatures.MONSTERS]
mons += [[g.fish(f) for f in range(3)]]
save(grid(mons, 16, 16, [g.sprite_pal("p1")[:11] + cols for cols in g.MONSTER_COLS]), "monsters.png")

# the creature bosses and the shark, normal and angry
brows, bpals = [], []
for name in g.creatures.BOSSES + ["sea"]:
    pics = [g.shark(f) for f in range(2)] if name == "sea" else \
           [g.creature_pic(name, 32, 24, f, (2, 3, 4), (7, 8), 6) for f in range(2)]
    img_row = []
    for mood in ("boss", "angry"):
        img_row.append(grid([pics], 32, 24, [g.sprite_pal(f"{mood}_{name}")]))
    both = Image.new("RGBA", (128, 24))
    both.paste(img_row[0], (0, 0)); both.paste(img_row[1], (64, 0))
    brows.append(both)
bosses = Image.new("RGBA", (128, 24 * len(brows)))
for j, r in enumerate(brows):
    bosses.paste(r, (0, j * 24))
save(bosses, "bosses.png")

save(grid([[g.logo()]], 288, 64, [g.PAL1]), "logo.png")
