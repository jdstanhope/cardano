# Cardano — product design

How the tool works and why it is shaped this way. The [README](../../README.md) is the
short introduction; this is the document to read before building or changing anything.

Living document. Expect it to grow, and expect parts of it to be revised once the first
implementation makes the consequences concrete.

## Purpose and audience

Cardano is a tool for designing and evaluating the mathematics of slot games.

Slot design is a numbers problem before it is an art problem. Which symbols sit on each
reel, how many times each one appears, and what the paytable awards together decide how
often the game pays, how much it returns over its lifetime, and how it feels to play.
The tool exists to make those consequences visible while the design is still being
decided, rather than after the game has been built.

The audience is whoever is choosing those numbers. They need an answer fast enough to
try another option, and exact enough to take to an operator.

## Domain model

The vocabulary, from the smallest piece upward.

**Symbol** — one image that can appear on a reel, such as `A`, `K`, or a themed
high-value symbol.

**Reel** — one vertical strip of symbols. A spin stops each reel independently, and the
reel window shows a few consecutive positions from each.

**Stop** — a single position on a reel strip where it can come to rest. The number of
stops on a reel, and how often a given symbol occupies one, sets the probability of that
symbol appearing. Adding one more `A` to a reel changes the RTP.

**Reel window** — the grid of positions visible after a spin, and the only place
matching happens. Two dimensions: the number of reels available for matching, normally
the same as the number of reels the game defines, and the number of rows available. A
five-reel game showing three rows has a 5x3 window of fifteen positions.

The window is **rectangular to begin with** — every reel shows the same number of rows.
A later version may let the row count vary per reel, which changes both the shape of the
window and which paylines can be drawn through it, so the rectangular case is worth
getting right first.

**Payline** — a fixed path through the reel window, taking one position from each reel
in play, along which matching symbols are counted. A game defines a set of these, and a
spin is evaluated against every one of them. The window's height bounds which paths can
exist: three rows allow a line to take row 1, 2, or 3 on any given reel.

**Winning combination** — the symbols on a payline that actually form a paytable entry.
Reading from the leftmost reel, it is the leading run of matching symbols; anything
further along the line that does not extend that run is outside the combination. A
payline produces at most one, and produces none when no entry matches.

```
payline symbols:  A  A  A  K  Q
                  └───────┘
                  winning combination = A×3

The K and Q lie on the payline but outside the combination.
```

**Paytable** — the mapping from a winning combination to what it pays, keyed by symbol
and by how many of that symbol landed in a row. For example `A×3 = 5`, `A×4 = 25`,
`A×5 = 100`, as a multiple of the stake on that line.

**Game** — one titled slot game. The tool is built to hold many games rather than model
one at a time.

**Variation** — one complete, playable configuration of a game, identified by a two
digit number padded below ten: `01`, `02`, `99`. It is stored as an integer and padded
for display, so `1` and `01` cannot become different values for the same variation and
ordering is numeric rather than alphabetical. Every game is created with variation `01`,
since a game with no variation cannot hold any maths at all. Variations exist mainly
to offer the same game at **different RTP figures**, which operators and jurisdictions
routinely require: the same title might ship at 96%, 94%, and 92%.

### What owns what

This is the part that matters most, and the part a glossary alone does not convey.

```
Game
 ├── symbols          shared across variations
 ├── reel window      shared across variations
 ├── paylines         shared across variations
 └── Variation (many)
      ├── reel strips        differs between variations
      └── paytable           may differ between variations
```

A game owns what stays constant: symbols, reel window, paylines. Those are what make a
title recognisable, so its variations remain the same game to a player.

A variation owns what moves the maths. Reel strips are the **primary RTP lever** —
changing which symbols occupy which stops changes every probability in the game. The
paytable is the **secondary lever**, adjusted when reel strips alone cannot reach the
target.

Two consequences follow:

- **Figures belong to a variation, not a game.** A game does not have one RTP; each of
  its variations does. Anything that reports RTP, hit frequency, volatility, or max win
  is reporting on a variation.
- **A game owns a collection of variations from the outset**, even while only one
  exists. This is a starting point, not a simplification to design around — adding the
  second variation should be configuration, not rework.

## Data model

The first slice covers what a **game owns**. Reel strips and the paytable belong to a
variation and follow separately.

```
User
 └── Game               name, reel_count, row_count
      ├── GameSymbol    code, name, position
      ├── Payline       position, rows[]
      └── Variation     number, target_rtp_min, target_rtp_max
           ├── ReelStrip     position, symbols[]
           └── PaytableEntry game_symbol, count, payout
```

The reel window is two integers on the game rather than a table of its own, because
that is all it is.

`GameSymbol` is deliberately not called `Symbol`. A top-level `Symbol < ApplicationRecord`
would shadow Ruby's `::Symbol` across the whole application, and namespacing it as
`Game::Symbol` has the same problem inside `class Game`, where a bare `Symbol` would
resolve to the model. The association still reads `game.symbols`.

### Row indexing

Row indices run top to bottom, **descending, with zero at the centre**, so the centre
line is `[0, 0, 0, 0, 0]` whatever the window height. For `n` rows the top index is
`(n - 1) / 2` by integer division, and the bottom is `top - (n - 1)`.

| Window | Indices, top to bottom |
| ------ | ---------------------- |
| 2 rows | `0, -1` |
| 3 rows | `1, 0, -1` |
| 4 rows | `1, 0, -1, -2` |
| 5 rows | `2, 1, 0, -1, -2` |

An even window therefore has one row above the centre and two below it. A V across a
three-row window reads `[1, 0, -1, 0, 1]` — it looks like the shape it describes, which
a top-indexed `[0, 1, 2, 1, 0]` does not.

`Game#row_range` owns this rule so it is not re-derived elsewhere, and
`Game#offset_from_top` converts an index for rendering, since views count from the top
while the domain counts from the centre.

A payline is validated against its game: one row per reel, and every row inside the
window. A payline that does not fit its window is the most likely route to silently
wrong figures later.

### Reel strips and the paytable

A variation holds one `ReelStrip` per reel and a set of `PaytableEntry` rows. These are
the two levers on the maths: the strips are the primary one, the paytable the secondary.

**Reels may differ in length.** A five-reel game whose reels carry 32, 34, 32, 30, and
32 stops is ordinary design and a real lever, so nothing requires strips to match one
another. The outcome space is the product of the stop counts, not a power of one of them.

A strip stores its stops as symbol **codes**, and a paytable entry references a symbol by
**foreign key**. That inconsistency is forced rather than chosen: a Postgres array cannot
carry a foreign key, so the array validates in the model regardless — and given that,
codes buy readability and straightforward import, because strips arrive as columns of
codes rather than ids. A single-column reference can have a real foreign key, so it does.

Two rules stop a paytable describing something impossible. A `count` cannot exceed the
game's `reel_count`, and a `game_symbol` must belong to the same game as the variation.
Both records reach a game independently, and an entry pairing a variation with another
game's symbol describes a combination that can never land — it would skew the figures
quietly rather than raise.

### Wilds

A wild substitutes for other symbols rather than paying for itself. A game has at most
one and may have none, and a symbol named `Wild` is the wild by virtue of its name.

**It substitutes for everything except what it is told to leave alone** — a deny list,
not an allow list. The distinction matters more than it looks: with a deny list, a
symbol added later is substitutable without anyone remembering to revisit the setting.
With an allow list it would be silently excluded, and the result is an RTP that is too
low while looking entirely reasonable.

Two rules for evaluation, decided here and implemented when evaluation exists:

**A line pays its best interpretation, once.** For each symbol, the run is the leading
sequence of "that symbol or a wild". Several readings of one line may win; only the
best-paying one pays. Summing them would double count, because `W W A A A` and
`W W K K K` are the same outcome read two ways.

**A line of nothing but wilds pays the best-paying symbol's full line.** It follows
from the two rules above rather than being a special case: the wilds stand in for
whichever symbol pays most.

That second rule is also where the cheap RTP calculation needs care. Summing each
symbol's expected run independently overstates the figure once wilds exist, for the
same reason only one interpretation pays.

### How a game wins

A game pays by **lines** or by **ways**, and both are reached through one interface so
evaluation does not branch on which is in use.

Both answer the same question — which combinations does this spin offer to the
paytable — and differ only in how. A mechanic yields, for each winning shape:

    symbol, run length, how many times it occurs

**Lines** yields one entry per payline that produces a run, each occurring once. A line
pays its best interpretation and only that one, because several readings of one line
may win and paying both would count the same spin twice.

**Ways** yields one entry per symbol, occurring as many times as the arrangements
allow: the product of the matching positions on each reel. It cannot enumerate its
combinations one by one and does not need to — a 5x3 window has 243 and a 6x4 has
4,096, but there are only ever as many entries as there are symbols. Unlike a payline,
every winning symbol pays: two symbols can both land on one spin and both count.

The multiplicity is what lets one interface serve both. Lines is always one, which is
what it is rather than a special case.

A mechanic also answers **what a spin costs**, because RTP is return over stake and the
stake is not the same: one unit per payline, or one unit per way. Evaluation cannot
produce a figure without asking.

Runs read left to right and must begin on the leftmost reel, under both mechanics.

**A run pays the longest count the paytable prices.** Five of a kind on a paytable that
only names three pays the three, rather than nothing because five was never priced. For
ways, the arrangements are then counted over the reels forming that combination rather
than the whole run.

A ways game has no paylines and its count follows from the window. Switching a game
with paylines to ways is refused rather than discarding them — a setting does not
destroy work as a side effect.

### How the figures are checked

A calculation this central cannot be verified against tests written to match it. Three
checks are used, and they are independent in different ways.

**Brute force.** Every stop combination walked, payouts totalled, divided by the stake.
A completely separate route to the same number. It proves the expectation maths, but
not the rules: it shares the mechanics with the calculation, so a wrong rule would be
wrong identically in both and they would still agree.

**A trivial published figure.** Three reels of twenty symbols with one combination
paying 7,500 returns `7500 / 8000`, or 93.75%. That checks the arithmetic against
something nobody here wrote, but it uses one payline, one combination, no wilds and no
groups.

**Red White & Blue.** A real machine with published reel strips, a published paytable
and a published return of 86.58% for one coin. Fifteen overlapping combinations,
ordered sequences of specific symbols, ordered sequences of groups, a symbol belonging
to several groups at once, and a blank that pays. This is the only check that exercises
the *rules* rather than the arithmetic: if best interpretation did not pay exactly
once, the total would come out wrong rather than raising anything.

It computes 86.5761%, which is 86.58% to the precision published.

That definition is not confined to the test. It lives in `SampleGame::RedWhiteAndBlue`
and is also what somebody copies into their account from the games list, so the example
handed to a newcomer is the same data the calculation is proven against — an example
that is demonstrably right rather than one that merely looks plausible.

That last check also settled something the source did not state. Nothing published says
which symbols count as red, white or blue; the classic design colours the bars, one bar
red, two bar white, three bar blue. Under any other reading the total does not land on
the published figure, so the figure decided the question.

### Copying a game

Describing a game means entering symbols, groups, a reel window, paylines, strips and a
paytable by hand. Two situations avoid that: starting from a worked example, and trying
a change without risking the game you already have. Both are the same mechanism —
duplicating a game — and a sample is simply a template that gets duplicated.

`GameDuplication` rebuilds the whole graph: symbols, groups and their memberships, wild
substitution rules, paylines, and every variation with its strips and paytable
combinations. The hazard is not failure but success that is subtly wrong. A reference
left pointing at the original's rows would not raise; the copy would read as complete
while quietly sharing a paytable with the game it came from, so that editing one changed
the other. Nothing copies an id — every association is rewired through a map built as
records are created, and a lookup for something unmapped raises rather than returning
nil.

The check that matters is that a duplicate computes the same RTP as its original. That
one number covers the whole graph; no assertion about record counts would.

### Exactness

`Variation` stores its target RTP as **integer basis points** — 9600 is 96.00%. The
reason for evaluating every outcome is to produce exact figures, so a float target
would undercut the premise on the first column that stores a number. Payouts will be
integers for the same reason.

## How the figures are computed

Everything derives from one thing: the **outcome distribution**, a mapping from each
possible payout to the probability of it occurring. Compute that and the rest falls out.

| Figure | Derived as |
| ------ | ---------- |
| **RTP** (return to player) | The share of total stake returned over the long run: the sum of payout × probability, divided by stake. Typically has to land inside a target band set by an operator or regulator. |
| **Hit frequency** | How often a spin returns a win of any size: the total probability of all outcomes paying more than zero. Two variations can share an RTP and feel completely different depending on this figure. |
| **Volatility** | The spread of outcomes around the average — whether the game pays small and often, or rarely and large. |
| **Max win** | The largest achievable payout, usually expressed as a multiple of stake. |

### Computing RTP without enumerating

RTP does not need the outcome space walked, and computing it by expectation is exact
rather than approximate.

**Lines.** A reel stops uniformly, so for any fixed row the symbol on a reel is
distributed exactly as that strip's frequency — shifting by a row only relabels which
stop is landed on. Reels are independent, and every payline sees the same marginals, so
one line's expectation is the whole answer. The sum runs over symbol combinations
rather than stop combinations: a ten symbol five reel game has 100,000 of the former
and tens of millions of the latter.

Whole combinations are evaluated rather than each symbol's run summed separately. The
quicker route double counts, because a line pays its best reading once and `W W A A A`
and `W W K K K` are one outcome read two ways.

**Ways.** Every symbol pays independently, so there is no best-interpretation coupling,
and within a symbol the reels are independent. With the expected number of matching
positions per reel and the chance of none, the expectation factorises across reels.

A realistic five reel game with thirty stop strips and nine paylines computes in under
a tenth of a second. Enumerating its 24 million stop combinations would take minutes.

The other figures — hit frequency, volatility, max win — do need the outcome space,
because they depend on the joint distribution of payout per spin and paylines share
reel positions. That is what will need a background job.

## Why evaluation is exhaustive

For a base game with static reels the outcome space is finite and small. It is the
product of the stop counts across the reels, so five reels of 32 stops give

    32^5 = 33,554,432 combinations

That is few enough to enumerate directly. Every combination is evaluated against every
payline, and the results accumulate into the outcome distribution.

Exhaustive evaluation is preferred over simulation because it gives **exact** figures
rather than estimates. An RTP that must land inside a regulatory band should not carry a
confidence interval when it does not have to.

**Where this stops being true.** The approach holds while the outcome space stays
enumerable. Features multiply it: free spins introduce sequences of spins rather than
single ones, and cascading or expanding mechanics make the space unbounded. At that
point the choice is between evaluating the base game exhaustively and layering feature
contributions on analytically, or falling back to simulation for the affected parts.
That decision is not needed yet and should be made when the first feature arrives, not
before.

## Scope boundaries

The first implementation is deliberately the smallest thing that produces a real answer:

- a **game** carrying a **single variation**
- a **base game** only
- a **static set of reels**, each with a fixed set of **stops**
- a **rectangular reel window** of fixed dimensions
- **fixed paylines**
- a **paytable** mapping symbol and count to a payout

Explicitly excluded for now: multiple variations per game, wilds and scatters, free
spins, bonus rounds and feature triggers, ways or cluster pays, and progressive
jackpots. Each multiplies the outcome space and needs the base to be correct first.

### Expansion order

1. **Multiple variations per game.** Comes before any feature work — producing a title
   at several RTP figures is the point of the tool, not an enhancement to it. Once a
   single variation evaluates correctly, the work is holding several and comparing them
   side by side.
2. **Wilds and scatters**, then **free spins and bonus features**, each building on the
   same evaluation.
3. **Ways-based wins**, as an alternative to paylines.
4. **Non-rectangular reel windows** — a differing number of rows per reel. This reshapes
   the outcome space and the set of drawable paylines rather than adding a feature on
   top, so it is worth taking only once the rectangular case is solid.

## Open questions

Recorded rather than silently assumed. None of these block the first implementation.

- **How is a game defined and entered?** Through the web interface, an imported file, or
  both. Reel strips are long and hand-entering them is unpleasant.
- **Are variations compared in the tool?** Holding several is one thing; showing them
  side by side against a target band is another, and may be the more valuable half.
- **What precision do payouts and probabilities need?** Floating point is convenient and
  approximate; exact rational arithmetic is slower but genuinely exact, which is the
  stated reason for evaluating exhaustively in the first place.
- **Is evaluation fast enough interactively?** 33.5 million combinations against 20
  paylines is 670 million evaluations. That may or may not be acceptable inside a web
  request, and the answer changes the shape of the application.
- **Does a variation need a target RTP as input?** Recording the band a variation aims
  for would let the tool report whether it lands inside, rather than just what it is.
