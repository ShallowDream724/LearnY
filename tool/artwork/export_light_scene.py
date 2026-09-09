"""Export user-supplied desktop and mobile backgrounds with NumPy and Pillow.

The original is preserved separately. Neutral grading lifts the background's
shadows and confines warmth to reflections; the source is not a Flutter asset.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ARTWORK = ROOT / 'assets/artwork'


def main():
    original = Image.open(ARTWORK / 'source/glass_landscape.png').convert('RGB')
    colour = np.asarray(original, dtype=np.float32) / 255
    luminance = (colour * np.array([.2126, .7152, .0722])).sum(axis=2, keepdims=True)
    # Selectively reduce the yellow cast, retaining more of the cool reflections.
    # Work on colour separately from brightness to avoid a grey desaturation veil.
    warmth = np.clip((colour[..., :1] - colour[..., 2:3]) * 9, 0, 1)
    highlight = np.clip((luminance - .88) / .12, 0, 1)
    chroma_gain = .62 * (1 - warmth) + (.20 + .16 * highlight) * warmth
    chroma = (colour - luminance) * chroma_gain
    # Monotonic, soft compression: lift the dark contour without flattening it
    # and leave headroom above the broad lit surfaces for narrow highlights.
    daylight = .35 + .63 * luminance ** .7
    light = np.clip(daylight + chroma, 0, 1)
    Image.fromarray(np.rint(light * 255).astype(np.uint8)).save(
        ARTWORK / 'landscape_light.webp', lossless=True, method=6,
    )
    exposure = .045 + .22 * luminance ** 3
    night = np.clip(exposure * (1 + chroma * .9), 0, 1)
    Image.fromarray(np.rint(night * 255).astype(np.uint8)).save(
        ARTWORK / 'landscape_dark.webp', lossless=True, method=6,
    )
    thumbnail(Image.open(ARTWORK / 'landscape_light.webp'), 'landscape')
    for name in (
        'dunes', 'prism', 'alpine',
        'warm_hills_mobile', 'prism_mobile', 'alpine_mobile', 'cove_mobile',
    ):
        image = Image.open(ARTWORK / f'source/{name}.png').convert('RGB')
        image.save(ARTWORK / f'{name}_light.webp', lossless=True, method=6)
        colour = np.asarray(image, dtype=np.float32) / 255
        luminance = (colour * np.array([.2126, .7152, .0722])).sum(axis=2, keepdims=True)
        exposure = .045 + .22 * luminance ** 3
        night = np.clip(exposure * (1 + (colour - luminance) * .9), 0, 1)
        Image.fromarray(np.rint(night * 255).astype(np.uint8)).save(
            ARTWORK / f'{name}_dark.webp', lossless=True, method=6,
        )
        thumbnail(image, name, mobile=name.endswith('_mobile'))
    print('Exported four desktop and four mobile backgrounds with night variants and thumbnails.')


def thumbnail(image, name, mobile=False):
    size = (192, 416) if mobile else (384, 216)
    ImageOps.fit(image.convert('RGB'), size, method=Image.Resampling.LANCZOS).save(
        ARTWORK / f'{name}_thumbnail.webp', quality=88, method=6,
    )


if __name__ == '__main__':
    main()
