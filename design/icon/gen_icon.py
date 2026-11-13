# Generates the NexVault app icon: a brass seal rosette (same shape language as the
# workspace seal) with a keyhole cut through it, on a verdigris ground.
import math, sys
GROUND, GROUND2, BRASS, BRASS_HI = "#173D3A", "#0F2C2A", "#C8963A", "#E2B661"

def rosette(cx, cy, r, depth, lobes, rot=0, steps=360):
    pts = []
    for i in range(steps):
        a = i / steps * 2 * math.pi
        rr = r - depth / 2 + depth / 2 * math.cos(a * lobes)
        pts.append(f"{cx + rr*math.cos(a+rot):.1f} {cy + rr*math.sin(a+rot):.1f}")
    return "M" + "L".join(pts) + "Z"

def keyhole(cx, cy, s):
    # circle head + tapered slot, as one path (even-odd cut)
    r = 62*s; top = cy - 40*s
    return (f"M{cx} {top-r} a{r} {r} 0 1 1 -0.1 0 Z "
            f"M{cx-30*s} {top+30*s} L{cx+30*s} {top+30*s} L{cx+48*s} {top+190*s} L{cx-48*s} {top+190*s} Z")

def svg(full=True, fg_only=False):
    c = 512
    seal = rosette(c, c, 372, 16, 18, rot=math.pi/18)
    ring_dots = "".join(
        f'<circle cx="{c+296*math.cos(i/6*2*math.pi-math.pi/2):.1f}" cy="{c+296*math.sin(i/6*2*math.pi-math.pi/2):.1f}" r="25" fill="{GROUND}"/>'
        for i in range(6))
    bg = "" if fg_only else (
        f'<defs><radialGradient id="g" cx="50%" cy="38%" r="70%"><stop offset="0" stop-color="{GROUND}"/>'
        f'<stop offset="1" stop-color="{GROUND2}"/></radialGradient>'
        f'<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BRASS_HI}"/><stop offset="1" stop-color="{BRASS}"/></linearGradient></defs>'
        f'<rect width="1024" height="1024" {"rx=\"224\"" if full else ""} fill="url(#g)"/>')
    defs = "" if not fg_only else (f'<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BRASS_HI}"/><stop offset="1" stop-color="{BRASS}"/></linearGradient></defs>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{bg}{defs}'
            f'<path d="{seal}" fill="url(#b)"/>'
                        f'{ring_dots}'
            f'<path d="{keyhole(c, c+6, 1.42)}" fill="{GROUND}"/></svg>')

def scaled_fg():
    # adaptive foreground: shrink artwork into the 66% safe zone
    inner = svg(fg_only=True).split(">",1)[1].rsplit("</svg>",1)[0]
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'<g transform="translate(512 512) scale(0.84) translate(-512 -512)">{inner}</g></svg>')

open("icon.svg","w").write(svg(full=True))
open("icon_square.svg","w").write(svg(full=False))
open("icon_fg.svg","w").write(scaled_fg())
open("icon_mono.svg","w").write(scaled_fg().replace("url(#b)","#000"))
