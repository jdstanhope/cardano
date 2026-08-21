# Cardano

A Rails 8.1 application using PostgreSQL and Tailwind CSS.

## Development with Docker

Everything you need runs in containers — Ruby, the app server, the Tailwind
watcher, and PostgreSQL. Docker Desktop (or any Docker Engine with Compose v2+)
is the only prerequisite.

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
