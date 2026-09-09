"""Export the user-supplied light landscape. Tooling: NumPy and Pillow.

The light image is preserved losslessly; the provisional dark exposure keeps
the same geometry and colour relationships. The source is not a Flutter asset.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ARTWORK = ROOT / 'assets/artwork'


def main():
    original = Image.open(ARTWORK / 'source/glass_landscape.png').convert('RGB')
    original.save(ARTWORK / 'landscape_light.webp', lossless=True, method=6)
    colour = np.asarray(original, dtype=np.float32) / 255
    luminance = (colour * np.array([.2126, .7152, .0722])).sum(axis=2, keepdims=True)
    exposure = .045 + .22 * luminance ** 3
    night = np.clip(exposure * (1 + (colour - luminance) * .9), 0, 1)
    Image.fromarray(np.rint(night * 255).astype(np.uint8)).save(
        ARTWORK / 'landscape_dark.webp', lossless=True, method=6,
    )
    print(f'Exported landscape and night study at {original.width} x {original.height}.')


if __name__ == '__main__':
    main()
