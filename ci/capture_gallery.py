"""Capture production fixture views with simctl, before starting XCTest."""

import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time
import uuid

from export_screenshots import package_screenshots
from select_simulator import select_available_simulator


ROOT = Path(__file__).resolve().parents[1]
CARBON = ROOT / 'Carbon'
APP_ID = 'app.carbon.Carbon'
CAPTURES = (
    ('welcome', ('01-welcome',)),
    ('camera', ('02-camera',)),
    ('presets', ('03-preset-menu', '06-stock-top', '09-stock-selected')),
    ('stock-middle', ('07-stock-middle',)),
    ('stock-bottom', ('08-stock-bottom',)),
    ('rolls', ('04-rolls',)),
    ('settings', ('05-settings',)),
)


def write_request(directory: Path, scene: str, token: str) -> None:
    temporary = directory / 'request.tmp'
    temporary.write_text(json.dumps(dict(scene=scene, token=token)), encoding='utf-8')
    temporary.replace(directory / 'request.json')


def wait_ready(directory: Path, scene: str, token: str, timeout: float = 90) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            ready = json.loads((directory / 'ready.json').read_text(encoding='utf-8'))
        except (FileNotFoundError, json.JSONDecodeError):
            ready = {}
        if ready.get('token') == token:
            if ready.get('scene') != scene:
                raise ValueError(f'Harness acknowledged the wrong scene for {scene}')
            if ready.get('error'):
                raise ValueError(f"Harness failed for {scene}: {ready['error']}")
            expected = {'presets': 0, 'stock-middle': 0.5, 'stock-bottom': 1}.get(scene)
            if expected is not None:
                position = ready.get('scrollPosition')
                if type(position) not in (int, float) or not math.isfinite(position) or abs(position - expected) > 0.02:
                    raise ValueError(f'Wrong stock scroll position for {scene}: {position}')
            return ready
        time.sleep(0.1)
    raise TimeoutError(f'Harness did not acknowledge {scene} within {timeout}s')


def run(command: list[str], *, capture: bool = False, timeout: int = 120) -> str:
    result = subprocess.run(command, cwd=CARBON, check=True, timeout=timeout,
                            stdout=subprocess.PIPE if capture else None, text=True)
    return result.stdout.strip() if capture else ''


def record_timing(label: str, started: float) -> None:
    elapsed = round(time.monotonic() - started, 1)
    print(f'Timing: {label}: {elapsed}s', flush=True)
    if summary := os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a', encoding='utf-8') as file:
            file.write(f'| {label} | {elapsed}s |\n')


def main() -> None:
    build = CARBON / 'build'
    build.mkdir(exist_ok=True)
    if summary := os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a', encoding='utf-8') as file:
            file.write('### Gallery capture without XCTest\n\n| Phase | Duration |\n| --- | ---: |\n')
    started = time.monotonic()
    device = select_available_simulator(run(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], capture=True))
    record_timing('Select simulator', started)
    if output := os.environ.get('GITHUB_OUTPUT'):
        with open(output, 'a', encoding='utf-8') as file:
            file.write(f'device={device}\n')
    architecture = platform.machine()
    if architecture not in ('arm64', 'x86_64'):
        raise ValueError(f'Unsupported runner architecture: {architecture}')
    succeeded = False
    with (build / 'Gallery-simulator.log').open('w', encoding='utf-8') as boot_log:
        boot = subprocess.Popen(['xcrun', 'simctl', 'bootstatus', device, '-b'],
                                stdout=boot_log, stderr=subprocess.STDOUT)
        try:
            started = time.monotonic()
            command = [
                'xcodebuild', 'build', '-project', 'Carbon.xcodeproj', '-scheme', 'Carbon',
                '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator',
                '-derivedDataPath', './build/DerivedData', '-showBuildTimingSummary',
                f'ARCHS={architecture}', 'ONLY_ACTIVE_ARCH=YES', 'CODE_SIGNING_ALLOWED=NO',
                'COMPILATION_CACHE_ENABLE_CACHING=YES',
                'COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES',
                f"COMPILATION_CACHE_CAS_PATH={os.environ.get('COMPILATION_CACHE_DIR', str(build / 'CompilationCache.noindex'))}",
            ]
            with (build / 'Gallery-build.log').open('w', encoding='utf-8') as log:
                subprocess.run(command, cwd=CARBON, stdout=log, stderr=subprocess.STDOUT,
                               check=True, timeout=600)
            record_timing('Build fixture app (overlaps simulator boot)', started)
            started = time.monotonic()
            if boot.wait(timeout=300):
                raise RuntimeError('Simulator boot failed; see Gallery-simulator.log')
            record_timing('Remaining simulator wait', started)
            started = time.monotonic()
            app = build / 'DerivedData/Build/Products/Debug-iphonesimulator/Carbon.app'
            run(['xcrun', 'simctl', 'install', device, str(app)])
            container = Path(run(['xcrun', 'simctl', 'get_app_container', device, APP_ID, 'data'], capture=True))
            control = container / 'Documents/ScreenshotHarness'
            control.mkdir(parents=True, exist_ok=True)
            run(['xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41',
                 '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3',
                 '--batteryState', 'charged', '--batteryLevel', '100'])
            run(['xcrun', 'simctl', 'launch', '--terminate-running-process', device, APP_ID,
                 '--ui-testing', '--insert-sample-shot', '--welcome-testing', '--capture-harness'])
            record_timing('Install and launch fixture app', started)
            started = time.monotonic()
            staging = build / 'GalleryAttachments'
            staging.mkdir(exist_ok=True)
            attachments = []
            acknowledgements = []
            for scene, names in CAPTURES:
                token = uuid.uuid4().hex
                write_request(control, scene, token)
                acknowledgements.append(wait_ready(control, scene, token))
                primary = staging / f'{names[0]}.png'
                run(['xcrun', 'simctl', 'io', device, 'screenshot', str(primary)])
                for name in names:
                    target = staging / f'{name}.png'
                    if target != primary:
                        shutil.copyfile(primary, target)
                    attachments.append(dict(suggestedHumanReadableName=name, exportedFileName=target.name))
            (staging / 'manifest.json').write_text(json.dumps([dict(attachments=attachments)]), encoding='utf-8')
            package_screenshots(staging, build / 'UIScreenshots')
            (build / 'UIScreenshots/capture-metadata.json').write_text(
                json.dumps(dict(method='simctl-production-fixtures', device=device,
                                architecture=architecture, states=acknowledgements), indent=2), encoding='utf-8')
            record_timing('Capture and package nine gallery PNGs', started)
            # The full UI suite reuses this booted device after gallery upload.
            succeeded = True
        finally:
            if boot.poll() is None:
                boot.terminate()
                boot.wait(timeout=10)
            if not succeeded:
                subprocess.run(['xcrun', 'simctl', 'shutdown', device], check=False,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
