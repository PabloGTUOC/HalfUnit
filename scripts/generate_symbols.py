#!/usr/bin/env python3
"""
Generate filled-path SF Symbol v4.0 SVGs for HalfUnit drink presets.
Ensures:
1. One style: all six are outline style (closed filled contour paths with single horizontal liquid line).
2. Visual weight: outline thickness ≈ 9-10% of cap height (cap height = 100, thickness = 9.5).
3. Optical size: symbols span from baseline to capline (tall symbols up to 15% above; shot/small wine ~74% of tallest).
4. ZERO 'stroke' attributes inside <g id="Symbols">. Guide lines in <g id="Guides"> retain strokes (exactly 12).
"""

import math
import os

def capsule_path(x1, y1, x2, y2, width):
    """Generates a filled closed capsule path along a line segment with round ends."""
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
# 1. halfunit.wine.glass (Full-size wine glass: 0.2 l)
# Spans baseline (y=200) to capline (y=98, height=102). Width=66.
# Outline thickness=9.5. Higher liquid line at y=124.
# ==============================================================================
def make_wine_glass():
    # Foot: flat capsule resting on y=200, width=60 (470 to 530)
    foot = capsule_path(474.75, 195.25, 525.25, 195.25, 9.5)
    # Stem: vertical solid bar width=9.5 (495.25 to 504.75), y=145 to 195
    stem = '<path fill="#000000" d="M 495.25 145 L 504.75 145 L 504.75 195 L 495.25 195 Z" />'
    # Bowl: tulip silhouette. Outer rim at y=98, widest at y=132 (w=66), base at y=145
    # Wall thickness = 9.5. Rim caps rounded with radius 4.75.
    bowl = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 473 98 '
        'A 4.75 4.75 0 0 1 482.5 98 '
        'C 482.5 110 476.5 120 476.5 130 '
        'C 476.5 140 488 145 495.25 145 '
        'L 504.75 145 '
        'C 512 145 523.5 140 523.5 130 '
        'C 523.5 120 517.5 110 517.5 98 '
        'A 4.75 4.75 0 0 1 527 98 '
        'C 527 112 533 122 533 132 '
        'C 533 146 515 154.5 504.75 154.5 '
        'L 495.25 154.5 '
        'C 485 154.5 467 146 467 132 '
        'C 467 122 473 112 473 98 Z" />'
    )
    # Single horizontal liquid line at y=124
    liquid = capsule_path(476.0, 124.0, 524.0, 124.0, 9.0)
    return [foot, stem, bowl, liquid], 467.0, 533.0

# ==============================================================================
# 2. halfunit.wine.small (Small wine glass: 0.1 l)
# Spans baseline (y=200) to y=108 (height=92). Width=58.
# Outline thickness=9.5. Lower liquid line at y=142.
# ==============================================================================
def make_wine_small():
    # Foot: flat capsule on y=200, width=54 (473 to 527)
    foot = capsule_path(477.75, 195.25, 522.25, 195.25, 9.5)
    # Stem: vertical bar width=9.5, y=152 to 195
    stem = '<path fill="#000000" d="M 495.25 152 L 504.75 152 L 504.75 195 L 495.25 195 Z" />'
    # Bowl: rim at y=108, widest at y=140 (w=58), base at y=152
    bowl = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 476 108 '
        'A 4.75 4.75 0 0 1 485.5 108 '
        'C 485.5 118 480.5 128 480.5 136 '
        'C 480.5 146 490 152 495.25 152 '
        'L 504.75 152 '
        'C 510 152 519.5 146 519.5 136 '
        'C 519.5 128 514.5 118 514.5 108 '
        'A 4.75 4.75 0 0 1 524 108 '
        'C 524 120 529 130 529 138 '
        'C 529 152 514 161.5 504.75 161.5 '
        'L 495.25 161.5 '
        'C 486 161.5 471 152 471 138 '
        'C 471 130 476 120 476 108 Z" />'
    )
    # Single horizontal liquid line at y=142 (lower pour)
    liquid = capsule_path(478.0, 142.0, 522.0, 142.0, 9.0)
    return [foot, stem, bowl, liquid], 471.0, 529.0

# ==============================================================================
# 3. halfunit.shot (Shot glass: 2-4 cl)
# Spans baseline (y=200) to y=108 (height=92). Width=62 (469 to 531).
# Tapered hollow outline + heavy base + single liquid line at y=142.
# ==============================================================================
def make_shot():
    # Heavy solid base bar on baseline y=200 (thickness 10.0, y=190 to 200)
    base = (
        '<path fill="#000000" d="'
        'M 474 190 '
        'L 526 190 '
        'L 526 195 '
        'C 526 198 523.5 200 520.5 200 '
        'L 479.5 200 '
        'C 476.5 200 474 198 474 195 Z" />'
    )
    # Heavy base line just above base
    base_line = capsule_path(476.0, 182.0, 524.0, 182.0, 7.5)
    # Tapered hollow body outline: rim at y=108 (w=62), wall thickness=9.5
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 469 108 '
        'A 4.75 4.75 0 0 1 478.5 108 '
        'L 483.5 186 '
        'L 516.5 186 '
        'L 521.5 108 '
        'A 4.75 4.75 0 0 1 531 108 '
        'L 526 188 '
        'C 526 189 525 190 524 190 '
        'L 476 190 '
        'C 475 190 474 189 474 188 Z" />'
    )
    # Single horizontal liquid line at y=142
    liquid = capsule_path(475.0, 142.0, 525.0, 142.0, 9.0)
    return [base, base_line, body, liquid], 469.0, 531.0

# ==============================================================================
# 4. halfunit.beer.bottle (0.33 l bottle)
# OUTLINE STYLE: closed outline drawn as filled contour paths (w=60, h=124).
# Spans baseline (y=200) to cap (y=76). Outline thickness=9.5.
# Single horizontal liquid line at y=152.
# ==============================================================================
def make_beer_bottle():
    # Crown cap at top (y=76 to 85, width=32, 484 to 516)
    cap = capsule_path(488.75, 80.5, 511.25, 80.5, 9.0)
    # Hollow bottle outline: body w=60 (470 to 530), neck w=28 (486 to 514).
    # Wall thickness=9.5 throughout.
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        # Outer contour (clockwise)
        'M 486 85 '
        'L 486 110 '
        'C 486 122 470 126 470 138 '
        'L 470 192 '
        'C 470 196.5 473.5 200 478 200 '
        'L 522 200 '
        'C 526.5 200 530 196.5 530 192 '
        'L 530 138 '
        'C 530 126 514 122 514 110 '
        'L 514 85 '
        'Z '
        # Inner contour (counter-clockwise)
        'M 495.5 87 '
        'L 504.5 87 '
        'L 504.5 110 '
        'C 504.5 120 520.5 126 520.5 138 '
        'L 520.5 190.5 '
        'L 479.5 190.5 '
        'L 479.5 138 '
        'C 479.5 126 495.5 120 495.5 110 '
        'Z" />'
    )
    # Single horizontal liquid line inside bottle body at y=152
    liquid = capsule_path(479.5, 152.0, 520.5, 152.0, 9.0)
    return [cap, body, liquid], 470.0, 530.0

# ==============================================================================
# 5. halfunit.beer.mug (0.5 l mug)
# OUTLINE STYLE: closed outline body (w=62), foam top (y=94, h=106), handle (to x=556).
# Outline thickness=9.5. Single horizontal liquid line at y=138.
# ==============================================================================
def make_beer_mug():
    # Mug body hollow outline: 464 to 526, baseline y=200, rim y=108.
    # Thickness = 9.5
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        # Outer
        'M 464 108 '
        'L 464 192 '
        'C 464 196.5 467.5 200 472 200 '
        'L 518 200 '
        'C 522.5 200 526 196.5 526 192 '
        'L 526 108 '
        'Z '
        # Inner
        'M 473.5 112 '
        'L 516.5 112 '
        'L 516.5 190.5 '
        'L 473.5 190.5 '
        'Z" />'
    )
    # Foam head across top rim (y=94 to 108)
    foam = (
        '<path fill="#000000" d="'
        'M 464 108 '
        'C 464 99 474 94 482 96 '
        'C 488 92 498 92 504 96 '
        'C 512 94 526 99 526 108 '
        'C 526 112 518 112 516 108 '
        'C 514 102 504 101 500 105 '
        'C 494 101 482 102 480 108 '
        'C 478 112 464 112 464 108 Z" />'
    )
    # Handle on right side (y=122 to 178, w=30, thickness=9.5)
    handle = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 526 122 '
        'C 556 122 556 178 526 178 '
        'L 526 168.5 '
        'C 544 168.5 544 131.5 526 131.5 Z" />'
    )
    # Single horizontal liquid line at y=138
    liquid = capsule_path(473.5, 138.0, 516.5, 138.0, 9.0)
    return [body, foam, handle, liquid], 464.0, 556.0

# ==============================================================================
# 6. halfunit.longdrink (Highball tumbler)
# OUTLINE STYLE: tall cylinder (w=56, h=104 to rim, h=126 to straw top).
# Outline thickness=9.5. Angled straw. Single horizontal liquid line at y=126.
# ==============================================================================
def make_longdrink():
    # Heavy base on baseline y=200
    base = (
        '<path fill="#000000" d="'
        'M 472 191 '
        'L 528 191 '
        'L 528 195 '
        'C 528 198 525.5 200 522.5 200 '
        'L 477.5 200 '
        'C 474.5 200 472 198 472 195 Z" />'
    )
    # Tall cylinder hollow outline: rim at y=96 (w=56, 472 to 528)
    body = (
        '<path fill="#000000" fill-rule="evenodd" d="'
        'M 472 96 '
        'A 4.75 4.75 0 0 1 481.5 96 '
        'L 481.5 190.5 '
        'L 518.5 190.5 '
        'L 518.5 96 '
        'A 4.75 4.75 0 0 1 528 96 '
        'L 528 191 '
        'L 472 191 Z" />'
    )
    # Angled straw extending from inside glass through rim up to (536, 74)
    straw = capsule_path(494.0, 172.0, 536.0, 74.0, 8.5)
    # Single horizontal liquid line at y=126
    liquid = capsule_path(481.5, 126.0, 518.5, 126.0, 9.0)
    return [base, body, straw, liquid], 472.0, 538.0

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
