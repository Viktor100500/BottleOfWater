"""Renders the Bottle of Water app icon (default, dark, tinted) at 4x and downsamples.

Usage: python3 scripts/make_icon.py App/Resources/Assets.xcassets/AppIcon.appiconset
Requires Pillow."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4                 # supersampling
N = 1024 * S
out_dir = sys.argv[1]

def px(v): return int(v * S)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def hexc(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

BG_TOP, BG_BOTTOM = hexc('#12305A'), hexc('#060A13')
AQUA, BLUE, SKY = hexc('#22D3EE'), hexc('#2563EB'), hexc('#38BDF8')

def vertical_gradient(size, top, bottom, y0=0, y1=None):
    w, h = size
    y1 = h if y1 is None else y1
    grad = Image.new('RGB', (1, h))
    for y in range(h):
        t = min(1, max(0, (y - y0) / max(1, y1 - y0)))
        grad.putpixel((0, y), lerp(top, bottom, t))
    return grad.resize((w, h))

def background():
    img = Image.new('RGB', (N, N))
    cx, cy, r = N * 0.5, N * 0.18, N * 1.05
    small = 256
    bg = Image.new('RGB', (small, small))
    for y in range(small):
        for x in range(small):
            d = math.hypot(x / small * N - cx, y / small * N - cy) / r
            bg.putpixel((x, y), lerp(BG_TOP, BG_BOTTOM, min(1, d ** 0.9)))
    img.paste(bg.resize((N, N), Image.BICUBIC))
    # soft aqua glow behind the water
    glow = Image.new('L', (N, N), 0)
    ImageDraw.Draw(glow).ellipse([px(250), px(470), px(774), px(990)], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(px(110)))
    img = Image.composite(Image.new('RGB', (N, N), hexc('#0E7490')), img, glow)
    return img

def smooth(mask, radius, threshold=128):
    """Blur + threshold: rounds both convex and concave corners (fillets the neck)."""
    return mask.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: 255 if v >= threshold else 0)

def bottle_mask():
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([px(300), px(352), px(724), px(892)], radius=px(132), fill=255)   # body
    d.rounded_rectangle([px(426), px(214), px(598), px(420)], radius=px(46), fill=255)    # neck
    # shoulders: a trapezoid that blends neck into body
    d.polygon([(px(426), px(330)), (px(598), px(330)), (px(690), px(420)), (px(334), px(420))], fill=255)
    m = smooth(m, px(14))
    return m.filter(ImageFilter.GaussianBlur(S * 0.6))

def erode(mask, amount):
    return smooth(mask, px(amount), threshold=235)

def wave_mask(level_y, amp, wavelength, phase):
    m = Image.new('L', (N, N), 0)
    pts = []
    for xi in range(0, 1025, 4):
        y = level_y + amp * math.sin((xi / wavelength) * 2 * math.pi + phase)
        pts.append((px(xi), px(y)))
    pts += [(N, N), (0, N)]
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m

def render(variant):
    if variant == 'default':
        canvas = background().convert('RGBA')
    else:
        canvas = Image.new('RGBA', (N, N), (0, 0, 0, 0))

    tinted = variant == 'tinted'
    body = bottle_mask()
    inner = erode(body, 12)

    # glass
    glass_alpha = 42 if variant == 'default' else 70
    glass = Image.new('RGBA', (N, N), (255, 255, 255, 0) if tinted else (190, 222, 255, 0))
    glass.putalpha(body.point(lambda v: v * glass_alpha // 255))
    canvas = Image.alpha_composite(canvas, glass)

    # rim (outline): body minus inner
    rim = ImageChops.subtract(body, erode(body, 7))
    rim_layer = Image.new('RGBA', (N, N), (220, 238, 255, 0))
    rim_layer.putalpha(rim.point(lambda v: v * 150 // 255))
    canvas = Image.alpha_composite(canvas, rim_layer)

    # water
    water = ImageChops.multiply(inner, wave_mask(560, 18, 300, 0.9))
    if tinted:
        fill = Image.new('RGB', (N, N), (235, 235, 235))
    else:
        fill = vertical_gradient((N, N), AQUA, BLUE, y0=px(540), y1=px(880))
    wl = fill.convert('RGBA'); wl.putalpha(water)
    canvas = Image.alpha_composite(canvas, wl)

    # surface highlight
    surface = ImageChops.subtract(water, ImageChops.multiply(inner, wave_mask(574, 18, 300, 0.9)))
    sl = Image.new('RGBA', (N, N), (255, 255, 255, 0)); sl.putalpha(surface.point(lambda v: v * 170 // 255))
    canvas = Image.alpha_composite(canvas, sl)

    # bubbles
    bubbles = Image.new('L', (N, N), 0)
    bd = ImageDraw.Draw(bubbles)
    for cx, cy, r in [(468, 690, 14), (590, 760, 22), (520, 830, 11), (632, 650, 9)]:
        bd.ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=255)
    bubbles = ImageChops.multiply(bubbles, water).filter(ImageFilter.GaussianBlur(S))
    bl = Image.new('RGBA', (N, N), (255, 255, 255, 0)); bl.putalpha(bubbles.point(lambda v: v * 110 // 255))
    canvas = Image.alpha_composite(canvas, bl)

    # glass highlight (left)
    hl = Image.new('L', (N, N), 0)
    ImageDraw.Draw(hl).rounded_rectangle([px(352), px(470), px(384), px(800)], radius=px(16), fill=255)
    hl = ImageChops.multiply(hl, inner).filter(ImageFilter.GaussianBlur(S * 2))
    hll = Image.new('RGBA', (N, N), (255, 255, 255, 0)); hll.putalpha(hl.point(lambda v: v * 90 // 255))
    canvas = Image.alpha_composite(canvas, hll)

    # cap
    cap = Image.new('L', (N, N), 0)
    ImageDraw.Draw(cap).rounded_rectangle([px(408), px(150), px(616), px(244)], radius=px(34), fill=255)
    cap = cap.filter(ImageFilter.GaussianBlur(S * 0.6))
    cap_fill = Image.new('RGB', (N, N), (250, 250, 250)) if tinted else vertical_gradient((N, N), AQUA, SKY, px(150), px(244))
    cl = cap_fill.convert('RGBA'); cl.putalpha(cap)
    # shadow under cap
    shadow = ImageChops.offset(cap, 0, px(10)).filter(ImageFilter.GaussianBlur(px(8)))
    shl = Image.new('RGBA', (N, N), (0, 0, 0, 0)); shl.putalpha(ImageChops.multiply(shadow, body).point(lambda v: v * 90 // 255))
    canvas = Image.alpha_composite(canvas, shl)
    canvas = Image.alpha_composite(canvas, cl)

    img = canvas.resize((1024, 1024), Image.LANCZOS)
    if variant == 'default':
        img = img.convert('RGB')          # App Store icons must not have alpha
    elif tinted:
        img = img.convert('LA').convert('RGBA')
    return img

for name, variant in [('icon.png', 'default'), ('icon-dark.png', 'dark'), ('icon-tinted.png', 'tinted')]:
    render(variant).save(f'{out_dir}/{name}')
    print('wrote', name)
