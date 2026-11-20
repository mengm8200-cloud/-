#!/usr/bin/env python3
"""Render a motion-storyboard preview (动态分镜预览) for an episode.

    python3 tools/animatic.py ep01                  # -> ep01/animatic.mp4
    python3 tools/animatic.py ep01 --sheet out.png  # one frame per clip, for checking

There is no AI footage here and no characters: every clip is drawn with simple
procedural effects (rain, golden light, the ring of black orbs, the black crack,
frozen rain), its description and timed subtitles, over procedurally generated
ambience. Timing comes from storyboard.json, so it lines up with subtitles.srt.
"""
from __future__ import annotations

import math
import os
import subprocess
import sys
import wave
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import ROOT, layout, tc, validate  # noqa: E402

import json  # noqa: E402

W, H, FPS, SR = 1280, 720, 24, 48000
M = 48  # background margin for shake and parallax
GOLD = (242, 182, 64)
GOLD_HI = (255, 228, 150)
WHITE = (255, 255, 255)

FONT_CANDIDATES = [
    os.environ.get("ANIMATIC_FONT", ""),
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "C:/Windows/Fonts/msyh.ttc",
]


# ------------------------------------------------------------------ basics

def font_path() -> str:
    for p in FONT_CANDIDATES:
        if p and Path(p).exists():
            return p
    sys.exit("找不到中文字体，请用 ANIMATIC_FONT=字体文件路径 指定")


@lru_cache(None)
def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path(), size)


def ease(x: float) -> float:
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def smooth(a: float, b: float, x: float) -> float:
    return ease((x - a) / (b - a)) if b != a else float(x >= b)


def lerp(a, b, k):
    return a + (b - a) * k


@lru_cache(maxsize=256)
def _glow(radius: int, color: tuple, power: float, level: int) -> Image.Image:
    r = max(2, radius)
    y, x = np.ogrid[-r:r, -r:r]
    d = np.sqrt(x * x + y * y) / r
    a = np.clip(1.0 - d, 0, 1) ** power * (level / 20.0)
    arr = np.empty((2 * r, 2 * r, 4), np.uint8)
    arr[..., :3] = color
    arr[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def comp(frame: Image.Image, sprite: Image.Image, cx: float, cy: float) -> None:
    sw, sh = sprite.size
    x0, y0 = int(cx - sw / 2), int(cy - sh / 2)
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(sw, W - x0), min(sh, H - y0)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    frame.alpha_composite(sprite, dest=(x0 + sx0, y0 + sy0), source=(sx0, sy0, sx1, sy1))


def glow(frame, cx, cy, radius, color, strength=1.0, power=2.0):
    level = int(round(min(1.0, max(0.0, strength)) * 20))
    if level <= 0 or radius < 2:
        return
    r = int(radius) if radius < 48 else int(round(radius / 8.0) * 8)
    comp(frame, _glow(r, tuple(color), power, level), cx, cy)


def layer():
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return ov, ImageDraw.Draw(ov)


def gline(dr, pts, color, width, alpha=255):
    """A line with a soft halo: wide faint passes under a bright core."""
    for w_mul, a_mul in ((5.0, 0.12), (2.4, 0.3), (1.0, 1.0)):
        dr.line(pts, fill=color + (int(alpha * a_mul),), width=max(1, int(width * w_mul)), joint="curve")


# ------------------------------------------------------------------ backgrounds

def _grad(w, h, stops):
    ys = np.linspace(0.0, 1.0, h)
    pos = [p for p, _ in stops]
    out = np.empty((h, w, 3), np.float32)
    for i in range(3):
        out[..., i] = np.interp(ys, pos, [c[i] for _, c in stops])[:, None]
    return out


def _img(arr, rng, grain=2.5):
    arr = arr + rng.normal(0, grain, arr.shape[:2])[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def bg_dusk(rng, figure=False):
    w, h = W + 2 * M, H + 2 * M
    a = _grad(w, h, [(0, (34, 32, 54)), (0.40, (104, 62, 62)), (0.60, (206, 122, 62)),
                     (0.655, (150, 86, 52)), (0.66, (70, 46, 38)), (1.0, (28, 22, 20))])
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - w * 0.62) ** 2 + ((yy - h * 0.60) * 1.3) ** 2)
    a += (np.clip(1 - d / 420, 0, 1) ** 2.2)[..., None] * np.array([90, 60, 20], np.float32)
    img = _img(a, rng, 3.0)
    dr = ImageDraw.Draw(img)
    hz = int(h * 0.66)
    pts = [(0, hz)] + [(x, hz + int(rng.integers(-6, 6))) for x in range(0, w + 40, 40)] + [(w, h), (0, h)]
    dr.polygon(pts, fill=(40, 30, 27))
    for _ in range(9):
        cx, cy = int(rng.integers(0, w)), int(rng.integers(hz + 20, h))
        rx = int(rng.integers(60, 200))
        ry = rx // 5
        dr.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(30, 23, 21))
        dr.arc([cx - rx, cy - ry, cx + rx, cy + ry], 180, 360, fill=(74, 52, 42), width=2)
    for _ in range(28):
        x, y = int(rng.integers(0, w)), int(rng.integers(hz + 10, h - 10))
        length = rng.integers(14, 40) * (0.6 + (y - hz) / (h - hz))
        ang = math.radians(rng.uniform(-25, 25))
        dr.line([(x, y), (x + length * math.sin(ang), y - length * math.cos(ang))], fill=(18, 14, 13), width=2)
    if figure:  # a tiny lone silhouette on the horizon
        fx, fy = w * 0.5, hz + 4
        dr.ellipse([fx - 4, fy - 30, fx + 4, fy - 22], fill=(16, 12, 12))
        dr.polygon([(fx - 6, fy - 22), (fx + 6, fy - 22), (fx + 5, fy), (fx - 5, fy)], fill=(16, 12, 12))
        for k in range(7):  # spiky hair
            ang = math.radians(-160 + k * 23)
            dr.line([(fx, fy - 27), (fx + 7 * math.cos(ang), fy - 27 + 7 * math.sin(ang))], fill=(16, 12, 12), width=2)
    return img


SHAFTS = (0.30, 0.52, 0.72)


def bg_tunnel(rng):
    w, h = W + 2 * M, H + 2 * M
    a = _grad(w, h, [(0, (16, 22, 30)), (0.5, (30, 40, 52)), (0.74, (22, 30, 40)),
                     (0.75, (34, 46, 60)), (1, (14, 19, 26))])
    yy, xx = np.mgrid[0:h, 0:w]
    vx, vy = w * 0.5, h * 0.52
    d = np.sqrt((xx - vx) ** 2 + ((yy - vy) * 1.6) ** 2)
    a *= (0.5 + 0.5 * np.clip(d / 520, 0, 1))[..., None]
    img = _img(a, rng)
    dr = ImageDraw.Draw(img, "RGBA")
    for i, s in enumerate([1.25, 0.95, 0.7, 0.5, 0.34, 0.22]):
        rx, ry = w * 0.62 * s, h * 0.78 * s
        dr.arc([vx - rx, vy - ry, vx + rx, vy + ry * 0.55], 180, 360,
               fill=(70, 88, 104, 120 - i * 14), width=max(2, int(10 * s)))
    for side in (-1, 1):
        for k in range(5):
            dr.line([(vx + side * w * 0.62, h * 0.18 + k * h * 0.12),
                     (vx + side * w * 0.08, vy - h * 0.03 + k * h * 0.012)],
                    fill=(54, 70, 84, 150), width=max(2, 9 - k))
        for k in range(3):
            x = vx + side * (w * 0.42 + k * 46)
            dr.rectangle([x - 9, 0, x + 9, h * 0.80], fill=(28, 36, 46, 255))
            dr.line([(x - 4, 0), (x - 4, h * 0.80)], fill=(70, 86, 100, 120), width=2)
    for _ in range(40):
        y, x, length = rng.uniform(h * 0.76, h), rng.uniform(0, w), rng.uniform(30, 160)
        dr.line([(x, y), (x + length, y)], fill=(110, 130, 150, int(rng.uniform(20, 60))), width=1)
    for gx in SHAFTS:
        x = w * gx
        dr.polygon([(x - 30, 0), (x + 30, 0), (x + 90, h * 0.78), (x - 70, h * 0.78)], fill=(150, 175, 200, 18))
        dr.rectangle([x - 34, 0, x + 34, 10], fill=(90, 110, 128, 200))
    return img


def bg_skyline(rng):
    w, h = W + 2 * M, H + 2 * M
    a = _grad(w, h, [(0, (52, 62, 74)), (0.55, (104, 116, 128)), (0.80, (70, 80, 92)), (1, (34, 40, 48))])
    img = _img(a, rng)
    dr = ImageDraw.Draw(img, "RGBA")
    for _ in range(14):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h * 0.25)
        rx, ry = rng.uniform(120, 300), rng.uniform(20, 50)
        dr.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(40, 48, 58, 60))
    x = -20.0
    while x < w:
        tw, th = rng.uniform(40, 90), rng.uniform(h * 0.25, h * 0.5)
        dr.rectangle([x, h * 0.82 - th, x + tw, h], fill=(84, 95, 107, 255))
        x += tw + rng.uniform(4, 20)
    x = -30.0
    target_x = M + W * 0.82
    while x < w:
        tw, th = rng.uniform(90, 170), rng.uniform(h * 0.45, h * 0.8)
        if x < target_x < x + tw + 80:  # leave room for the target tower
            x = target_x + 90
            continue
        top = h * 0.9 - th
        _tower(dr, x, top, tw, h)
        x += tw + rng.uniform(30, 80)
    _tower(dr, target_x - 75, M + H * 0.16, 150, h)
    dr.polygon([(0, h), (0, h * 0.86), (w * 0.2, h * 0.9), (w * 0.45, h * 0.84), (w * 0.7, h * 0.92),
                (w, h * 0.87), (w, h)], fill=(22, 27, 34, 255))
    return img


def _tower(dr, x, top, tw, h):
    dr.rectangle([x, top, x + tw, h], fill=(40, 48, 58, 255))
    for k in range(int(tw // 22)):
        px = x + 10 + k * 22
        dr.line([(px, top + 10), (px, h)], fill=(62, 74, 86, 255), width=4)
    yb = top + 30
    while yb < h:
        dr.line([(x, yb), (x + tw, yb)], fill=(30, 36, 44, 255), width=3)
        yb += 46
    dr.rectangle([x + tw * 0.45, top - 30, x + tw * 0.55, top], fill=(40, 48, 58, 255))


def bg_vision(rng):
    a = _grad(W, H, [(0, (128, 176, 222)), (0.55, (236, 214, 172)), (0.62, (214, 186, 140)), (1, (120, 112, 86))])
    img = _img(a, rng, 2.0).convert("RGBA")
    glow(img, W * 0.3, H * 0.42, 220, (255, 244, 210), 0.8)
    dr = ImageDraw.Draw(img, "RGBA")
    dr.polygon([(W * 0.48, H * 0.62), (W * 0.52, H * 0.30), (W * 0.62, H * 0.24), (W * 0.78, H * 0.26),
                (W * 0.86, H * 0.36), (W * 0.9, H * 0.62)], fill=(150, 128, 110, 255))
    for k in range(4):
        y = H * (0.34 + k * 0.06)
        dr.line([(W * 0.55, y), (W * 0.84, y + 6)], fill=(128, 108, 92, 255), width=3)
    for y, s, col in ((H * 0.66, 26, (176, 96, 70)), (H * 0.74, 34, (160, 82, 60)), (H * 0.84, 44, (140, 70, 52))):
        x = rng.uniform(-20, 0)
        while x < W:
            ww = s * rng.uniform(1.4, 2.4)
            dr.rectangle([x + ww * 0.12, y, x + ww * 0.88, y + s * 0.7], fill=(226, 210, 180, 255))
            dr.polygon([(x, y), (x + ww * 0.5, y - s * 0.6), (x + ww, y)], fill=col + (255,))
            x += ww + rng.uniform(4, 16)
    for _ in range(30):
        x, y, r = rng.uniform(0, W), rng.uniform(H * 0.6, H * 0.95), rng.uniform(10, 26)
        dr.ellipse([x - r, y - r, x + r, y + r * 0.8], fill=(70, 120, 70, 230))
    return img


def crack_frame(rng):
    """Black frame with a jagged lens-shaped window, for the vision in 7E."""
    pts = []
    for k in range(64):
        th = 2 * math.pi * k / 64
        jitter = 1 + rng.uniform(-0.07, 0.07)
        pts.append((W / 2 + W * 0.38 * math.cos(th) * jitter, H / 2 + H * 0.42 * math.sin(th) * jitter))
    mask = Image.new("L", (W, H), 255)
    ImageDraw.Draw(mask).polygon(pts, fill=0)
    fr = Image.new("RGBA", (W, H), (4, 4, 8, 255))
    fr.putalpha(mask)
    dr = ImageDraw.Draw(fr)
    gline(dr, pts + [pts[0]], (235, 240, 255), 2.0, 220)
    return fr


def make_crack(rng):
    segs, trunk = [], []

    def branch(x, y, ang, length, width, dist, depth):
        nonlocal trunk
        for _ in range(int(length // 22)):
            ang = min(math.radians(160), max(math.radians(20), ang + rng.normal(0, 0.35)))
            nx, ny = x + 22 * math.cos(ang), y + 22 * math.sin(ang)
            segs.append((x, y, nx, ny, dist, dist + 22, width))
            if depth == 0:
                trunk.append((nx, ny))
            x, y, dist = nx, ny, dist + 22
            if depth < 2 and rng.random() < 0.12:
                branch(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), length * 0.35,
                       max(1.0, width * 0.6), dist, depth + 1)
            width = max(1.0, width * 0.985)

    trunk.append((W * 0.56, -20.0))
    branch(W * 0.56, -20.0, math.radians(95), H * 0.62, 5.0, 0.0, 0)
    return segs, trunk


def draw_crack(dr, segs, maxd, progress=1.0, scale=1.0, focus=(0.0, 0.0), glow_k=1.0):
    lim = progress * maxd
    fx, fy = focus
    vis = []
    for (x0, y0, x1, y1, d0, d1, w) in segs:
        if d0 > lim:
            continue
        if d1 > lim:
            k = (lim - d0) / (d1 - d0)
            x1, y1 = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        vis.append(((fx + (x0 - fx) * scale, fy + (y0 - fy) * scale),
                    (fx + (x1 - fx) * scale, fy + (y1 - fy) * scale), w * scale))
    for wm, add, a in ((5.0, 8, 26), (2.2, 3, 70)):
        for p0, p1, w in vis:
            dr.line([p0, p1], fill=(235, 240, 255, int(min(255, a * glow_k))), width=int(w * wm + add))
    for p0, p1, w in vis:
        dr.line([p0, p1], fill=(6, 6, 10, 255), width=max(1, int(w)))


# ------------------------------------------------------------------ particles

class Rain:
    def __init__(self, rng, n=320):
        self.n = n
        self.x = rng.uniform(-60, W + 60, n)
        self.y0 = rng.uniform(0, H + 120, n)
        self.v = rng.uniform(900, 1400, n)
        self.len = rng.uniform(14, 34, n)
        self.a = rng.uniform(0.35, 1.0, n)
        self.size = rng.uniform(1.0, 2.0, n)
        self.phase = rng.uniform(0, 6.28, n)

    def ys(self, clock):
        return (self.y0 + self.v * clock) % (H + 120) - 60

    def fall(self, dr, clock, color, alpha, stretch=1.0, every=1, shafts=False, bright=None):
        ys = self.ys(clock)
        for i in range(0, self.n, every):
            x, y = self.x[i], ys[i]
            a = alpha * self.a[i]
            if shafts and any(abs(x - (gx * (W + 2 * M) - M + y * 0.08)) < 40 for gx in SHAFTS):
                a = min(255, a * 2.3)
            if stretch < 0.12:
                s = self.size[i]
                dr.ellipse([x - s, y - s, x + s, y + s], fill=color + (int(a * 1.6),))
            else:
                length = self.len[i] * stretch
                dr.line([(x, y), (x + length * 0.12, y + length)], fill=color + (int(a),), width=1)

    def frozen(self, dr, clock, t, color=(200, 206, 214), gold_at=None, scale=1.0, focus=(0, 0),
               tremble=None, frame=None):
        ys = self.ys(clock)
        fx, fy = focus
        lit = []
        for i in range(self.n):
            x, y = fx + (self.x[i] - fx) * scale, fy + (ys[i] - fy) * scale
            if tremble is not None:
                x += math.sin(t * 40 + self.phase[i]) * tremble
            s = self.size[i] * (0.8 + 0.4 * scale)
            a = 150 * (0.7 + 0.3 * math.sin(t * 1.5 + self.phase[i]))
            c = color
            if gold_at is not None:
                d = math.hypot(x - gold_at[0], y - gold_at[1])
                k = max(0.0, 1 - d / 460)
                if k > 0:
                    c = tuple(int(lerp(color[j], GOLD_HI[j], k)) for j in range(3))
                    a = min(255, a + 100 * k)
                    if k > 0.55:
                        lit.append((x, y, k))
            dr.ellipse([x - s, y - s, x + s, y + s], fill=c + (int(a),))
        if frame is not None:
            for x, y, k in lit[:40]:
                glow(frame, x, y, 12, GOLD, 0.5 * k)


def particles(seed, n, **ranges):
    rng = np.random.default_rng(seed)
    return {k: rng.uniform(lo, hi, n) for k, (lo, hi) in ranges.items()}


# ------------------------------------------------------------------ effects

def gold_presence(frame, t, cx, cy, k=1.0):
    br = 0.85 + 0.15 * math.sin(t * 2.4)
    glow(frame, cx, cy, 340, GOLD, 0.5 * k * br, 2.4)
    glow(frame, cx, cy, 120, GOLD_HI, 0.7 * k * br, 1.8)
    glow(frame, cx, cy, 36, (255, 246, 220), 0.9 * k, 1.5)


def orb_ring(dr, t, cx, cy, rx=150, ry=44, r=15, visible=9, lift=80):
    items = []
    for k in range(9):
        th = 2 * math.pi * k / 9 + t * 0.6
        items.append(((math.sin(th) + 1) / 2, cx + rx * math.cos(th), cy - lift + ry * math.sin(th), k))
    for depth, x, y, k in sorted(items):
        if k >= visible:
            continue
        rr = r * (0.8 + 0.35 * depth)
        dr.ellipse([x - rr - 3, y - rr - 3, x + rr + 3, y + rr + 3], fill=GOLD + (int(90 + 80 * depth),))
        dr.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(8, 8, 12, 255))
        dr.ellipse([x - rr * 0.5, y - rr * 0.6, x - rr * 0.1, y - rr * 0.25], fill=(96, 96, 116, 150))


def purple_eyes(frame, dr, cx, cy, size=1.0, strength=1.0, rings=False):
    for side in (-1, 1):
        x = cx + side * 26 * size
        glow(frame, x, cy, 30 * size, (178, 128, 255), 0.7 * strength)
        if rings:
            r = 26 * size
            dr.ellipse([x - r, cy - r, x + r, cy + r], fill=(206, 182, 240, 255))
            for k in range(1, 4):
                rk = r * (1 - k * 0.22)
                dr.ellipse([x - rk, cy - rk, x + rk, cy + rk], outline=(92, 62, 140, 255), width=max(1, int(2 * size)))
            dr.ellipse([x - 3 * size, cy - 3 * size, x + 3 * size, cy + 3 * size], fill=(60, 36, 100, 255))
            dr.ellipse([x + r * 0.25, cy - r * 0.45, x + r * 0.45, cy - r * 0.25], fill=GOLD_HI + (200,))
        else:
            dr.ellipse([x - 4 * size, cy - 2 * size, x + 4 * size, cy + 2 * size], fill=(236, 220, 255, int(230 * strength)))


def lens(cx, cy, hh, wm, n=40):
    left, right = [], []
    for k in range(n + 1):
        y = cy - hh + 2 * hh * k / n
        u = (y - cy) / hh if hh else 0
        hw = wm * math.sqrt(max(0.0, 1 - u * u))
        left.append((cx - hw, y))
        right.append((cx + hw, y))
    return left + right[::-1]


def rift(frame, dr, t, cx, cy, hh, wm):
    if hh < 2:
        return
    poly = lens(cx, cy, hh, wm)
    dr.polygon(poly, fill=(36, 54, 74, 255))
    for k in range(14):  # rain seen through the rift
        x = cx + (k / 13 - 0.5) * 1.8 * wm
        y = cy - hh + ((t * 700 + k * 97) % (2 * hh))
        u = (y - cy) / hh
        if abs(x - cx) < wm * math.sqrt(max(0.0, 1 - u * u)) * 0.9:
            dr.line([(x, y), (x + 2, y + 18)], fill=(170, 192, 215, 180), width=1)
    gline(dr, poly + [poly[0]], GOLD, 2.2, 230)
    glow(frame, cx, cy, max(40, hh * 0.9), GOLD, 0.35)


def photo_card(rng):
    img = Image.new("RGBA", (380, 270), (236, 230, 218, 255))
    dr = ImageDraw.Draw(img)
    dr.rectangle([16, 16, 364, 254], fill=(176, 150, 112, 255))
    hx, hy = 190, 130
    for k in range(13):  # spiky white hair
        ang = math.radians(-200 + k * 18)
        dr.polygon([(hx + 30 * math.cos(ang - 0.3), hy + 30 * math.sin(ang - 0.3)),
                    (hx + 78 * math.cos(ang), hy + 70 * math.sin(ang) + 30),
                    (hx + 30 * math.cos(ang + 0.3), hy + 30 * math.sin(ang + 0.3))], fill=(232, 228, 220, 255))
    dr.ellipse([hx - 34, hy - 40, hx + 34, hy + 36], fill=(206, 172, 132, 255))
    for side in (-1, 1):
        dr.line([(hx + side * 14, hy - 2), (hx + side * 17, hy + 18)], fill=(170, 60, 50, 255), width=3)
    dr.arc([hx - 18, hy + 6, hx + 18, hy + 26], 10, 170, fill=(120, 80, 60, 255), width=3)
    dr.rectangle([16, 200, 364, 254], fill=(150, 60, 50, 255))
    arr = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:270, 0:380]
    vig = 1 - 0.35 * (((xx - 190) / 190) ** 2 + ((yy - 135) / 135) ** 2)
    arr[16:254, 16:364, :3] *= vig[16:254, 16:364, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def plate_layer(t):
    ov, dr = layer()
    cx, cy = W * 0.5, H * 0.58
    band = []
    for k in range(60):  # cloth band fluttering to the right
        x = cx + 200 + k * 14
        amp = 6 + k * 0.9
        band.append((x, cy - 10 + amp * math.sin(k * 0.45 - t * 7)))
    top = [(x, y - 16) for x, y in band]
    bot = [(x, y + 16) for x, y in band][::-1]
    dr.polygon(top + bot, fill=(26, 26, 30, 255))
    dr.rectangle([cx - 260, cy - 26, cx - 200, cy + 6], fill=(26, 26, 30, 255))
    dr.rounded_rectangle([cx - 210, cy - 75, cx + 210, cy + 75], 14, fill=(148, 150, 156, 255))
    dr.rounded_rectangle([cx - 200, cy - 66, cx + 200, cy - 30], 10, fill=(186, 188, 194, 255))
    for sx in (-185, 185):
        for sy in (-50, 50):
            dr.ellipse([cx + sx - 6, cy + sy - 6, cx + sx + 6, cy + sy + 6], fill=(96, 98, 104, 255))
    dr.line([(cx - 120, cy - 70), (cx - 60, cy - 10), (cx - 80, cy + 30), (cx - 10, cy + 74)], fill=(54, 54, 60, 255), width=3)
    dr.line([(cx + 60, cy - 72), (cx + 90, cy - 20), (cx + 140, cy + 10)], fill=(54, 54, 60, 255), width=2)
    for k in range(12):  # rubble over the lower edge
        x = cx - 260 + k * 48
        dr.polygon([(x, cy + 70), (x + 30, cy + 40 + (k * 13) % 25), (x + 60, cy + 70), (x + 40, cy + 110), (x + 5, cy + 105)],
                   fill=(52, 40, 34, 255))
    return ov


# ------------------------------------------------------------------ text

def wrap(text, f, width):
    lines, cur = [], ""
    for ch in text:
        if f.getlength(cur + ch) > width:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def hud_layer(shot, clip):
    img = Image.new("RGBA", (W, 190), (0, 0, 0, 0))
    a = np.linspace(170, 0, 190).astype(np.uint8)
    shade = np.zeros((190, W, 4), np.uint8)
    shade[..., 3] = a[:, None]
    img = Image.alpha_composite(img, Image.fromarray(shade, "RGBA"))
    dr = ImageDraw.Draw(img)
    dr.text((40, 24), f"镜头 {shot['no']}｜{shot['title']}", font=font(26), fill=(236, 240, 246))
    dr.text((40, 62), f"{clip['id']} · {clip['size']} · {clip['move']} · {tc(clip['start'])}–{tc(clip['end'])}",
            font=font(19), fill=(178, 188, 200))
    f = font(19)
    lines = wrap(clip["visual"], f, W - 80 - 250)
    for i, ln in enumerate(lines[:3]):
        dr.text((40, 96 + i * 27), ln, font=f, fill=(214, 220, 228))
    return img


def sub_layer(line):
    img = Image.new("RGBA", (W, 120), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.text((W / 2, 22), line["who"], font=font(20), fill=GOLD + (255,), anchor="mm",
            stroke_width=2, stroke_fill=(0, 0, 0, 200))
    dr.text((W / 2, 72), line["text"], font=font(38), fill=(255, 255, 255, 255), anchor="mm",
            stroke_width=3, stroke_fill=(0, 0, 0, 255))
    return img


# ------------------------------------------------------------------ renderer

class Renderer:
    def __init__(self, d):
        self.d = d
        rng = np.random.default_rng(20261120)
        self.dusk = bg_dusk(rng)
        self.dusk_fig = bg_dusk(np.random.default_rng(20261120), figure=True)
        self.dusk_blur = Image.eval(self.dusk.filter(ImageFilter.GaussianBlur(9)), lambda v: int(v * 0.72))
        self.tunnel = bg_tunnel(rng)
        self.sky = bg_skyline(rng)
        g = np.asarray(self.sky.convert("L")).astype(np.float32)
        self.sky_gray = Image.fromarray(np.clip(np.stack([g * 0.95, g * 0.98, g * 1.03], -1), 0, 255).astype(np.uint8), "RGB")
        self.vision = bg_vision(rng)
        self.frame7e = crack_frame(rng)
        self.crack, self.trunk = make_crack(rng)
        self.crack_maxd = max(s[5] for s in self.crack)
        self.crack_end = self.trunk[-1]
        self.photo = photo_card(rng)
        self.rain = Rain(rng)
        self.dust = particles(11, 70, x=(0, W), y=(H * 0.25, H), s=(1, 3), v=(20, 60))
        self.clips = d["all_clips"]
        self.shot_of = {c["id"]: s for s in d["shots"] for c in s["clips"]}
        self.huds = {c["id"]: hud_layer(self.shot_of[c["id"]], c) for c in self.clips}
        self.subs = [(ln["start"], ln["end"], sub_layer(ln)) for ln in d["all_lines"]]
        self.start = {c["id"]: c["start"] for c in self.clips}
        self.freeze_clock = self.start["7A"] + 1.5
        self.target = (M + W * 0.82, M + H * 0.36)
        self.total = d["total"]

    # background window with zoom / shake / parallax; returns RGBA frame and a bg->screen mapper
    def base(self, img, z=1.0, ox=0.0, oy=0.0):
        cw, ch = W / z, H / z
        cx, cy = img.width / 2 + ox, img.height / 2 + oy
        box = (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)
        out = img.resize((W, H), Image.BILINEAR, box=box).convert("RGBA")

        def to_screen(px, py):
            return ((px - box[0]) * z, (py - box[1]) * z)
        return out, to_screen

    def clip_at(self, t):
        for c in self.clips:
            if c["start"] <= t < c["end"]:
                return c
        return None

    def frame(self, t):
        c = self.clip_at(t)
        if c is None:
            return self.endcard(t - self.d["endcard"]["start"])
        tau, dur = t - c["start"], c["dur"]
        img, show_hud = self.draw(c["id"], tau, dur, t)
        if show_hud:
            img.alpha_composite(self.huds[c["id"]], dest=(0, 0))
            dr = ImageDraw.Draw(img)
            dr.text((W - 40, 28), "动态分镜预览 · 非成片", font=font(17), fill=GOLD + (255,), anchor="ra")
            dr.text((W - 40, 56), f"{tc(t)} / {tc(self.total)}", font=font(19), fill=(206, 212, 220, 255), anchor="ra")
            for s, e, sub in self.subs:
                if s <= t < e:
                    img.alpha_composite(sub, dest=(0, H - 140))
        return img

    def endcard(self, tau):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        dr = ImageDraw.Draw(img)
        a1 = int(255 * smooth(0.3, 1.0, tau))
        a2 = int(255 * smooth(1.8, 2.5, tau))
        dr.text((W / 2, H / 2 - 30), "第一集完", font=font(60), fill=(240, 240, 240, a1), anchor="mm")
        dr.text((W / 2, H / 2 + 50), f"下集预告：《{self.d['meta']['next_title']}》", font=font(32),
                fill=GOLD + (a2,), anchor="mm")
        return img

    def draw(self, cid, tau, dur, t):  # noqa: C901 - one branch per clip, on purpose
        p = tau / dur
        rain = self.rain
        hud = True

        def shake(t0, amp, decay=1.6):
            if tau < t0:
                return 0.0, 0.0
            k = amp * math.exp(-(tau - t0) * decay)
            return k * math.sin(tau * 61), k * math.cos(tau * 47)

        def tunnel_rain(f, every=1, alpha=60):
            ov, dr = layer()
            rain.fall(dr, t, (150, 172, 195), alpha, every=every, shafts=True)
            f.alpha_composite(ov)

        def sky_rain(f, alpha=85):
            ov, dr = layer()
            rain.fall(dr, t, (186, 196, 208), alpha)
            f.alpha_composite(ov)

        def frozen(f, gold_at=None, **kw):
            ov, dr = layer()
            rain.frozen(dr, self.freeze_clock, t, gold_at=gold_at, frame=f if gold_at else None, **kw)
            f.alpha_composite(ov)

        def dust(f, warm=True):
            ov, dr = layer()
            P = self.dust
            for i in range(len(P["x"])):
                x = (P["x"][i] + P["v"][i] * t) % W
                y = P["y"][i] + 8 * math.sin(t + i)
                s = P["s"][i]
                dr.ellipse([x - s, y - s, x + s, y + s], fill=(232, 196, 150, 90) if warm else (200, 200, 200, 60))
            f.alpha_composite(ov)

        def crack(f, **kw):
            ov, dr = layer()
            draw_crack(dr, self.crack, self.crack_maxd, **kw)
            f.alpha_composite(ov)

        # ------------------------------------------------ shot 1
        if cid == "1A":
            f, _ = self.base(self.dusk_fig, z=1.0 + 0.12 * ease(p))
            dust(f)
        elif cid == "1B":
            f, _ = self.base(self.dusk_blur)
            dust(f)
            f.alpha_composite(plate_layer(t))
        elif cid == "1C":
            f, _ = self.base(self.dusk_blur)
            f = Image.eval(f, lambda v: int(v * 0.9))
            dust(f)
            ph = self.photo.rotate(-4 + 1.2 * math.sin(t * 1.3), expand=True, resample=Image.BICUBIC)
            comp(f, ph, W * 0.5, H * 0.56 + 520 * smooth(0.45, 1.0, p))
        # ------------------------------------------------ shot 2
        elif cid == "2A":
            f, _ = self.base(self.dusk_blur)
            f = Image.eval(f, lambda v: int(v * 0.6))
            comp(f, self.photo.resize((228, 162)), W * 0.5, H * 0.66)
            cx, cy = W * 0.5, H * 0.6
            glow(f, cx, cy, 260, GOLD, 0.25 + 0.45 * ease(p) + 0.1 * math.sin(t * 6), 2.2)
            glow(f, cx, cy, 70, GOLD_HI, 0.5 + 0.4 * ease(p))
            for k in range(26):
                rise = (tau * 70 + k * 23) % 280
                x = cx + (36 + 0.18 * rise) * math.sin(k * 1.7 + tau * 2.4 + rise / 40)
                glow(f, x, cy - rise, 11, (140, 190, 255), 0.7 * (1 - rise / 280))
        elif cid in ("2B", "2C"):
            f, _ = self.base(self.dusk)
            f = Image.eval(f, lambda v: int(v * 0.7))
            ov, dr = layer()
            cx, cy = W * 0.5, H * 0.46
            if cid == "2B":
                for k in range(4):
                    r = (tau * 120 + k * 80) % 320
                    dr.ellipse([cx - r * 0.6, cy - r, cx + r * 0.6, cy + r], outline=(236, 206, 150, int(120 * (1 - r / 320))), width=2)
                op = ease(tau / 2.2)
                rift(f, dr, t, cx, cy, 240 * op, 38 * op)
                for k in range(40):
                    dist = (tau * 300 + k * 37) % 520
                    ang = k * 2.4
                    x, y = cx + dist * math.cos(ang) * 0.9, cy + dist * math.sin(ang) * 0.6
                    dr.line([(x, y), (x + 4 * math.cos(ang), y + 10)], fill=(176, 198, 222, int(150 * (1 - dist / 520))), width=1)
            else:
                close = 1 - smooth(2.4, 3.1, tau)
                rift(f, dr, t, cx, cy, 240 * close, 38 * close)
                k = min(1.0, (tau / 2.4) ** 2)
                bx, by = cx, lerp(H + 80, cy, k)
                f.alpha_composite(ov)
                ov, dr = layer()
                if tau < 2.6:
                    for j in range(6):
                        kj = min(1.0, (max(0.0, tau - 0.06 * j) / 2.4) ** 2)
                        glow(f, cx, lerp(H + 80, cy, kj), 60 - j * 6, GOLD, 0.55 - j * 0.08)
                    glow(f, bx, by, 150, GOLD, 0.6)
                    glow(f, bx, by, 40, GOLD_HI, 0.95)
                    vis = int(9 * smooth(1.0, 2.2, tau))
                    orb_ring(dr, t, bx, by, rx=90, ry=26, r=9, visible=vis, lift=10)
            f.alpha_composite(ov)
            if cid == "2C":
                fl = smooth(2.9, 3.2, tau) * (1 - smooth(3.3, 4.0, tau))
                if fl > 0:
                    f = Image.blend(f, Image.new("RGBA", (W, H), (255, 250, 236, 255)), 0.85 * fl)
        # ------------------------------------------------ shot 3
        elif cid == "3A":
            f, _ = self.base(self.tunnel, ox=-20 + 40 * p)
            tunnel_rain(f)
            ov, dr = layer()
            for k in range(8):
                per = 1.3 + k * 0.17
                ph = (tau + k * 0.37) % per / per
                x, y = W * (0.15 + 0.1 * k), H * (0.82 + 0.02 * (k % 3))
                dr.ellipse([x - 40 * ph, y - 8 * ph, x + 40 * ph, y + 8 * ph], outline=(150, 170, 190, int(120 * (1 - ph))), width=1)
            f.alpha_composite(ov)
        elif cid == "3B":
            f, _ = self.base(self.tunnel, z=1.0 + 0.15 * ease(p))
            tunnel_rain(f)
            ov, dr = layer()
            vx, vy = W * 0.5, H * 0.5
            flick = 1.0 if math.sin(t * 9) > -0.3 else 0.55
            purple_eyes(f, dr, vx, vy - 30, size=0.6, strength=flick)
            k = ease(p) * 0.92
            tx, ty = lerp(vx, W * 0.38, k), lerp(vy, H * 0.82, k)
            wt = 2 + 16 * k
            ang = math.atan2(ty - vy, tx - vx) + math.pi / 2
            dr.polygon([(vx, vy), (tx + wt * math.cos(ang), ty + wt * math.sin(ang)), (tx, ty),
                        (tx - wt * math.cos(ang), ty - wt * math.sin(ang))], fill=(8, 8, 10, 255))
            dr.ellipse([tx - 30 * k - 8, ty - 12 * k - 4, tx + 30 * k + 8, ty + 12 * k + 4], outline=(200, 214, 228, 70), width=2)
            f.alpha_composite(ov)
        elif cid == "3C":
            sx, sy = shake(0.25, 12)
            f, _ = self.base(self.tunnel, ox=sx, oy=sy)
            tunnel_rain(f)
            hit = 0.25
            tint = 0.0 if tau < hit else 0.28 * math.exp(-(tau - hit) * 1.2) + 0.1
            if tint:
                f = Image.blend(f, Image.new("RGBA", (W, H), GOLD + (255,)), tint)
            ox_, oy_ = W * 0.56 + sx, H * 0.52 + sy
            if tau >= hit:
                glow(f, ox_, oy_, 420, GOLD, 0.9 * math.exp(-(tau - hit) * 2.2) + 0.25)
                glow(f, ox_ - 70, oy_ + 10, 120, (255, 250, 230), 1.0 * math.exp(-(tau - hit) * 4))
            ov, dr = layer()
            left = ox_ - 64
            if tau < hit:
                tip = lerp(-60, left, tau / hit)
            else:
                tip = lerp(left, -80, smooth(hit + 0.05, 1.8, tau))
            dr.polygon([(-80, oy_ + 60), (tip, oy_ + 6), (tip, oy_ + 14), (-80, oy_ + 84)], fill=(8, 8, 10, 255))
            if tau >= hit:
                P = particles(31, 90, ts=(hit, 1.8), vx=(-260, -40), vy=(-120, 60), s=(1.5, 4))
                for i in range(90):
                    age = tau - P["ts"][i]
                    if age < 0:
                        continue
                    x0 = lerp(left, -80, smooth(hit + 0.05, 1.8, P["ts"][i]))
                    x = x0 + P["vx"][i] * age
                    y = oy_ + 10 + P["vy"][i] * age + 120 * age * age
                    s = P["s"][i]
                    dr.rectangle([x - s, y - s, x + s, y + s], fill=(12, 12, 14, int(255 * max(0.0, 1 - age / 1.5))))
                r = 700 * (tau - hit)
                dr.ellipse([ox_ - r, oy_ - r * 0.7, ox_ + r, oy_ + r * 0.7], outline=GOLD + (int(max(0.0, 200 - 160 * (tau - hit))),), width=4)
            dr.ellipse([ox_ - 70, oy_ - 70, ox_ + 70, oy_ + 70], fill=GOLD + (200,))
            dr.ellipse([ox_ - 64, oy_ - 64, ox_ + 64, oy_ + 64], fill=(8, 8, 12, 255))
            dr.ellipse([ox_ - 40, oy_ - 46, ox_ - 12, oy_ - 24], fill=(96, 96, 116, 150))
            f.alpha_composite(ov)
        elif cid == "3D":
            f, _ = self.base(self.tunnel, z=1.05)
            tunnel_rain(f)
            glow(f, W * 0.98, H * 0.5, 640, GOLD, 0.55 + 0.12 * math.sin(t * 13))
        elif cid in ("3E", "4E"):
            low = cid == "4E"
            f, _ = self.base(self.tunnel, z=1.04 if low else 1.0)
            tunnel_rain(f)
            cx, cy = W * 0.5, H * (0.56 if low else 0.62)
            gold_presence(f, t, cx, cy, 0.95)
            for k in range(14):
                rise = (tau * 30 + k * 19) % 160
                glow(f, cx - 130 + k * 20, cy - 40 - rise, 34, (230, 236, 244), 0.12 * (1 - rise / 160))
            ov, dr = layer()
            orb_ring(dr, t, cx, cy)
            f.alpha_composite(ov)
        # ------------------------------------------------ shot 4
        elif cid == "4A":
            f, _ = self.base(self.tunnel, z=1.0 + 0.08 * p)
            tunnel_rain(f)
            ov, dr = layer()
            vx, vy = W * 0.5, H * 0.5
            for j, ang in enumerate((-2.6, -2.0, -1.2, -0.5, 0.3, 2.9)):
                k = ease(min(1.0, p * 1.15 + j * 0.03))
                dist = 40 + 560 * k
                x, y = vx + dist * math.cos(ang), vy + dist * math.sin(ang) * 0.6
                px, py = vx + (dist - 90) * math.cos(ang), vy + (dist - 90) * math.sin(ang) * 0.6
                dr.line([(px, py), (x, y)], fill=(178, 128, 255, 70), width=int(2 + 6 * k))
                purple_eyes(f, dr, x, y, size=0.4 + 1.1 * k, strength=0.9)
            f.alpha_composite(ov)
        elif cid == "4B":
            f, _ = self.base(self.tunnel)
            tunnel_rain(f)
            cx, cy = W * 0.5, H * 0.62
            gold_presence(f, t, cx, cy, 0.8 + 0.35 * p)
            ov, dr = layer()
            if tau > 1.8:
                for k in range(3):
                    r = ((tau - 1.8) * 220 + k * 90) % 300
                    dr.ellipse([cx - r, cy - r * 0.4, cx + r, cy + r * 0.4], outline=GOLD + (int(150 * (1 - r / 300)),), width=3)
            orb_ring(dr, t, cx, cy)
            f.alpha_composite(ov)
        elif cid == "4C":
            sx, sy = shake(0.15, 15, 1.1)
            f, _ = self.base(self.tunnel, ox=sx, oy=sy)
            tunnel_rain(f)
            cx, cy = W * 0.5 + sx, H * 0.6 + sy
            gold_presence(f, t, cx, cy, 1.25)
            ov, dr = layer()
            ends = [(-60, H * 0.35), (W + 60, H * 0.35), (-60, H * 0.85), (W + 60, H * 0.88), (W * 0.18, -60), (W * 0.82, -60)]
            fade = 1 - smooth(1.6, 2.6, tau)
            for j, (ex, ey) in enumerate(ends):
                t0 = 0.1 + j * 0.07
                k = ease((tau - t0) / 0.35)
                if k <= 0:
                    continue
                px, py = lerp(cx, ex, k), lerp(cy, ey, k)
                gline(dr, [(cx, cy), (px, py)], GOLD_HI, 9, int(230 * fade))
                if k >= 1 and fade > 0:
                    glow(f, lerp(cx, ex, 0.93), lerp(cy, ey, 0.93), 120, (255, 240, 200), 0.8 * math.exp(-(tau - t0 - 0.35) * 2) * fade)
            if tau > 1.0:
                for k in range(30):
                    x = W * (0.05 + 0.03 * k)
                    y = ((tau - 1.0) * 900 + k * 53) % (H * 0.8)
                    dr.line([(x, y), (x + 3, y + 40)], fill=(200, 216, 232, 110), width=2)
            f.alpha_composite(ov)
        elif cid == "4D":
            f, _ = self.base(self.tunnel, z=1.0 + 0.06 * p)
            tunnel_rain(f)
            ov, dr = layer()
            purple_eyes(f, dr, W * 0.5, H * 0.46, size=1.6, rings=True)
            f.alpha_composite(ov)
        # ------------------------------------------------ shot 5
        elif cid in ("5A", "5B", "5C", "5D"):
            if cid == "5C":
                f, _ = self.base(self.tunnel, ox=-24 + 48 * p)
            else:
                f, _ = self.base(self.tunnel, z=1.0 + (0.05 * p if cid == "5A" else 0.06 if cid == "5B" else 0.0))
            tunnel_rain(f, every=2, alpha=50)
            spots = {"5A": (0.5, 0.62), "5B": (0.3, 0.42), "5C": (0.62, 0.5), "5D": (0.5, 0.6)}
            cx, cy = W * spots[cid][0], H * spots[cid][1]
            gold_presence(f, t, cx, cy, 0.55)
            glow(f, W * 0.5, H * 0.55, 600, (255, 196, 120), 0.12)
            if cid in ("5A", "5D"):
                ov, dr = layer()
                orb_ring(dr, t, cx, cy)
                f.alpha_composite(ov)
        # ------------------------------------------------ shot 6
        elif cid == "6A":
            f, _ = self.base(self.tunnel)
            tunnel_rain(f)
            ov, dr = layer()
            vx, vy = W * 0.5, H * 0.5
            purple_eyes(f, dr, vx, vy - 20, size=0.45, rings=True)
            r = 20 + 130 * ease(p)
            dr.ellipse([vx - r, vy - r * 0.8, vx + r, vy + r * 0.8], outline=(220, 228, 240, int(40 + 50 * p)), width=2)
            f.alpha_composite(ov)
        elif cid == "6B":
            sx, sy = shake(0.0, 18, 1.4)
            a, _ = self.base(self.tunnel, ox=sx, oy=sy)
            b, _ = self.base(self.sky, ox=sx, oy=sy)
            f = Image.blend(a, b, smooth(0.25, 1.6, tau))
            sky_rain(f, 60)
            ov, dr = layer()
            cx, cy = W * 0.5 + sx, H * 0.5 + sy
            k = min(1.0, tau / 1.3)
            r = 1400 * (1 - (1 - k) ** 2)
            dr.ellipse([cx - r, cy - r * 0.75, cx + r, cy + r * 0.75], outline=(236, 242, 250, int(220 * (1 - k))), width=8)
            dr.ellipse([cx - r * 0.96, cy - r * 0.72, cx + r * 0.96, cy + r * 0.72], outline=(236, 242, 250, int(70 * (1 - k))), width=20)
            P = particles(61, 110, ang=(0, 6.283), v=(300, 900), s=(3, 9), ts=(0.0, 0.5))
            for i in range(110):
                age = tau - P["ts"][i]
                if age < 0:
                    continue
                dist = P["v"][i] * age
                x = cx + dist * math.cos(P["ang"][i])
                y = cy + dist * math.sin(P["ang"][i]) * 0.7 + 90 * age * age
                s = P["s"][i]
                dr.polygon([(x - s, y), (x, y - s * 0.7), (x + s, y + s * 0.3), (x, y + s)], fill=(28, 30, 34, 255))
            f.alpha_composite(ov)
        elif cid == "6C":
            f, _ = self.base(self.sky)
            sky_rain(f)
            gold_presence(f, t, W * 0.36, H * 0.66, 0.85)
            ov, dr = layer()
            sxc, syc = W * 0.6, H * 0.55
            if tau < 1.4:
                rr = lerp(900, 640, min(1.0, tau / 0.3))
                a = int(200 * (1 - smooth(0.3, 1.4, tau)))
                dr.arc([W * 1.42 - rr, syc - rr, W * 1.42 + rr, syc + rr], 150, 210, fill=(236, 242, 250, a), width=8)
            P = particles(62, 60, x=(W * 0.66, W * 0.95), y=(H * 0.25, H * 0.8), s=(3, 8))
            for i in range(60):
                fall = max(0.0, tau - 0.4)
                y = P["y"][i] + 500 * fall * fall
                if y > H + 20:
                    continue
                s = P["s"][i]
                dr.rectangle([P["x"][i] - s, y - s, P["x"][i] + s, y + s], fill=(30, 32, 36, 255))
            dr.ellipse([sxc - 128, syc - 158, sxc + 128, syc + 158], fill=GOLD + (210,))
            dr.ellipse([sxc - 120, syc - 150, sxc + 120, syc + 150], fill=(8, 8, 12, 255))
            dr.ellipse([sxc - 70, syc - 110, sxc - 20, syc - 60], fill=(70, 70, 90, 120))
            f.alpha_composite(ov)
        elif cid == "6D":
            z = 1.08 - 0.08 * ease(p)
            f, to_s = self.base(self.sky, z=z)
            sky_rain(f)
            tx, ty = to_s(*self.target)
            gold_presence(f, t, W * 0.2, H * 0.66, 0.9)
            ov, dr = layer()
            k = ease((tau - 0.15) / 0.25)
            fade = 1 - smooth(1.5, 2.4, tau)
            if k > 0 and fade > 0:
                sx_, sy_ = W * 0.25, H * 0.62
                gline(dr, [(sx_, sy_), (lerp(sx_, tx, k), lerp(sy_, ty, k))], GOLD_HI, 14, int(240 * fade))
            if tau >= 0.4:
                dr.ellipse([tx - 26, ty - 26, tx + 26, ty + 26], fill=(14, 16, 20, 255))
                P = particles(63, 40, vx=(-60, 60), s=(2, 6), ts=(0.4, 2.5))
                for i in range(40):
                    age = tau - P["ts"][i]
                    if age < 0:
                        continue
                    x, y = tx + P["vx"][i] * age, ty + 20 + 300 * age * age
                    s = P["s"][i]
                    dr.rectangle([x - s, y - s, x + s, y + s], fill=(30, 32, 36, 255))
            f.alpha_composite(ov)
            if tau >= 0.4:
                glow(f, tx, ty, 200, (255, 236, 190), 0.95 * math.exp(-(tau - 0.4) * 1.8))
        elif cid == "6E":
            f, to_s = self.base(self.sky, z=1.04)
            sky_rain(f)
            tx, ty = to_s(*self.target)
            ov, dr = layer()
            dr.ellipse([tx - 27, ty - 27, tx + 27, ty + 27], fill=(14, 16, 20, 255))
            f.alpha_composite(ov)
            for k in range(10):
                rise = (tau * 26 + k * 17) % 170
                glow(f, tx - 40 + k * 9, ty - rise, 46, (150, 152, 156), 0.25 * (1 - rise / 170))
        # ------------------------------------------------ shot 7
        elif cid == "7A":
            f, _ = self.base(self.sky)
            v = max(0.0, 1 - tau / 3.0)
            clock = self.start["7A"] + (min(tau, 3.0) - min(tau, 3.0) ** 2 / 6.0)
            ov, dr = layer()
            rain.fall(dr, clock, (186, 196, 208), 85, stretch=v)
            f.alpha_composite(ov)
            g = smooth(0.6, 3.4, tau)
            if g > 0:
                f = Image.blend(f, f.convert("L").convert("RGBA"), g)
            gold_presence(f, t, W * 0.5, H * 0.66, 0.75)
        elif cid == "7B":
            f, to_s = self.base(self.sky_gray, ox=-15 + 30 * p)
            frozen(f)
            tx, ty = to_s(*self.target)
            ov, dr = layer()
            dr.ellipse([tx - 27, ty - 27, tx + 27, ty + 27], fill=(14, 16, 20, 255))
            dr.ellipse([tx + 30, ty - 20, tx + 42, ty - 8], fill=(10, 10, 12, 255))
            dr.polygon([(tx + 30, ty - 8), (tx + 44, ty - 8), (tx + 50, ty + 22), (tx + 26, ty + 22)], fill=(10, 10, 12, 255))
            f.alpha_composite(ov)
            crack(f, progress=smooth(0.2, 3.8, tau))
        elif cid == "7C":
            f, _ = self.base(self.sky_gray)
            frozen(f)
            crack(f)
            gold_presence(f, t, W * 0.44, H * 0.7, 0.7)
            ov, dr = layer()
            dx, dy = W * 0.58, H * 0.5
            dr.ellipse([dx - 10, dy - 10, dx + 10, dy + 10], fill=(220, 226, 236, 200))
            dr.ellipse([dx - 5, dy - 7, dx - 1, dy - 3], fill=(255, 255, 255, 255))
            if 0.8 < tau < 2.0:
                r = (tau - 0.8) * 60
                dr.ellipse([dx - r, dy - r, dx + r, dy + r], outline=(230, 236, 246, int(160 * (1 - (tau - 0.8) / 1.2))), width=2)
            f.alpha_composite(ov)
        elif cid == "7D":
            f, _ = self.base(self.sky_gray, z=1.0 + 0.2 * ease(p))
            s = 1 + 1.4 * ease(p)
            focus = (W * 0.56, H * 0.28)
            frozen(f, scale=s, focus=focus)
            ov, dr = layer()
            pts = [(focus[0] + (x - focus[0]) * s, focus[1] + (y - focus[1]) * s) for x, y in self.trunk]
            open_w = 6 + 80 * ease(p)
            dr.line(pts, fill=(235, 240, 255, 60), width=int(open_w + 26), joint="curve")
            dr.line(pts, fill=(6, 6, 10, 255), width=int(open_w), joint="curve")
            for j in range(2, len(pts), 3):
                x, y = pts[j]
                a = int(90 * (0.5 + 0.5 * math.sin(t * 3 + j)))
                half = open_w * 0.3
                dr.line([(x - half, y + math.sin(t * 2 + j) * 6), (x + half, y + math.sin(t * 2 + j) * 6)],
                        fill=(170, 176, 190, a), width=2)
            f.alpha_composite(ov)
            crack(f, scale=s, focus=focus)
        elif cid == "7E":
            f = self.vision.copy()
            front = smooth(0.2, 3.8, tau) * W * 0.44
            ov, dr = layer()
            if front > 1:
                for side in (-1, 1):
                    edge = []
                    for k in range(37):
                        y = H * k / 36
                        jag = 18 * math.sin(k * 1.9 + t * 3) + 10 * math.sin(k * 4.3)
                        edge.append(((front + jag) if side < 0 else (W - front - jag), y))
                    outer = [(0, H), (0, 0)] if side < 0 else [(W, H), (W, 0)]
                    dr.polygon(outer + edge, fill=(232, 234, 238, 255))
                P = particles(71, 140, y=(0, H), side=(-1, 1), v=(30, 120), ts=(0.2, 3.8), s=(1, 3))
                for i in range(140):
                    age = tau - P["ts"][i]
                    if age < 0 or age > 2:
                        continue
                    fr = smooth(0.2, 3.8, P["ts"][i]) * W * 0.44
                    x = fr if P["side"][i] < 0 else W - fr
                    y = P["y"][i] - P["v"][i] * age
                    sz = P["s"][i]
                    dr.ellipse([x - sz, y - sz, x + sz, y + sz], fill=(255, 255, 255, int(220 * (1 - age / 2))))
            f.alpha_composite(ov)
            f.alpha_composite(self.frame7e)
        # ------------------------------------------------ shot 8
        elif cid in ("8A", "8C", "8D"):
            f, _ = self.base(self.sky_gray, ox=(-20 + 40 * p) if cid == "8A" else 0)
            spot = {"8A": (0.5, 0.64), "8C": (0.22, 0.82), "8D": (0.5, 0.64)}[cid]
            cx, cy = W * spot[0], H * spot[1]
            frozen(f, gold_at=(cx, cy))
            crack(f)
            if cid == "8D":
                k = ease(p)
                glow(f, cx, cy, 300 + 120 * k, GOLD, 0.45 + 0.4 * k, 2.2)
                glow(f, cx, cy, 40 + 70 * k, (255, 246, 220), 0.7 + 0.3 * k + 0.1 * math.sin(t * 30))
                ov, dr = layer()
                rr = np.random.default_rng(int(t * FPS))
                for _ in range(int(8 + 18 * k)):
                    ang = rr.uniform(0, 6.283)
                    r0, r1 = 30 + 40 * k, 70 + 120 * k * rr.uniform(0.5, 1)
                    dr.line([(cx + r0 * math.cos(ang), cy + r0 * math.sin(ang)),
                             (cx + r1 * math.cos(ang), cy + r1 * math.sin(ang))], fill=GOLD_HI + (200,), width=2)
                f.alpha_composite(ov)
            else:
                big = cid == "8C"
                gold_presence(f, t, cx, cy, 1.0 if big else 0.9)
                ov, dr = layer()
                if big:
                    orb_ring(dr, t, cx, cy, rx=230, ry=64, r=24, lift=150)
                else:
                    orb_ring(dr, t, cx, cy)
                f.alpha_composite(ov)
        elif cid == "8B":
            f, _ = self.base(self.sky_gray, z=1.0 + 0.04 * p)
            frozen(f, tremble=0.8)
            pulse = max(0.0, math.sin(2 * math.pi * tau / 1.25))
            for k in range(8):
                x0, y0 = self.trunk[min(len(self.trunk) - 1, 3 + k * 3)]
                drop = (tau * 28 + k * 30) % 170
                glow(f, x0 + 10 * math.sin(k + tau), y0 + drop, 80, (8, 8, 12), 0.45 * (1 - drop / 170) * (0.6 + 0.4 * pulse))
            crack(f, glow_k=1 + 1.2 * pulse)
        elif cid == "8E":
            if tau >= 3.6:
                return Image.new("RGBA", (W, H), (0, 0, 0, 255)), False
            f, _ = self.base(self.sky_gray)
            frozen(f)
            crack(f, glow_k=1 + tau)
            ex, ey = self.crack_end
            k = min(1.0, (tau / 2.6) ** 2)
            glow(f, ex, ey + 30 * k, 60 + 200 * k, (6, 6, 10), 0.85, 1.6)
            if tau < 2.6:
                for j in range(7):
                    kj = min(1.0, (max(0.0, tau - 0.05 * j) / 2.6) ** 2)
                    glow(f, lerp(W * 0.5, ex, kj), lerp(H + 60, ey, kj), 70 - j * 7, GOLD, 0.6 - j * 0.07)
                bx, by = lerp(W * 0.5, ex, k), lerp(H + 60, ey, k)
                glow(f, bx, by, 170, GOLD, 0.7)
                glow(f, bx, by, 46, (255, 246, 220), 1.0)
            fl = smooth(2.6, 3.0, tau)
            if fl > 0:
                f = Image.blend(f, Image.new("RGBA", (W, H), (255, 255, 255, 255)), fl)
            hud = tau < 2.6
        else:
            f = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        return f, hud


# ------------------------------------------------------------------ audio

def synth_audio(d, total, path):
    n = int((total + 1) * SR)
    L = np.zeros(n, np.float32)
    R = np.zeros(n, np.float32)
    S = {c["id"]: c["start"] for c in d["all_clips"]}
    E = {c["id"]: c["end"] for c in d["all_clips"]}
    S["END"] = d["endcard"]["start"]
    rng = np.random.default_rng(5)

    def secs(m):
        return np.arange(m, dtype=np.float32) / SR

    def band(dur, lo, hi, seed):
        m = int(dur * SR)
        x = np.random.default_rng(seed).standard_normal(m).astype(np.float32)
        X = np.fft.rfft(x)
        fr = np.fft.rfftfreq(m, 1 / SR)
        resp = 1 / (1 + (lo / np.maximum(fr, 1)) ** 4) / (1 + (fr / hi) ** 4)
        y = np.fft.irfft(X * resp, m).astype(np.float32)
        return y / (np.std(y) + 1e-9)

    def sine(dur, f0, f1=None):
        tt = secs(int(dur * SR))
        f1 = f0 if f1 is None else f1
        return np.sin(2 * np.pi * (f0 * tt + 0.5 * (f1 - f0) / dur * tt * tt)).astype(np.float32)

    def env(m, a, r):
        e = np.ones(m, np.float32)
        ia, ir = min(m, int(a * SR)), min(m, int(r * SR))
        if ia:
            e[:ia] = np.linspace(0, 1, ia)
        if ir:
            e[m - ir:] *= np.linspace(1, 0, ir)
        return e

    def dec(m, tau):
        return np.exp(-secs(m) / tau).astype(np.float32)

    def add(sig, t0, gain=1.0, right=None):
        i0 = int(t0 * SR)
        if i0 >= n:
            return
        sig = sig[: n - i0] * gain
        L[i0:i0 + len(sig)] += sig
        r = sig if right is None else right[: len(sig)] * gain
        R[i0:i0 + len(r)] += r

    def curve(t0, t1, keys):
        tt = t0 + secs(int((t1 - t0) * SR))
        return np.interp(tt, [k for k, _ in keys], [v for _, v in keys]).astype(np.float32)

    def impact(size=1.0, seed=0):
        dur = 1.8 * size
        m = int(dur * SR)
        return sine(dur, 140, 50) * dec(m, 0.38 * size) + 0.6 * band(dur, 60, 1800, seed) * dec(m, 0.12 * size)

    def metal(seed=0):
        dur = 1.4
        m = int(dur * SR)
        sig = sum(sine(dur, f) * dec(m, tau) * a for f, tau, a in ((420, 0.5, 0.5), (1130, 0.3, 0.35), (2260, 0.18, 0.25), (3470, 0.1, 0.2)))
        return sig + 0.4 * band(dur, 800, 6000, seed) * dec(m, 0.05)

    def whoosh(dur, lo=300, hi=4000, seed=0):
        m = int(dur * SR)
        shape = np.sin(np.linspace(0, np.pi, m)) ** 2
        return band(dur, lo, hi, seed) * shape.astype(np.float32)

    def clicks(t0, t1, rate, f_lo, f_hi, gain, seed):
        r = np.random.default_rng(seed)
        t = t0
        while t < t1:
            t += r.exponential(1 / rate)
            f = r.uniform(f_lo, f_hi)
            m = int(0.05 * SR)
            add(sine(0.05, f) * dec(m, 0.012), t, gain * r.uniform(0.4, 1.0))

    # wind and embers (shot 1)
    t1 = E["2A"]
    wc = curve(0, t1, [(0, 0), (1.2, 0.06), (E["1C"] - 1.5, 0.06), (E["1C"], 0.02), (t1, 0)])
    wc *= (0.75 + 0.25 * np.sin(2 * np.pi * 0.17 * secs(len(wc))))
    add(band(t1, 120, 900, 1) * wc, 0, right=band(t1, 120, 900, 2) * wc)
    clicks(0, E["1C"], 3, 1500, 4000, 0.05, 3)
    # resonance hum (2A)
    dur = E["2A"] - S["2A"] + 0.6
    m = int(dur * SR)
    hum = (sine(dur, 110) + 0.6 * sine(dur, 165) + 0.4 * sine(dur, 220)) * env(m, 2.5, 0.8)
    add(hum, S["2A"], 0.07)
    # rift tear, leap, flash
    add(whoosh(0.8, 300, 3000, 4) * 0.5 + sine(0.8, 900, 200) * dec(int(0.8 * SR), 0.3) * 0.2, S["2B"], 0.5)
    add(whoosh(1.8, 400, 6000, 5), S["2C"] + 0.6, 0.45)
    add(impact(1.2, 6), S["2C"] + 2.9, 0.75)
    # rain bed
    r0, r1 = S["2B"], E["7A"]
    lvl = [(r0, 0), (r0 + 0.8, 0.025), (E["2C"] - 0.4, 0.025), (S["3A"], 0.055), (S["5A"], 0.055), (S["5A"] + 1, 0.03),
           (E["5D"], 0.03), (S["6A"], 0.05), (S["6B"] - 0.55, 0.05), (S["6B"] - 0.5, 0.0), (S["6B"] + 0.4, 0.0),
           (S["6B"] + 1.0, 0.065), (S["7A"], 0.065), (S["7A"] + 3.0, 0.0), (r1, 0.0)]
    c = curve(r0, r1, lvl)
    add(band(r1 - r0, 700, 9000, 7) * c, r0, right=band(r1 - r0, 700, 9000, 8) * c)
    clicks(S["3A"], S["6A"], 2.5, 1100, 2600, 0.06, 9)  # drips
    # rod whistle, orb impact, gold hum
    add(sine(E["3B"] - S["3B"] - 0.2, 1800, 2700) * env(int((E["3B"] - S["3B"] - 0.2) * SR), 0.6, 0.05), S["3B"] + 0.2, 0.05)
    add(metal(10), S["3C"] + 0.25, 0.64)
    add(impact(0.8, 11), S["3C"] + 0.25, 0.56)
    dur = E["3E"] - S["3C"] - 0.25
    m = int(dur * SR)
    add((sine(dur, 220) + 0.5 * sine(dur, 331) + 0.3 * sine(dur, 442)) * env(m, 0.3, 1.0), S["3C"] + 0.25, 0.035)
    # pains rush, surge, arms
    add(whoosh(E["4A"] - S["4A"], 200, 2500, 12), S["4A"], 0.5)
    dur = E["4B"] - S["4B"]
    add(sine(dur, 110, 220) * env(int(dur * SR), 1.5, 0.2), S["4B"], 0.06)
    for k, dt in enumerate((0.15, 0.35, 0.55, 0.8)):
        add(impact(0.9, 13 + k), S["4C"] + dt, 0.55)
    add(band(3.5, 40, 200, 17) * dec(int(3.5 * SR), 1.2), S["4C"], 0.35)
    add(band(2.8, 300, 3000, 18) * env(int(2.8 * SR), 0.5, 1.0), S["4C"] + 1.0, 0.12)
    dur = E["4E"] - S["4E"]
    add((sine(dur, 196) + 0.5 * sine(dur, 294)) * env(int(dur * SR), 0.5, 0.5), S["4E"], 0.03)
    # reunion theme (shot 5): three slow chords
    chords = [(S["5A"], S["5C"], (110.0, 164.8, 220.0, 261.6)),
              (S["5C"], S["5D"], (87.3, 130.8, 174.6, 220.0)),
              (S["5D"], E["5D"] + 1.0, (130.8, 196.0, 261.6, 329.6))]
    for a, b, notes in chords:
        dur = b - a + 1.2
        m = int(dur * SR)
        vib = 1 + 0.002 * np.sin(2 * np.pi * 5 * secs(m))
        sig = sum(np.sin(2 * np.pi * f * np.cumsum(vib) / SR).astype(np.float32) for f in notes)
        add(sig * env(m, 1.4, 1.4), a, 0.03)
    # shinra tensei: inhale, silence, blast, stop, beam
    dur = S["6B"] - 0.5 - S["6A"]
    add(whoosh(dur * 2, 200, 3000, 19)[: int(dur * SR)] * np.linspace(0, 1, int(dur * SR)), S["6A"], 0.25)
    add(impact(2.0, 20), S["6B"], 1.0)
    blast = band(E["6B"] - S["6B"] + 0.3, 80, 6000, 21) * dec(int((E["6B"] - S["6B"] + 0.3) * SR), 0.8)
    add(blast, S["6B"], 0.5)
    clicks(S["6B"] + 0.2, E["6B"], 14, 300, 1200, 0.18, 22)
    stop_i = int((S["6C"] + 0.3) * SR)
    L[stop_i:stop_i + int(0.02 * SR)] *= np.linspace(1, 0.15, int(0.02 * SR))
    R[stop_i:stop_i + int(0.02 * SR)] *= np.linspace(1, 0.15, int(0.02 * SR))
    clicks(S["6C"] + 0.4, S["6C"] + 2.0, 18, 250, 900, 0.16, 23)
    add(sine(0.9, 200, 900) * env(int(0.9 * SR), 0.6, 0.1) + whoosh(0.9, 500, 7000, 24), S["6D"] + 0.1, 0.25)
    add(impact(0.7, 25), S["6D"] + 0.45, 0.35)
    clicks(S["6E"], E["6E"], 4, 200, 700, 0.08, 26)
    # frozen world: drone, glass, heartbeat
    d0, d1 = S["7A"] + 2.0, E["8D"]
    dur = d1 - d0
    m = int(dur * SR)
    drone = (sine(dur, 55) + sine(dur, 58) + 0.6 * sine(dur, 110) + 0.3 * sine(dur, 220)) * env(m, 2.0, 0.2) + 0.3 * band(dur, 60, 240, 27)
    add(drone * curve(d0, d1, [(d0, 0.03), (S["7D"], 0.03), (E["7D"], 0.055), (S["7E"], 0.022), (S["8A"], 0.035), (d1, 0.05)]), d0)
    clicks(S["7B"], E["7B"], 7, 3500, 7000, 0.05, 28)
    clicks(S["7D"], E["7E"], 3, 3500, 7000, 0.03, 29)
    for k in range(4):
        for dt in (0.3, 0.55):
            beat = (sine(0.18, 72) + 0.5 * sine(0.18, 144)) * dec(int(0.18 * SR), 0.05)
            add(beat, S["7C"] + k * 0.95 + dt, 0.5)
    dur = E["8A"] - S["8A"]
    add((sine(dur, 220) + 0.6 * sine(dur, 277) + 0.4 * sine(dur, 330)) * env(int(dur * SR), 0.6, 0.4), S["8A"], 0.03)
    for k in range(4):
        add(band(1.2, 30, 160, 30 + k) * np.sin(np.linspace(0, np.pi, int(1.2 * SR))).astype(np.float32), S["8B"] + k * 1.25, 0.35)
    dur = E["8D"] - S["8D"]
    m = int(dur * SR)
    add((sine(dur, 100, 420) * 0.5 + band(dur, 2000, 9000, 34) * 0.4) * np.linspace(0, 1, m) ** 2, S["8D"], 0.22)
    # clash, flash, hard cut
    add(whoosh(2.8, 300, 8000, 35) * np.linspace(0.2, 1, int(2.8 * SR)), S["8E"], 0.4)
    add(impact(2.2, 36), S["8E"] + 2.6, 1.0)
    add(band(1.0, 100, 9000, 37) * env(int(1.0 * SR), 0.05, 0.3), S["8E"] + 2.6, 0.45)
    cut = int((S["8E"] + 3.6) * SR)
    end_i = int(S["END"] * SR)
    L[cut:end_i] = 0
    R[cut:end_i] = 0
    # end card: two soft bell strikes
    for dt, f0, g in ((0.3, 98.0, 0.5), (1.8, 146.8, 0.35)):
        dur = 4.0
        m = int(dur * SR)
        bell = sum(sine(dur, f0 * h) * dec(m, tau) * a for h, tau, a in ((1, 2.2, 0.6), (2.76, 1.1, 0.3), (5.4, 0.5, 0.15), (8.93, 0.25, 0.08)))
        add(bell, S["END"] + dt, g)

    # dialogue (from tools/voice.py), with the ambience ducked underneath it
    voice = voice_track(d, n)
    if voice is not None:
        k = int(0.2 * SR)
        cs = np.concatenate([[0.0], np.cumsum(np.abs(voice), dtype=np.float64)])
        env = ((cs[k:] - cs[:-k]) / k).astype(np.float32)
        env = np.roll(np.concatenate([env, np.zeros(n - len(env), np.float32)]), k // 2)
        duck = 1 - 0.55 * np.clip(env / 0.06, 0, 1)
        L *= duck
        R *= duck
        L += voice * 0.6
        R += voice * 0.6

    mix = np.stack([L, R], 1)
    mix = np.tanh(mix * 1.6) / np.tanh(1.6)
    peak = np.max(np.abs(mix)) or 1.0
    mix = (mix / peak * 0.89 * 32767).astype(np.int16)
    mix = mix[: int(total * SR)]
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(mix.tobytes())


def voice_track(d, n):
    """Mono dialogue track built from <ep>/voice/voices.json, or None if there is none."""
    man = ROOT / d["_ep"] / "voice" / "voices.json"
    if not man.exists():
        return None
    v = np.zeros(n, np.float32)
    for item in json.loads(man.read_text(encoding="utf-8")):
        with wave.open(str(man.parent / item["file"]), "rb") as wf:
            sr = wf.getframerate()
            x = np.frombuffer(wf.readframes(wf.getnframes()), np.int16).astype(np.float32) / 32767
        if sr != SR:
            x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x).astype(np.float32)
        i0 = int(item["start"] * SR)
        seg = x[: max(0, n - i0)] * item.get("gain", 1.0)
        v[i0:i0 + len(seg)] += seg
    return v


# ------------------------------------------------------------------ main

def load(ep):
    data = json.loads((ROOT / ep / "storyboard.json").read_text(encoding="utf-8"))
    data["_ep"] = ep
    validate(data)
    layout(data)
    return data


def contact_sheet(r, path):
    times = [c["start"] + c["dur"] * 0.6 for c in r.clips] + [r.d["endcard"]["start"] + 3.0]
    cols, tw, th = 6, 320, 180
    rows = math.ceil(len(times) / cols)
    sheet = Image.new("RGB", (cols * tw, rows * th), (0, 0, 0))
    for i, t in enumerate(times):
        sheet.paste(r.frame(t).convert("RGB").resize((tw, th)), ((i % cols) * tw, (i // cols) * th))
    sheet.save(path)


def main(argv):
    args = argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    ep = args[0].strip("/")
    d = load(ep)
    r = Renderer(d)
    if "--sheet" in args:
        contact_sheet(r, args[args.index("--sheet") + 1])
        return
    out = ROOT / ep / "animatic.mp4"
    wav = ROOT / ep / ".animatic.wav"
    synth_audio(d, d["total"], wav)
    nframes = int(round(d["total"] * FPS))
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-i", str(wav), "-c:v", "libx264", "-preset", "medium", "-crf", "23",
           "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", "-shortest", str(out)]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(nframes):
        proc.stdin.write(r.frame(i / FPS).convert("RGB").tobytes())
        if i % (FPS * 10) == 0:
            print(f"  {tc(i / FPS)} / {tc(d['total'])}", flush=True)
    proc.stdin.close()
    proc.wait()
    wav.unlink(missing_ok=True)
    if proc.returncode:
        sys.exit("ffmpeg 失败")
    print(f"写好了：{out}")


if __name__ == "__main__":
    main(sys.argv)
