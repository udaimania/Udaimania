#!/usr/bin/env python3
"""Compare on-device OCR intervals with the separate synthetic app's monotonic log.

This measures a controlled fixture, never real Slack/Gmail/iCloud reliability.
Reads local lab.json (or an exported report) and one reference-UUID.json.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path


def reference_segments(events):
    result = []
    for left, right in zip(events, events[1:]):
        if left['event'] not in {'step-start', 'foreground'} or left.get('step') is None:
            continue
        if right['uptime'] > left['uptime']:
            segment = (left['step'], left['classification'], left['uptime'], right['uptime'])
            if result and result[-1][:2] == segment[:2] and result[-1][3] == segment[2]:
                result[-1] = (*segment[:2], result[-1][2], segment[3])
            else:
                result.append(segment)
    return result


def analyze(trial, events):
    end = trial.get('endedUptime')
    if end is None:
        raise ValueError('Stop capture before analyzing a trial.')
    samples = sorted((s for s in trial['samples'] if trial['startedUptime'] <= s['uptime'] <= end), key=lambda s: s['uptime'])
    estimates = []
    for left, right in zip(samples, samples[1:]):
        kind = left['classification']['kind']
        if (0 < right['uptime'] - left['uptime'] <= 6 and left['condition'] == right['condition'] == 'readable'
                and kind == right['classification']['kind'] and kind != 'unknown'):
            estimates.append((kind, left['uptime'], right['uptime']))
    steps = []
    for index, expected, start, stop in reference_segments(events):
        totals = defaultdict(float)
        for kind, a, b in estimates:
            totals[kind] += max(0, min(stop, b) - max(start, a))
        observed = [s for s in samples if start <= s['uptime'] < stop]
        duration = stop - start
        correct = totals[expected] if expected != 'unknown' else None
        false_work = sum(totals[k] for k in ['slack', 'workMail']) if expected in {'unknown', 'nonWork'} else None
        steps.append({
            'step': index + 1, 'expectedClass': expected, 'referenceSeconds': duration,
            'estimatedSecondsByClass': dict(totals),
            'unclassifiedSeconds': max(0, duration - sum(totals.values())),
            'correctClassEstimatedSeconds': correct,
            'absoluteDurationErrorFraction': abs(correct - duration) / duration if correct is not None else None,
            'falseWorkSeconds': false_work,
            'sampleConditions': dict(Counter(s['condition'] for s in observed)),
            'sampleClasses': dict(Counter(s['classification']['kind'] for s in observed)),
        })
    return {
        'trialID': trial['id'], 'syntheticOnly': True, 'steps': steps,
        'referenceCompleted': any(e['event'] == 'finished' for e in events),
        'referenceInterrupted': any(e['event'] == 'interrupted' for e in events),
        'captureEnded': trial.get('endReason'),
        'limitations': [
            'Synthetic screens do not establish capture behavior in Slack, Gmail or Apple Mail.',
            'Reference measures fixture display intervals, not attention.',
            'Reference logs programmatic stage transitions; rendering and app activation can shift visible boundaries.',
            'Duration estimates interpolate adjacent matching readable samples at most six seconds apart.',
            'The two logs must come from the same iPhone boot; monotonic clocks are not comparable across reboots.'
        ]
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lab', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--trial-id')
    args = parser.parse_args()
    trials = json.loads(args.lab.read_text())['trials']
    trial = next((t for t in trials if not args.trial_id or t['id'] == args.trial_id), None)
    if trial is None:
        parser.error('No matching trial.')
    print(json.dumps(analyze(trial, json.loads(args.reference.read_text())), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
