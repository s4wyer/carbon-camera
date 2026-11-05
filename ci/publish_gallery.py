"""Publish an inline gallery as soon as its artifact exists, before UI tests end."""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import time

from export_screenshots import SCREENS, publish_screenshots, write_summary


ARTIFACT_NAME = 'Carbon-UI-Screenshots'
CAPTURE_JOB = 'Capture UI Screenshots'


def api(endpoint: str) -> dict:
    return json.loads(subprocess.check_output(['gh', 'api', endpoint], text=True))


def timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def wait_for_gallery(repo: str, run_id: int, attempt: int, timeout: float = 1080) -> dict:
    base = f'repos/{repo}/actions/runs/{run_id}'
    attempt_start = timestamp(api(f'{base}/attempts/{attempt}')['run_started_at'])
    deadline = time.monotonic() + timeout
    print('Waiting for gallery upload; the macOS job may continue running UI tests.', flush=True)
    while time.monotonic() < deadline:
        jobs = api(f'{base}/attempts/{attempt}/jobs?per_page=100')['jobs']
        capture = next((job for job in jobs if job['name'] == CAPTURE_JOB), None)
        # A publisher-only rerun may reuse a completed capture job from an older
        # attempt. Otherwise require an artifact from the current capture start.
        not_before = timestamp(capture['started_at']) if capture and capture.get('started_at') else attempt_start
        artifacts = api(f'{base}/artifacts?per_page=100')['artifacts']
        matching = [item for item in artifacts
                    if item['name'] == ARTIFACT_NAME and not item['expired']
                    and timestamp(item['created_at']) >= not_before]
        if matching:
            artifact = max(matching, key=lambda item: item['id'])
            print(f"Gallery artifact {artifact['id']} is available; publishing now.", flush=True)
            return artifact
        if capture:
            failed_steps = [step['name'] for step in capture.get('steps', [])
                            if step['name'] in ('Capture gallery screenshots', 'Upload screenshots')
                            and step.get('conclusion') in ('failure', 'cancelled', 'skipped', 'timed_out')]
            if failed_steps or capture.get('conclusion') in ('failure', 'cancelled', 'timed_out'):
                raise RuntimeError(f"Gallery upload stopped before an artifact was available: {', '.join(failed_steps) or capture['conclusion']}")
        time.sleep(10)
    raise TimeoutError(f'No gallery artifact became available within {timeout}s')


def publish_gallery(directory: Path, repo: str, run_id: int, attempt: int,
                    server: str, artifact_url: str, summary: Path) -> None:
    for name in SCREENS:
        path = directory / f'{name}.png'
        if not path.is_file() or not path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError(f'Missing or invalid gallery PNG: {name}')
    run_dir = f'runs/{run_id}-{attempt}'
    # Publication failures are errors here: this job must produce inline images,
    # rather than silently finishing with only a downloadable artifact link.
    commit = publish_screenshots(directory, run_dir=run_dir)
    base_image_url = f'{server.rstrip("/")}/{repo}/blob/{commit}/{run_dir}'
    write_summary(summary, base_image_url=base_image_url, artifact_url=artifact_url)
    with summary.open('a', encoding='utf-8') as file:
        file.write('\nGallery capture is complete. Full UI tests may still be running; '
                   f'[check their status]({server.rstrip("/")}/{repo}/actions/runs/{run_id}).\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('wait', 'publish'))
    parser.add_argument('directory', nargs='?', type=Path)
    args = parser.parse_args()
    repo = os.environ['GITHUB_REPOSITORY']
    run_id = int(os.environ['GITHUB_RUN_ID'])
    attempt = int(os.environ['GITHUB_RUN_ATTEMPT'])
    server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
    if args.command == 'wait':
        artifact = wait_for_gallery(repo, run_id, attempt)
        artifact_id = int(artifact['id'])
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as file:
            file.write(f'artifact-id={artifact_id}\n')
            file.write(f'artifact-url={server}/{repo}/actions/runs/{run_id}/artifacts/{artifact_id}\n')
    else:
        if args.directory is None:
            parser.error('publish requires the downloaded gallery directory')
        publish_gallery(args.directory, repo, run_id, attempt, server,
                        os.environ['SCREENSHOTS_URL'], Path(os.environ['GITHUB_STEP_SUMMARY']))


if __name__ == '__main__':
    main()
