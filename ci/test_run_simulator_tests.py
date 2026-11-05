"""Exercise simulator/build coordination and failure propagation without Xcode."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


CI_DIR = Path(__file__).resolve().parent
DEVICE = 'EDC4F281-97FB-4004-B8FA-3ED2BD36749C'


@unittest.skipUnless(shutil.which('bash'), 'requires Bash')
class SimulatorRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'Carbon').mkdir()
        (self.root / 'ci').mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name in ('run_simulator_tests.sh', 'select_simulator.py'):
            shutil.copyfile(CI_DIR / name, self.root / 'ci' / name)
        self.write_command('xcodebuild', f'''#!/bin/bash
set -euo pipefail
case "$1" in
  build-for-testing)
    echo build-start >> ../events
    touch build/build-started
    # Boot must be running concurrently, even if the compiler starts first.
    for ((i=0; i<100; i++)); do
      [ ! -f build/boot-requested ] || break
      sleep 0.05
    done
    test -f build/boot-requested
    echo "$*" >> ../commands
    if [ "${{MOCK_BUILD_STATUS:-0}}" != 0 ]; then
      exit "$MOCK_BUILD_STATUS"
    fi
    touch build/build-finished
    echo build-finished >> ../events
    ;;
  test-without-building)
    test -f build/build-finished
    test -f build/boot-ready
    echo tests >> ../events
    echo "$*" >> ../commands
    exit "${{MOCK_TEST_STATUS:-0}}"
    ;;
  *) exit 90 ;;
esac
''')
        self.write_command('xcrun', '''#!/bin/bash
set -euo pipefail
case "$2" in
  list)
    version="${MOCK_IOS_VERSION:-26.2}"
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-%s":[{"udid":"EDC4F281-97FB-4004-B8FA-3ED2BD36749C","name":"iPhone 16","isAvailable":true}]}}\\n' "${version//./-}"
    ;;
  bootstatus)
    echo boot-start >> ../events
    touch build/boot-requested
    # A sequential boot-before-compile implementation would deadlock here.
    for ((i=0; i<100; i++)); do
      [ ! -f build/build-started ] || break
      sleep 0.05
    done
    test -f build/build-started
    if [ "${MOCK_BOOT_STATUS:-0}" != 0 ]; then
      echo 'simulator boot failed'
      exit "$MOCK_BOOT_STATUS"
    fi
    touch build/boot-ready
    echo boot-ready >> ../events
    ;;
  shutdown) echo shutdown >> ../events ;;
  *) exit 91 ;;
esac
''')

    def write_command(self, name, source):
        path = self.bin / name
        path.write_text(source, encoding='utf-8', newline='\n')
        path.chmod(0o755)

    def run_runner(self, **overrides):
        env = dict(os.environ)
        env.update(
            PATH=str(self.bin) + os.pathsep + env['PATH'],
            GITHUB_STEP_SUMMARY=(self.root / 'summary.md').as_posix(),
        )
        env.update(overrides)
        result = subprocess.run(
            ['bash', 'ci/run_simulator_tests.sh', 'CarbonKitTests', 'TestResults'],
            cwd=self.root, env=env, capture_output=True, text=True, timeout=15,
        )
        events = (self.root / 'events').read_text().splitlines()
        return result, events

    def test_boot_overlaps_build_and_tests_wait_for_both(self):
        result, events = self.run_runner()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertLess(events.index('build-start'), events.index('boot-ready'))
        self.assertLess(events.index('boot-ready'), events.index('tests'))
        self.assertLess(events.index('build-finished'), events.index('tests'))
        self.assertEqual(events[-1], 'shutdown')
        commands = (self.root / 'commands').read_text().splitlines()
        self.assertEqual(len(commands), 2)
        for command in commands:
            self.assertIn(f'platform=iOS Simulator,id={DEVICE}', command)
            self.assertIn('-parallel-testing-enabled NO', command)
            self.assertIn('-enableCodeCoverage YES', command)
        summary = (self.root / 'summary.md').read_text()
        self.assertIn('Compile test bundles', summary)
        self.assertIn('Wait for simulator after compilation', summary)
        self.assertIn('Execute tests without rebuilding', summary)

    def test_compile_failure_skips_tests_and_preserves_exit_status(self):
        result, events = self.run_runner(MOCK_BUILD_STATUS='42')
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertNotIn('tests', events)
        self.assertEqual(events[-1], 'shutdown')

    def test_accepts_eligible_runtime_on_older_runner_images(self):
        result, events = self.run_runner(MOCK_IOS_VERSION='18.5')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('tests', events)

    def test_boot_failure_skips_tests_and_surfaces_log(self):
        result, events = self.run_runner(MOCK_BOOT_STATUS='43')
        self.assertEqual(result.returncode, 43, result.stdout + result.stderr)
        self.assertIn('simulator boot failed', result.stdout)
        self.assertNotIn('tests', events)
        self.assertEqual(events[-1], 'shutdown')

    def test_test_failure_is_not_hidden_by_logging_or_cleanup(self):
        result, events = self.run_runner(MOCK_TEST_STATUS='44')
        self.assertEqual(result.returncode, 44, result.stdout + result.stderr)
        self.assertIn('tests', events)
        self.assertEqual(events[-1], 'shutdown')


if __name__ == '__main__':
    unittest.main()
