"""Select an iPhone from Xcode destinations or CoreSimulator's available devices."""

import argparse
import json
import re
import sys


def select_available_simulator(output: str, ios_major: int | None = None) -> str:
    candidates = []
    for runtime, devices in json.loads(output)['devices'].items():
        match = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+(?:-\d+)*)', runtime)
        if not match:
            continue
        version = tuple(map(int, match[1].split('-')))
        if ios_major is not None and version[0] != ios_major:
            continue
        for device in devices:
            if not device.get('isAvailable') or not device.get('name', '').startswith('iPhone'):
                continue
            device_id = device.get('udid', '')
            if re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', device_id):
                candidates.append((version, device_id))
    if not candidates:
        raise ValueError('No available iPhone simulator found in CoreSimulator devices')
    return max(candidates)[1]


def select_simulator(output: str, ios_major: int | None = None) -> str:
    available = False
    candidates = []
    for line in output.splitlines():
        if 'Available destinations for ' in line:
            available = True
            continue
        if 'Ineligible destinations for ' in line:
            available = False
        if not available:
            continue
        fields = dict(re.findall(r'(\w+):\s*([^,}]+)', line))
        if fields.get('platform', '').strip() != 'iOS Simulator':
            continue
        if not fields.get('name', '').strip().startswith('iPhone'):
            continue
        device_id = fields.get('id', '').strip()
        if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', device_id):
            continue
        version = fields.get('OS', '').strip()
        if not re.fullmatch(r'\d+(?:\.\d+)*', version):
            continue
        version_tuple = tuple(map(int, version.split('.')))
        if ios_major is not None and version_tuple[0] != ios_major:
            continue
        candidates.append((version_tuple, device_id))
    if not candidates:
        runtime = f'iOS {ios_major}' if ios_major is not None else 'iOS'
        raise ValueError(f'No eligible {runtime} iPhone simulator found in Xcode scheme destinations')
    return max(candidates)[1]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ios-major', type=int, help='Require this iOS major version; otherwise select the newest eligible runtime')
    parser.add_argument('--simctl-json', action='store_true', help='Read xcrun simctl list devices available -j output')
    args = parser.parse_args()
    try:
        selector = select_available_simulator if args.simctl_json else select_simulator
        print(selector(sys.stdin.read(), args.ios_major))
    except ValueError as error:
        sys.exit(str(error))
