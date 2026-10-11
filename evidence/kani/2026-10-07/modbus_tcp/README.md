# Kani — Modbus TCP layer (2026-10-07)

Tree: `7353899` (`01807ab` adds the module). Kani 0.68.0, CBMC 6.11.0, Linux.
Reproduce from the repository root: `evidence/kani/2026-10-07/modbus_tcp/run_mbtcp.sh <out_dir>`.

| Run | Harness | Expected | Result |
|---|---|---|---|
| tree as committed | `proof_mbtcp_frame_iff_act_and_matches_order` | verified | VERIFICATION SUCCESSFUL, 13.8 s |
| tree as committed | `proof_mbtcp_parse_total` | verified | VERIFICATION SUCCESSFUL, 8.0 s |
| mutant A: MBAP `tid ^ 1` in `from_rtu` | `proof_mbtcp_frame_iff_act_and_matches_order` | fails | FAILED: `u16_be(b, 0) == tid` |
| mutant B: FC16 quantity 9 accepted | `proof_mbtcp_parse_total` | fails | FAILED: bounded-write assertion |

The script aborts if a mutation does not apply, and restores the source on exit.

**First negative control had no effect.** Mutant B was first run, during development, against
a parser harness limited to 30-byte inputs. A 9-register FC16 frame is 31 bytes, so the
mutation was never explored and the harness still passed. The harness now explores inputs up
to 37 bytes (8 past the largest valid frame), and mutant B fails as expected.

Scope: these harnesses prove the TCP transport only. That a frame exists only for `Act` is
inherited from `modbus_gateway::gateway_decision`, whose own proofs are in `../modbus/`.

---

## Erratum et réexécution — 2026-10-08

**Ce paquet était incomplet** : son `SHA256SUMS` listait **quatre logs absents du dépôt**.
`*.log` est ignoré par git et les logs n'avaient pas été forcés à l'ajout, donc le
manifeste revendiquait un résultat qu'il ne pouvait pas montrer. Le manifeste lui-même en
était la preuve.

Les quatre exécutions ont été **refaites le 2026-10-08 sur `ef6adb5`**, la révision où le
module entre dans la branche principale — mieux que de restaurer des logs d'un arbre plus
ancien, puisque c'est ce code-là qui est livré :

| Exécution | Harnais | Attendu | Résultat |
|---|---|---|---|
| arbre tel quel | `proof_mbtcp_frame_iff_act_and_matches_order` | vérifié | **SUCCESSFUL** |
| arbre tel quel | `proof_mbtcp_parse_total` | vérifié | **SUCCESSFUL** |
| mutant A : `mbap` écrit `tid ^ 1` | `proof_mbtcp_frame_iff_act_and_matches_order` | échoue | **FAILED**, comme voulu |
| mutant B : borne de quantité FC16 portée à `MAX_REGS + 1` | `proof_mbtcp_parse_total` | échoue | **FAILED**, comme voulu |

⚠️ **Les deux mutations ne sont pas celles que décrivait ce README.** Il citait
`u16_be(b, 0) == tid` et « quantité 9 acceptée » ; ces motifs n'existent pas dans le
source. Les vraies mutations portent sur `b[0..2].copy_from_slice(&tid.to_be_bytes())`
(ligne 55) et sur `if qty == 0 || qty > MAX_REGS` (ligne 146). Le script
[`run_mbtcp_redo.sh`](run_mbtcp_redo.sh) les applique en vérifiant que chaque motif
apparaît **exactement une fois**, et abandonne sinon — ce qu'il a fait au premier essai,
ce qui est précisément comment l'écart a été trouvé.
