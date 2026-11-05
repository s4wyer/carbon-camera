import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from capture_gallery import CAPTURES, wait_ready, write_request
from export_screenshots import SCREENS


class CaptureProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)

    def ready(self, **changes):
        value = dict(token='current', scene='camera') | changes
        (self.directory / 'ready.json').write_text(json.dumps(value), encoding='utf-8')

    def test_capture_plan_produces_every_gallery_image_once(self):
        names = [name for _, names in CAPTURES for name in names]
        self.assertEqual(set(names), set(SCREENS))
        self.assertEqual(len(names), len(SCREENS))

    def test_request_replacement_is_atomic_and_carries_a_fresh_token(self):
        write_request(self.directory, 'welcome', 'first')
        write_request(self.directory, 'camera', 'second')
        request = json.loads((self.directory / 'request.json').read_text())
        self.assertEqual(request, dict(scene='camera', token='second'))
        self.assertFalse((self.directory / 'request.tmp').exists())

    def test_stale_acknowledgement_cannot_capture_the_previous_scene(self):
        self.ready(token='previous')
        with patch('capture_gallery.time.monotonic', return_value=0), \
             patch('capture_gallery.time.sleep', side_effect=lambda _: self.ready()) as sleep:
            result = wait_ready(self.directory, 'camera', 'current')
        sleep.assert_called_once()
        self.assertEqual(result['token'], 'current')

    def test_missing_or_stale_acknowledgement_times_out(self):
        self.ready(token='previous')
        with patch('capture_gallery.time.monotonic', side_effect=[0, 0, 2]), \
             patch('capture_gallery.time.sleep'), self.assertRaises(TimeoutError):
            wait_ready(self.directory, 'camera', 'current', timeout=1)

    def test_render_failure_or_wrong_scene_prevents_capture(self):
        for changes in (dict(error='missing fixture'), dict(scene='settings')):
            with self.subTest(changes=changes):
                self.ready(**changes)
                with self.assertRaises(ValueError):
                    wait_ready(self.directory, 'camera', 'current')

    def test_scroll_acknowledgement_must_match_requested_position(self):
        self.ready(scene='stock-bottom', scrollPosition=0.5)
        with self.assertRaisesRegex(ValueError, 'Wrong stock scroll position'):
            wait_ready(self.directory, 'stock-bottom', 'current')
        self.ready(scene='stock-bottom', scrollPosition=1)
        self.assertEqual(wait_ready(self.directory, 'stock-bottom', 'current')['scrollPosition'], 1)

    def test_ready_app_does_not_wait_for_a_slow_launch_client(self):
        self.ready()
        process = Mock()
        process.poll.return_value = None
        self.assertEqual(wait_ready(self.directory, 'camera', 'current', process=process)['scene'], 'camera')
        process.wait.assert_not_called()

    def test_launch_failure_is_reported_without_waiting_for_ready_timeout(self):
        process = Mock()
        process.poll.return_value = 17
        with self.assertRaisesRegex(RuntimeError, 'launch failed \\(17\\)'):
            wait_ready(self.directory, 'camera', 'current', process=process)


if __name__ == '__main__':
    unittest.main()
