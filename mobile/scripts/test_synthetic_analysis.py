import unittest
from analyze_synthetic_trial import analyze, reference_segments


class SyntheticAnalysisTests(unittest.TestCase):
    def test_estimated_intervals_are_clipped_to_reference_and_false_work_is_visible(self):
        def sample(t, kind):
            return {'uptime': t, 'condition': 'readable', 'classification': {'kind': kind}}
        trial = {'id': 'fixture', 'startedUptime': 0, 'endedUptime': 8,
                 'samples': [sample(0, 'slack'), sample(2, 'slack'), sample(4, 'slack'), sample(8, 'unknown')]}
        events = [
            {'uptime': 1, 'event': 'step-start', 'classification': 'slack', 'step': 0},
            {'uptime': 3, 'event': 'step-start', 'classification': 'unknown', 'step': 1},
            {'uptime': 8, 'event': 'finished', 'classification': 'unknown', 'step': 1}
        ]
        result = analyze(trial, events)['steps']
        self.assertEqual(result[0]['correctClassEstimatedSeconds'], 2)
        self.assertEqual(result[1]['falseWorkSeconds'], 1)
        self.assertEqual(result[1]['unclassifiedSeconds'], 4)

    def test_incomplete_capture_is_not_reported_as_finished(self):
        with self.assertRaises(ValueError):
            analyze({'id': 'running', 'samples': []}, [])

    def test_foreground_transition_does_not_duplicate_one_reference_stage(self):
        events = [
            {'uptime': 1, 'event': 'step-start', 'classification': 'slack', 'step': 0},
            {'uptime': 2, 'event': 'foreground', 'classification': 'slack', 'step': 0},
            {'uptime': 31, 'event': 'finished', 'classification': 'slack', 'step': 0}
        ]
        self.assertEqual(reference_segments(events), [(0, 'slack', 1, 31)])
