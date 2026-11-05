#!/usr/bin/env python3
"""Validate the finished unsigned Carbon IPA before publishing its artifact."""

import argparse
import plistlib
from pathlib import PurePosixPath
import re
import stat
import struct
from zipfile import BadZipFile, ZipFile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_executable(data):
    require(len(data) >= 32, "App executable is truncated")
    magic, cpu, _, kind, commands, command_size, _, _ = struct.unpack_from("<8I", data)
    require(magic == 0xFEEDFACF and cpu == 0x0100000C and kind == 2,
            "App executable must be an ARM64 Mach-O executable")
    require(32 + command_size <= len(data), "Mach-O load commands are truncated")
    offset = 32
    ios_device = False
    for _ in range(commands):
        require(offset + 8 <= 32 + command_size, "Missing Mach-O load command")
        command, size = struct.unpack_from("<2I", data, offset)
        require(size >= 8 and offset + size <= 32 + command_size,
                "Invalid Mach-O load command size")
        if command == 0x32:  # LC_BUILD_VERSION: iOS = 2, iOS Simulator = 7.
            require(size >= 24, "Invalid LC_BUILD_VERSION")
            ios_device = struct.unpack_from("<I", data, offset + 8)[0] == 2
        if command == 0x2C:  # LC_ENCRYPTION_INFO_64
            require(size >= 24, "Invalid LC_ENCRYPTION_INFO_64")
            require(struct.unpack_from("<I", data, offset + 16)[0] == 0,
                    "Encrypted executables cannot be re-signed")
        offset += size
    require(ios_device, "Executable must target a physical iOS device, not a simulator or Mac")


def png_size(data):
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), "App icon is not a PNG")
    offset = 8
    while offset + 12 <= len(data):
        length, kind = struct.unpack_from(">I4s", data, offset)
        require(offset + 12 + length <= len(data), "App icon PNG is truncated")
        if kind == b"IHDR":
            require(length == 13, "Invalid PNG header")
            return struct.unpack_from(">2I", data, offset + 8)
        offset += 12 + length  # actool can insert CgBI before IHDR.
    raise ValueError("App icon PNG has no image header")


def check_ipa(path):
    with ZipFile(path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), "IPA contains duplicate ZIP paths")
        require(archive.testzip() is None, "IPA ZIP integrity check failed")
        require(all(not PurePosixPath(n).is_absolute() and ".." not in PurePosixPath(n).parts
                    and "\\" not in n for n in names), "IPA contains unsafe ZIP paths")
        require(all(n.startswith("Payload/") for n in names),
                "IPA must contain Payload/ at the ZIP root; extract the GitHub artifact ZIP first")
        apps = {PurePosixPath(n).parts[1] for n in names
                if len(PurePosixPath(n).parts) >= 2}
        require(len(apps) == 1 and next(iter(apps)).endswith(".app"),
                "Payload must contain exactly one .app bundle")
        root = f"Payload/{next(iter(apps))}/"
        require(root + "Info.plist" in names, "App bundle has no Info.plist")
        info = plistlib.loads(archive.read(root + "Info.plist"))
        for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleName",
                    "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion"):
            value = info.get(key)
            require(isinstance(value, str) and value and "$(" not in value,
                    f"Missing or unresolved bundle metadata: {key}")
        require(info.get("CFBundlePackageType") == "APPL", "Bundle is not an application")
        require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
                "Bundle does not target iPhoneOS")
        executable = root + info["CFBundleExecutable"]
        require(executable in names, "CFBundleExecutable does not exist in the app bundle")
        require(archive.getinfo(executable).external_attr >> 16 & stat.S_IXUSR,
                "App executable has lost its executable permission")
        check_executable(archive.read(executable))

        primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
        icons = primary.get("CFBundleIconFiles", [])
        require(primary.get("CFBundleIconName") and icons,
                "Missing primary app icon metadata (CFBundleIcons/CFBundlePrimaryIcon)")
        sizes = set()
        for icon in icons:
            stem = icon.removesuffix(".png")
            pattern = re.compile(re.escape(root + stem) + r"(?:@[23]x)?(?:~iphone)?\.png")
            matches = [n for n in names if pattern.fullmatch(n)]
            require(matches, f"Primary icon {icon!r} has no bundled PNG files")
            sizes.update(png_size(archive.read(n)) for n in matches)
        require({(120, 120), (180, 180)} <= sizes, "Missing 2x/3x iPhone home screen icons")
        require(root + "Assets.car" in names, "Missing compiled asset catalog")
        for folder, extension, count in (("halide", ".ccube", 25), ("nofusion", ".lutbin", 20), ("lapse", ".cube", 1)):
            actual = sum(n.startswith(root + f"LUTs/{folder}/") and n.endswith(extension)
                         for n in names)
            require(actual == count, f"Expected {count} {folder} LUTs, found {actual}")
        return info


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    args = parser.parse_args()
    try:
        info = check_ipa(args.ipa)
    except (ValueError, BadZipFile, KeyError, OSError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"IPA validation failed: {error}\n")
    print(f"IPA validated: {info['CFBundleIdentifier']} {info['CFBundleShortVersionString']} "
          f"({info['CFBundleVersion']}), iOS {info['MinimumOSVersion']}+")
