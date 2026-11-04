import json
from pathlib import Path
import tempfile
import unittest

from export_screenshots import SCREENS, package_screenshots
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

    def test_gallery_contains_five_named_pngs_and_relative_links(self):
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
        with self.assertRaisesRegex(ValueError, "Missing UI screenshots: 05-settings"):
            package_screenshots(self.attachments_dir, self.output_dir)
        self.assertFalse(self.output_dir.exists())

    def test_rejects_non_png_screenshot(self):
        (self.attachments_dir / "attachment-0.png").write_bytes(b"not a PNG")
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "01-welcome is not a PNG"):
            package_screenshots(self.attachments_dir, self.output_dir)


if __name__ == "__main__":
    unittest.main()
