import unittest

from check_test_results import check_summary


class TestResultChecks(unittest.TestCase):
    def summary(self, **overrides):
        return dict(result='Passed', totalTestCount=45, passedTests=45,
                    failedTests=0, skippedTests=0) | overrides

    def test_accepts_a_completed_suite(self):
        self.assertEqual(check_summary(self.summary()), 45)

    def test_rejects_empty_or_entirely_skipped_suites(self):
        for changes in (
            dict(totalTestCount=0, passedTests=0),
            dict(passedTests=0, skippedTests=45),
        ):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                check_summary(self.summary(**changes))

    def test_rejects_partial_skips_and_failed_results(self):
        for changes in (
            dict(passedTests=44, skippedTests=1),
            dict(passedTests=44, failedTests=1),
            dict(result='Failed'),
        ):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                check_summary(self.summary(**changes))

    def test_rejects_missing_or_invalid_counts(self):
        for value in (None, '45', -1, True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                check_summary(self.summary(passedTests=value))


if __name__ == '__main__':
    unittest.main()
