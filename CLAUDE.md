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

**Keep the change small and self-contained.** A diff must be readable in one sitting;
**over ~100 changed lines is too large** and should be split. Size is measured on
`git diff --stat origin/main...HEAD`.

- One issue, one concern, one PR. Resolve an unrelated problem found along the way by
  opening a separate issue, not by widening this branch.
- If work is heading past the limit, stop and propose a split before writing more.
  Splitting a finished branch is far more expensive than sequencing it up front.
- Generated files and vendored content don't count toward the limit; say so explicitly
  when they're the reason a diff looks large.
- Exceeding the limit requires saying so, and why, when presenting the PR. It is an
  exception to be justified, never a default.

### 4. Verify — this is what "done" means

```sh
docker compose exec app bin/ci
```

**The work is not done until this exits 0.** It runs RuboCop, Brakeman, bundler-audit,
the importmap audit, the test suite, and seeds.

A green gate is necessary but not sufficient: `bin/ci` and `.github/workflows/ci.yml`
are separate definitions and can drift. GitHub prepares the test database with
`db:test:prepare`, which `bin/ci` does not. Always check the PR's checks after opening
it, and treat any divergence as a bug in `bin/ci` worth its own issue.

**System tests run nowhere automatically.** They were removed from CI for failing
intermittently there and never locally (#51). Run them by hand after changing anything
that depends on JavaScript — Turbo submissions, the sign-out link, the live reel
counter — because nothing else covers those:

```sh
docker compose exec app bin/rails test:system
```

- Never report work as complete, finished, or passing without running this and showing
  the actual output.
- A failing gate means fix the code. Never skip a step, disable a cop, or narrow the
  test run to manufacture green.
- If a check genuinely cannot pass, stop and say why. Do not open the PR.


### 5. Push and open the PR

```sh
git push -u origin HEAD
gh pr create --title "<title>" --body "<body>"
```

The body must contain `Closes #<issue-number>` so the issue closes on merge, and must
include the risk analysis below. Do not stop for approval first — the pull request is
where the change gets reviewed, next to the diff.

### 6. Confirm the checks pass

```sh
gh pr checks <number> --watch
```

A green local gate does not guarantee green checks; the two are separate definitions and
can drift. Report the result. If the checks fail, fix them rather than handing over a red
pull request.

## Autonomy

Everything through to an open, green pull request runs without asking: the issue, the
branch, the work, the gate, the push, and the pull request itself.

**Merging is manual.** That is the review point, and it stays with the person whose
repository it is.

Two things still stop the work rather than proceeding: a gate that cannot be made to
pass, and a design question whose answer would change what gets built. Neither is a
request for permission — they are cases where continuing would mean guessing.

## Merging

**Merge commits only.** Squash and rebase merging are disabled on the repository, so
the GitHub merge button offers only "Create a merge commit". This is deliberate.

Squashing replaces a branch's commits with a new commit that shares no ancestry with
them. Git then cannot tell that those commits are already in `main`, so any other
branch carrying them hits conflicts on changes that were already resolved once. Merge
commits keep the ancestry, which keeps parallel branches cheap to reconcile, and the
merge commit's second parent is a permanent record that the work happened on its own
branch.

For the collapsed one-line-per-PR view of history:

```sh
git log --first-parent main
```

### Keeping a branch current

Rebase while the branch is private; merge once it has been pushed.

```sh
# not yet pushed — rebase to keep history tidy
git fetch origin && git rebase origin/main

# already pushed or shared — merge, never rewrite
git fetch origin && git merge origin/main
```

Never force-push a branch that someone else may have pulled.

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
