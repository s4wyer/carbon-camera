"""Select an iPhone destination accepted by the current Xcode scheme."""

import argparse
import re
import sys


def select_simulator(output: str, ios_major: int = 26) -> str:
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
        if version_tuple[0] != ios_major:
            continue
        candidates.append((version_tuple, device_id))
    if not candidates:
        raise ValueError(f'No eligible iOS {ios_major} iPhone simulator found in Xcode scheme destinations')
    return max(candidates)[1]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ios-major', type=int, default=26)
    args = parser.parse_args()
    try:
        print(select_simulator(sys.stdin.read(), args.ios_major))
    except ValueError as error:
        sys.exit(str(error))
