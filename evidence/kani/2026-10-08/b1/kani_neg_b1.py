#!/usr/bin/env python3
"""Negative control for the B1 harnesses. Aborts unless every pattern matches once."""
import io
import os
import sys

MUTATIONS = [
    (
        'oasis-rt/src/mavlink_order.rs',
        '    if class != OrderClass::Act {\n'
        '        return (Decision::Reject(crate::actuation::Reason::OutOfLimits), None, None);\n'
        '    }\n',
        '',
        'proof_stop_class_never_arms',
        'a Stop order reaches the gate and can arm',
    ),
    (
        'oasis-rt/src/mavlink_order.rs',
        '        Decision::Reject(_) => (d, None, None),',
        '        Decision::Reject(_) => (\n'
        '            d,\n'
        '            Some(ArmAction::Arm),\n'
        '            Some(encode_command_long(\n'
        '                seq, sysid, compid, target_sys, target_comp,\n'
        '                MAV_CMD_COMPONENT_ARM_DISARM, 0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,\n'
        '            )),\n'
        '        ),',
        'proof_no_arm_frame_without_act',
        'a rejected order produces an ARM frame anyway',
    ),
    (
        'oasis-rt/src/mavlink_order.rs',
        '    if o.force == 1.0 {\n        Some(ArmAction::Arm)',
        '    if o.force >= 1.0 {\n        Some(ArmAction::Arm)',
        'proof_action_is_total_and_binary',
        'force above 1.0 counts as an arm, so the action is no longer binary',
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
