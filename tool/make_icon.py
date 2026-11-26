#!/usr/bin/env python3
"""Generate assets/icon/icon.png (1024x1024) with no third-party deps."""
import math
import os
import struct
import zlib

W = 1024
S = 2  # supersample factor
N = W * S


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def mix(a, b, t):
    t = clamp(t)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def rounded_rect(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


INDIGO = (0x4F, 0x46, 0xE5)
VIOLET = (0x93, 0x33, 0xEA)
DEEP = (0x2E, 0x1B, 0x6B)
WHITE = (0xFF, 0xFF, 0xFF)
LILAC = (0xC7, 0xD2, 0xFE)
LINE = (0xA5, 0xB4, 0xFC)
AMBER = (0xFB, 0xBF, 0x24)
FOLD_COLOR = (0xE0, 0xE7, 0xFF)

# page geometry (fractions of canvas)
PX0, PY0, PX1, PY1 = 0.285, 0.215, 0.715, 0.785
FOLD = 0.155


def sample(u, v):
    """u,v in 0..1 -> (r,g,b)"""
    # background: diagonal indigo -> violet with soft radial highlight
    t = clamp((u * 0.55 + v * 0.75 - 0.15) / 1.05)
    col = mix(INDIGO, VIOLET, t)
    d = math.hypot(u - 0.28, v - 0.22)
    glow = clamp(1.0 - d / 0.75) ** 2 * 0.35
    col = mix(col, (0xFF, 0xFF, 0xFF), glow * 0.55)
    col = mix(col, DEEP, clamp((d - 0.55) / 0.6) * 0.35)

    # page sheet with folded corner
    if rounded_rect(u, v, PX0, PY0, PX1, PY1, 0.045):
        fx0, fy1 = PX1 - FOLD, PY0 + FOLD
        if u > fx0 and v < fy1 and (u - fx0) + (fy1 - v) > FOLD:
            return FOLD_COLOR  # cut corner
        if u > fx0 and v < fy1:
            return mix(FOLD_COLOR, WHITE, 0.35)  # fold flap
        # text lines
        for i, (ly, lx1) in enumerate(
            [(0.40, 0.635), (0.50, 0.600), (0.60, 0.520)]
        ):
            if rounded_rect(u, v, 0.355, ly, lx1, ly + 0.036, 0.018):
                return LINE
        if circle(u, v, 0.640, 0.700, 0.042):
            return AMBER
        return WHITE
    return col


def build():
    rows = []
    for y in range(N):
        row = bytearray()
        v = (y + 0.5) / N
        for x in range(N):
            u = (x + 0.5) / N
            r, g, b = sample(u, v)
            row += bytes((int(r), int(g), int(b), 255))
        rows.append(row)

    # box-downsample SxS
    out = bytearray()
    for y in range(W):
        out.append(0)  # filter type 0
        for x in range(W):
            r = g = b = 0
            for dy in range(S):
                row = rows[y * S + dy]
                for dx in range(S):
                    i = (x * S + dx) * 4
                    r += row[i]
                    g += row[i + 1]
                    b += row[i + 2]
            n = S * S
            out += bytes((r // n, g // n, b // n))
    return bytes(out)


def chunk(tag, data):
    return (
        struct.pack('>I', len(data))
        + tag
        + data
        + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def main():
    raw = build()
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', W, W, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, '..', 'assets', 'icon', 'icon.png')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'wb') as f:
        f.write(png)
    print('wrote', out, len(png), 'bytes')


if __name__ == '__main__':
    main()