from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from export_screenshots import SCREENS
from publish_gallery import publish_gallery, wait_for_gallery


START = '2026-11-05T06:00:00Z'
UPLOADED = '2026-11-05T06:06:00Z'


class GalleryPublisherTests(unittest.TestCase):
    def capture(self, **changes):
        return dict(name='Capture UI Screenshots', started_at=START,
                    status='in_progress', conclusion=None, steps=[]) | changes

    def artifact(self, **changes):
        return dict(id=123, name='Carbon-UI-Screenshots', expired=False,
                    created_at=UPLOADED) | changes

    def fake_api(self, capture, snapshots):
        snapshots = iter(snapshots)

        def result(endpoint):
            if endpoint.endswith('/attempts/2'):
                return dict(run_started_at=START)
            if '/jobs?' in endpoint:
                return dict(jobs=[capture])
            return dict(artifacts=next(snapshots))
        return result

    def test_publishes_while_the_capture_job_is_still_running_ui_tests(self):
        with patch('publish_gallery.api', side_effect=self.fake_api(self.capture(), [[self.artifact()]])):
            artifact = wait_for_gallery('owner/repo', 100, 2)
        self.assertEqual(artifact['id'], 123)

    def test_waits_for_current_capture_instead_of_using_previous_attempt(self):
        old = self.artifact(id=122, created_at='2026-11-05T05:00:00Z')
        with patch('publish_gallery.api', side_effect=self.fake_api(self.capture(), [[old], [old, self.artifact()]])), \
             patch('publish_gallery.time.sleep') as sleep:
            artifact = wait_for_gallery('owner/repo', 100, 2)
        self.assertEqual(artifact['id'], 123)
        sleep.assert_called_once()

    def test_publisher_only_rerun_can_reuse_completed_capture(self):
        old_start = '2026-11-05T05:00:00Z'
        capture = self.capture(started_at=old_start, status='completed', conclusion='success')
        artifact = self.artifact(created_at='2026-11-05T05:06:00Z')
        with patch('publish_gallery.api', side_effect=self.fake_api(capture, [[artifact]])):
            self.assertEqual(wait_for_gallery('owner/repo', 100, 2)['id'], 123)

    def test_capture_failure_stops_waiting(self):
        capture = self.capture(steps=[dict(name='Capture gallery screenshots', conclusion='failure')])
        with patch('publish_gallery.api', side_effect=self.fake_api(capture, [[]])), self.assertRaises(RuntimeError):
            wait_for_gallery('owner/repo', 100, 2)

    def test_expired_artifacts_cannot_satisfy_the_wait(self):
        with patch('publish_gallery.api', side_effect=self.fake_api(self.capture(), [[self.artifact(expired=True)]])), \
             patch('publish_gallery.time.monotonic', side_effect=[0, 0, 2]), \
             patch('publish_gallery.time.sleep'), self.assertRaises(TimeoutError):
            wait_for_gallery('owner/repo', 100, 2, timeout=1)

    def test_publication_requires_all_valid_pngs(self):
        with tempfile.TemporaryDirectory() as temporary, patch('publish_gallery.publish_screenshots') as publish:
            directory = Path(temporary)
            with self.assertRaises(ValueError):
                publish_gallery(directory, 'owner/repo', 100, 2, 'https://github.com', 'artifact', directory / 'summary')
            publish.assert_not_called()

    def test_summary_has_inline_images_and_pending_test_notice(self):
        with tempfile.TemporaryDirectory() as temporary, \
             patch('publish_gallery.publish_screenshots', return_value='image-commit'):
            directory = Path(temporary)
            for name in SCREENS:
                (directory / f'{name}.png').write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            summary = directory / 'summary.md'
            publish_gallery(directory, 'owner/repo', 100, 2, 'https://github.com', 'artifact', summary)
            content = summary.read_text()
            self.assertEqual(content.count('<img '), 9)
            self.assertIn('image-commit/runs/100-2/01-welcome.png', content)
            self.assertIn('Full UI tests may still be running', content)


if __name__ == '__main__':
    unittest.main()
