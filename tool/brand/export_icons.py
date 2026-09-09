"""Export platform icons from the approved sundial PNG. Requires Pillow."""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/brand/source/sundial.png'
PREVIEW = ROOT / 'build/brand'


def opaque_artwork(tile):
    """Continue edge colors into transparent corners for OS-applied masks."""
    alpha = tile.getchannel('A')
    background = tile.convert('RGB')
    valid_rows = []
    for y in range(tile.height):
        row = alpha.crop((0, y, tile.width, y + 1))
        bounds = row.point(lambda value: 255 if value >= 254 else 0).getbbox()
        if bounds:
            left, _, right, _ = bounds
            ImageDraw.Draw(background).line(
                (0, y, left, y), fill=tile.getpixel((left, y))[:3]
            )
            ImageDraw.Draw(background).line(
                (right - 1, y, tile.width - 1, y),
                fill=tile.getpixel((right - 1, y))[:3],
            )
            valid_rows.append(y)
    for y in range(valid_rows[0]):
        background.paste(background.crop((0, valid_rows[0], tile.width, valid_rows[0] + 1)), (0, y))
    for y in range(valid_rows[-1] + 1, tile.height):
        background.paste(background.crop((0, valid_rows[-1], tile.width, valid_rows[-1] + 1)), (0, y))
    background.paste(tile, (0, 0), tile)
    return background


def adaptive_background(image):
    """Place artwork in the central 72/108 area and bleed edges beyond it."""
    inner = image.resize((720, 720), Image.Resampling.LANCZOS)
    outer = Image.new('RGB', (1080, 1080))
    outer.paste(inner, (180, 180))
    outer.paste(inner.crop((0, 0, 720, 1)).resize((720, 180)), (180, 0))
    outer.paste(inner.crop((0, 719, 720, 720)).resize((720, 180)), (180, 900))
    outer.paste(outer.crop((180, 0, 181, 1080)).resize((180, 1080)), (0, 0))
    outer.paste(outer.crop((899, 0, 900, 1080)).resize((180, 1080)), (900, 0))
    return outer


def save_at(image, path, size):
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main():
    source = Image.open(SOURCE).convert('RGBA')
    tile = source.crop(source.getchannel('A').getbbox())
    tile = tile.resize((1024, 1024), Image.Resampling.LANCZOS)
    complete = opaque_artwork(tile)
    background = adaptive_background(complete)
    foreground = Image.new('RGBA', (1080, 1080))
    save_at(tile, ROOT / 'assets/brand/app_icon.png', 256)
    tile.save(
        ROOT / 'windows/runner/resources/app_icon.ico',
        sizes=[(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 128, 256)],
    )
    android = ROOT / 'android/app/src/main/res'
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        directory = android / f'mipmap-{density}'
        save_at(tile, directory / 'ic_launcher.png', size)
        round_icon = complete.convert('RGBA')
        mask = Image.new('L', complete.size)
        ImageDraw.Draw(mask).ellipse((0, 0, 1023, 1023), fill=255)
        round_icon.putalpha(mask)
        save_at(round_icon, directory / 'ic_launcher_round.png', size)
        adaptive_size = size * 9 // 4
        save_at(background, directory / 'ic_launcher_background_layer.png', adaptive_size)
        save_at(foreground, directory / 'ic_launcher_foreground.png', adaptive_size)
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((ios / 'Contents.json').read_text())['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        save_at(complete.convert('RGB'), ios / entry['filename'], size)

    preview = Image.new('RGB', (960, 420), '#F5F6FA')
    for x, y, size in [(42, 42, 336), (444, 90, 160), (666, 110, 96), (810, 134, 48)]:
        icon = tile.resize((size, size), Image.Resampling.LANCZOS)
        preview.paste(icon, (x, y), icon)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW / 'preview.png')
    save_at(round_icon, PREVIEW / 'round-preview.png', 192)
    print('Exported approved sundial to app, Windows, Android and iOS icon assets.')


if __name__ == '__main__':
    main()
