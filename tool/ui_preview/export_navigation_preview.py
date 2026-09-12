"""Export navigation captures without introducing false bands in the glass."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2] / 'build/ui_preview/liquid_navigation'
DURATIONS = [400] + [40] * 14 + [350] + [40] * 7 + [800]


def dock_crop(screenshot):
    height = round(screenshot.width * 460 / 1170)
    return screenshot.crop((0, screenshot.height - height,
                            screenshot.width, screenshot.height))


def export_motion(frames, name):
    assert len(frames) == len(DURATIONS), len(frames)
    # Lossless animation is the visual reference. GIF cannot preserve all the
    # colors of a changing page, even when each source frame is a correct PNG.
    frames[0].save(ROOT / f'{name}.webp', save_all=True,
                   append_images=frames[1:], duration=DURATIONS, loop=0,
                   lossless=True, method=6)
    # Build the fallback palette from every page, including the white home card.
    # The old first-frame-only palette caused the apparent cut in the home lens.
    samples = [frame.resize((195, round(frame.height * 195 / frame.width)),
                            Image.Resampling.LANCZOS) for frame in frames]
    atlas = Image.new('RGB', (195, sum(sample.height for sample in samples)))
    top = 0
    for sample in samples:
        atlas.paste(sample, (0, top))
        top += sample.height
    palette = atlas.quantize(colors=256)
    indexed = [frame.quantize(palette=palette,
                              dither=Image.Dither.FLOYDSTEINBERG)
               for frame in frames]
    indexed[0].save(ROOT / f'{name}.gif', save_all=True,
                    append_images=indexed[1:], duration=DURATIONS, loop=0,
                    optimize=False, disposal=2)


def main():
    for name in ('courses_light', 'courses_dark', 'home_light'):
        with Image.open(ROOT / f'{name}.png') as screenshot:
            dock_crop(screenshot).save(ROOT / f'{name}_dock.png')
    for path in ROOT.glob('android_*.png'):
        if path.stem.endswith('_dock'):
            continue
        with Image.open(path) as screenshot:
            dock_crop(screenshot).save(ROOT / f'{path.stem}_dock.png')
    with Image.open(ROOT / 'profile_light.png') as screenshot:
        screenshot.crop((0, 0, screenshot.width,
                         round(screenshot.width * 260 / 390))).save(
                             ROOT / 'profile_header.png')
    dock, whole = [], []
    for path in sorted((ROOT / 'frames').glob('*.png')):
        with Image.open(path) as screenshot:
            dock.append(dock_crop(screenshot).resize(
                (780, 307), Image.Resampling.LANCZOS).convert('RGB'))
            whole.append(screenshot.resize(
                (390, 844), Image.Resampling.LANCZOS).convert('RGB'))
    export_motion(dock, 'navigation_motion')
    export_motion(whole, 'page_motion')


if __name__ == '__main__':
    main()
