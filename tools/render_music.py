#!/usr/bin/env python3
"""Render the Mega Drive version's songs (VGM files from md/res/music) to OGG for Godot.

ffmpeg's libgme plays the VGM (YM2612 FM + PSG). Each song is rendered as its intro plus exactly
one pass of its loop, read from the VGM header, and the loop's start in seconds goes to
assets/music/loops.json so the game can loop it seamlessly. Jingles have no loop.

Usage: tools/render_music.py [path to bomb-yard-nes]
"""
import json
import os
import struct
import subprocess
import sys

SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/bomb-yard-nes"))
IN = os.path.join(SRC, "md", "res", "music")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music")
RATE = 44100

os.makedirs(OUT, exist_ok=True)
loops = {}
for name in sorted(os.listdir(IN)):
    if not name.endswith(".vgm"):
        continue
    data = open(os.path.join(IN, name), "rb").read()
    total, loop_ofs, loop_samples = struct.unpack_from("<III", data, 0x18)
    song = name[:-4]
    if loop_ofs and loop_samples:
        intro = total - loop_samples
        length = total
        loops[song] = intro / RATE
    else:
        length = total + RATE // 2      # let a jingle's last note ring out
    out = os.path.join(OUT, song + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(IN, name),
                    "-af", f"atrim=end_sample={length}", "-ar", str(RATE),
                    "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    print(f"{song}: {length / RATE:.2f}s" + (f", loops at {loops[song]:.2f}s" if song in loops else ""))
json.dump(loops, open(os.path.join(OUT, "loops.json"), "w"), indent=1)
