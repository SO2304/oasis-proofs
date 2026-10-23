# Withheld traces — what was removed, and how to check it

**Since 23 October 2026, this corpus publishes verdicts, not the traces that reveal the code.**

The repository has held proofs and not code since 11 October 2026. But proofs carry traces, and
some traces describe the code they ran: a formal-verification log prints the module and the source
line of every check, a compiler warning quotes the offending line of source, and a supply-chain log
lists every dependency. Counted on 23 October 2026, the public traces named the code's structure
about 19 800 times and quoted some 13 400 lines of source. Those traces are withheld. What a trace
**proved** is kept.

## What replaces a withheld trace

| | |
|---|---|
| **an extract**, `<name>.extrait.txt`, next to where the original was | every verdict as it came out — the property and its result, the test counts, the fuzzing statistics, the measurement table, the supply-chain verdict — and nothing that describes the code |
| **a commitment**, `RETENUS.tsv`, in the same directory | for every withheld file: its extract (or `-`), the **SHA-256 of the original**, its size, its nature |

Each extract repeats the original's SHA-256 and size in its header. An extract of a formal-verification
log is named after the **property** it proves, not after its module. A campaign trace keeps every
line; only source paths, internal identifiers and tool names are replaced in it.

## How to check a withheld trace

The originals are kept, byte for byte and at the same path, in the private code repository —
checked for every one of them on 23 October 2026. Under a non-disclosure agreement the original can
be produced; anyone can then compute its SHA-256 and compare it with `RETENUS.tsv`. The commitment
was published before any request, so the original cannot be adjusted to fit it.

⚠️ **An extract is a declaration, not a proof on its own.** It becomes checkable only against the
original, under NDA. That is the price of not publishing the code's map, and it is stated here
rather than left for a reader to discover.

## Counts

| | files |
|---|---:|
| withheld | **548** |
| replaced by an extract | 532 |
| withheld without an extract (13 binaire, 1 diff, 2 source) | 16 |
| directories carrying a `RETENUS.tsv` | 59 |
| reports redacted (source paths, internal identifiers, script and file names removed) | 53 |

Each redacted report says so in a note under its title. Its results are unchanged: the names of the
formally verified properties are kept, because they **are** what was proven.

## What was not withheld

Journals, journal verdicts, campaign consoles, measurements, the vulnerability-audit summaries and
every report: they describe what OASIS did, not how it is built. Host working paths and private,
non-routable LAN addresses appear in some traces; they do not describe the code.
