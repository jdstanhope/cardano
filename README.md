# Cardano

A tool for designing and evaluating the mathematics of slot games.

Slot design is a numbers problem before it is an art problem. Which symbols sit on
each reel, how many times each one appears, and what the paytable awards together
decide how often the game pays, how much it returns over its lifetime, and how it
feels to play. Cardano exists to make those consequences visible while the design is
still being decided, rather than after the game has been built.

The tool holds many games, and each game can carry several variations — alternate
configurations of the same game tuned to different RTP figures.

## What it computes

Given a complete definition of a game variation, the tool evaluates the outcome space
and reports:

| Figure | Meaning |
| ------ | ------- |
| **RTP** (return to player) | The share of total stake the game returns over the long run, as a percentage. Typically has to land inside a target band set by an operator or a regulator. |
| **Hit frequency** | How often a spin returns a win of any size. Two games can share an RTP and feel completely different depending on this figure. |
| **Volatility** | The spread of outcomes around the average — whether the game pays small and often, or rarely and large. |
| **Max win and distribution** | The largest achievable payout, and the full distribution of outcomes it comes from. Every figure above is derived from that distribution. |

For a base game with static reels the outcome space is finite and small: it is the
product of the stop counts across the reels, so five reels of 32 stops give
32<sup>5</sup> = 33,554,432 combinations. That is few enough to evaluate exhaustively,
which yields exact figures rather than the estimates a simulation would produce.

## Terms

**Symbol** — one image that can appear on a reel, such as `A`, `K`, or a themed
high-value symbol.

**Reel** — one vertical strip of symbols. A spin stops each reel independently, and
the reel window shows a few consecutive positions from each.

**Stop** — a single position on a reel strip where it can come to rest. The number of
stops on a reel, and how often a given symbol occupies one, is what sets the
probability of that symbol appearing. Adding one more `A` to a reel changes the RTP.

**Reel window** — the grid of positions visible after a spin, and the only place
matching happens. It has two dimensions: the number of reels available for matching,
normally the same as the number of reels the game defines, and the number of rows
available. A five-reel game showing three rows has a 5x3 window of fifteen positions.

The window is **rectangular to begin with** — every reel shows the same number of rows.
A later version may let the row count vary per reel, which changes both the shape of
the window and which paylines can be drawn through it, so the rectangular case is worth
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

**Game** — one titled slot game: its symbols, its reel window, its paylines, and the
variations below. The tool is built to hold many games rather than model one at a time.

**Variation** — one complete, playable configuration of a game. Variations exist mainly
to offer the same game at **different RTP figures**, which operators and jurisdictions
routinely require: the same title might ship at 96%, 94%, and 92%.

A variation differs from its siblings in its **reel strips**, and possibly in its
**paytable**. Changing which symbols occupy which stops changes every probability in
the game, so it is the primary lever for moving RTP; adjusting the paytable is the
secondary one. The symbols, reel window, and paylines are properties of the game and
are shared across its variations, so the variations remain recognisably the same game
to a player.

Every figure under [What it computes](#what-it-computes) belongs to a variation, not to
a game. A game does not have one RTP; each of its variations does.

## Starting scope

The first implementation is deliberately the smallest thing that produces a real
answer:

- a **game** carrying a **single variation**
- a **base game** only
- a **static set of reels**, each with a fixed set of **stops**
- a **rectangular reel window** of fixed dimensions
- **fixed paylines**
- a **paytable** mapping symbol and count to a payout

Explicitly not included yet: multiple variations per game, wilds and scatters, free
spins, bonus rounds and feature triggers, ways or cluster pays, and progressive
jackpots. Each of those multiplies the outcome space and needs the base to be correct
first.

Supporting one variation is a starting point, not a simplification to design around:
the structure should treat a game as owning a collection of variations from the outset,
so that adding the second is configuration rather than rework.

## Where it goes from here

The base game is a starting point rather than the intended scope. Ways-based wins,
wilds and scatters, and free-spin features are the natural next steps, each building on
the same exhaustive evaluation.

Multiple variations per game come earlier than any of those, since the ability to
produce a title at several RTP figures is the point of the tool rather than an
enhancement to it. Once a single variation evaluates correctly, the work is holding
several and comparing them side by side.

A non-rectangular reel window — a differing number of rows per reel — is a further
expansion. It affects the outcome space and the set of drawable paylines rather than
adding a feature on top, so it is worth taking only once the rectangular case is solid.

## Development with Docker

Cardano is a Rails 8.1 application using PostgreSQL and Tailwind CSS. Everything
you need runs in containers — Ruby, the app server, the Tailwind watcher, and
PostgreSQL. Docker Desktop (or any Docker Engine with Compose v2+) is the only
prerequisite.

```sh
docker compose up
```

That builds the image on first run, waits for PostgreSQL to report healthy,
creates and migrates `cardano_development` and `cardano_test`, then starts Puma
and the Tailwind watcher. The app is at <http://localhost:3000>.

### Everyday commands

Run these in a second terminal while the stack is up:

```sh
docker compose exec app bin/rails console
docker compose exec app bin/rails test
docker compose exec app bin/rails generate model Widget name:string
docker compose exec app bin/rails db:migrate
docker compose exec app bin/rubocop
docker compose exec app bash          # a shell in the app container
```

If the stack is *not* running, swap `exec` for `run --rm` and Compose will start
PostgreSQL as needed:

```sh
docker compose run --rm app bin/rails db:migrate
```

### Debugging

`bin/dev` enables the `debug` gem. Drop a `debugger` call in your code, then
attach to the running container to get the prompt:

```sh
docker compose attach app     # detach again with ctrl-p ctrl-q
```

Error pages also give you an interactive `web-console` session in the browser.

### Managing the stack

```sh
docker compose logs -f app    # tail the Rails and Tailwind output
docker compose restart app    # after changing an initializer or the Gemfile
docker compose down           # stop; database and gems are preserved
docker compose down -v        # stop and delete the database and gem volumes
docker compose build app      # rebuild after changing Dockerfile.dev
```

Gems live in a `bundle` volume rather than the image, so after editing the
`Gemfile` a `docker compose restart app` is enough — the entrypoint notices the
bundle is out of date and installs the difference. No rebuild required.

### Connecting to the database

PostgreSQL is published on the host at `localhost:5432` for GUI clients:

| Setting  | Value                 |
| -------- | --------------------- |
| Host     | `localhost`           |
| Port     | `5432`                |
| User     | `cardano`             |
| Password | `password`            |
| Database | `cardano_development` |

These credentials are for local development only. Change the port mapping in
`compose.yaml` if something already occupies 5432.

Both published ports are bound to `127.0.0.1` rather than all interfaces, so
neither the app nor the database is reachable from your local network. This
matters in development specifically: `web-console` renders an interactive Ruby
REPL on error pages, which is code execution for anyone who can load one.

### How it fits together

| File                      | Purpose                                                     |
| ------------------------- | ----------------------------------------------------------- |
| `compose.yaml`            | The `app` and `postgres` services, volumes, and health check |
| `Dockerfile.dev`          | The development image (`Dockerfile` is for production)       |
| `bin/docker-dev-entrypoint` | Syncs gems and prepares the database before booting        |

Caching, Action Cable, and Active Job all run in-process in development
(`memory_store` and the `async` adapters), so no Redis or worker container is
needed. Production uses Solid Cache, Solid Cable, and Solid Queue instead.

**System tests** are not covered by this setup — `selenium-webdriver` needs a
browser that the app container doesn't include. They are commented out in
`config/ci.rb` and `test/system` is empty, so nothing is broken today; adding a
`selenium/standalone-chromium` service to `compose.yaml` is the fix when the
first system test lands.

## Developing without Docker

The app still runs natively against a local PostgreSQL install. `config/database.yml`
only reads `DB_HOST`, `DB_USERNAME`, and `DB_PASSWORD` when they are set, and
`compose.yaml` is the only thing that sets them — so with them unset, Rails connects
over the local domain socket exactly as a stock Rails app does.

```sh
bin/setup
bin/dev
```

## Deployment

The production image is built from `Dockerfile` and deployed with
[Kamal](https://kamal-deploy.org) via `config/deploy.yml`.
