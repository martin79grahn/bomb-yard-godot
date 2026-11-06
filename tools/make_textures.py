#!/usr/bin/env python3
"""Generate the PBR surface textures for the 3D arenas: albedo, normal and roughness maps
(plus emission for the glowing lava) for each level's floor, walls and breakable blocks.

Everything is synthesised from tileable noise, Voronoi cells and simple patterns, so the
textures tile seamlessly. Block textures carry a baked bevel along their edges, because each
face of a block shows the whole texture (object-space triplanar mapping in Godot).

Usage: tools/make_textures.py        writes assets/tex/<name>_{albedo,normal,rough[,emit]}.png
"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tex")
S = 512
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- noise
def vnoise(px, py=None, size=S):
    """Tileable value noise with px x py cells over the texture."""
    py = py or px
    grid = rng.random((py, px))
    x = np.arange(size) * px / size
    y = np.arange(size) * py / size
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = x - x0; fy = y - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    x1 = (x0 + 1) % px; y1 = (y0 + 1) % py
    a = grid[np.ix_(y0, x0)]; b = grid[np.ix_(y0, x1)]
    c = grid[np.ix_(y1, x0)]; d = grid[np.ix_(y1, x1)]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(p, octaves=5, pers=0.5, py=None):
    out = np.zeros((S, S)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        out += vnoise(p * 2 ** o, (py or p) * 2 ** o) * amp
        tot += amp; amp *= pers
    return out / tot


def voronoi(n):
    """Tileable Voronoi: distance to the nearest and second nearest point, and the cell id."""
    pts = rng.random((n, 2)) * S
    offs = [(dx, dy) for dx in (-S, 0, S) for dy in (-S, 0, S)]
    allp = np.concatenate([pts + o for o in offs])
    ids = np.tile(np.arange(n), len(offs))
    yy, xx = np.mgrid[0:S, 0:S]
    f1 = np.full((S, S), 1e9); f2 = np.full((S, S), 1e9); cid = np.zeros((S, S), int)
    for i, (x, y) in enumerate(allp):
        d = np.hypot(xx - x, yy - y)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, ids[i], cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def lerp(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t


def col(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])


def bevel(width=0.06):
    """0 at a block's edges rising to 1 inside: the rounded rim of a block face."""
    u = (np.arange(S) + 0.5) / S
    d = np.minimum(u, 1 - u)
    e = np.minimum(d[None, :], d[:, None])
    return np.clip(e / width, 0, 1) ** 0.6


def normal_map(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    n = np.dstack([-dx * strength, dy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def save(name, albedo, height, rough, strength=6.0, emit=None):
    os.makedirs(OUT, exist_ok=True)
    def img(a):
        return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    img(albedo).save(os.path.join(OUT, f"{name}_albedo.png"))
    img(normal_map(height * S / 64, strength / 8)).save(os.path.join(OUT, f"{name}_normal.png"))
    img(rough).save(os.path.join(OUT, f"{name}_rough.png"))
    if emit is not None:
        img(emit).save(os.path.join(OUT, f"{name}_emit.png"))
    print(name)


# ---------------------------------------------------------------- floors
def grass():
    base = fbm(4, 5)
    blades = vnoise(160, 40) * 0.6 + vnoise(220, 70) * 0.4      # streaky fine grass
    clumps = fbm(8, 3)
    dirt = np.clip((fbm(3, 4) - 0.62) * 5, 0, 1)
    a = lerp(col("#2f6b1e"), col("#6fae38"), base * 0.6 + blades * 0.6 - 0.15)
    a = lerp(a, col("#a7c95a"), np.clip((blades - 0.72) * 4, 0, 1) * 0.6)
    a = lerp(a, col("#6b5236"), dirt * 0.75)
    a *= (0.8 + 0.3 * clumps)[..., None]
    h = blades * 0.6 + clumps * 0.4 - dirt * 0.3
    save("floor_yard", a, h, 0.85 + 0.1 * blades, 5)


def sand():
    warp = fbm(3, 4)
    ripple = 0.5 + 0.5 * np.sin((np.arange(S)[:, None] / S * 18 + warp * 4.0 + np.arange(S)[None, :] / S * 2) * 2 * np.pi)
    grain = vnoise(256) * 0.5 + vnoise(128) * 0.5
    a = lerp(col("#b88f55"), col("#ecd29c"), ripple * 0.45 + fbm(4, 4) * 0.4 + grain * 0.25)
    pebbles = np.clip((vnoise(90) - 0.86) * 9, 0, 1)
    a = lerp(a, col("#8a6a44"), pebbles * 0.7)
    h = ripple * 0.5 + grain * 0.15 + pebbles * 0.4
    save("floor_sand", a, h, 0.92 + 0.05 * grain, 5)


def frost():
    f1, f2, _ = voronoi(26)
    crack = np.clip(1 - (f2 - f1) / 3.0, 0, 1)
    frostn = fbm(5, 5)
    sparkle = (vnoise(256) > 0.93).astype(float)
    a = lerp(col("#a9cde6"), col("#f2fbff"), frostn * 0.9 + 0.2)
    a = lerp(a, col("#5e93bd"), crack * 0.55)
    a = np.clip(a + sparkle[..., None] * 0.25, 0, 1)
    h = frostn * 0.6 - crack * 0.5
    save("floor_frost", a, h, 0.25 + 0.35 * frostn - sparkle * 0.2, 4)


def lava():
    f1, f2, _ = voronoi(22)
    edge = f2 - f1
    crack = np.clip(1 - edge / 6.0, 0, 1) ** 2.5
    rock = fbm(6, 5)
    a = lerp(col("#141012"), col("#463b3a"), rock * 0.9)
    a = lerp(a, col("#2a0a04"), crack * 0.8)
    glow = crack * (0.6 + 0.4 * fbm(4, 3))
    emit = lerp(col("#000000"), col("#ff5a10"), glow) + lerp(col("#000000"), col("#ffd040"), np.clip(glow - 0.6, 0, 1) * 2)
    h = rock * 0.7 - crack * 0.9
    save("floor_lava", a, h, 0.9 - crack * 0.4, 7, emit)


def cloud():
    soft = fbm(3, 6, 0.55)
    puff = fbm(6, 4)
    a = lerp(col("#c9dcf5"), col("#ffffff"), soft * 0.9 + puff * 0.3)
    h = soft * 0.8 + puff * 0.2
    save("floor_cloud", a, h, np.full((S, S), 0.95), 3)


def seabed():
    warp = fbm(3, 4)
    ripple = 0.5 + 0.5 * np.sin((np.arange(S)[None, :] / S * 14 + warp * 5) * 2 * np.pi)
    caustic_f1, caustic_f2, _ = voronoi(30)
    caustic = np.clip(1 - (caustic_f2 - caustic_f1) / 5, 0, 1) ** 3
    a = lerp(col("#1d4d55"), col("#5f9c8c"), fbm(4, 5) * 0.7 + ripple * 0.3)
    a = np.clip(a + caustic[..., None] * np.array([0.25, 0.35, 0.35]), 0, 1)
    pebble = np.clip((vnoise(70) - 0.85) * 8, 0, 1)
    a = lerp(a, col("#c9b08a"), pebble * 0.6)
    h = ripple * 0.4 + pebble * 0.5
    save("floor_sea", a, h, 0.8 - caustic * 0.3, 5)


# ---------------------------------------------------------------- indestructible walls
def framed(a, h, rough, edge_col=None, width=0.07):
    b = bevel(width)
    a = a * (0.55 + 0.45 * b)[..., None]
    if edge_col is not None:
        a = lerp(edge_col, a, b * 1.3)
    return a, h * 0.5 + b * 1.2, rough


def wall_yard():
    n = fbm(5, 6)
    pits = np.clip((vnoise(180) - 0.88) * 10, 0, 1)
    a = lerp(col("#7d8086"), col("#c3c6cb"), n)
    a = lerp(a, col("#50525a"), pits)
    save("wall_yard", *framed(a, n * 0.5 - pits * 0.6, 0.8 + 0.1 * n))


def wall_sand():
    y = np.arange(S)[:, None] / S
    strata = 0.5 + 0.5 * np.sin((y * 9 + fbm(2, 4) * 1.5) * 2 * np.pi)
    n = fbm(6, 5)
    a = lerp(col("#b77f48"), col("#e9c48a"), strata * 0.5 + n * 0.5)
    save("wall_sand", *framed(a, strata * 0.4 + n * 0.4, np.full((S, S), 0.9)))


def wall_frost():
    f1, f2, _ = voronoi(9)
    crack = np.clip(1 - (f2 - f1) / 2.0, 0, 1)
    n = fbm(3, 5)
    a = lerp(col("#7fc1e8"), col("#e6f8ff"), n * 0.8 + 0.2)
    a = lerp(a, col("#ffffff"), crack * 0.6)
    save("wall_frost", *framed(a, n * 0.3 + crack * 0.2, 0.08 + 0.15 * n, col("#bfe6ff")))


def wall_lava():
    f1, f2, _ = voronoi(14)
    cols = np.clip((f2 - f1) / 10, 0, 1)
    n = fbm(6, 5)
    a = lerp(col("#1a1719"), col("#4d4547"), n * 0.6 + cols * 0.4)
    vein = np.clip(1 - (f2 - f1) / 2.5, 0, 1) ** 3
    emit = lerp(col("#000000"), col("#c03008"), vein * 0.7)
    a, h, r = framed(a, n * 0.5 + cols * 0.5, 0.85 + 0.1 * n)
    save("wall_lava", a, h, r, 6, emit * bevel()[..., None])


def wall_cloud():
    warp = fbm(3, 5)
    vein = np.abs(np.sin((np.arange(S)[None, :] / S * 3 + warp * 6) * np.pi)) ** 0.15
    a = lerp(col("#c9a24a"), col("#fff3c8"), vein)
    a, h, r = framed(a, vein * 0.2, 0.3 + 0.2 * (1 - vein), col("#b8892a"), 0.09)
    save("wall_cloud", a, h, r, 3)


def wall_sea():
    f1, f2, _ = voronoi(70)
    pores = np.clip(1 - f1 / 9, 0, 1) ** 2
    n = fbm(5, 5)
    a = lerp(col("#c45a52"), col("#ffab95"), n * 0.7 + 0.2)
    a = lerp(a, col("#6e2228"), pores * 0.8)
    save("wall_sea", *framed(a, n * 0.4 - pores * 0.8, 0.75 + 0.2 * pores))


# ---------------------------------------------------------------- breakable blocks
def crate():
    u = (np.arange(S) + 0.5) / S
    U, V = np.meshgrid(u, u)
    grain = vnoise(6, 90) * 0.6 + vnoise(12, 200) * 0.4           # long grain along x
    planks = (V * 4) % 1
    seam = np.clip(1 - np.minimum(planks, 1 - planks) / 0.02, 0, 1)
    frame = np.minimum(np.minimum(U, 1 - U), np.minimum(V, 1 - V)) < 0.11
    brace = np.abs(U - V) < 0.06
    board = frame | brace
    a = lerp(col("#7b4a22"), col("#c48a4c"), grain)
    a = np.where(board[..., None], lerp(col("#6a3d1a"), col("#a8703a"), grain), a)
    a *= (1 - seam * 0.6 * ~board)[..., None]
    nails = np.zeros((S, S))
    for cx, cy in ((0.055, 0.055), (0.945, 0.055), (0.055, 0.945), (0.945, 0.945)):
        nails += np.clip(1 - np.hypot(U - cx, V - cy) / 0.018, 0, 1)
    a = lerp(a, col("#3a3a40"), nails * 2)
    h = grain * 0.3 + board * 0.5 - seam * 0.4 + nails
    a, h, r = framed(a, h, 0.75 + 0.15 * grain, None, 0.04)
    save("stone_yard", a, h, r, 6)


def bricks(name, c_dark, c_light, mortar, rough, rows=5):
    u = (np.arange(S) + 0.5) / S
    U, V = np.meshgrid(u, u)
    row = np.floor(V * rows)
    off = (row % 2) * 0.25
    bu = (U * 2 + off) % 1
    bv = (V * rows) % 1
    m = np.minimum(np.minimum(bu, 1 - bu) * 2 / rows * 2, np.minimum(bv, 1 - bv) / rows)
    joint = np.clip(1 - m / 0.012, 0, 1)
    rid = (row * 7 + np.floor(U * 2 + off) * 13) % 5 / 5
    n = fbm(8, 5)
    a = lerp(col(c_dark), col(c_light), rid * 0.5 + n * 0.5)
    a = lerp(a, col(mortar), joint)
    h = n * 0.3 - joint * 0.8
    save(name, *framed(a, h, rough + 0.1 * n, None, 0.04))


def magma():
    f1, f2, _ = voronoi(16)
    crack = np.clip(1 - (f2 - f1) / 4.0, 0, 1) ** 2
    n = fbm(6, 5)
    a = lerp(col("#1e1210"), col("#5a3a2c"), n)
    a = lerp(a, col("#3a0c02"), crack)
    glow = crack * (0.7 + 0.3 * fbm(3, 3))
    emit = lerp(col("#000000"), col("#ff6a14"), glow) + lerp(col("#000000"), col("#ffe070"), np.clip(glow - 0.65, 0, 1) * 2.5)
    a, h, r = framed(a, n * 0.6 - crack * 0.9, 0.85 - crack * 0.3)
    save("stone_lava", a, h, r, 7, emit)


def cotton():
    n = fbm(4, 6, 0.6)
    a = lerp(col("#dfe9f8"), col("#ffffff"), n)
    a, h, r = framed(a, n, np.full((S, S), 1.0), col("#c4d6ef"), 0.12)
    save("stone_cloud", a, h, r, 4)


def barnacle():
    n = fbm(5, 5)
    a = lerp(col("#5b6a74"), col("#a9b7bf"), n)
    f1, _, _ = voronoi(60)
    shell = np.clip(1 - f1 / 13, 0, 1)
    hole = np.clip(1 - f1 / 4, 0, 1)
    a = lerp(a, col("#e8e2d0"), (shell > 0.05) * 0.6)
    a = lerp(a, col("#1a2026"), hole)
    algae = np.clip((fbm(3, 4) - 0.55) * 4, 0, 1)
    a = lerp(a, col("#3f7a3a"), algae * 0.6)
    save("stone_sea", *framed(a, n * 0.3 + shell * 0.8 - hole, 0.8 + 0.1 * n, None, 0.05))


for f in (grass, sand, frost, lava, cloud, seabed, wall_yard, wall_sand, wall_frost, wall_lava, wall_cloud, wall_sea,
          crate, magma, cotton, barnacle):
    f()
bricks("stone_sand", "#8e3e22", "#c9683e", "#d8c3a0", 0.85)
bricks("stone_frost", "#c9dff0", "#ffffff", "#7fa6c8", 0.5, rows=4)
