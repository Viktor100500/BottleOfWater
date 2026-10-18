"""Composes App Store screenshots (6.9", 1320x2868) from raw simulator captures.

Raw captures come from the Debug build launched with demo data, e.g.
  xcrun simctl launch <device> com.vlasov.bottleofwater -demoData YES -screen history -range month
  xcrun simctl io <device> screenshot raw/en-history.png
(screens: today, add, history, reminders; see App/Sources/DemoData.swift).

Usage: python3 scripts/make_screenshots.py <raw_dir> <out_dir>
Requires Pillow and macOS (uses the system SF Pro font).
"""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
FONT = '/System/Library/Fonts/SFNS.ttf'

CAPTIONS = {
    'en': {
        'today': ('Log water', 'in one tap'),
        'add': ('Any amount,', 'even after the fact'),
        'history': ('See your streaks', 'and trends'),
        'reminders': ('Reminders that', 'know when to stay quiet'),
    },
    'ru': {
        'today': ('Вода —', 'в одно касание'),
        'add': ('Любой объём,', 'даже задним числом'),
        'history': ('Серии и тренды', 'за любой период'),
        'reminders': ('Напоминания,', 'которые не раздражают'),
    },
}
ORDER = ['today', 'add', 'history', 'reminders']


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def background():
    small = Image.new('RGB', (132, 287))
    top, bottom = (18, 48, 90), (6, 10, 19)
    for y in range(small.height):
        for x in range(small.width):
            d = math.hypot((x - 66) / 132, (y + 20) / 287 * 1.4)
            t = min(1, d * 1.15)
            small.putpixel((x, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return small.resize((W, H), Image.BICUBIC)


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = img.convert('RGBA')
    out.putalpha(mask)
    return out


def compose(raw: Path, caption, out: Path):
    canvas = background().convert('RGBA')
    draw = ImageDraw.Draw(canvas)

    title, subtitle = caption
    size = 112
    while size > 60 and max(draw.textlength(t, font=font(size, 'Heavy')) for t in caption) > W - 140:
        size -= 4
    f = font(size, 'Heavy')
    y = 150 + (112 - size)
    for text, color in [(title, (242, 246, 255)), (subtitle, (34, 211, 238))]:
        w = draw.textlength(text, font=f)
        draw.text(((W - w) / 2, y), text, font=f, fill=color)
        y += int(size * 1.18)

    shot = Image.open(raw).convert('RGB')
    width = 1080
    shot = shot.resize((width, int(shot.height * width / shot.width)), Image.LANCZOS)
    framed = rounded(shot, 96)
    x, top = (W - width) // 2, 520

    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).rounded_rectangle([x - 10, top - 10, x + width + 10, top + framed.height + 10], radius=110, fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    canvas = Image.alpha_composite(canvas, Image.merge('RGBA', [Image.new('L', (W, H), 34)] * 1
                                                       + [Image.new('L', (W, H), 211), Image.new('L', (W, H), 238), glow]))
    border = Image.new('RGBA', (width + 12, framed.height + 12), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle([0, 0, width + 11, framed.height + 11], radius=102,
                                             outline=(148, 184, 255, 70), width=6)
    canvas.alpha_composite(framed, (x, top))
    canvas.alpha_composite(border, (x - 6, top - 6))
    canvas.convert('RGB').save(out, quality=92, optimize=True)


def main():
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    for lang, captions in CAPTIONS.items():
        target = out_dir / lang
        target.mkdir(parents=True, exist_ok=True)
        for index, screen in enumerate(ORDER, start=1):
            raw = raw_dir / f'{lang}-{screen}.png'
            if raw.exists():
                compose(raw, captions[screen], target / f'{index:02d}-{screen}.jpg')
                print('wrote', target / f'{index:02d}-{screen}.jpg')


if __name__ == '__main__':
    main()
