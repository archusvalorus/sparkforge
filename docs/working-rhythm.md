# Working Rhythm — How We Plan → Build → Close Out

*The operating system for how Brandon and Claude collaborate on Forgebound
Labs projects. Written for Sparkforge, but studio-portable — paste it into any
project's session to bootstrap the rhythm, and codify the non-negotiables in
that repo's `CLAUDE.md` to make it stick. Last updated July 15, 2026.*

## Two homes for knowledge — keep them separate

- **Per-sprint scope → a kickoff doc** (`docs/<version>-kickoff.md`), committed
  to the repo. Structure:
  - **Thesis** — what this version is, in a sentence or two.
  - **Decided — do not relitigate** — the locked calls, so we don't re-argue
    settled questions mid-sprint.
  - **Unit sequence** — each unit with a **Definition of Done (DoD)**.
  - **Waiting on** — external dependencies (e.g. a creative brief).
  - **Banked / out of scope** — deferred ideas, explicitly parked.
  - Future versions get a lighter `<version>-outline.md`; creative/design asks
    get their own `<name>-brief.md`.
- **Cross-session facts → the memory system** — decisions, banked ideas, user
  preferences, the roadmap arc, working agreements. One index doc as the
  "start here." This is what survives when a thread ends; the kickoff docs are
  the sprint's working surface, memory is the studio's long-term brain.

## The unit loop (plot → plan → execute → build → refine → closeout)

1. **Scope before code.** Don't build what isn't scoped; don't relitigate
   decided questions.
2. **Plan the big ones.** For complex or load-bearing units: plan → get
   approval → build. Surface the *real* forks with a recommendation; use a
   decision prompt for genuine either/ors. Skip planning for trivial mechanical
   work — when you have enough to act, act.
3. **One unit at a time.** Build it, run the gates, then **STOP**.
4. **Quality gates:** builds clean, **zero new warnings**, config-driven (no
   scattered magic values), no risky patterns (e.g. no force-unwraps in new
   code). Match existing conventions.
5. **Static checks are Claude's; feel is the human's.** Claude launches,
   screenshots reachable screens, confirms no-crash / performance — but does
   **not** drive the app to judge gameplay feel. Brandon owns the interactive
   validation gate; it's his design instrument, not just QA.
6. **Commit on an explicit "pass"** — **one commit per unit, at DoD-pass**,
   message noting what shipped + "device-validated" when it was.
   **Never push without explicit approval.**
7. **Refine from the playtest.** Tuning values are one-line dials — adjust,
   re-gate, commit.

## Bank everything, immediately

Any idea that surfaces mid-work but isn't in the current scope gets pinned
**right then** — memory for durable/cross-session, the doc's "banked" section
for sprint-local. Nothing evaporates. **Completion > new ideas:** the bench of
banked ideas is a feature, not a backlog guilt-trip — it's what lets us finish
the thing in front of us without losing the thing we just thought of.

## Roles

- **Brandon** — product, orchestration, playtesting / device validation gate.
- **Claude** — build, static/build checks, documentation, memory.
- **Creative partner (e.g. Lyra)** — design briefs, art/narrative direction,
  where applicable. Typical flow: *brief → build → review → orchestrate/playtest.*

## Closeout

Version bump → ship pass (screenshots, release notes / What's New) → **the
human does the store submission** (credentials + public release are theirs to
execute) → post-ship registry/doc updates (portfolio registry, live-version
flip, any new physics bits / ad units).

## Making it stick in a new repo

- **Codify the non-negotiables in that repo's `CLAUDE.md`** — workflow, quality
  gates, division of labor, locked design canon. This note *bootstraps* the
  rhythm; `CLAUDE.md` *enforces* it for every future session automatically.
- **Seed its memory early** with the roadmap + locked decisions, so
  cross-session continuity kicks in from day one.
