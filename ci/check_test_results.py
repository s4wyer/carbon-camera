"""Reject successful Xcode invocations that ran no tests or skipped targets."""

import argparse
import json
from pathlib import Path
import sys


def check_summary(summary: dict) -> int:
    for name in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests'):
        if type(summary.get(name)) is not int or summary[name] < 0:
            raise ValueError(f'Missing or invalid Xcode test count: {name}')
    if summary.get('result') != 'Passed' or summary['failedTests']:
        raise ValueError('Xcode test results did not pass')
    if not summary['totalTestCount'] or not summary['passedTests']:
        raise ValueError('Xcode executed no passing tests')
    if summary['skippedTests']:
        raise ValueError(f"Xcode skipped {summary['skippedTests']} tests; check the test manifest and destination")
    return summary['passedTests']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('summary', type=Path)
    args = parser.parse_args()
    try:
        count = check_summary(json.loads(args.summary.read_text(encoding='utf-8')))
    except (ValueError, OSError) as error:
        sys.exit(str(error))
    print(f'Verified {count} passed tests, with no failures or skips')
