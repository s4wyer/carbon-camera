"""Package native welcome XCTest attachments into a portable review gallery."""
import argparse
import html
import json
from pathlib import Path
import shutil


def package(source: Path, destination: Path, device: str) -> int:
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    target = destination / device
    target.mkdir(parents=True, exist_ok=True)
    names = set()
    for test in manifest:
        for attachment in test.get('attachments', []):
            name = attachment.get('suggestedHumanReadableName', '')
            if not name.startswith('welcome-') or not name.endswith('.png'):
                continue
            name = name.split('_', 1)[0]
            image = source / attachment['exportedFileName']
            if not image.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError(f'Invalid PNG: {image}')
            shutil.copyfile(image, target / f'{name}.png')
            names.add(name)
    required = {'welcome-resting', 'welcome-leak-start', 'welcome-leak-peak-before',
                'welcome-leak-peak-after', 'welcome-leak-end', 'welcome-leak-camera',
                'welcome-reduce-motion-camera', 'welcome-after-rapid-taps',
                'welcome-permission-denied', 'welcome-accessibility-xxxl'}
    if missing := required - names:
        raise ValueError(f'Missing {device} screenshots: {sorted(missing)}')
    video = source.parent / f'Welcome-{device}.mov'
    if video.exists():
        shutil.copyfile(video, target / 'transition.mov')
    return len(names)


def gallery(destination: Path) -> None:
    cards = []
    order = {name: index for index, name in enumerate([
        'welcome-resting', 'welcome-leak-start', 'welcome-leak-peak-before',
        'welcome-leak-peak-after', 'welcome-leak-end', 'welcome-leak-camera',
        'welcome-reduce-motion-camera', 'welcome-after-rapid-taps',
        'welcome-permission-denied', 'welcome-accessibility-xxxl',
        'welcome-accessibility-xxxl-scrolled',
    ])}
    for device in ('se', 'pro-max'):
        if (destination / device / 'transition.mov').exists():
            cards.append(f'<figure><video controls preload="metadata" src="{device}/transition.mov"></video><figcaption>{device} / actual timed transition</figcaption></figure>')
        for image in sorted((destination / device).glob('*.png'), key=lambda p: order.get(p.stem, 99)):
            relative = image.relative_to(destination).as_posix()
            title = html.escape(f'{device} / {image.stem.removeprefix("welcome-")}')
            cards.append(f'<figure><a href="{relative}"><img loading="lazy" src="{relative}" alt="{title}"></a><figcaption>{title}</figcaption></figure>')
    (destination / 'index.html').write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Carbon welcome — simulator captures</title>
<style>body{margin:32px;background:#0e0e10;color:#f6f3ec;font:16px system-ui}
h1{font:40px Georgia}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:24px}
figure{margin:0}img,video{width:100%;height:auto;border-radius:16px}figcaption{padding:12px 0}</style>
<h1>Carbon welcome</h1><p>Native iOS Simulator captures: SE and Pro Max. Select a frame for its original PNG.</p>
<main>''' + '\n'.join(cards) + '</main></html>', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('attachments', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('device', choices=['se', 'pro-max'])
    args = parser.parse_args()
    print(f'Packaged {package(args.attachments, args.destination, args.device)} screenshots')
    gallery(args.destination)
