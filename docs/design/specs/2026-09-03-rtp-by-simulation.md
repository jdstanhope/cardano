# Estimating RTP by simulation

Design for [#84](https://github.com/jdstanhope/cardano/issues/84). Written before any
code, and expected to be revised once the first implementation makes the consequences
concrete.

[product.md](../product.md) is the document to read first; this one assumes it.

## Why this exists

Exact evaluation works where the outcome space factorises, which is what `Rtp::Lines`
and `Rtp::Ways` do today. It does not cover everything: hit frequency, volatility and
max win need the joint distribution of payout per spin, which paylines sharing reel
positions prevent factorising, and games too large or too dynamic to evaluate have no
other route.

A run should therefore be able to be a **simulation**, asked for by the precision
wanted rather than by a spin count. The accuracy is what somebody cares about; how many
spins reach it depends on the game's volatility and is arithmetic the tool can do.

## What the measurements said

Taken on the development machine before the design was settled, because the shape of
the feature depends entirely on how fast a spin can be made to go. The subject is a
realistic 5x3 game: 20 paylines, 10 symbols including a wild, 32-stop strips, 27
paytable entries.

| Route | Spins per second |
| ----- | ---------------- |
| `WinMechanic` per spin, as the code stands | 28 |
| `WinMechanic` per spin, `excluded_symbols` preloaded | 331 |
| Compiled evaluator | **166,758** |

The first row is not a fair reflection of `WinMechanic`; it is a bug, described under
[A finding that is not part of this work](#a-finding-that-is-not-part-of-this-work).

The third row is what makes the feature possible. At 331 spins per second, a precision
of +/-0.05 points at 95% takes roughly 320 hours and every run in practice ends at its
ceiling, which means the tool would spend its time reporting that it could not answer
the question. At 166,758 it takes about 38 minutes.

Those durations assume a per-spin standard deviation of five times stake, which is
modest for a real game. **The spin count needed is a property of the game's volatility,
not a constant**, and a high-volatility game will want an order of magnitude more. That
is the whole reason the run is asked for by precision and works the count out
adaptively; the figures above are for sizing the feature, not promises to a user.

The compiled evaluator was also run against the ways mechanic — 157,691 spins per
second — so the approach is not specific to lines.

## The compiled evaluator

`SpinTable.for(variation)`, mirroring the existing `WinMechanic.for(game)`, with
`SpinTable::Lines` and `SpinTable::Ways`.

```ruby
table = SpinTable.for(variation)   # compiles once
table.spin(rng)                    # => payout in stake units, an Integer
table.hits                         # => per-entry tally, for coverage
table.stake_units
```

The load-bearing observation is that **a reel's window is a pure function of that
reel's stop**. Everything a mechanic needs from a reel can therefore be precomputed
into a table indexed by the stop, and a spin becomes table lookups and integer
arithmetic that never touches a symbol object.

**Lines.** Each symbol becomes an integer index, each paytable entry a bit in a bitset
ordered by descending payout, and each `(reel, symbol)` pair a bitset of the entries
whose matcher at that reel accepts that symbol — plus every entry too short to reach
that reel, since nothing there can disqualify them. A payline is then an intersection,
and the best-paying match is the lowest set bit, which is `live & -live`.

```ruby
live = -1
line.each { |reel, row| live &= alive[reel][window[reel][row]]; break if live.zero? }
total += payout_for[live & -live] unless live.zero?
```

That the best match falls out of `live & -live` is what makes it fast, and it is
exactly the "a line pays its best reading once" rule that `WinMechanic::Lines` states
in prose — not a different rule that happens to agree.

**Ways.** Ways needs the count of matching positions per reel, multiplied, rather than
an intersection. Those counts precompute into a table indexed by `[reel][stop][matcher]`,
and a spin multiplies integers.

### The matching rules are not duplicated

This is the part that answers the risk the issue raises — that a sampler sharing the
evaluation rules keeps a wrong rule wrong in both, while a sampler *not* sharing them
can silently disagree.

Compilation does not restate the rules. It precomputes their answers by asking the
existing rule objects:

```ruby
bits |= (1 << index) if matcher.matches?(shown)          # lines
counts = window.count { |shown| matcher.matches?(shown) } # ways
```

`PaytableMatcher#matches?` is the same code the exact calculation uses. Wilds, wild
exclusions, symbol groups and any future matcher semantics therefore reach the compiled
evaluator for free and cannot drift, because there is only one definition of them. What
is written twice is only the **mechanic-level assembly** — how wins are selected and
combined — and that is bound by the agreement test below.

### How it is kept correct

A permanent test asserts that `SpinTable` and `WinMechanic` produce the same payout for
**every one of Red White & Blue's 262,144 outcomes**. The spike version of this already
passes with zero mismatches.

This is exhaustive rather than sampled, it is cheap because the game is small, and it is
the reason a second evaluation path is acceptable at all. One new mechanic means one new
compiled assembly and one extension to this test.

### The bitset has a boundary at 62 paytable entries

One entry is one bit, so the whole bitset is a single machine word while a variation has
at most 62 combinations. Past that Ruby's integers leave fixnum range and every `&`
allocates. Measured on the intersection alone:

```
 61 entries   505,759 line-groups/s   1.02x
 62 entries   509,860 line-groups/s   1.03x
 80 entries   259,554 line-groups/s   0.52x
400 entries   219,739 line-groups/s   0.44x
```

Flat to the boundary, then half. It does not degrade further with size — 400 entries
costs about what 80 does — because the cost is the allocation rather than the width.

**Not worth solving yet.** The measured game has 27 entries and a rich one with twelve
symbols across four lengths has 48; exceeding 62 takes a lot of bespoke mixed
combinations, and the penalty when it happens is a factor of two rather than a wall.

**The remedy, when it is wanted**, is to split the bitset into fixnum-sized banks.
Trading one bignum `&` for three fixnum ones is close to a wash on its own, but entries
are already ordered by descending payout, so bank zero holds the highest-paying ones:
process banks in order and stop at the first with a survivor, and most spins never look
past bank zero.

### Building the window may be avoidable

The evaluator as spiked materialises the window each spin, which costs a modulo per
position:

```ruby
rows.times { |o| col[o] = strip[(stop + o) % lengths[reel]] }
```

But a payline reads one row per reel, and `alive[reel][window[reel][row]]` is a pure
function of `(reel, stop, row)` — so it can be precomputed as `line_mask[reel][stop][row]`
and the window never built at all. That is the same hoist the ways table already makes,
applied to lines.

Unmeasured, so it is not assumed. Pull request **a** implements the straightforward
version first and compares the two; if the precomputed masks do not win, the simpler
loop stays. The tables also cost memory proportional to reels x stops x rows, which is
small but not nothing.

### Where it stops working

Recorded so the limit is a known one rather than a surprise.

| Extension | Effect on the compiled evaluator |
| --------- | -------------------------------- |
| New matcher semantics, wilds, exclusions, groups | None. Compiles through `matches?` automatically |
| Scatters paying anywhere | Small: a count per `(reel, stop)`, summed |
| Non-rectangular reel windows | Small: tables are already per reel |
| Multipliers | Small: a per-entry scalar |
| Free spins, bonus rounds | Natural: a sequence of spins, each still a stop tuple |
| A new mechanic, such as cluster pays | A new compiled assembly, plus the agreement test |
| Cascades, expanding or sticky wilds | **Breaks the premise** — the window stops being a function of the stops |

The last row is not a reason to choose differently now. Cascading and expanding
mechanics break the *exact* calculation considerably harder: product.md already records
that they make the outcome space unbounded. At that point simulation is the only route
left, and this inner loop is the foundation it would be built on, minus the per-stop
tables.

## The sampler

`Rtp::Simulation` draws a stop per reel from a seeded `Random`, evaluates through
`SpinTable`, and accumulates two things:

- an **exact integer total** of payout in stake units
- **Welford** running mean and `m2`, in floating point, for the variance

So the figure is exactly `Rational(total, spins * stake_units)` and drops into
`RtpFigure`'s existing `numerator` and `denominator` with no change to how a figure is
stored. The interval is floating point, because a variance estimate has no business
pretending to be exact, and the project's rational arithmetic exists to keep exact
things exact rather than to decorate estimates.

Welford rather than accumulating a sum of squares: the sum of squares of integer
payouts is exact but leaves fixnum range within a run of this length, and bignum
arithmetic in the hottest loop in the application is a poor trade for a number only
used to size an interval.

## Precision, and being honest about it

`Rtp::Precision` carries the requested `points`, the `confidence`, the `ceiling`, and a
minimum spin floor, and answers `:precision`, `:ceiling`, or nil.

The interval is the ordinary CLT interval, `z * sqrt(variance / n)`, with `z` from a
lookup for the confidences the interface offers rather than an inverse normal nobody
needs. **A figure is always reported with its interval** — `96.21% +/-0.04 at 95%`,
never a bare `96.21%`. `Rtp::Result` already carries its method for exactly this reason,
and gains an `interval` alongside it.

**The minimum spin floor** exists because an interval computed from a handful of spins
can be narrow by accident, and a stopping rule that believes it would stop almost
immediately.

**Coverage is reported alongside the interval.** Slot payouts are extremely skewed: a
2400x combination dominates the variance, and before it has been hit the interval is
over-confident in a way no amount of arithmetic on the observed sample can detect. So
the run reports how many times each paying combination actually landed:

```
96.21% +/-0.04 at 95%
384,000,000 spins, stopped on precision

coverage
  R7 W7 B7   x2400     seen 3 times      (!)
  R7 x3      x1199     seen 41 times
  W7 x3      x200      seen 892 times
  everything else                        seen over 1,000 times
```

Reporting it rather than letting it block stopping is a deliberate choice. A rule that
refused to stop until every combination had been seen twenty times would, for a
genuinely rare one, run every simulation to its ceiling and make the requested precision
decorative. Telling the reader both the interval and whether to believe it is strictly
more information than silently continuing.

**Stopping is a decision, not an accident.** The run stops on precision or on ceiling
and records which. Reaching the ceiling without the precision is a result —
`+/-0.11 at 95% after 5,000,000,000 spins` — and not a failure.

## Reproducibility

The seed is recorded on the run, and re-running from a recorded seed reproduces the
figure exactly. An unreproducible figure cannot be investigated, and a disputed one is
precisely the case this has to serve.

This holds while a run is one process drawing stops in a fixed order. Splitting a run
across workers means per-worker seeds and combining partial results, which is the
parallel search's problem too, and is out of scope here.

## Two hazards this has to handle

Neither is mentioned in the issue, and both would be silent.

**`RtpFigure.record` would discard the second run.** It deduplicates on fingerprint,
on the reasoning that "an unchanged configuration recomputes to the same figure". That
is true of exact evaluation and false of sampling: two simulations of one configuration
legitimately differ, and under the current rule the second is dropped and the history
shows one figure where two runs happened. Sampled figures must bypass the deduplication.

**The Red White & Blue acceptance test must use a fixed seed.** "The simulation lands
within its stated interval of the exact figure" is a probabilistic claim, and at 95%
confidence it fails one run in twenty. Left seeded randomly it would be a test that goes
red every few weeks for no reason, which teaches everyone to ignore it — [#51](https://github.com/jdstanhope/cardano/issues/51)
is already that lesson. With a fixed seed the assertion is deterministic and still
proves what it is there to prove.

## Data model

Additive and nullable throughout. Nothing is backfilled: runs that predate this have no
seed because they were not simulations.

```
calculations   + seed             bigint
               + spins            bigint
               + precision_points integer   requested, in hundredths of a point
               + confidence       integer   90, 95, 99
               + ceiling          bigint
               + stopped_because  string    "precision" | "ceiling"

rtp_figures    + half_width       decimal   nil for an exact figure
               + confidence       integer   nil for an exact figure
               + spins            bigint
               + coverage         jsonb     per-combination hit counts
```

`Rtp::SAMPLED` joins `Rtp::EXACT`, and `computed_by` already carries the method on both
`calculations` and `rtp_figures`, so no column is repurposed.

## Delivery

Five pull requests. CLAUDE.md holds a diff to roughly 100 changed lines, and this is
comfortably past that as one change. The order puts the maths first, where being wrong
is cheapest to discover.

| | | Verified by |
| --- | --- | --- |
| **a** | `SpinTable`, both mechanics, and the per-stop mask comparison | Agreement with `WinMechanic` across all 262,144 RWB outcomes |
| **b** | `Rtp::Simulation` — seeded draws, exact total, Welford | Same seed gives the same figure; RWB lands within its interval of 86.5761% |
| **c** | `Rtp::Precision`, the coverage tally | Stops on precision; stops on ceiling; says which |
| **d** | Persistence: seed, spins, interval, coverage, stop reason | Two sampled runs both record; `computed_by` round-trips |
| **e** | The run form, live progress, cancellation, the interval on screen | System tests |

Nothing is visible in the browser until **e**, which is the accepted cost of landing the
risk first.

## A finding that is not part of this work

`GameSymbol#substitutes_for?` calls `excluded_symbols.exclude?(symbol)`. On an unloaded
association `include?` issues an `EXISTS` query on every call and never caches the
result, so a game with a wild queries the database once per matcher check. On the 5x3
game above:

```
exact, as it is today               153.02s    336,399 SQL queries   RTP 117.9591%
exact, excluded_symbols preloaded    13.27s          11 SQL queries   RTP 117.9591%
```

The same figure, 11.5 times faster. This affects the **exact** calculation today and has
nothing to do with simulation — the compiled evaluator resolves wilds once at compile
time and never pays this cost. It is raised as its own issue rather than widening this
branch.

## Out of scope

- Splitting one run across several workers
- Hit frequency, volatility and max win, which this makes reachable but does not deliver
- Searching variations for one meeting a requirement, which is [#85](https://github.com/jdstanhope/cardano/issues/85) and builds on this

## Open questions

- **How is the time estimate produced before a run starts?** A short pilot run gives a
  variance estimate and therefore a spin count, but its own estimate is poor early. The
  interface may be better showing the estimate settling as the run proceeds than
  promising a duration up front.
- **What is a sensible default precision?** +/-0.05 points is about 38 minutes on the
  measured game; +/-0.5 points is about 24 seconds. The default decides whether the
  feature feels interactive or batch, and should probably be the looser one.
