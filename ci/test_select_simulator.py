import unittest

from select_simulator import select_simulator


IOS_18 = 'A5B144E6-A071-4106-B457-76AA34C952DD'
IOS_26 = 'EDC4F281-97FB-4004-B8FA-3ED2BD36749C'
IOS_26_NEWER = '154781AA-E525-424F-9768-390D4DED6241'


def destination(device_id, os_version, platform='iOS Simulator', name='iPhone 16'):
    return f'{{ platform:{platform}, id:{device_id}, OS:{os_version}, name:{name} }}'


def destinations(*lines):
    return 'Available destinations for the "Carbon" scheme:\n' + '\n'.join(lines)


class SimulatorSelectionTests(unittest.TestCase):
    def test_requires_ios_26_instead_of_first_available_runtime(self):
        output = destinations(destination(IOS_18, '18.2'), destination(IOS_26, '26.0'))
        self.assertEqual(select_simulator(output), IOS_26)

    def test_prefers_latest_eligible_ios_26_and_handles_duplicates(self):
        output = destinations(
            destination(IOS_26, '26.0'),
            destination(IOS_26_NEWER, '26.2'),
            destination(IOS_26_NEWER, '26.2'),
        )
        self.assertEqual(select_simulator(output), IOS_26_NEWER)

    def test_does_not_silently_fall_back_to_ios_18(self):
        with self.assertRaisesRegex(ValueError, 'No eligible iOS 26'):
            select_simulator(destinations(destination(IOS_18, '18.2')))

    def test_ignores_ipads_other_platforms_and_placeholders(self):
        output = destinations(
            destination(IOS_26, '26.2', name='iPad Pro'),
            destination(IOS_26, '26.2', platform='visionOS Simulator'),
            destination('placeholder', '26.2'),
            destination(IOS_26_NEWER, '26.1'),
        )
        self.assertEqual(select_simulator(output), IOS_26_NEWER)

    def test_ignores_ineligible_destinations_and_unrelated_output(self):
        output = '\n'.join([
            destination(IOS_26_NEWER, '26.2'),
            destinations(destination(IOS_26, '26.0')),
            'Ineligible destinations for the "Carbon" scheme:',
            destination(IOS_26_NEWER, '26.2'),
        ])
        self.assertEqual(select_simulator(output), IOS_26)

    def test_supports_explicit_runtime_major(self):
        self.assertEqual(
            select_simulator(destinations(destination(IOS_18, '18.2')), ios_major=18), IOS_18
        )

    def test_empty_output_fails_clearly(self):
        with self.assertRaises(ValueError):
            select_simulator('')


if __name__ == '__main__':
    unittest.main()
