# Panda. — the secret tree (LOCKED design + build status)

*Design: Brandon + Lyra, Jul 20 2026. Built Jul 25 2026.*

> **Read this before touching anything below.** Panda is a trust-fall between the
> player and the game, and it is **never fully legible, on purpose.** "The moment
> we explain why the panda samurai selects a target, we have wounded the panda."
> If the Internet cracks the logic, **we change the backend logic** — we do not
> confirm it. Brandon: "I will die on this hill."

---

## The card ladder

All ability text is `???`. Forever. Including the capstone reveal. The
punctuation **is** the information:

| Tier | Name | Character |
|---|---|---|
| T1 | `Pandas.` | a panda wanders in, does one mildly useful thing |
| T2 | `Panda!` | more frequent, more proactive |
| T3 | `Panda...?` | raises questions |
| T4 | `Panda.` | meaningfully but inconsistently helpful · **samurai appears** |
| T5 | `PANDA.` | Spark becomes a flaming panda kaiju |

## The Panda Run Rule (LOCKED)

- **9.27%** eligibility roll at run start. Erratic on purpose — *not* 10%, *not*
  9%. Do not round it.
- If eligible, the first offer appears in an **early window (levels 2–5)**, so a
  committed player can still reach T5.
- **Activation is TAKING the card, not seeing it.** The first domino.
- Once active, **every other level-up** guarantees one Panda slot (one slot, not
  the spread), climbing T2→T5 deterministically.
- Passing a rung is never punished — it returns at the next scheduled offering.
  Waiting. Judging.
- **You cannot reroll the panda**, and it can never appear *because* you
  rerolled.
- **Outside the taxonomy:** no tag, no synergy contribution, no normal pool
  presence, no truthful descriptions, no capstone modal until T5.

## The Panda Samurai

A rare panda with a bamboo sword walks **calmly** to ONE target, strikes once,
**bows, and leaves**. Priority: **elite > miniboss > boss > highest-HP normal** —
deliberately *not* the game's normal boss-first-nearest rule.

The trigger is **5%**. That is the whole trigger. It is not conditional on
anything.

---

# BUILD STATUS — Jul 25 2026

All five tiers **built**, building clean, static sim launch clean at 60fps.
Interactive feel pass reserved for Brandon.

## Where it lives
- `UpgradeCard.isSecret` — out of every pool; the scheduler is the only way in.
- `UpgradeCard.tierNames` — the punctuation ladder (new; generic).
- `UpgradeManager` — `pandaEligible` / `pandaActive` / `pandaOffer(atLevel:)`.
- `PandaNode.swift` — the puppet (waddle, roll, sit, hat, portal, sword, bow).
- `GameScene` — `PandaAct`, `updatePandas`, `updatePandaKaiju`. **The scene owns
  every decision**; the node knows how, never why.
- `GameConfig.Panda` — every number.

## Acts, by tier
- **T1** roll · sit (eats shots) · aggro · bamboo (a pickup) · **pleased (does
  nothing — load-bearing)**
- **T2** body-check, plus a tighter arrival cadence
- **T3** portal · stack (a second panda climbs on) · **follow (shadows an elite,
  never attacks it)** · bamboo rain (5 stalks, 1 is real) · tiny hat
- **T4** pin · nap (a heal zone) · badly-coordinated avalanche · **samurai (5%)**
- **T5** the kaiju: ~10s, 85% damage reduction, contact damage + knockback, boss
  takes repeated **stagger, never deletion**. Reverts to embers; a panda eats
  bamboo and refuses to acknowledge any of it; ordinary pandas are left milling.

## Decisions made during the build (Brandon to confirm)
- **The first offer sits in the window on EVERY level 2–5 until taken**, rather
  than one single chance. 9.27% is already the rarity; making the player also win
  a one-shot coin flip would make the tree effectively unseeable.
- **Panda is NOT flagged `isCapstone`.** That flag drives the draft's
  focus-and-finish lockout, so flagging it would let a joke tree block a player's
  real capstone and eat its guaranteed slot. The T5 reveal modal is fired by hand
  instead — title `PANDA.`, effect `???`.
- **Excluded from GRANTED draws** (the gauntlet's RANDOM opener): being handed a
  card is not *taking* it, and grants would violate the activation rule.
- **The kaiju reads out on the CapstoneTimerHUD as `???`.** The player learns the
  *rhythm* — real agency, you can bank a fight for it — without ever being told
  what the rhythm is for. Legible cadence, illegible cause.
- **Kaiju damage reduction sits OUTSIDE the Forge Path DR cap.** It's a
  transformation, not another entry in the mitigation bucket.
- **The samurai can't delete boss-class above `BossClass.executeThreshold`** —
  catastrophic damage instead. Canon holds even here.

## Defect found en route
`upgradeManager.reset()` only runs on **restart**, never on the first run after
launch — so rolling the mutation solely there meant run 1 of every session could
never be Panda-eligible. Now rolled in `init` *and* `reset` via
`rollRunMutations()`. Worth remembering: in a system designed to be silent,
a silent bug is invisible.

## Testing it
`GameConfig.Panda.debugAlwaysEligible = true` forces every run eligible — 9.27%
is not something you can iterate against. **An active seam paints a badge in the
run HUD**, and you must reinstall the sim after switching it back off.

## OPEN
- **Balance:** at T1 one of five acts is a free health orb (~1 per 45s). Faithful
  to "one mildly useful act", but it is real sustain — watch it.
- **Not yet built:** the panda skins (earned mask-only Spark / premium mini
  flaming kaiju), both gated behind reaching T5 once. They belong to the **art
  pass**, alongside the Nature Canon sprites.
- **Not yet built:** the "hidden Panda stacks accumulating since T1, all firing at
  T5" optional flavour.
