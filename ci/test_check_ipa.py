import plistlib
from pathlib import Path
import stat
import struct
import tempfile
import unittest
from zipfile import ZipFile, ZipInfo
import zlib

from check_ipa import check_ipa


def png(size):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress((b"\0" + b"\0" * size * 3) * size))
            + chunk(b"IEND", b""))


class IPAPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "Carbon.ipa"
        self.root = "Payload/Carbon.app/"
        self.info = {
            "CFBundleIdentifier": "app.carbon.Carbon", "CFBundleExecutable": "Carbon",
            "CFBundleName": "Carbon", "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1", "MinimumOSVersion": "18.0", "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "CFBundleIcons": {"CFBundlePrimaryIcon": {
                "CFBundleIconName": "AppIcon", "CFBundleIconFiles": ["AppIcon60x60"]}},
        }
        self.files = {"Assets.car": b"assets", "AppIcon60x60@2x.png": png(120),
                      "AppIcon60x60@3x.png": png(180)}
        for folder, extension, count in (("halide", "ccube", 25), ("nofusion", "lutbin", 20), ("lapse", "cube", 1)):
            self.files.update({f"LUTs/{folder}/{i}.{extension}": b"lut" for i in range(count)})

    def write(self, platform=2, executable=True, prefix=""):
        self.files["Info.plist"] = plistlib.dumps(self.info, fmt=plistlib.FMT_BINARY)
        data = (struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 24, 0, 0)
                + struct.pack("<6I", 0x32, 24, platform, 0, 0, 0))
        self.files["Carbon"] = data
        with ZipFile(self.path, "w") as archive:
            for name, contents in self.files.items():
                entry = ZipInfo(prefix + self.root + name)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | (0o755 if name == "Carbon" and executable else 0o644)) << 16
                archive.writestr(entry, contents)

    def test_valid_unsigned_device_ipa(self):
        self.write()
        self.assertEqual(check_ipa(self.path)["CFBundleIdentifier"], "app.carbon.Carbon")

    def test_rejects_original_missing_icon_metadata(self):
        del self.info["CFBundleIcons"]
        self.write()
        with self.assertRaisesRegex(ValueError, "Missing primary app icon metadata"):
            check_ipa(self.path)

    def test_rejects_missing_icon_png(self):
        del self.files["AppIcon60x60@3x.png"]
        self.write()
        with self.assertRaisesRegex(ValueError, "Missing 2x/3x"):
            check_ipa(self.path)

    def test_rejects_simulator_and_mac_arm64_executables(self):
        for platform in (7, 1):
            with self.subTest(platform=platform):
                self.write(platform=platform)
                with self.assertRaisesRegex(ValueError, "physical iOS device"):
                    check_ipa(self.path)

    def test_rejects_github_wrapper_renamed_to_ipa(self):
        with ZipFile(self.path, "w") as archive:
            archive.writestr("Carbon-unsigned.ipa", b"inner ZIP")
        with self.assertRaisesRegex(ValueError, "extract the GitHub artifact ZIP first"):
            check_ipa(self.path)

    def test_rejects_extra_directory_around_payload(self):
        self.write(prefix="build/")
        with self.assertRaisesRegex(ValueError, "Payload/ at the ZIP root"):
            check_ipa(self.path)

    def test_rejects_unexpanded_bundle_settings(self):
        self.info["CFBundleExecutable"] = "$(EXECUTABLE_NAME)"
        self.write()
        with self.assertRaisesRegex(ValueError, "unresolved bundle metadata"):
            check_ipa(self.path)

    def test_rejects_lost_executable_permissions(self):
        self.write(executable=False)
        with self.assertRaisesRegex(ValueError, "executable permission"):
            check_ipa(self.path)

    def test_rejects_missing_luts(self):
        del self.files["LUTs/halide/0.ccube"]
        self.write()
        with self.assertRaisesRegex(ValueError, "Expected 25 halide LUTs"):
            check_ipa(self.path)


if __name__ == "__main__":
    unittest.main()
