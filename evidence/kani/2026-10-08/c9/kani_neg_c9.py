#!/usr/bin/env python3
"""Negative control for the C9 harnesses. Aborts unless every pattern matches once."""
import io
import os
import sys

MUTATIONS = [
    (
        'oasis-rt/src/quorum.rs',
        '    if !quorum_ok {\n        return Decision::Reject(Reason::QuorumMissing);\n    }\n',
        '',
        'proof_quorum_required_to_act',
        'the quorum is no longer required to act',
    ),
    (
        'oasis-rt/src/quorum.rs',
        'if n == 0 || n > MAX_QUORUM_SIGS || b.len() != oaq1_len(n) {',
        'if n > MAX_QUORUM_SIGS || b.len() != oaq1_len(n) {',
        'proof_oaq1_parse_total',
        'a quorum order with zero signatures parses, so it looks like an ordinary order',
    ),
]

root, mode = sys.argv[1], sys.argv[2]
for i, (rel, old, new, proof, what) in enumerate(MUTATIONS, 1):
    path = os.path.join(root, rel)
    with io.open(path, encoding='utf-8', newline='') as f:
        raw = f.read()
    crlf = '\r\n' in raw
    s = raw.replace('\r\n', '\n')
    a, b = (old, new) if mode == 'apply' else (new, old)
    n = s.count(a)
    if n != 1:
        raise SystemExit(
            'ABORT M%d (%s): pattern found %d times, expected 1. Head: %r'
            % (i, rel, n, a[:60])
        )
    s = s.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(s.replace('\n', '\r\n') if crlf else s)
    print('M%d %s -> %s MUST FAIL (%s)' % (i, mode, proof, what))

print('all %d mutations %sed' % (len(MUTATIONS), mode))
