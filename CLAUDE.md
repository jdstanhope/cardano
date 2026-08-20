# CLAUDE.md

Project conventions for Claude Code. These rules are mandatory, not advisory.

## Environment

This project is developed in Docker containers. Rails and PostgreSQL both run under
Compose; nothing is installed on the host.

```sh
docker compose up -d                # start the stack
docker compose exec app <command>   # run anything inside the app container
```

Every Ruby, Rails, and Rake command in this file assumes that `docker compose exec app`
prefix. See `README.md` for the full command reference.

Stack: Rails 8.1, PostgreSQL 18, Propshaft, importmap (no Node, no JS bundler),
Tailwind v4, Minitest (not RSpec), RuboCop via `rubocop-rails-omakase`. Solid
Cache/Queue/Cable are production-only; development runs them in-process.

## Workflow

All work follows these steps in order. No step is optional and no step may be reordered.

### 1. Open a GitHub issue first

No code is written before an issue exists.

```sh
gh issue create --title "<short imperative title>" \
  --body "<problem, desired outcome, acceptance criteria>"
```

Record the issue number — steps 2 and 6 need it. If work is requested without an issue,
create the issue first and confirm the framing before starting.

### 2. Branch from an up-to-date main

```sh
git fetch origin
git checkout main
git pull --ff-only origin main
git checkout -b <type>/<issue-number>-<slug>
```

`<type>` is one of `feature`, `fix`, `chore`, `docs`. Example: `feature/12-user-sign-in`.

Never commit directly to `main`. `--ff-only` is deliberate: if it refuses, `main` has
diverged and that must be resolved explicitly rather than absorbed into a silent merge
commit.

### 3. Do the work

Write the test first wherever there is behaviour to test. Follow the patterns already
in the codebase rather than introducing new ones.

### 4. Verify — this is what "done" means

```sh
docker compose exec app bin/ci
```

**The work is not done until this exits 0.** It runs RuboCop, Brakeman, bundler-audit,
the importmap audit, the test suite, and seeds — the same checks GitHub Actions runs
against the PR.

- Never report work as complete, finished, or passing without running this and showing
  the actual output.
- A failing gate means fix the code. Never skip a step, disable a cop, or narrow the
  test run to manufacture green.
- If a check genuinely cannot pass, stop and say why. Do not open the PR.

### 5. Draft the PR, then stop

Write the PR title, body, and risk analysis and **wait for explicit approval before
anything reaches GitHub**. Creating the issue, branching, committing, and running the
gate are autonomous. Pushing and opening the PR are not.

### 6. Push and open the PR

```sh
git push -u origin HEAD
gh pr create --title "<title>" --body "<body>"
```

The body must contain `Closes #<issue-number>` so the issue closes on merge, and must
include the risk analysis below.

## Risk analysis

Every PR body carries a `## Risk analysis` section with all six headings. "Low risk" is
not an acceptable substitute for any of them.

**Blast radius** — which files, endpoints, jobs, or behaviours this change can affect,
including indirect consumers.

**Failure modes** — what specifically goes wrong if this change is incorrect, and what
the user-visible symptom would be.

**Data and migrations** — does it alter schema or data, and is it reversible? Name any
migration that cannot be rolled back without data loss.

**Security and configuration** — any change to authentication, authorisation, secrets,
published ports, allowed hosts, CORS, or dependency versions. State "none" only if true.

**Test coverage gaps** — what this change does that the suite does not verify. Be
specific; reviewers rely on this section most.

**Rollback** — the exact steps to undo this in production, and anything that makes
rollback harder than reverting the commit.
