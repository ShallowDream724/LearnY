"""Export platform icons from the canonical Flutter-rendered artwork.

Run flutter test --no-pub tool/brand/render_brand_test.dart first.
Requires Pillow; use the project's aider environment on this workstation.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
LAYERS = ROOT / 'build/brand'


def rounded(image, radius):
    image = image.copy().convert('RGBA')
    mask = Image.new('L', image.size)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius=radius, fill=255
    )
    image.putalpha(mask)
    return image


def save_at(image, path, size):
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main():
    layers = {
        name: Image.open(LAYERS / f'{name}.png').convert('RGBA')
        for name in ('complete', 'background', 'foreground', 'monochrome')
    }
    complete = layers['complete']
    complete.save(ROOT / 'assets/brand/app_icon.png')
    tile = rounded(complete, 240)
    tile.save(
        ROOT / 'windows/runner/resources/app_icon.ico',
        sizes=[(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 128, 256)],
    )
    android = ROOT / 'android/app/src/main/res'
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        directory = android / f'mipmap-{density}'
        save_at(tile, directory / 'ic_launcher.png', size)
        save_at(rounded(complete, 512), directory / 'ic_launcher_round.png', size)
        adaptive_size = size * 9 // 4
        for layer, filename in [
            ('background', 'ic_launcher_background_layer'),
            ('foreground', 'ic_launcher_foreground'),
            ('monochrome', 'ic_launcher_monochrome'),
        ]:
            save_at(layers[layer], directory / f'{filename}.png', adaptive_size)
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((ios / 'Contents.json').read_text())['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        save_at(complete.convert('RGB'), ios / entry['filename'], size)

    preview = Image.new('RGB', (960, 420), '#F5F6FA')
    for x, y, size in [(42, 42, 336), (444, 90, 160), (666, 110, 96), (810, 134, 48)]:
        icon = tile.resize((size, size), Image.Resampling.LANCZOS)
        preview.paste(icon, (x, y), icon)
    preview.save(LAYERS / 'preview.png')
    print('Exported app, Windows, Android adaptive/monochrome and iOS icon assets.')


if __name__ == '__main__':
    main()
