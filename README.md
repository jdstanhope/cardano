# Cardano

A tool for designing and evaluating the mathematics of slot games.

Slot design is a numbers problem before it is an art problem. Which symbols sit on each
reel, how many times each one appears, and what the paytable awards together decide how
often the game pays, how much it returns over its lifetime, and how it feels to play.
Cardano exists to make those consequences visible while the design is still being
decided, rather than after the game has been built.

The tool holds many games. Each game carries one or more variations — alternate
configurations tuned to different RTP figures — and every figure below is reported per
variation.

## What it computes

- **RTP** (return to player) — the share of stake returned over the long run
- **Hit frequency** — how often a spin returns a win of any size
- **Volatility** — whether the game pays small and often, or rarely and large
- **Max win** — the largest achievable payout

For a base game with static reels the outcome space is small enough to evaluate
exhaustively, so these are exact figures rather than simulated estimates.

## Design

**[docs/design/product.md](docs/design/product.md)** is the reference for the domain
model, how the figures are computed, the scope of the first implementation, and the open
questions. Read it before building or changing anything.

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

Drop a `debugger` call in your code, then attach to the running container to get
the prompt:

```sh
docker compose attach app     # detach again with ctrl-p ctrl-q
```

Error pages also give you an interactive `web-console` session in the browser.

### Running system tests

System tests drive a real browser, which runs in the `selenium` service rather than
being installed on your machine:

```sh
docker compose exec app bin/rails test:system
```

To watch a run as it happens, open <http://localhost:7900> and enter the password
`secret`. The browser is deliberately not headless so this works.

Neither `bin/ci` nor GitHub Actions runs them. They failed intermittently in CI and
never locally — sixteen local runs across both browser modes, no failures — so the job
was removed rather than left to turn unrelated pull requests red. See issue #51.

That makes running them a deliberate step. They cover what integration tests cannot:
Turbo submissions, the sign-out link, and the live reel counter. Worth running after
touching any of those, because nothing else will.

### Managing the stack

```sh
docker compose logs -f app    # tail the Rails and Tailwind output
docker compose restart app    # after changing an initializer or the Gemfile
docker compose restart css    # rarely needed; the watcher restarts itself
docker compose down           # stop; database and gems are preserved
docker compose down -v        # stop and delete the database and gem volumes
docker compose build app      # rebuild after changing Dockerfile.dev
```

Gems live in a `bundle` volume rather than the image, so after editing the
`Gemfile` a `docker compose restart app` is enough — the entrypoint notices the
bundle is out of date and installs the difference. No rebuild required. A
generator that adds a gem is the same case: the running server booted before the
gem existed, so restart it or the next request fails to load it.

### Why the watcher is its own service

Puma runs in `app` and the Tailwind watcher runs in `css`. They were originally a
single service running `bin/dev`, which runs both under foreman — and foreman
tears down the whole formation as soon as any one process exits. A `git checkout`
rewrites files under the bind mount, the watcher notices and exits, and that
stopped the web server too.

Split apart, the watcher restarts itself without touching Puma. `restart:
unless-stopped` is set on `css` only; on `app` it would mask a crash loop rather
than surface it.

`bin/dev` still exists and still works for running the app natively.

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
| `compose.yaml`            | The `app`, `css`, `postgres`, and `selenium` services, volumes, and health check |
| `Dockerfile.dev`          | The development image (`Dockerfile` is for production)       |
| `bin/docker-dev-entrypoint` | Syncs gems and prepares the database before booting        |

Caching, Action Cable, and Active Job all run in-process in development
(`memory_store` and the `async` adapters), so no Redis or worker container is
needed. Production uses Solid Cache, Solid Cable, and Solid Queue instead.

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
