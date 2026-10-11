#!/usr/bin/env python3
"""Negative control for the parts J and K harnesses.

Three mutations, each required to break one named proof. Aborts if any pattern does not
match exactly once -- the phase 1.4 control was invalid because a sed silently matched
nothing after cargo fmt reflowed a line.

  python3 kani_neg_jk.py <repo-root> apply
"""
import io
import os
import sys

MUTATIONS = [
    (
        'oasis-rt/src/actuation/wire.rs',
        'if b.len() != OAS1_LEN || b[0..4] != OAS1_MAGIC || b[10] != 0 {',
        'if b.len() != OAS1_LEN || b[0..4] != OAS1_MAGIC {',
        'proof_oas1_parse_total',
        'the reserved byte is no longer checked, so a stop has more than one encoding',
    ),
    (
        'oasis-rt/src/actuation/wire.rs',
        'self.actuator_id == OAS1_ALL_ACTUATORS || self.actuator_id == id',
        'self.actuator_id == id',
        'proof_oas1_addressing_is_total',
        'actuator_id 0 no longer addresses every actuator, so a fleet stop addresses nothing',
    ),
    (
        'oasis-rt/src/actuation/timeview.rs',
        'if validity_ms == 0 || validity_ms > MAX_VALIDITY_MS {',
        'if validity_ms == 0 {',
        'proof_timeview_window_is_bounded',
        'a commander can ask for a window wider than the gate allows',
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
            'ABORT M%d (%s): pattern found %d times, expected 1. The control would be '
            'invalid. Head: %r' % (i, rel, n, a[:60])
        )
    s = s.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(s.replace('\n', '\r\n') if crlf else s)
    print('M%d %s %-34s -> %s MUST FAIL (%s)' % (i, mode, rel.split('/')[-1], proof, what))

print('all %d mutations %sed' % (len(MUTATIONS), mode))
