#!/usr/bin/env python3
"""
Generate filled-path SF Symbol v4.0 SVGs for HalfUnit drink presets.
Ensures ZERO 'stroke' attributes inside <g id="Symbols">.
Every element is a filled <path fill="#000000">.
"""

import math
import os
import subprocess

def capsule_path(x1, y1, x2, y2, width):
    """Generates a filled closed capsule path along a line segment."""
    dx = x2 - x1
    dy = y2 - y1
    length = math.hypot(dx, dy)
    r = width / 2.0
    if length < 1e-4:
        return f'<path fill="#000000" d="M {x1-r:.2f} {y1:.2f} A {r:.2f} {r:.2f} 0 1 1 {x1+r:.2f} {y1:.2f} A {r:.2f} {r:.2f} 0 1 1 {x1-r:.2f} {y1:.2f} Z" />'
    ux = dx / length
    uy = dy / length
    nx = -uy * r
    ny = ux * r
    p1x, p1y = x1 + nx, y1 + ny
    p2x, p2y = x2 + nx, y2 + ny
    p3x, p3y = x2 - nx, y2 - ny
    p4x, p4y = x1 - nx, y1 - ny
    d = (
        f"M {p1x:.2f} {p1y:.2f} "
        f"L {p2x:.2f} {p2y:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {p3x:.2f} {p3y:.2f} "
        f"L {p4x:.2f} {p4y:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {p1x:.2f} {p1y:.2f} Z"
    )
    return f'<path fill="#000000" d="{d}" />'

def rect_outline_path(cx, cy, w, h, thickness, angle_deg=0.0):
    """Generates an outlined hollow rectangle path rotated by angle_deg."""
    hw = w / 2.0
    hh = h / 2.0
    t = thickness
    rad = math.radians(angle_deg)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)

    def rot(x, y):
        rx_ = cx + (x * cos_a - y * sin_a)
        ry_ = cy + (x * sin_a + y * cos_a)
        return f"{rx_:.2f} {ry_:.2f}"

    outer = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
    ihw = hw - t
    ihh = hh - t
    inner = [(-ihw, -ihh), (-ihw, ihh), (ihw, ihh), (ihw, -ihh)]

    d = f"M {rot(*outer[0])} L {rot(*outer[1])} L {rot(*outer[2])} L {rot(*outer[3])} Z "
    d += f"M {rot(*inner[0])} L {rot(*inner[1])} L {rot(*inner[2])} L {rot(*inner[3])} Z"
    return f'<path fill="#000000" fill-rule="evenodd" d="{d}" />'

def make_svg(m_paths, min_x, max_x):
    margin = 14.0
    left_m = round(min_x - margin, 1)
    right_m = round(max_x + margin, 1)

    # Scale S (0.85 around 500,200 -> 150,200)
    left_s = round(150.0 + (left_m - 500.0) * 0.85, 1)
    right_s = round(150.0 + (right_m - 500.0) * 0.85, 1)

    # Scale L (1.20 around 500,200 -> 850,200)
    left_l = round(850.0 + (left_m - 500.0) * 1.20, 1)
    right_l = round(850.0 + (right_m - 500.0) * 1.20, 1)

    paths_joined = "\n      ".join(m_paths)

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" viewBox="0 0 1000 1000">
  <g id="Notes">
    <text id="template-version">Template v.4.0</text>
  </g>
  <g id="Guides">
    <line id="Baseline-S" x1="0" y1="200.0" x2="300" y2="200.0" stroke="#000000" />
    <line id="Capline-S" x1="0" y1="115.0" x2="300" y2="115.0" stroke="#000000" />
    <line id="left-margin-Regular-S" x1="{left_s}" y1="50" x2="{left_s}" y2="250" stroke="#000000" />
    <line id="right-margin-Regular-S" x1="{right_s}" y1="50" x2="{right_s}" y2="250" stroke="#000000" />

    <line id="Baseline-M" x1="350" y1="200.0" x2="650" y2="200.0" stroke="#000000" />
    <line id="Capline-M" x1="350" y1="100.0" x2="650" y2="100.0" stroke="#000000" />
    <line id="left-margin-Regular-M" x1="{left_m}" y1="50" x2="{left_m}" y2="250" stroke="#000000" />
    <line id="right-margin-Regular-M" x1="{right_m}" y1="50" x2="{right_m}" y2="250" stroke="#000000" />

    <line id="Baseline-L" x1="700" y1="200.0" x2="1000" y2="200.0" stroke="#000000" />
    <line id="Capline-L" x1="700" y1="80.0" x2="1000" y2="80.0" stroke="#000000" />
    <line id="left-margin-Regular-L" x1="{left_l}" y1="50" x2="{left_l}" y2="250" stroke="#000000" />
    <line id="right-margin-Regular-L" x1="{right_l}" y1="50" x2="{right_l}" y2="250" stroke="#000000" />
  </g>
  <g id="Symbols">
    <g id="Regular-S" transform="translate(150.0, 200.0) scale(0.8500) translate(-500.0, -200.0)">
      {paths_joined}
    </g>
    <g id="Regular-M">
      {paths_joined}
    </g>
    <g id="Regular-L" transform="translate(850.0, 200.0) scale(1.2000) translate(-500.0, -200.0)">
      {paths_joined}
    </g>
  </g>
</svg>
"""

# ==============================================================================
# 1. halfunit.wine.glass (Full-size wine glass: bowl + stem + foot on baseline)
# ==============================================================================
def make_wine_glass():
    # Foot: flat foot resting on baseline y = 200, width 56 (472 to 528)
    foot = capsule_path(474.75, 197.25, 525.25, 197.25, 5.5)
    # Stem: vertical bar connecting bowl to foot
    stem = '<path fill="#000000" d="M 497.25 152 L 502.75 152 L 502.75 198 L 497.25 198 Z" />'
    # Bowl: classic tulip silhouette. Rim at y = 104, base at y = 152
    bowl = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 476 104 '
        'A 2.75 2.75 0 0 1 481.5 104 '
        'C 481.5 116 475.5 125 475.5 133 '
        'C 475.5 142 490 148.5 500 148.5 '
        'C 510 148.5 524.5 142 524.5 133 '
        'C 524.5 125 518.5 116 518.5 104 '
        'A 2.75 2.75 0 0 1 524 104 '
        'C 524 116 530 125 530 134 '
        'C 530 146 512 154 502.75 154 '
        'L 497.25 154 '
        'C 488 154 470 146 470 134 '
        'C 470 125 476 116 476 104 Z" />'
    )
    # Liquid line: higher in wine.glass (y = 126)
    liquid = capsule_path(476.0, 126.0, 524.0, 126.0, 5.0)
    return [foot, stem, bowl, liquid], 470.0, 530.0

# ==============================================================================
# 2. halfunit.wine.small (Small wine glass: ~80% size, also standing on baseline)
# ==============================================================================
def make_wine_small():
    # Scaled around (500, 200) by 0.8:
    # Foot: width 56 * 0.8 = 44.8 (477.6 to 522.4), rests on y = 200
    foot = capsule_path(479.8, 197.8, 520.2, 197.8, 4.4)
    # Stem: width 4.4, from y = 161.6 to y = 198
    stem = '<path fill="#000000" d="M 497.8 161.6 L 502.2 161.6 L 502.2 198 L 497.8 198 Z" />'
    # Bowl: rim at y = 123.2, base at y = 161.6
    bowl = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 480.8 123.2 '
        'A 2.2 2.2 0 0 1 485.2 123.2 '
        'C 485.2 132.8 480.4 140 480.4 146.4 '
        'C 480.4 153.6 492 158.8 500 158.8 '
        'C 508 158.8 519.6 153.6 519.6 146.4 '
        'C 519.6 140 514.8 132.8 514.8 123.2 '
        'A 2.2 2.2 0 0 1 519.2 123.2 '
        'C 519.2 132.8 524 140 524 147.2 '
        'C 524 156.8 509.6 163.2 502.2 163.2 '
        'L 497.8 163.2 '
        'C 490.4 163.2 476 156.8 476 147.2 '
        'C 476 140 480.8 132.8 480.8 123.2 Z" />'
    )
    # Liquid line: lower in wine.small (y = 150.0)
    liquid = capsule_path(481.5, 150.0, 518.5, 150.0, 4.0)
    return [foot, stem, bowl, liquid], 476.0, 524.0

# ==============================================================================
# 3. halfunit.beer.bottle (0.33 l bottle: neck, cap, label band, base on 200)
# ==============================================================================
def make_beer_bottle():
    # Crown cap at y = 74 to 79
    cap = capsule_path(492.0, 76.5, 508.0, 76.5, 5.0)
    # Bottle body & neck hollow contour
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 492.5 79 '
        'L 492.5 112 '
        'C 492.5 124 478 128 478 138 '
        'L 478 196 '
        'C 478 198.5 480 200 482.5 200 '
        'L 517.5 200 '
        'C 520 200 522 198.5 522 196 '
        'L 522 138 '
        'C 522 128 507.5 124 507.5 112 '
        'L 507.5 79 '
        'A 2.75 2.75 0 0 0 502 79 '
        'L 502 110 '
        'C 502 122 483.5 126 483.5 136 '
        'L 483.5 194.5 '
        'L 516.5 194.5 '
        'L 516.5 136 '
        'C 516.5 126 498 122 498 110 '
        'L 498 79 '
        'A 2.75 2.75 0 0 0 492.5 79 Z" />'
    )
    # Label band lines
    label_top = capsule_path(481.5, 154.0, 518.5, 154.0, 5.0)
    label_bot = capsule_path(481.5, 176.0, 518.5, 176.0, 5.0)
    return [cap, body, label_top, label_bot], 478.0, 522.0

# ==============================================================================
# 4. halfunit.beer.mug (0.5 l mug: foam top, handle, flutes, base on 200)
# ==============================================================================
def make_beer_mug():
    # Mug body hollow contour
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 464 106 '
        'L 464 196 '
        'C 464 198.5 466.5 200 469 200 '
        'L 521 200 '
        'C 523.5 200 526 198.5 526 196 '
        'L 526 106 '
        'A 3 3 0 0 0 520 106 '
        'L 520 194 '
        'L 470 194 '
        'L 470 106 '
        'A 3 3 0 0 0 464 106 Z" />'
    )
    # Foam head at top (y = 96 to 106)
    foam = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 464 106 '
        'C 464 98 474 94 482 97 '
        'C 488 93 498 93 504 97 '
        'C 512 94 526 98 526 106 '
        'C 526 110 520 110 518 106 '
        'C 516 100 504 99 499 103 '
        'C 493 99 481 100 479 106 '
        'C 477 110 464 110 464 106 Z" />'
    )
    # Handle on right (y = 122 to 176)
    handle = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 526 122 '
        'C 554 122 554 176 526 176 '
        'L 526 170 '
        'C 547 170 547 128 526 128 Z" />'
    )
    # Flutes (vertical ribs)
    flute1 = capsule_path(484.0, 126.0, 484.0, 180.0, 5.0)
    flute2 = capsule_path(506.0, 126.0, 506.0, 180.0, 5.0)
    return [body, foam, handle, flute1, flute2], 464.0, 554.0

# ==============================================================================
# 5. halfunit.shot (Short tapered glass: heavy base line, liquid line, base on 200)
# ==============================================================================
def make_shot():
    # Tapered hollow glass body: rim at y = 132, base at y = 200
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 473 132 '
        'L 480 196 '
        'C 480.5 198.5 482 200 484 200 '
        'L 516 200 '
        'C 518 200 519.5 198.5 520 196 '
        'L 527 132 '
        'A 2.75 2.75 0 0 0 521.5 132 '
        'L 514.8 194.5 '
        'L 485.2 194.5 '
        'L 478.5 132 '
        'A 2.75 2.75 0 0 0 473 132 Z" />'
    )
    # Heavy base line
    base_line = capsule_path(482.0, 186.0, 518.0, 186.0, 5.5)
    # Liquid line
    liquid_line = capsule_path(476.5, 154.0, 523.5, 154.0, 5.0)
    return [body, base_line, liquid_line], 473.0, 527.0

# ==============================================================================
# 6. halfunit.longdrink (Highball tumbler: tall cylinder, base, ice cube, straw)
# ==============================================================================
def make_longdrink():
    # Tall tumbler hollow body: rim at y = 100, base at y = 200
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 474 100 '
        'L 476 196 '
        'C 476.5 198.5 478 200 480 200 '
        'L 520 200 '
        'C 522 200 523.5 198.5 524 196 '
        'L 526 100 '
        'A 2.75 2.75 0 0 0 520.5 100 '
        'L 518.5 194.5 '
        'L 481.5 194.5 '
        'L 479.5 100 '
        'A 2.75 2.75 0 0 0 474 100 Z" />'
    )
    # Heavy base line
    base_line = capsule_path(478.0, 190.0, 522.0, 190.0, 5.5)
    # Liquid line at y = 124
    liquid_line = capsule_path(476.0, 124.0, 524.0, 124.0, 5.0)
    # Ice cube: tilted hollow square
    ice_cube = rect_outline_path(497.0, 155.0, 18.0, 18.0, 4.5, angle_deg=15.0)
    # Straw: extending from inside bottom to up-right through rim
    straw1 = capsule_path(490.0, 180.0, 522.0, 96.0, 5.0)
    straw2 = capsule_path(522.0, 96.0, 544.0, 65.0, 5.0)
    return [body, base_line, liquid_line, ice_cube, straw1, straw2], 474.0, 546.0

def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    assets_dir = os.path.join(root, "Resources", "Assets.xcassets")

    symbols = {
        "halfunit.wine.glass": make_wine_glass(),
        "halfunit.wine.small": make_wine_small(),
        "halfunit.beer.bottle": make_beer_bottle(),
        "halfunit.beer.mug": make_beer_mug(),
        "halfunit.shot": make_shot(),
        "halfunit.longdrink": make_longdrink(),
    }

    for name, (paths, min_x, max_x) in symbols.items():
        svg_content = make_svg(paths, min_x, max_x)
        symbolset_dir = os.path.join(assets_dir, f"{name}.symbolset")
        os.makedirs(symbolset_dir, exist_ok=True)
        svg_path = os.path.join(symbolset_dir, "symbol.svg")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(svg_content)
        print(f"Generated {name} at {svg_path} (width: {max_x - min_x:.1f})")

if __name__ == "__main__":
    main()
