#!/usr/bin/env python3
"""Export named UI screenshots and a browser gallery from an Xcode result bundle."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


SCREENS = {
    "01-welcome": "Welcome",
    "02-camera": "Camera",
    "03-preset-menu": "Preset browser",
    "04-rolls": "Rolls",
    "05-settings": "Settings",
    "06-stock-top": "Stock browser, top",
    "07-stock-middle": "Stock browser, middle",
    "08-stock-bottom": "Stock browser, bottom",
    "09-stock-selected": "Stock browser, selected",
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
        "You can also open or share the PNG files individually.\n"
        "Xcode and a local web server are not required.\n",
        encoding="utf-8",
    )


def publish_screenshots(
    output_dir: Path,
    branch: str = "refs/screenshots/latest",
    run_dir: str = "latest",
    repo_dir: Path = Path("."),
) -> str:
    """Publish exported PNG screenshots to a hidden git ref and return the commit SHA."""
    missing = [name for name in SCREENS if not (output_dir / f"{name}.png").is_file()]
    if missing:
        raise ValueError(f"Missing exported screenshots in {output_dir}: {', '.join(missing)}")

    target_ref = branch if branch.startswith("refs/") else f"refs/screenshots/{branch}"
    clean_run_dir = run_dir.strip("/") or "latest"
    with tempfile.TemporaryDirectory(prefix="carbon-publish-") as temporary:
        worktree = Path(temporary) / "worktree"
        subprocess.run(
            ["git", "-C", str(repo_dir), "worktree", "add", "--detach", str(worktree)],
            check=True,
        )
        try:
            subprocess.run(
                ["git", "-C", str(worktree), "checkout", "--orphan", "ci-screenshots"],
                check=True,
            )
            subprocess.run(
                ["git", "-C", str(worktree), "rm", "-rf", "--ignore-unmatch", "."],
                check=True,
            )
            target = worktree / clean_run_dir
            target.mkdir(parents=True, exist_ok=True)
            for name in SCREENS:
                filename = f"{name}.png"
                shutil.copyfile(output_dir / filename, target / filename)
            if (output_dir / "index.html").is_file():
                shutil.copyfile(output_dir / "index.html", target / "index.html")

            subprocess.run(["git", "-C", str(worktree), "add", "-A"], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(worktree),
                    "-c",
                    "user.name=github-actions[bot]",
                    "-c",
                    "user.email=41898282+github-actions[bot]@users.noreply.github.com",
                    "commit",
                    "-m",
                    f"Publish UI screenshots ({clean_run_dir})",
                ],
                check=True,
            )
            commit_sha = subprocess.check_output(
                ["git", "-C", str(worktree), "rev-parse", "HEAD"],
                text=True,
            ).strip()
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(worktree),
                    "push",
                    "origin",
                    f"HEAD:{target_ref}",
                    "--force",
                ],
                check=True,
            )
            return commit_sha
        finally:
            subprocess.run(
                ["git", "-C", str(repo_dir), "worktree", "remove", "--force", str(worktree)],
                check=False,
            )


def render_summary(
    base_image_url: str | None = None,
    artifact_url: str | None = None,
    columns: int = 3,
) -> str:
    """Render a GitHub Actions job summary with inline screenshots and artifact links."""
    lines = [
        "## UI Screenshots",
        "",
        "Screenshots of all major screens captured from iOS Simulator:",
        "",
    ]
    if base_image_url:
        base = base_image_url.rstrip("/")
        items = list(SCREENS.items())
        for row_index in range(0, len(items), columns):
            chunk = items[row_index : row_index + columns]
            padded = chunk + [("", "")] * (columns - len(chunk))
            if row_index == 0:
                headers = [title if title else " " for _, title in padded]
                lines.append("| " + " | ".join(headers) + " |")
                lines.append("| " + " | ".join([":---:"] * columns) + " |")
            else:
                headers = [f"**{title}**" if title else " " for _, title in padded]
                lines.append("| " + " | ".join(headers) + " |")

            cells = []
            for name, title in padded:
                if name:
                    img_url = f"{base}/{name}.png?raw=true"
                    cells.append(
                        f'<a href="{img_url}"><img src="{img_url}" alt="{title}" width="220"></a>'
                    )
                else:
                    cells.append(" ")
            lines.append("| " + " | ".join(cells) + " |")
        lines.append("")
    else:
        for name, title in SCREENS.items():
            lines.append(f"- **{name}.png** - {title}")
        lines.append("")

    if artifact_url:
        lines.extend([
            f"Download [Carbon-UI-Screenshots]({artifact_url}), extract the ZIP, and open "
            "**index.html** in any browser. The PNG files can also be viewed or shared individually. "
            "Raw Xcode results are available separately in **Carbon-UI-Test-Results**.",
            "",
        ])
    return "\n".join(lines)


def write_summary(
    summary_file: Path,
    base_image_url: str | None = None,
    artifact_url: str | None = None,
) -> None:
    content = render_summary(base_image_url=base_image_url, artifact_url=artifact_url)
    with summary_file.open("a", encoding="utf-8") as handle:
        handle.write(content)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="+",
        type=Path,
        help="Either '<result_bundle> <output_dir>' or '<output_dir>' when already exported.",
    )
    parser.add_argument(
        "--publish-branch",
        "--publish-ref",
        dest="publish_branch",
        help="Git ref (outside refs/heads/*) to force-push exported PNGs to for inline CI summary rendering.",
    )
    parser.add_argument(
        "--run-dir",
        default="latest",
        help="Subdirectory on the screenshot branch for this run (default: latest).",
    )
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY", ""),
        help="GitHub 'owner/repo' slug (defaults to $GITHUB_REPOSITORY).",
    )
    parser.add_argument(
        "--server-url",
        default=os.environ.get("GITHUB_SERVER_URL", "https://github.com"),
        help="GitHub server URL (defaults to $GITHUB_SERVER_URL or https://github.com).",
    )
    parser.add_argument(
        "--base-image-url",
        help="Explicit base URL where PNG screenshots are hosted.",
    )
    parser.add_argument(
        "--artifact-url",
        default=os.environ.get("SCREENSHOTS_URL", ""),
        help="URL to the uploaded screenshot ZIP artifact.",
    )
    parser.add_argument(
        "--summary-file",
        type=Path,
        help="Path to $GITHUB_STEP_SUMMARY to append the markdown summary to.",
    )
    args = parser.parse_args()

    if len(args.paths) == 2:
        result_bundle, output_dir = args.paths
        with tempfile.TemporaryDirectory(prefix="carbon-screenshots-") as temporary:
            attachments_dir = Path(temporary)
            subprocess.run(
                [
                    "xcrun",
                    "xcresulttool",
                    "export",
                    "attachments",
                    "--path",
                    str(result_bundle),
                    "--output-path",
                    str(attachments_dir),
                ],
                check=True,
            )
            package_screenshots(attachments_dir, output_dir)
        print(f"Exported {len(SCREENS)} PNG screenshots and index.html to {output_dir}")
    elif len(args.paths) == 1:
        output_dir = args.paths[0]
    else:
        parser.error("Expected either '<result_bundle> <output_dir>' or '<output_dir>'")

    base_image_url = args.base_image_url
    if args.publish_branch:
        clean_run_dir = args.run_dir.strip("/") or "latest"
        try:
            commit_sha = publish_screenshots(
                output_dir=output_dir,
                branch=args.publish_branch,
                run_dir=clean_run_dir,
            )
            if not base_image_url and args.repo:
                server = args.server_url.rstrip("/")
                base_image_url = f"{server}/{args.repo}/blob/{commit_sha}/{clean_run_dir}"
        except subprocess.CalledProcessError as exc:
            print(
                f"Warning: could not publish screenshots to ref {args.publish_branch}: {exc}",
                file=sys.stderr,
            )

    if args.summary_file:
        write_summary(
            summary_file=args.summary_file,
            base_image_url=base_image_url,
            artifact_url=args.artifact_url or None,
        )
        print(f"Wrote screenshot summary to {args.summary_file}")


if __name__ == "__main__":
    main()
