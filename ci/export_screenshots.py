#!/usr/bin/env python3
"""Export named UI screenshots and a browser gallery from an Xcode result bundle."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


SCREENS = {
    "01-welcome": "Welcome",
    "02-camera": "Camera",
    "03-preset-menu": "Preset browser",
    "04-rolls": "Rolls",
    "05-settings": "Settings",
}


def package_screenshots(attachments_dir: Path, output_dir: Path) -> None:
    manifest = json.loads((attachments_dir / "manifest.json").read_text(encoding="utf-8"))
    screenshots = {}
    for test in manifest:
        for attachment in test.get("attachments", []):
            suggested = attachment.get("suggestedHumanReadableName", "")
            for name in SCREENS:
                if name in suggested:
                    source = attachments_dir / attachment["exportedFileName"]
                    if not source.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
                        raise ValueError(f"Screenshot {name} is not a PNG: {source}")
                    screenshots[name] = source

    missing = SCREENS.keys() - screenshots.keys()
    if missing:
        raise ValueError(f"Missing UI screenshots: {', '.join(sorted(missing))}")

    output_dir.mkdir(parents=True, exist_ok=True)
    cards = []
    for name, title in SCREENS.items():
        filename = f"{name}.png"
        shutil.copyfile(screenshots[name], output_dir / filename)
        cards.append(
            f'<figure><a href="{filename}"><img src="{filename}" alt="{title}"></a>'
            f'<figcaption>{title} &middot; <a href="{filename}" download>Download PNG</a>'
            '</figcaption></figure>'
        )

    gallery = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Carbon UI Screenshots</title>
<style>
  body { margin: 0; padding: 32px; background: #0e0e10; color: #f6f3ec;
         font: 16px/1.5 system-ui, sans-serif; }
  h1 { margin: 0; font-family: Georgia, serif; font-weight: normal; }
  p { color: #b8b5ae; }
  main { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
         gap: 24px; max-width: 1800px; margin: 32px auto; }
  figure { margin: 0; }
  img { display: block; width: 100%; height: auto; border-radius: 12px; }
  figcaption { padding: 12px 0; }
  a { color: #9ebeff; }
</style>
<h1>Carbon UI Screenshots</h1>
<p>Captured on the iOS Simulator. Select an image to open it at full size.</p>
<main>
""" + "\n".join(cards) + "\n</main>\n</html>\n"
    (output_dir / "index.html").write_text(gallery, encoding="utf-8")
    (output_dir / "README.txt").write_text(
        "Extract this ZIP, then open index.html in any web browser.\n"
        "You can also open or share the five PNG files individually.\n"
        "Xcode and a local web server are not required.\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result_bundle", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="carbon-screenshots-") as temporary:
        attachments_dir = Path(temporary)
        subprocess.run(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", str(args.result_bundle),
             "--output-path", str(attachments_dir)],
            check=True,
        )
        package_screenshots(attachments_dir, args.output_dir)
    print(f"Exported {len(SCREENS)} PNG screenshots and index.html to {args.output_dir}")


if __name__ == "__main__":
    main()
