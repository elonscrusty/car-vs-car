#!/usr/bin/env python3
"""Offline preview, step 2: draw the parts that tools/preview/dump.luau wrote.

A tiny painter's-algorithm renderer (numpy + Pillow only). It is a layout check, not a screenshot:
flat shading, no textures, no text, no lighting from Roblox. Use Studio for the real look.

  python3 tools/preview/render.py parts.json out.png --view top
  python3 tools/preview/render.py parts.json out.png --view spawn
  python3 tools/preview/render.py parts.json out.png --eye 40,30,70 --look 0,2,10 --fov 60
"""
import argparse
import json
import math

import numpy as np
from PIL import Image, ImageDraw

LIGHT = np.array([-0.35, 0.85, 0.40])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def block_mesh(size):
    sx, sy, sz = (size[0] / 2, size[1] / 2, size[2] / 2)
    v = np.array(
        [[x * sx, y * sy, z * sz] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], dtype=float
    )
    # index = x*4 + y*2 + z  with x,y,z in {0,1} meaning -1/+1
    faces = [
        ([4, 5, 7, 6], (1, 0, 0)),
        ([0, 2, 3, 1], (-1, 0, 0)),
        ([2, 6, 7, 3], (0, 1, 0)),
        ([0, 1, 5, 4], (0, -1, 0)),
        ([1, 3, 7, 5], (0, 0, 1)),
        ([0, 4, 6, 2], (0, 0, -1)),
    ]
    return [(v[idx], np.array(n, dtype=float)) for idx, n in faces]


def cylinder_mesh(size, seg=14):
    # Roblox cylinders run along local X: size.x is the length, y/z the diameters
    L, ry, rz = size[0] / 2, size[1] / 2, size[2] / 2
    ring = [(math.cos(2 * math.pi * i / seg), math.sin(2 * math.pi * i / seg)) for i in range(seg)]
    out = []
    for i in range(seg):
        a, b = ring[i], ring[(i + 1) % seg]
        quad = np.array(
            [[-L, a[0] * ry, a[1] * rz], [L, a[0] * ry, a[1] * rz], [L, b[0] * ry, b[1] * rz], [-L, b[0] * ry, b[1] * rz]]
        )
        mid = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        n = np.array([0, mid[0] / ry if ry else 0, mid[1] / rz if rz else 0])
        nn = np.linalg.norm(n)
        out.append((quad, n / nn if nn else n))
    for sx in (-1, 1):
        cap = np.array([[sx * L, c[0] * ry, c[1] * rz] for c in ring])
        out.append((cap if sx == 1 else cap[::-1], np.array([sx, 0, 0], dtype=float)))
    return out


def ball_mesh(size, lat=5, lon=8):
    rx, ry, rz = size[0] / 2, size[1] / 2, size[2] / 2
    out = []

    def pt(i, j):
        th = math.pi * i / lat
        ph = 2 * math.pi * j / lon
        return np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])

    for i in range(lat):
        for j in range(lon):
            q = [pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1)]
            n = sum(q)
            n = n / np.linalg.norm(n)
            out.append((np.array([[p[0] * rx, p[1] * ry, p[2] * rz] for p in q]), n))
    return out


def wedge_mesh(size):
    # a ramp: slopes up toward -z (Roblox wedge: the slope faces +z at the top)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    a = [-sx, -sy, -sz]
    b = [sx, -sy, -sz]
    c = [sx, -sy, sz]
    d = [-sx, -sy, sz]
    e = [-sx, sy, sz]
    f = [sx, sy, sz]
    n_slope = np.array([0, sz, sy], dtype=float)
    n_slope /= np.linalg.norm(n_slope)
    return [
        (np.array([a, d, c, b], dtype=float), np.array([0, -1, 0], dtype=float)),
        (np.array([d, e, f, c], dtype=float), np.array([0, 0, 1], dtype=float)),
        (np.array([a, e, d], dtype=float), np.array([-1, 0, 0], dtype=float)),
        (np.array([b, c, f], dtype=float), np.array([1, 0, 0], dtype=float)),
        (np.array([a, b, f, e], dtype=float), -n_slope),
    ]


MESH = {"Block": block_mesh, "Cylinder": cylinder_mesh, "Ball": ball_mesh, "Wedge": wedge_mesh}


def part_polys(p):
    mesh = MESH.get(p["sh"], block_mesh)(p["s"])
    R = np.array(p["m"], dtype=float).reshape(3, 3)
    pos = np.array(p["p"], dtype=float)
    base = np.array(p["c"], dtype=float)
    neon = p["mat"] == "Neon"
    for verts, n in mesh:
        yield verts @ R.T + pos, R @ n, base, neon


def look_at(eye, target):
    f = target - eye
    f = f / np.linalg.norm(f)
    up = np.array([0.0, 1.0, 0.0])
    r = np.cross(f, up)
    if np.linalg.norm(r) < 1e-6:
        r = np.array([1.0, 0.0, 0.0])
    r = r / np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def render(parts, eye, target, fov, size, ortho=None, ssaa=2, sky=True):
    W, H = size[0] * ssaa, size[1] * ssaa
    img = Image.new("RGB", (W, H), (150, 200, 245))
    if sky:
        d = ImageDraw.Draw(img)
        for y in range(H):
            t = y / H
            d.line([(0, y), (W, y)], fill=(int(120 + 110 * t), int(180 + 60 * t), int(245 + 8 * t)))
    draw = ImageDraw.Draw(img)
    r, u, f = look_at(eye, target)
    polys = []
    focal = (H / 2) / math.tan(math.radians(fov) / 2)
    for p in parts:
        top = p["p"][1] + max(p["s"]) / 2
        ground = (p["p"][1] + abs(p["m"][4]) * p["s"][1] / 2 + p["s"][1] <= 0.6) and max(p["s"][0], p["s"][2]) > 1.5 and p["s"][1] < 1.6
        for verts, n, base, neon in part_polys(p):
            cen = verts.mean(axis=0)
            if ortho is None:
                if float(np.dot(n, eye - cen)) <= 0:
                    continue
            else:
                if float(np.dot(n, -f)) <= 0:
                    continue
            rel = verts - eye
            xc, yc, zc = rel @ r, rel @ u, rel @ f
            if ortho is None:
                if np.any(zc < 0.5):
                    continue
                sx = W / 2 + focal * xc / zc
                sy = H / 2 - focal * yc / zc
                depth = float(np.max(zc))
            else:
                sx = W / 2 + xc * ortho * ssaa
                sy = H / 2 - yc * ortho * ssaa
                depth = float(np.max(zc))
            lam = max(0.0, float(np.dot(n, LIGHT)))
            k = 0.52 + 0.55 * lam
            col = base if neon else np.clip(base * k, 0, 255)
            if neon:
                col = np.clip(base * 1.05 + 20, 0, 255)
            polys.append(((0 if ground else 1), -depth, list(zip(sx.tolist(), sy.tolist())), tuple(int(c) for c in col)))
    polys.sort(key=lambda t: (t[0], t[1]))
    for _, _, pts, col in polys:
        edge = tuple(int(c * 0.72) for c in col)
        draw.polygon(pts, fill=col, outline=edge)
    return img.resize(size, Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parts")
    ap.add_argument("out")
    ap.add_argument("--view", default="top", choices=["top", "spawn", "iso", "custom"])
    ap.add_argument("--eye")
    ap.add_argument("--look")
    ap.add_argument("--fov", type=float, default=60)
    ap.add_argument("--width", type=int, default=1400)
    ap.add_argument("--height", type=int, default=900)
    ap.add_argument("--scale", type=float, default=5.0, help="pixels per stud for the top view")
    ap.add_argument("--cx", type=float, default=0.0)
    ap.add_argument("--cz", type=float, default=-10.0)
    ap.add_argument("--exclude", default="GrassPlate,Hills,FarScenery", help="part groups/names to skip")
    args = ap.parse_args()
    data = json.load(open(args.parts))["parts"]
    skip = set(s for s in args.exclude.split(",") if s)
    parts = [p for p in data if p["n"] not in skip and p["g"] not in skip]
    size = (args.width, args.height)
    if args.eye:
        eye = np.array([float(x) for x in args.eye.split(",")])
        look = np.array([float(x) for x in (args.look or "0,0,0").split(",")])
        img = render(parts, eye, look, args.fov, size)
    elif args.view == "top":
        eye = np.array([args.cx, 300.0, args.cz])
        look = np.array([args.cx, 0.0, args.cz - 0.001])
        # looking straight down with "up" = -z (so -z, the back, is at the top of the picture)
        img = render_top(parts, args.cx, args.cz, size, args.scale)
    elif args.view == "spawn":
        img = render(parts, np.array([0.0, 6.5, 62.0]), np.array([0.0, 3.0, 0.0]), 72, size)
    else:
        img = render(parts, np.array([120.0, 95.0, 150.0]), np.array([0.0, 0.0, -10.0]), 50, size)
    img.save(args.out)
    print("saved", args.out)


def render_top(parts, cx, cz, size, scale, ssaa=2):
    W, H = size[0] * ssaa, size[1] * ssaa
    img = Image.new("RGB", (W, H), (127, 186, 66))
    draw = ImageDraw.Draw(img)
    polys = []
    for p in parts:
        ground = p["p"][1] + p["s"][1] / 2 <= 0.6 and p["s"][1] < 1.6
        for verts, n, base, neon in part_polys(p):
            if n[1] <= 0.05:
                continue
            sx = W / 2 + (verts[:, 0] - cx) * scale * ssaa
            sy = H / 2 + (verts[:, 2] - cz) * scale * ssaa
            lam = max(0.0, float(np.dot(n, LIGHT)))
            k = 0.52 + 0.55 * lam
            col = base if neon else np.clip(base * k, 0, 255)
            if neon:
                col = np.clip(base * 1.05 + 20, 0, 255)
            polys.append(((0 if ground else 1), float(verts[:, 1].max()), list(zip(sx.tolist(), sy.tolist())), tuple(int(c) for c in col)))
    polys.sort(key=lambda t: (t[0], t[1]))
    for _, _, pts, col in polys:
        draw.polygon(pts, fill=col, outline=tuple(int(c * 0.72) for c in col))
    return img.resize(size, Image.LANCZOS)


if __name__ == "__main__":
    main()
