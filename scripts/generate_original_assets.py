#!/usr/bin/env python3
"""
Procedural generator for a 100% original bubble-shooter asset pack.

Everything this script writes is drawn or synthesised from scratch here, from the
specifications in blueprint/original/06_AUDIO_AND_SOUND_DESIGN.md and
blueprint/original/07_ASSET_PRODUCTION_SPEC.md. No file is read from any APK, and
no output is derived from anyone else's artwork or audio.

Requires: Pillow, numpy.  Optional: ffmpeg (for .ogg output).

    python scripts/generate_original_assets.py --out generated_assets
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS

# --------------------------------------------------------------------------- #
# palette and shape language
# --------------------------------------------------------------------------- #
BUBBLES = [
    ("red", "#E8453C", "circle"),
    ("blue", "#2D9CDB", "triangle"),
    ("green", "#27AE60", "square"),
    ("yellow", "#F2C94C", "diamond"),
    ("purple", "#9B51E0", "star"),
    ("orange", "#F2994A", "cross"),
]
ACCENT = "#F2C94C"
NEUTRAL_DARK = "#1A1A22"
NEUTRAL_LIGHT = "#F5F6FA"
LIGHT_DIR = np.array([-0.45, -0.62, 0.64])
LIGHT_DIR = LIGHT_DIR / np.linalg.norm(LIGHT_DIR)

SS = 3          # supersample factor for sprites
SR = 44100      # audio sample rate


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), RESAMPLE)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def star_points(cx, cy, r_out, r_in, points=5, rot=-90.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# --------------------------------------------------------------------------- #
# bubbles
# --------------------------------------------------------------------------- #
def sphere(size: int, colour: tuple[int, int, int], emblem: str | None = None,
           alpha: float = 1.0) -> Image.Image:
    """A shaded sphere: diffuse + specular + rim light, anti-aliased edge."""
    n = size * SS
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = (n - 1) / 2.0
    radius = n * 0.47
    dx = (xx - cx) / radius
    dy = (yy - cy) / radius
    dist = np.sqrt(dx * dx + dy * dy)

    mask = np.clip((1.0 - dist) * radius, 0.0, 1.0)          # 1 px anti-aliased edge

    nz = np.sqrt(np.clip(1.0 - dx * dx - dy * dy, 0.0, 1.0))
    lambert = np.clip(dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1] + nz * LIGHT_DIR[2], 0.0, 1.0)
    spec = np.clip(lambert, 0.0, 1.0) ** 28 * 255.0
    rim = np.clip(dist, 0.0, 1.0) ** 6 * 70.0

    base = np.array(colour, dtype=np.float32)
    shade = 0.42 + 0.85 * lambert
    out = np.zeros((n, n, 4), dtype=np.float32)
    for i in range(3):
        out[..., i] = np.clip(base[i] * shade + spec * 0.85 + rim * 0.45, 0, 255)
    out[..., 3] = mask * 255.0 * alpha

    img = Image.fromarray(out.astype(np.uint8), "RGBA")

    if emblem:
        d = ImageDraw.Draw(img)
        c = (cx, cy)
        r = n * 0.20
        col = (255, 255, 255, 58)
        if emblem == "circle":
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=col, width=max(2, n // 40))
        elif emblem == "triangle":
            d.polygon(star_points(c[0], c[1], r * 1.15, r * 1.15, points=3), outline=col,
                      width=max(2, n // 40))
        elif emblem == "square":
            d.rectangle([c[0] - r * 0.8, c[1] - r * 0.8, c[0] + r * 0.8, c[1] + r * 0.8],
                        outline=col, width=max(2, n // 40))
        elif emblem == "diamond":
            d.polygon([(c[0], c[1] - r), (c[0] + r, c[1]), (c[0], c[1] + r), (c[0] - r, c[1])],
                      outline=col, width=max(2, n // 40))
        elif emblem == "star":
            d.polygon(star_points(c[0], c[1], r, r * 0.45), outline=col, width=max(2, n // 40))
        elif emblem == "cross":
            w = max(2, n // 40)
            d.line([c[0] - r * 0.8, c[1], c[0] + r * 0.8, c[1]], fill=col, width=w)
            d.line([c[0], c[1] - r * 0.8, c[0], c[1] + r * 0.8], fill=col, width=w)
    return finish(img, size, size)


def pop_frames(size: int, colour: tuple[int, int, int], frames: int = 8,
               seed: int = 7) -> list[Image.Image]:
    """Pop sequence: the bubble swells, then bursts into fragments."""
    out = []
    rng = np.random.default_rng(seed)
    angles = rng.uniform(0, 2 * math.pi, 10)
    speeds = rng.uniform(0.55, 1.25, 10)
    base = sphere(int(size * 0.72), colour)
    for f in range(frames):
        t = f / (frames - 1)
        img = canvas(size, size)
        d = ImageDraw.Draw(img)
        s = 0.72 + 0.55 * t
        if t < 0.45:
            k = int(size * s * SS)
            img.alpha_composite(base.resize((k, k), RESAMPLE),
                                (int((size * SS - k) / 2), int((size * SS - k) / 2)))
        # fragments
        for i, (a, sp) in enumerate(zip(angles, speeds)):
            rr = (size * 0.12) * (1 - t) + 1.0
            dist = (size * 0.16 + t * size * 0.40) * sp
            x = size * SS / 2 + math.cos(a) * dist
            y = size * SS / 2 + math.sin(a) * dist
            alpha = int(230 * (1 - t) ** 1.4)
            if alpha <= 2:
                continue
            col = (*colour, alpha)
            d.ellipse([x - rr * SS, y - rr * SS, x + rr * SS, y + rr * SS], fill=col)
        # expanding ring
        if t > 0.2:
            ring_r = size * SS * (0.2 + 0.55 * t)
            ring_a = int(120 * (1 - t))
            d.ellipse([size * SS / 2 - ring_r, size * SS / 2 - ring_r,
                       size * SS / 2 + ring_r, size * SS / 2 + ring_r],
                      outline=(255, 255, 255, ring_a), width=max(2, SS * 2))
        out.append(finish(img, size, size))
    return out


# --------------------------------------------------------------------------- #
# blockers, boosters, fx
# --------------------------------------------------------------------------- #
def ice_overlay(size: int, stage: int, seed: int = 3) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    pad = size * 0.03
    d.rounded_rectangle([pad * SS, pad * SS, (size - pad) * SS, (size - pad) * SS],
                        radius=size * 0.22 * SS,
                        fill=(198, 232, 255, 110), outline=(235, 250, 255, 190),
                        width=max(2, SS * 2))
    rng = np.random.default_rng(seed)
    cracks = 2 + stage * 2
    for _ in range(cracks):
        x0, y0 = rng.uniform(0.15, 0.85) * size, rng.uniform(0.15, 0.85) * size
        pts = [(x0 * SS, y0 * SS)]
        for _ in range(3):
            x0 += rng.uniform(-0.18, 0.18) * size
            y0 += rng.uniform(-0.18, 0.18) * size
            pts.append((x0 * SS, y0 * SS))
        d.line(pts, fill=(255, 255, 255, 150), width=max(1, SS))
    return finish(img, size, size)


def stone(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(11)
    pts = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        r = (0.44 + rng.uniform(-0.04, 0.04)) * size
        pts.append((size * SS / 2 + r * SS * math.cos(a), size * SS / 2 + r * SS * math.sin(a)))
    d.polygon(pts, fill=(108, 112, 122, 255), outline=(78, 82, 92, 255))
    for _ in range(40):
        x, y = rng.uniform(0.2, 0.8) * size * SS, rng.uniform(0.2, 0.8) * size * SS
        rr = rng.uniform(0.01, 0.03) * size * SS
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(128, 132, 142, 190))
    return finish(img, size, size)


def chain_overlay(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    w = max(3, SS * 4)
    for k in (-1, 1):
        d.line([(0, size * SS / 2 + k * size * SS * 0.18),
                (size * SS, size * SS / 2 + k * size * SS * 0.18)],
               fill=(196, 200, 210, 235), width=w)
        for i in range(7):
            cx = size * SS * (0.08 + i * 0.14)
            cy = size * SS / 2 + k * size * SS * 0.18
            r = size * SS * 0.055
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(150, 155, 168, 255), width=max(2, SS))
    return finish(img, size, size)


def cage_overlay(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    w = max(3, SS * 4)
    for i in range(1, 5):
        x = size * SS * i / 5
        d.line([(x, size * SS * 0.06), (x, size * SS * 0.94)], fill=(170, 176, 190, 235), width=w)
    d.line([(size * SS * 0.06, size * SS * 0.2), (size * SS * 0.94, size * SS * 0.2)],
           fill=(170, 176, 190, 235), width=w)
    return finish(img, size, size)


def cloud_overlay(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    for cx, cy, r in [(0.36, 0.46, 0.26), (0.58, 0.40, 0.24), (0.50, 0.60, 0.28), (0.68, 0.58, 0.20)]:
        d.ellipse([(cx - r) * size * SS, (cy - r) * size * SS,
                   (cx + r) * size * SS, (cy + r) * size * SS], fill=(240, 244, 252, 205))
    return finish(img, size, size)


def morph_ring(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    r = size * SS * 0.42
    cx = cy = size * SS / 2
    for i in range(24):
        if i % 2:
            continue
        a0 = 2 * math.pi * i / 24
        a1 = a0 + 2 * math.pi / 24
        d.arc([cx - r, cy - r, cx + r, cy + r], math.degrees(a0), math.degrees(a1),
              fill=(255, 255, 255, 210), width=max(3, SS * 3))
    return finish(img, size, size)


def booster_icon(size: int, kind: str) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    s = size * SS
    body = (58, 62, 78, 255)
    gold = rgb(ACCENT)
    if kind == "bomb":
        d.ellipse([s * 0.18, s * 0.24, s * 0.82, s * 0.88], fill=body)
        d.ellipse([s * 0.30, s * 0.34, s * 0.44, s * 0.46], fill=(110, 116, 136, 255))
        d.line([s * 0.62, s * 0.24, s * 0.72, s * 0.10], fill=(150, 120, 80, 255), width=max(3, SS * 3))
        d.ellipse([s * 0.68, s * 0.04, s * 0.80, s * 0.16], fill=(255, 180, 60, 255))
    elif kind == "rainbow":
        for i, c in enumerate(["#E8453C", "#F2994A", "#F2C94C", "#27AE60", "#2D9CDB", "#9B51E0"]):
            r = s * (0.44 - i * 0.06)
            d.arc([s / 2 - r, s / 2 - r, s / 2 + r, s / 2 + r], 180, 360,
                  fill=(*rgb(c), 255), width=max(3, int(s * 0.06)))
    elif kind == "laser":
        d.line([s * 0.2, s * 0.8, s * 0.8, s * 0.2], fill=(255, 80, 90, 255), width=max(4, SS * 5))
        d.line([s * 0.2, s * 0.8, s * 0.8, s * 0.2], fill=(255, 210, 210, 200), width=max(1, SS * 2))
    elif kind == "swap":
        d.arc([s * 0.18, s * 0.28, s * 0.82, s * 0.78], 20, 160, fill=gold, width=max(4, SS * 4))
        d.arc([s * 0.18, s * 0.24, s * 0.82, s * 0.74], 200, 340, fill=(255, 255, 255, 235),
              width=max(4, SS * 4))
    elif kind == "extra_moves":
        d.ellipse([s * 0.16, s * 0.16, s * 0.84, s * 0.84], outline=gold, width=max(4, SS * 4))
        d.line([s * 0.5, s * 0.5, s * 0.5, s * 0.26], fill=gold, width=max(3, SS * 3))
        d.line([s * 0.5, s * 0.5, s * 0.70, s * 0.58], fill=gold, width=max(3, SS * 3))
    elif kind == "continue":
        d.ellipse([s * 0.16, s * 0.16, s * 0.84, s * 0.84], outline=(255, 255, 255, 220),
                  width=max(4, SS * 4))
        d.polygon([(s * 0.42, s * 0.32), (s * 0.42, s * 0.68), (s * 0.72, s * 0.50)],
                  fill=(255, 255, 255, 235))
    return finish(img, size, size)


def star_particle(size: int, colour: tuple[int, int, int]) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    d.polygon(star_points(c, c, size * SS * 0.48, size * SS * 0.18),
              fill=(*colour, 255))
    return finish(img, size, size)


def shockwave(size: int) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    r = size * SS * 0.42
    c = size * SS / 2
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 220), width=max(3, SS * 4))
    img = img.filter(ImageFilter.GaussianBlur(SS * 1.5))
    return finish(img, size, size)


def laser_beam(w: int, h: int) -> Image.Image:
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([w * SS * 0.42, 0, w * SS * 0.58, h * SS], fill=(255, 90, 100, 235))
    d.rectangle([w * SS * 0.47, 0, w * SS * 0.53, h * SS], fill=(255, 235, 235, 255))
    img = img.filter(ImageFilter.GaussianBlur(SS * 1.2))
    return finish(img, w, h)


# --------------------------------------------------------------------------- #
# UI, cannon, map, hud
# --------------------------------------------------------------------------- #
def rounded_panel(w: int, h: int, fill=(30, 32, 44, 240), radius=0.18,
                  outline=(255, 255, 255, 40)) -> Image.Image:
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    r = min(w, h) * radius * SS
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=r, fill=fill, outline=outline,
                        width=max(2, SS * 2))
    # top highlight
    d.rounded_rectangle([SS * 3, SS * 3, w * SS - SS * 3, h * SS * 0.45],
                        radius=r * 0.8, fill=(255, 255, 255, 16))
    return finish(img, w, h)


def button(w: int, h: int, state: str, hue: str = "#F2994A") -> Image.Image:
    base = np.array(rgb(hue), dtype=np.float32)
    if state == "pressed":
        base = base * 0.78
    if state == "disabled":
        base = base * 0.42 + 60
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    r = h * 0.30 * SS
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=r,
                        fill=tuple(int(v) for v in base) + (255,))
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS * 0.52], radius=r,
                        fill=(255, 255, 255, 46 if state == "normal" else 18))
    d.rounded_rectangle([SS * 2, SS * 2, w * SS - SS * 2, h * SS - SS * 2], radius=r,
                        outline=(0, 0, 0, 60), width=max(2, SS * 2))
    return finish(img, w, h)


def hud_icon(size: int, kind: str) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    s = size * SS
    white = (255, 255, 255, 240)
    if kind == "coin":
        d.ellipse([s * 0.10, s * 0.10, s * 0.90, s * 0.90], fill=rgb(ACCENT) + (255,),
                  outline=(214, 160, 40, 255), width=max(2, SS * 2))
        d.ellipse([s * 0.28, s * 0.28, s * 0.72, s * 0.72], outline=(255, 255, 255, 180),
                  width=max(2, SS * 2))
    elif kind == "heart":
        d.ellipse([s * 0.14, s * 0.18, s * 0.52, s * 0.56], fill=(232, 69, 60, 255))
        d.ellipse([s * 0.48, s * 0.18, s * 0.86, s * 0.56], fill=(232, 69, 60, 255))
        d.polygon([(s * 0.14, s * 0.44), (s * 0.86, s * 0.44), (s * 0.50, s * 0.90)],
                  fill=(232, 69, 60, 255))
    elif kind in ("star_on", "star_off"):
        col = rgb(ACCENT) + (255,) if kind == "star_on" else (120, 124, 136, 255)
        d.polygon(star_points(s / 2, s * 0.52, s * 0.46, s * 0.19), fill=col)
    elif kind == "gem":
        d.polygon([(s * 0.50, s * 0.12), (s * 0.86, s * 0.42), (s * 0.50, s * 0.90),
                   (s * 0.14, s * 0.42)], fill=(90, 200, 240, 255))
        d.line([(s * 0.14, s * 0.42), (s * 0.86, s * 0.42)], fill=(255, 255, 255, 200),
               width=max(2, SS * 2))
    elif kind == "pause":
        d.rounded_rectangle([s * 0.28, s * 0.20, s * 0.42, s * 0.80], radius=SS * 2, fill=white)
        d.rounded_rectangle([s * 0.58, s * 0.20, s * 0.72, s * 0.80], radius=SS * 2, fill=white)
    elif kind == "play":
        d.polygon([(s * 0.34, s * 0.18), (s * 0.34, s * 0.82), (s * 0.82, s * 0.50)], fill=white)
    elif kind == "settings":
        d.ellipse([s * 0.30, s * 0.30, s * 0.70, s * 0.70], outline=white, width=max(3, SS * 3))
        for i in range(8):
            a = 2 * math.pi * i / 8
            d.line([s * 0.5 + math.cos(a) * s * 0.34, s * 0.5 + math.sin(a) * s * 0.34,
                    s * 0.5 + math.cos(a) * s * 0.46, s * 0.5 + math.sin(a) * s * 0.46],
                   fill=white, width=max(3, SS * 3))
    elif kind in ("sound_on", "sound_off"):
        d.polygon([(s * 0.18, s * 0.38), (s * 0.34, s * 0.38), (s * 0.50, s * 0.22),
                   (s * 0.50, s * 0.78), (s * 0.34, s * 0.62), (s * 0.18, s * 0.62)], fill=white)
        if kind == "sound_on":
            for i, r in enumerate((0.16, 0.26)):
                d.arc([s * 0.50 - s * r, s * 0.5 - s * r, s * 0.50 + s * r, s * 0.5 + s * r],
                      -55, 55, fill=white, width=max(2, SS * 2))
        else:
            d.line([s * 0.62, s * 0.36, s * 0.86, s * 0.64], fill=white, width=max(3, SS * 3))
            d.line([s * 0.86, s * 0.36, s * 0.62, s * 0.64], fill=white, width=max(3, SS * 3))
    elif kind == "music_on":
        d.ellipse([s * 0.20, s * 0.62, s * 0.44, s * 0.84], fill=white)
        d.rectangle([s * 0.40, s * 0.20, s * 0.46, s * 0.74], fill=white)
        d.polygon([(s * 0.46, s * 0.20), (s * 0.78, s * 0.30), (s * 0.78, s * 0.40),
                   (s * 0.46, s * 0.30)], fill=white)
    elif kind == "spin":
        d.arc([s * 0.16, s * 0.16, s * 0.84, s * 0.84], 30, 320, fill=white, width=max(4, SS * 4))
        d.polygon([(s * 0.78, s * 0.10), (s * 0.92, s * 0.34), (s * 0.66, s * 0.32)], fill=white)
    elif kind == "piggy":
        d.ellipse([s * 0.12, s * 0.26, s * 0.88, s * 0.80], fill=(240, 150, 170, 255))
        d.ellipse([s * 0.66, s * 0.40, s * 0.86, s * 0.62], fill=(228, 130, 152, 255))
        d.ellipse([s * 0.70, s * 0.47, s * 0.74, s * 0.51], fill=(80, 40, 50, 255))
        d.ellipse([s * 0.78, s * 0.47, s * 0.82, s * 0.51], fill=(80, 40, 50, 255))
    elif kind == "shop":
        d.rounded_rectangle([s * 0.16, s * 0.34, s * 0.84, s * 0.86], radius=SS * 4, fill=white)
        d.arc([s * 0.30, s * 0.16, s * 0.70, s * 0.56], 180, 360, fill=white, width=max(3, SS * 3))
    elif kind == "gift":
        d.rectangle([s * 0.16, s * 0.40, s * 0.84, s * 0.86], fill=white)
        d.rectangle([s * 0.44, s * 0.40, s * 0.56, s * 0.86], fill=(232, 69, 60, 255))
        d.rectangle([s * 0.16, s * 0.32, s * 0.84, s * 0.42], fill=(232, 69, 60, 255))
    elif kind == "lock":
        d.rounded_rectangle([s * 0.24, s * 0.46, s * 0.76, s * 0.86], radius=SS * 3, fill=white)
        d.arc([s * 0.32, s * 0.18, s * 0.68, s * 0.58], 180, 360, fill=white, width=max(3, SS * 3))
    elif kind == "close":
        d.line([s * 0.26, s * 0.26, s * 0.74, s * 0.74], fill=white, width=max(4, SS * 4))
        d.line([s * 0.74, s * 0.26, s * 0.26, s * 0.74], fill=white, width=max(4, SS * 4))
    return finish(img, size, size)


def cannon_base() -> Image.Image:
    w, h = 220, 180
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([w * SS * 0.10, h * SS * 0.35, w * SS * 0.90, h * SS * 0.95],
                        radius=h * SS * 0.16, fill=(52, 56, 74, 255),
                        outline=(88, 94, 116, 255), width=max(3, SS * 3))
    d.ellipse([w * SS * 0.32, h * SS * 0.10, w * SS * 0.68, h * SS * 0.46],
              fill=(72, 78, 100, 255), outline=(120, 128, 152, 255), width=max(3, SS * 3))
    return finish(img, w, h)


def cannon_barrel() -> Image.Image:
    w, h = 120, 200
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([w * SS * 0.28, h * SS * 0.02, w * SS * 0.72, h * SS * 1.0],
                        radius=w * SS * 0.16, fill=(64, 70, 92, 255),
                        outline=(110, 118, 142, 255), width=max(3, SS * 3))
    d.ellipse([w * SS * 0.24, h * SS * 0.02, w * SS * 0.76, h * SS * 0.16],
              fill=(96, 104, 128, 255))
    # pivot marker at the base centre
    d.ellipse([w * SS * 0.40, h * SS * 0.90, w * SS * 0.60, h * SS * 0.99],
              fill=(180, 186, 200, 90))
    return finish(img, w, h)


def map_node(size: int, state: str, stars: int = 0) -> Image.Image:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    r = size * SS * 0.36
    ring = {"locked": (90, 94, 108, 255), "current": rgb(ACCENT) + (255,),
            "done": (60, 180, 120, 255), "done3": (232, 190, 60, 255)}[state]
    fill = {"locked": (46, 48, 60, 255), "current": (70, 76, 98, 255),
            "done": (52, 64, 60, 255), "done3": (64, 58, 40, 255)}[state]
    d.ellipse([c - r, c - r, c + r, c + r], fill=fill, outline=ring, width=max(4, SS * 4))
    if state == "locked":
        d.rounded_rectangle([c - r * 0.34, c - r * 0.06, c + r * 0.34, c + r * 0.46],
                            radius=SS * 3, fill=(150, 156, 172, 235))
        d.arc([c - r * 0.26, c - r * 0.46, c + r * 0.26, c + r * 0.10], 180, 360,
              fill=(150, 156, 172, 235), width=max(3, SS * 3))
    else:
        for i in range(3):
            x = c + (i - 1) * r * 0.52
            col = rgb(ACCENT) + (255,) if i < stars else (110, 114, 128, 255)
            d.polygon(star_points(x, c, r * 0.22, r * 0.09), fill=col)
    return finish(img, size, size)


def map_tile(size: int = 512) -> Image.Image:
    """Seamless tile: sums of sinusoids with integer frequencies wrap exactly."""
    n = size
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u = xx / n * 2 * math.pi
    v = yy / n * 2 * math.pi
    field = (np.sin(3 * u) * np.cos(2 * v) * 0.5
             + np.sin(5 * v) * 0.35
             + np.cos(4 * u + 1.7) * np.sin(3 * v) * 0.25)
    field = (field - field.min()) / (np.ptp(field) + 1e-6)
    top = np.array(rgb("#1B2436"), dtype=np.float32)
    bot = np.array(rgb("#2E3B57"), dtype=np.float32)
    t = field[..., None]
    arr = top * (1 - t) + bot * t
    alpha = np.full((n, n, 1), 255.0)
    img = Image.fromarray(np.concatenate([arr, alpha], axis=2).astype(np.uint8), "RGBA")
    return img


def loading_bar(w: int, h: int, kind: str) -> Image.Image:
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    r = h * 0.5 * SS
    if kind == "bg":
        d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=r, fill=(28, 30, 42, 220),
                            outline=(255, 255, 255, 40), width=max(2, SS * 2))
    else:
        d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=r, fill=rgb(ACCENT) + (255,))
    return finish(img, w, h)


# --------------------------------------------------------------------------- #
# audio synthesis
# --------------------------------------------------------------------------- #
def t_axis(dur: float) -> np.ndarray:
    return np.linspace(0, dur, int(SR * dur), endpoint=False, dtype=np.float32)


def adsr(n: int, a=0.005, d=0.08, s=0.55, r=0.12) -> np.ndarray:
    env = np.ones(n, dtype=np.float32) * s
    ai = max(1, int(a * SR))
    di = max(1, int(d * SR))
    ri = max(1, int(r * SR))
    ai, di, ri = min(ai, n), min(di, n), min(ri, n)
    env[:ai] = np.linspace(0, 1, ai)
    if ai + di < n:
        env[ai:ai + di] = np.linspace(1, s, di)
    env[n - ri:] *= np.linspace(1, 0, ri)
    return env


def sine(f, dur, phase=0.0):
    t = t_axis(dur)
    return np.sin(2 * np.pi * f * t + phase).astype(np.float32)


def sweep(f0, f1, dur, kind="sine"):
    t = t_axis(dur)
    k = (f1 / max(f0, 1e-6)) ** (1 / max(len(t) - 1, 1))
    phase = 2 * np.pi * f0 * np.cumsum(k ** np.arange(len(t))) / SR
    return np.sin(phase).astype(np.float32)


def noise(dur, seed=0):
    rng = np.random.default_rng(seed)
    return rng.standard_normal(int(SR * dur)).astype(np.float32) * 0.5


def lowpass(x, cutoff=0.2):
    """One-pole low-pass; cutoff is the smoothing coefficient (0-1)."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += cutoff * (x[i] - acc)
        y[i] = acc
    return y


def lp_fast(x, k=0.2):
    """Vectorised-ish one-pole using cumulative filtering via convolution."""
    taps = np.exp(-np.arange(0, 200) * (1.0 / max(k, 1e-3) * 0.12)).astype(np.float32)
    taps /= taps.sum()
    return np.convolve(x, taps, mode="same").astype(np.float32)


def hp_fast(x, k=0.2):
    return (x - lp_fast(x, k)).astype(np.float32)


def bell(freq, dur, partials=((1, 1.0), (2.01, 0.45), (3.02, 0.2))):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for mult, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t * (3.0 + mult))
    return out.astype(np.float32)


def normalise(x, peak=0.85):
    m = np.max(np.abs(x)) if len(x) else 0
    if m < 1e-9:
        return x
    return (x / m * peak).astype(np.float32)


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def sfx_table() -> dict[str, np.ndarray]:
    """Every entry of the 43-item catalogue in 06_AUDIO_AND_SOUND_DESIGN.md."""
    out: dict[str, np.ndarray] = {}

    # 1 cannon rotate loop
    t = t_axis(0.4)
    out["sfx_cannon_rotate"] = normalise(
        (np.sin(2 * np.pi * 180 * t) * 0.2 + lp_fast(noise(0.4, 1), 0.08) * 0.4)
        * adsr(len(t), 0.02, 0.05, 0.8, 0.05), 0.4)
    # 2 aim lock
    out["sfx_aim_lock"] = normalise(bell(1800, 0.08) * adsr(int(SR * 0.08)), 0.35)
    # 3 shot
    whoosh = lp_fast(noise(0.25, 2), 0.35) * np.linspace(1, 0.05, int(SR * 0.25)) ** 1.6
    thump = sine(140, 0.25) * np.exp(-t_axis(0.25) * 26)
    out["sfx_shot"] = normalise(whoosh * 0.9 + thump * 0.5, 0.8)
    # 4 wall bounce
    out["sfx_wall_bounce"] = normalise(bell(760, 0.12) * adsr(int(SR * 0.12), 0.002, 0.03, 0.3, 0.05), 0.5)
    # 5 snap
    out["sfx_snap"] = normalise(bell(1200, 0.09) * adsr(int(SR * 0.09), 0.001, 0.02, 0.25, 0.03), 0.45)

    # 6-10 pop ladder: two semitones apart
    for i in range(5):
        f = 520 * (2 ** (2 * i / 12))
        d = 0.18
        t = t_axis(d)
        body = np.sin(2 * np.pi * f * np.exp(-t * 7) * t) * np.exp(-t * 22)
        click = lp_fast(noise(d, 10 + i), 0.5) * np.exp(-t * 90) * 0.5
        out[f"sfx_pop_{i + 1:02d}"] = normalise(body + click, 0.72)

    # 11 cluster big
    parts = [normalise(sweep(300, 900, 0.5) * adsr(int(SR * 0.5), 0.01, 0.2, 0.5, 0.2), 0.5)]
    for i, f in enumerate((660, 880, 1100)):
        parts.append(bell(f, 0.5) * 0.35)
    out["sfx_cluster_big"] = normalise(np.sum([p[: int(SR * 0.5)] for p in parts], axis=0), 0.85)

    # 12 drop start / 13 drop land
    out["sfx_drop_start"] = normalise(
        lp_fast(noise(0.3, 20), 0.12) * np.linspace(0.2, 1, int(SR * 0.3)) ** 2, 0.45)
    out["sfx_drop_land"] = normalise(bell(220, 0.15) * 0.7 + lp_fast(noise(0.15, 21), 0.2) * 0.4, 0.4)
    # 14 ceiling drop
    t = t_axis(0.6)
    out["sfx_ceiling_drop"] = normalise(
        (sine(70, 0.6) * np.exp(-t * 4) + lp_fast(noise(0.6, 22), 0.05) * 0.6)
        * adsr(int(SR * 0.6), 0.01, 0.3, 0.4, 0.2), 0.8)
    # 15-19 boosters
    t = t_axis(0.7)
    out["sfx_booster_bomb"] = normalise(
        lp_fast(noise(0.7, 30), 0.25) * np.exp(-t * 5) + sine(60, 0.7) * np.exp(-t * 6) * 0.8, 0.9)
    t = t_axis(0.8)
    rain = np.zeros_like(t)
    for i, f in enumerate((440, 554, 659, 880, 1109)):
        rain += np.sin(2 * np.pi * f * t) * np.exp(-((t - i * 0.11) ** 2) * 220)
    out["sfx_booster_rainbow"] = normalise(rain, 0.75)
    out["sfx_booster_laser"] = normalise(
        hp_fast(sweep(2400, 600, 0.3) * adsr(int(SR * 0.3), 0.002, 0.05, 0.6, 0.1), 0.4), 0.6)
    out["sfx_booster_swap"] = normalise(
        np.concatenate([bell(720, 0.1), bell(960, 0.1)])[: int(SR * 0.2)] * 0.8, 0.55)
    out["sfx_booster_extra_moves"] = normalise(
        np.sum([bell(1200 + i * 160, 0.4) * (0.6 - i * 0.08) for i in range(4)], axis=0), 0.6)
    # 20-23 UI
    out["sfx_ui_click"] = normalise(bell(2000, 0.06) * adsr(int(SR * 0.06), 0.001, 0.01, 0.2, 0.02), 0.3)
    out["sfx_ui_back"] = normalise(bell(1400, 0.08) * 0.7 + bell(1000, 0.08) * 0.5, 0.32)
    out["sfx_popup_open"] = normalise(
        lp_fast(noise(0.25, 40), 0.3) * np.linspace(0, 1, int(SR * 0.25)) ** 2
        + bell(880, 0.25) * 0.4, 0.5)
    out["sfx_popup_close"] = normalise(
        lp_fast(noise(0.18, 41), 0.3) * np.linspace(1, 0, int(SR * 0.18)) ** 2, 0.45)
    # 24-27 coins and stars
    out["sfx_coin_tick"] = normalise(bell(2400, 0.04), 0.25)
    for i, f in enumerate((784, 988, 1319)):
        out[f"sfx_star_{i + 1:02d}"] = normalise(bell(f, 0.5 + i * 0.2), 0.65)
    # 28-29 win/lose
    notes = [523, 659, 784, 1047]
    win = np.zeros(int(SR * 1.8), dtype=np.float32)
    for i, f in enumerate(notes):
        seg = bell(f, 0.9) * (0.9 - i * 0.1)
        start = int(i * 0.14 * SR)
        win[start:start + len(seg)] += seg[: max(0, len(win) - start)]
    out["sfx_level_win"] = normalise(win, 0.8)
    lose = np.zeros(int(SR * 1.4), dtype=np.float32)
    for i, f in enumerate((392, 330, 262)):
        seg = bell(f, 0.7) * (0.9 - i * 0.15)
        start = int(i * 0.22 * SR)
        lose[start:start + len(seg)] += seg[: max(0, len(lose) - start)]
    out["sfx_level_fail"] = normalise(lose, 0.7)
    # 30-31 lives
    out["sfx_lives_empty"] = normalise(sine(180, 1.0) * np.exp(-t_axis(1.0) * 3.2), 0.55)
    out["sfx_life_refill"] = normalise(bell(880, 0.5) * 0.7 + bell(1320, 0.5) * 0.4, 0.6)
    # 32-33 spin
    out["sfx_spin_tick"] = normalise(bell(1600, 0.05) * adsr(int(SR * 0.05), 0.001, 0.01, 0.2, 0.02), 0.28)
    out["sfx_spin_win"] = out["sfx_level_win"]
    # 34-37 economy
    out["sfx_piggy_fill"] = normalise(bell(900, 0.15) * 0.8 + lp_fast(noise(0.15, 50), 0.4) * 0.2, 0.4)
    out["sfx_purchase_success"] = normalise(
        np.concatenate([bell(880, 0.25), bell(1174, 0.5)])[: int(SR * 0.75)], 0.65)
    out["sfx_purchase_fail"] = normalise(bell(330, 0.6) * 0.7 + bell(311, 0.6) * 0.5, 0.45)
    out["sfx_ad_reward"] = normalise(
        np.concatenate([bell(1046, 0.2), bell(1318, 0.3)])[: int(SR * 0.5)], 0.62)
    # 38-43 misc
    out["sfx_countdown"] = normalise(bell(880, 0.1), 0.4)
    out["sfx_blocker_crack"] = normalise(lp_fast(noise(0.2, 60), 0.6) * np.exp(-t_axis(0.2) * 18), 0.5)
    out["sfx_blocker_break"] = normalise(
        hp_fast(noise(0.35, 61), 0.5) * np.exp(-t_axis(0.35) * 9), 0.6)
    out["sfx_chain_break"] = normalise(bell(520, 0.4) * 0.6 + hp_fast(noise(0.4, 62), 0.6) * 0.5, 0.55)
    out["sfx_tutorial_point"] = normalise(bell(1320, 0.1), 0.35)
    t = t_axis(2.0)
    out["sfx_tension_layer"] = normalise(
        (np.sin(2 * np.pi * 110 * t) + 0.5 * np.sin(2 * np.pi * 165 * t))
        * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t)), 0.45)
    return out


def music_loop(kind: str) -> np.ndarray:
    """A short seamless loop: chord bed + arpeggio + light percussion."""
    tempo = {"map": 96, "game": 108, "tension": 108}[kind]
    bars, beats_per_bar = 8, 4
    beat = 60.0 / tempo
    total = bars * beats_per_bar * beat
    n = int(SR * total)
    out = np.zeros(n, dtype=np.float32)
    t_all = np.arange(n) / SR

    roots = {"map": [220, 174.6, 196, 164.8], "game": [261.6, 220, 233, 196],
             "tension": [110, 110, 116.5, 103.8]}[kind]

    # chord bed
    for b in range(bars):
        root = roots[b % len(roots)]
        start = int(b * beats_per_bar * beat * SR)
        length = int(beats_per_bar * beat * SR)
        seg_t = np.arange(length) / SR
        env = np.minimum(1, np.minimum(seg_t / 0.05, (length / SR - seg_t) / 0.08))
        for mult, amp in ((1, 0.30), (1.5, 0.16), (2, 0.12), (2.5, 0.06)):
            seg = np.sin(2 * np.pi * root * mult * seg_t) * amp
            out[start:start + length] += seg * env

    # arpeggio
    pattern = [1, 1.25, 1.5, 2, 1.5, 1.25]
    step = beat / 2
    for i in range(int(total / step)):
        root = roots[int(i * step / (beats_per_bar * beat)) % len(roots)]
        f = root * 2 * pattern[i % len(pattern)]
        start = int(i * step * SR)
        dur = 0.35
        seg_t = np.arange(int(SR * dur)) / SR
        seg = np.sin(2 * np.pi * f * seg_t) * np.exp(-seg_t * 9) * 0.13
        end = min(start + len(seg), n)
        out[start:end] += seg[: end - start]

    # percussion (game and tension only)
    if kind != "map":
        for i in range(int(total / beat)):
            start = int(i * beat * SR)
            dur = 0.12 if i % 2 == 0 else 0.06
            seg_t = np.arange(int(SR * dur)) / SR
            if i % 2 == 0:
                seg = np.sin(2 * np.pi * 60 * seg_t) * np.exp(-seg_t * 22) * 0.25
            else:
                seg = np.random.default_rng(i).standard_normal(len(seg_t)).astype(np.float32) \
                    * np.exp(-seg_t * 40) * 0.08
            end = min(start + len(seg), n)
            out[start:end] += seg[: end - start]

    out = normalise(out, 0.7)
    # click-free loop seam
    fade = int(0.02 * SR)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def contact_sheet(out_dir: Path) -> None:
    tiles = []
    for name, hexcol, emblem in BUBBLES:
        tiles.append(sphere(96, rgb(hexcol), emblem))
    tiles.append(booster_icon(96, "bomb"))
    tiles.append(booster_icon(96, "rainbow"))
    tiles.append(ice_overlay(96, 1))
    tiles.append(stone(96))
    tiles.append(chain_overlay(96))
    tiles.append(cage_overlay(96))
    tiles.append(cloud_overlay(96))
    tiles.append(map_node(96, "current", 2))
    tiles.append(map_node(96, "done3", 3))
    tiles.append(map_node(96, "locked"))
    for k in ("coin", "heart", "star_on", "gem", "pause", "settings", "spin", "piggy"):
        tiles.append(hud_icon(96, k))
    for i, img in enumerate(pop_frames(96, rgb(BUBBLES[0][1]))):
        if i % 2 == 0:
            tiles.append(img)

    cols = 8
    cell = 104
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (24, 26, 34, 255))
    for i, img in enumerate(tiles):
        x = (i % cols) * cell + 4
        y = (i // cols) * cell + 4
        sheet.alpha_composite(img, (x, y))
    save(sheet, out_dir / "_contact_sheet.png")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="generated_assets")
    ap.add_argument("--ogg", action="store_true", help="also convert audio to ogg via ffmpeg")
    args = ap.parse_args()
    out = Path(args.out)
    manifest: list[dict] = []

    def record(path: Path, kind: str, **extra) -> None:
        entry = {"path": str(path.relative_to(out)), "kind": kind,
                 "bytes": path.stat().st_size}
        entry.update(extra)
        manifest.append(entry)

    # ---- bubbles
    for name, hexcol, emblem in BUBBLES:
        p = out / "bubbles" / f"bubble_{name}_idle.png"
        save(sphere(96, rgb(hexcol), emblem), p)
        record(p, "sprite", w=96, h=96)
        p = out / "bubbles" / f"bubble_{name}_plain.png"
        save(sphere(96, rgb(hexcol)), p)
        record(p, "sprite", w=96, h=96)
        frames = pop_frames(96, rgb(hexcol), seed=hash(name) % 1000)
        for i, fr in enumerate(frames):
            p = out / "bubbles" / "pop" / f"bubble_{name}_pop_{i:02d}.png"
            save(fr, p)
            record(p, "sprite", w=96, h=96, frame=i)
    p = out / "bubbles" / "bubble_ghost.png"
    save(sphere(96, (255, 255, 255), None, alpha=0.4), p)
    record(p, "sprite", w=96, h=96)

    # ---- blockers
    for stage in (1, 2, 3):
        p = out / "blockers" / f"blocker_ice_{stage:02d}.png"
        save(ice_overlay(96, stage, seed=stage), p)
        record(p, "sprite", w=96, h=96)
    for name, img in (("blocker_stone", stone(96)), ("blocker_chain", chain_overlay(112)),
                      ("blocker_cage", cage_overlay(112)), ("blocker_cloud", cloud_overlay(96)),
                      ("blocker_morph_ring", morph_ring(112))):
        p = out / "blockers" / f"{name}.png"
        save(img, p)
        record(p, "sprite", w=img.width, h=img.height)

    # ---- boosters
    for kind in ("bomb", "rainbow", "laser", "swap", "extra_moves", "continue"):
        p = out / "boosters" / f"booster_{kind}.png"
        save(booster_icon(128, kind), p)
        record(p, "sprite", w=128, h=128)
    p = out / "boosters" / "booster_slot_empty.png"
    img = rounded_panel(132, 132, fill=(255, 255, 255, 18), radius=0.22,
                        outline=(255, 255, 255, 70))
    save(img, p)
    record(p, "sprite", w=132, h=132)

    # ---- fx
    for i, fr in enumerate(pop_frames(128, rgb(ACCENT), seed=99)):
        p = out / "fx" / "pop" / f"fx_pop_{i:02d}.png"
        save(fr, p)
        record(p, "sprite", w=128, h=128, frame=i)
    p = out / "fx" / "fx_star.png"
    save(star_particle(64, rgb(ACCENT)), p)
    record(p, "sprite", w=64, h=64)
    p = out / "fx" / "fx_shockwave.png"
    save(shockwave(256), p)
    record(p, "sprite", w=256, h=256)
    p = out / "fx" / "fx_laser_beam.png"
    save(laser_beam(64, 256), p)
    record(p, "sprite", w=64, h=256)
    p = out / "fx" / "fx_particle_dot.png"
    dot = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(dot)
    d.ellipse([2, 2, 30, 30], fill=(255, 255, 255, 235))
    dot = dot.filter(ImageFilter.GaussianBlur(2))
    save(dot, p)
    record(p, "sprite", w=32, h=32)

    # ---- ui
    for state in ("normal", "pressed", "disabled"):
        p = out / "ui" / f"btn_primary_{state}.png"
        save(button(240, 96, state), p)
        record(p, "sprite", w=240, h=96, nine_slice=True)
        p = out / "ui" / f"btn_secondary_{state}.png"
        save(button(240, 96, state, hue="#2D9CDB"), p)
        record(p, "sprite", w=240, h=96, nine_slice=True)
    p = out / "ui" / "pill_hud.png"
    save(rounded_panel(240, 84, fill=(18, 20, 30, 210), radius=0.5), p)
    record(p, "sprite", w=240, h=84, nine_slice=True)
    p = out / "ui" / "popup_frame.png"
    save(rounded_panel(720, 900, fill=(28, 30, 42, 246), radius=0.06), p)
    record(p, "sprite", w=720, h=900, nine_slice=True)
    p = out / "ui" / "popup_ribbon.png"
    save(rounded_panel(480, 110, fill=rgb(ACCENT) + (255,), radius=0.4), p)
    record(p, "sprite", w=480, h=110, nine_slice=True)
    p = out / "ui" / "popup_scrim.png"
    scrim = Image.new("RGBA", (64, 64), (0, 0, 0, 153))
    save(scrim, p)
    record(p, "sprite", w=64, h=64, nine_slice=True)
    for kind in ("bg", "fill"):
        p = out / "ui" / f"progress_{kind}.png"
        save(loading_bar(600, 24, kind), p)
        record(p, "sprite", w=600, h=24, nine_slice=True)
    p = out / "ui" / "loading_logo_plate.png"
    save(rounded_panel(520, 200, fill=(24, 26, 38, 220), radius=0.14), p)
    record(p, "sprite", w=520, h=200)

    # ---- hud icons
    for kind in ("coin", "heart", "star_on", "star_off", "gem", "pause", "settings",
                 "sound_on", "sound_off", "music_on", "spin", "piggy", "shop", "gift",
                 "lock", "close", "play"):
        for size in (96, 64):
            p = out / "hud" / f"icon_{kind}_{size}.png"
            save(hud_icon(size, kind), p)
            record(p, "sprite", w=size, h=size)

    # ---- cannon
    p = out / "cannon" / "cannon_base.png"
    save(cannon_base(), p)
    record(p, "sprite", w=220, h=180)
    p = out / "cannon" / "cannon_barrel.png"
    save(cannon_barrel(), p)
    record(p, "sprite", w=120, h=200, pivot="bottom-centre")

    # ---- map
    for state, stars in (("locked", 0), ("current", 0), ("done", 1), ("done3", 3)):
        p = out / "map" / f"map_node_{state}.png"
        save(map_node(128, state, stars), p)
        record(p, "sprite", w=128, h=128)
    p = out / "map" / "map_bg_tile.png"
    save(map_tile(512), p)
    record(p, "sprite", w=512, h=512, seamless=True)

    # ---- audio
    sfx = sfx_table()
    for name, data in sfx.items():
        p = out / "audio" / "sfx" / f"{name}.wav"
        write_wav(p, data)
        record(p, "audio", duration=round(len(data) / SR, 3))
    for kind in ("map", "game", "tension"):
        data = music_loop(kind)
        p = out / "audio" / "music" / f"bgm_{kind}.wav"
        write_wav(p, data)
        record(p, "audio", duration=round(len(data) / SR, 3), loop=True)

    # ---- optional ogg
    ogg_ok = False
    if args.ogg:
        try:
            subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
            ogg_ok = True
        except Exception:
            print("ffmpeg not found - keeping .wav only")
        if ogg_ok:
            for wav in sorted((out / "audio").rglob("*.wav")):
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                                "-c:a", "libvorbis", "-q:a", "5", str(wav.with_suffix(".ogg"))],
                               check=False)

    # ---- manifest, credits, contact sheet
    (out / "manifest.json").write_text(json.dumps({
        "generated_by": "scripts/generate_original_assets.py",
        "origin": "100% procedurally generated; no third-party art, audio or fonts",
        "license": "yours - generated for this project, no attribution required",
        "counts": {
            "sprites": sum(1 for m in manifest if m["kind"] == "sprite"),
            "audio": sum(1 for m in manifest if m["kind"] == "audio"),
            "total": len(manifest),
        },
        "files": manifest,
    }, indent=2), encoding="utf-8")

    (out / "ASSET_CREDITS.md").write_text(
        "# Asset credits\n\n"
        "Every file in this pack was generated by `scripts/generate_original_assets.py` "
        "from the specifications in this repository. No third-party artwork, audio, font or "
        "other asset is included, and nothing here is derived from any other game's files.\n\n"
        "You own the output. No attribution is required. Keep this file with the pack as the "
        "provenance record - if a store reviewer or a rights-holder ever asks where the art came "
        "from, this is the answer.\n\n"
        f"Generated: {len(manifest)} files "
        f"({sum(1 for m in manifest if m['kind'] == 'sprite')} images, "
        f"{sum(1 for m in manifest if m['kind'] == 'audio')} audio).\n",
        encoding="utf-8")

    contact_sheet(out)

    print(json.dumps({"out": str(out), "files": len(manifest),
                      "sprites": sum(1 for m in manifest if m["kind"] == "sprite"),
                      "audio": sum(1 for m in manifest if m["kind"] == "audio"),
                      "ogg": ogg_ok}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
