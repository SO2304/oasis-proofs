#!/usr/bin/env python3
"""Negative control for the phase-2 parts G/H/I harnesses.

Applies three mutations that MUST make a named proof fail. Aborts if any mutation
does not apply exactly once -- the phase 1.4 negative control was invalid because a
`sed` silently matched nothing after cargo fmt reflowed a line.

Run inside the WSL clone:  python3 kani_neg_hardening.py <repo-root> apply|revert
"""
import io
import os
import sys

MUTATIONS = [
    # (file, old, new, proof that must now FAIL, what it breaks)
    (
        'oasis-rt/src/actuation.rs',
        '''    if i.revoked {
        return StopDecision::Reject(Reason::Revoked);
    }
    StopDecision::Stop''',
        '''    if i.revoked {
        return StopDecision::Reject(Reason::Revoked);
    }
    if i.v0b_ok && i.stop_authorized {
        return StopDecision::Reject(Reason::Expired);
    }
    StopDecision::Stop''',
        'proof_stop_never_blocked',
        'a fourth condition that can refuse an otherwise valid stop',
    ),
    (
        'oasis-rt/src/actuation.rs',
        '''    if ctx.stopped {
        return Decision::Reject(Reason::Stopped);
    }
''',
        '',
        'proof_act_refused_while_stopped',
        'the stop latch no longer blocks an Act',
    ),
    (
        'oasis-rt/src/journal.rs',
        'if b.len() != ENTRY_LEN || b[RESERVED_OFF..ENTRY_LEN] != [0u8; ENTRY_LEN - RESERVED_OFF] {',
        'if b.len() != ENTRY_LEN || b[RESERVED_OFF] != 0 {',
        'proof_journal_parse_total',
        'only the first reserved byte is checked (the defect Kani found)',
    ),
]

root = sys.argv[1]
mode = sys.argv[2]

for i, (rel, old, new, proof, what) in enumerate(MUTATIONS, 1):
    path = os.path.join(root, rel)
    with io.open(path, encoding='utf-8', newline='') as f:
        raw = f.read()
    crlf = '\r\n' in raw
    s = raw.replace('\r\n', '\n')
    a, b = (old, new) if mode == 'apply' else (new, old)
    if a == '':
        raise SystemExit('M%d: cannot revert an empty pattern' % i)
    n = s.count(a)
    if n != 1:
        raise SystemExit(
            'ABORT M%d (%s): pattern found %d times, expected 1. '
            'The control would be invalid. Pattern head: %r' % (i, rel, n, a[:60])
        )
    s = s.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(s.replace('\n', '\r\n') if crlf else s)
    print('M%d %s %-28s -> %s MUST FAIL (%s)' % (i, mode, rel, proof, what))

print('all %d mutations %sed' % (len(MUTATIONS), mode))
