import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from export_screenshots import (
    SCREENS,
    package_screenshots,
    publish_screenshots,
    render_summary,
    write_summary,
)
from test_check_ipa import png


class ScreenshotPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.attachments_dir = Path(self.temporary.name) / "attachments"
        self.attachments_dir.mkdir()
        self.output_dir = Path(self.temporary.name) / "gallery"
        self.attachments = []
        for index, name in enumerate(SCREENS):
            exported = f"attachment-{index}.png"
            (self.attachments_dir / exported).write_bytes(png(8))
            self.attachments.append({
                "suggestedHumanReadableName": f"{name}_1_ABC.png",
                "exportedFileName": exported,
            })

    def write_manifest(self):
        (self.attachments_dir / "manifest.json").write_text(
            json.dumps([{"attachments": self.attachments}]), encoding="utf-8"
        )

    def test_gallery_contains_named_pngs_and_relative_links(self):
        self.attachments.append({"suggestedHumanReadableName": "debug.txt"})
        self.write_manifest()
        package_screenshots(self.attachments_dir, self.output_dir)
        self.assertEqual({p.stem for p in self.output_dir.glob("*.png")}, set(SCREENS))
        gallery = (self.output_dir / "index.html").read_text(encoding="utf-8")
        for name in SCREENS:
            self.assertIn(f'src="{name}.png"', gallery)
            self.assertIn(f'href="{name}.png"', gallery)
        self.assertTrue((self.output_dir / "README.txt").is_file())

    def test_missing_screen_fails_instead_of_publishing_incomplete_gallery(self):
        self.attachments.pop()
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Missing UI screenshots: 09-stock-selected"):
            package_screenshots(self.attachments_dir, self.output_dir)
        self.assertFalse(self.output_dir.exists())

    def test_rejects_non_png_screenshot(self):
        (self.attachments_dir / "attachment-0.png").write_bytes(b"not a PNG")
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "01-welcome is not a PNG"):
            package_screenshots(self.attachments_dir, self.output_dir)

    def test_render_summary_with_inline_images_and_artifact_url(self):
        base_url = "https://github.com/acme/carbon/blob/ci-screenshots/runs/42-1"
        artifact_url = "https://github.com/acme/carbon/actions/runs/42/artifacts/99"
        summary = render_summary(base_image_url=base_url, artifact_url=artifact_url)
        self.assertIn("## UI Screenshots", summary)
        for name, title in SCREENS.items():
            expected_img = f"{base_url}/{name}.png?raw=true"
            self.assertIn(f'src="{expected_img}"', summary)
            self.assertIn(f'alt="{title}"', summary)
        self.assertIn(f"[Carbon-UI-Screenshots]({artifact_url})", summary)

    def test_write_summary_fallback_without_base_image_url(self):
        summary_file = Path(self.temporary.name) / "step_summary.md"
        write_summary(
            summary_file=summary_file,
            base_image_url=None,
            artifact_url="https://example.com/artifact.zip",
        )
        content = summary_file.read_text(encoding="utf-8")
        for name, title in SCREENS.items():
            self.assertIn(f"- **{name}.png** - {title}", content)
        self.assertIn("https://example.com/artifact.zip", content)

    def test_publish_screenshots_pushes_orphan_branch(self):
        self.write_manifest()
        package_screenshots(self.attachments_dir, self.output_dir)

        remote_dir = Path(self.temporary.name) / "origin.git"
        repo_dir = Path(self.temporary.name) / "repo"
        subprocess.run(["git", "init", "--bare", str(remote_dir)], check=True, capture_output=True)
        subprocess.run(["git", "init", str(repo_dir)], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(repo_dir), "remote", "add", "origin", str(remote_dir)],
            check=True,
            capture_output=True,
        )
        (repo_dir / "README.md").write_text("seed\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo_dir), "add", "README.md"], check=True, capture_output=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(repo_dir),
                "-c",
                "user.name=test",
                "-c",
                "user.email=test@example.com",
                "commit",
                "-m",
                "init",
            ],
            check=True,
            capture_output=True,
        )

        commit_sha = publish_screenshots(
            output_dir=self.output_dir,
            branch="refs/screenshots/latest",
            run_dir="runs/100-1",
            repo_dir=repo_dir,
        )
        self.assertEqual(len(commit_sha), 40)

        files = subprocess.check_output(
            ["git", "-C", str(remote_dir), "ls-tree", "-r", "--name-only", "refs/screenshots/latest"],
            text=True,
        ).splitlines()
        for name in SCREENS:
            self.assertIn(f"runs/100-1/{name}.png", files)
        self.assertIn("runs/100-1/index.html", files)
        self.assertNotIn("README.md", files)

        heads = subprocess.check_output(
            ["git", "-C", str(remote_dir), "for-each-ref", "--format=%(refname)", "refs/heads/"],
            text=True,
        ).splitlines()
        self.assertEqual(heads, [])


if __name__ == "__main__":
    unittest.main()
