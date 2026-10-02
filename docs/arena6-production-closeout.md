# Arena 6 production closeout — The Splitworks (v2.1, geometry Units 4–5)

Written Oct 1, 2026, at the end of geometry Unit 5. It covers two things: what it took to ship an arena, and what is still open for this one. The design is in `arena6-splitworks-design-lock.md` and the engineering decisions in `arena6-geometry-reconciliation.md`. Ability-side hardening is in `v2.1-abilities-a7b-return.md` (S13–S15 are the geometry repairs).

**Status:**
- Built and checkpointed. Nothing is committed or pushed.
- Next: the consolidated regression and independent review, then **Brandon's release playtest**, which is the device gate for everything here.

---

## 1. Shipping an arena — the reusable checklist

Each step is a single home in the code. Arena 7+ should touch the same places and nothing else.

| Step | Where | What Arena 6 did |
|---|---|---|
| 1. **Arena entry** | `Config/ArenaConfig.swift`: one `ArenaConfig` plus a place in `all` | `splitworks` (id 5): palette, `radiusScale` 1.15, `bossID` / `bossName` / `bossFelledAccentHex`, `finalFelledLine` (the title card's line while it's the last arena), `geometryBuilder`. Registering it is all progression needs: the unlock registry (`ProgressionManager.registerArenaBossDefeat`) opens it when the previous boss falls, and the launch reconciliation heals any save that already felled that boss. |
| 2. **Geometry descriptor** | `Config/ArenaGeometry.swift`: `static var <name>` | One footprint (the Fallen Carrier), 6 route nodes and 6 edges, 4 deployment gates (spawn zones), and 2 safe anchors (`player_spawn`, `boss_anchor`). `swapArena` rebuilds it, so Boss Mode gets it too. |
| 3. **Floor and solid art** | `GameScene.setupArena`: a `build<Name>Motif` case, plus `buildSolidGeometryVisuals` | Procession rails into the wreck, route chevrons, gate masonry, broken signal standards; Carrier hull detail drawn **inside** the collision outline (painted = solid). All procedural. |
| 4. **Roster** | Node classes, a `spawn<Name>Enemy` dispatch, `GameConfig` blocks | Spurhound, Linekeeper, Ramplate (geometry Unit 2). |
| 5. **Boss** | An `ArenaBossNode` conformer | The Marchwarden (geometry Unit 3). It needs the shared damage entries (`takeDamage(_:ignoresChallengeDEF:resolved:)`, `takeDirectHit`), `VulnerabilityCarrier`, the status-tell anchor, and **`PlayerReachHazards`** whenever a hazard reaches Spark's body (A7b S15). Its `onDeath` records the kill, the bestiary, `registerArenaBossDefeat`, and the earned skin. |
| 6. **Boss Mode** | `Systems/BossRegistry.swift` entry, plus the gauntlet spawner `case` in `GameScene` | `BossEntry("marchwarden", arenaID: 5, .arena)` and `case "marchwarden": spawnMarchwarden()`. Boss Mode loads the home arena, geometry included. |
| 7. **Bestiary** | `BestiaryFamily` (stable id, name, `isBoss`, flavor, colour), the `bestiaryFamily(for:)` mapping, a `BestiaryCodexNode` portrait case | Four entries. Every line must fit the live wrapper: ≤ 3 lines at 39 characters on a 375pt phone (catalog CT9). |
| 8. **Reward** | `SkinManager`: a family plus an earned `SkinDefinition`, unlocked in the boss's `onDeath` | The Broken March / Marchworn: an earned re-tint, with no mechanical effect. |
| 9. **Sound** | `AudioManager.SFX` cases (procedural, synthesized with the shared helpers), triggered from the scene through node callbacks | Five cues (§3). Music is the shared 20-track deck; there is **no per-arena music**. |
| 10. **Proof** | Catalog WR-checks (wiring), geometry G-checks (the descriptor), vulnerability RN (the boss's real damage entries), mutants | WR19–WR23, CT9, G6–G8, RN7, the bgm harness, and the U4 / S13–S16 mutants. |

---

## 2. Arena 6 as shipped

- **Unlock:** felling the Unmade Star (Arena 5) opens the Splitworks. The registry gives `min(4 + 2, 6) = 6`.
- **Boss:** the Marchwarden. Felling it records the bestiary and **Marchworn**; Arena 7 doesn't exist yet, so nothing else opens.
- **The geometry repairs that land with it** (A7b S13–S15):
  - arcs and hops need a clear line past the Carrier;
  - Skybeam homing uses the gun's line of sight;
  - every knock is path-tested;
  - Vine Wall pushes before the resolve;
  - the lion and flowers never sit inside the Carrier (and flowers never past the wall);
  - Rich Soil respects the garden cap;
  - boss hazards reach the Harden-shrunk body.
- **Bestiary lines** are the design lock's lines verbatim:
  - Spurhound: "It learned the shortest distance between two points. Then it learned to hunt around corners."
  - Linekeeper: "A firing line given legs. It mistakes patience for permission."
  - Ramplate: "A barricade with forward momentum. The forge forgot that walls should stay put."
  - The Marchwarden: "The march ended long ago. Its warden still clears the road for an army that will never come."

  Each matches the shipped behaviour:
  - the hound flanks around the Carrier;
  - the Linekeeper anchors and aims;
  - the Ramplate braces, then charges;
  - the Marchwarden charges (Right of Way) and calls the column.

  All four fit the wrapper.
- **Marchworn** (an earned re-tint): charcoal-iron body `0x55514C` (lifted from pure charcoal so it reads on the Splitworks floor), oxidized-teal halo `0x3F8F8A`, an ember heart `0xFFB070`, pale-ceramic eyes `0xE8E0D0`, kiln-orange trail `0xD9772E`, glow ×1.25. Blurb: "Iron that kept marching after the road broke. Earned in Arena 6."

---

## 3. Sound

**Arena 6 cues** (design lock §9). Each is procedural and restrained, and plays on the tell that teaches its verb.

| Cue | Trigger | Character |
|---|---|---|
| `spurhoundWhine` | The Spurhound commits to its lunge | A turbine whine climbing 320 → 940 Hz, 0.34 s |
| `linekeeperAim` | The Linekeeper enters its aim | A thin sight tone at 1320 Hz with a slight waver, 0.26 s |
| `ramplateBrace` | The Ramplate braces | A dropping thud plus a grit burst and a dull 420 Hz clang |
| `wardenMuster` | The Marchwarden calls the Muster Signal | A brass-ish two-note call, D3 → G3 |
| `splitworksHorn` | Once, 1 s into an Arena 6 run | One distant low horn, and nothing answers |

The design lock's ambient beds (an interrupted hammer cadence, rail strain) were **not** built. "A restrained ambience … is sufficient", so they are a listening-gate question, not a gap.

**BGM.** One shuffled deck of all 20 verified Suno recordings. Its rules (`BGMDeck` / `MusicManager`):
- **Lifetime:** the app session.
- **Continuous** across title, run and boss.
- **Resume:** after an interruption, backgrounding or the BGM toggle, the same song resumes.
- **Boundary:** no back-to-back repeat at the cycle boundary.
- **Failure:** a track that won't start is dropped for that session.

The import:
- 20 copies of the verified source files, each named `bgm_<title>_<id8>.mp3`;
- byte-checked against the import map (71,528,558 bytes);
- the built app holds exactly those 20, with 20 distinct Suno IDs and no alternate encodings;
- the raw downloads and their manifests are untouched.

---

## 4. Integration checks (Unit 5)

| Check | Result |
|---|---|
| **Compatibility** | Clean Debug and Release builds: 0 errors, and the same 14 warning lines as before (none new). Boss Mode: the Marchwarden stage loads its home arena, geometry and safe anchor included (the `swapArena` → `setupArena` path). The independent review found that the swap left Growth's gardens, flowers and Tree in place, so `clampLooseNodesToArena` now re-validates them. **The title carousel and Boss Mode list are mostly data-driven, with two exceptions found in review:** the last live arena's victory line was hard-coded to the Star's (now `ArenaConfig.finalFelledLine`), and with six felled bosses the Boss Mode panel outgrew an iPhone SE (it now scales to fit). |
| **Progression** | The registry arithmetic is unchanged; adding the arena to `all` is the whole unlock. Players who already felled the Unmade Star get Arena 6 at their next launch through the reconciliation loop. |
| **Persistence** | Add-only. No `sf_` / `sparkforge_` key was removed or renamed (a source diff of every key literal); the four bestiary ids and the Marchworn unlock key are new. |
| **Telemetry** | The geometry counters already cover every Arena 6 verb: `spurhoundLunges`, `linekeeperAnchors` / `Shots` / `Relocates`, `ramplateBraces` / `Shoves` / `Misses` / `Walls`, `wardenCharges` / `Standards` / `Musters`, `losSuppressedTargets`, and the resolve causes. Nothing new was needed. |
| **Performance** | The floor adds about 52 static shape nodes (the Star Anvil's motif has about 25) plus the Carrier's interior detail. **Device watch**, judged in Brandon's playtest. |
| **Copy** | The bestiary is fitted (CT9) and the arena flavor line is unchanged ("the road broke. the march did not."). **The Marchworn name is canon; its blurb is new copy for Brandon to approve.** |

---

## 5. Open after Arena 6 (not blockers)

- **Lyra's pass:**
  - the bestiary lines are hers verbatim (provisional in the design lock), and Arena 5's copy was "locked by Lyra";
  - she may want the same lock here;
  - A9 may replace the procedural motif, Carrier detail and skin palette.
- **Ambient beds** (the hammer cadence, rail strain): optional by the design lock.
- **Found while logging hitboxes** (A7b S16): the Anvilborn slam ring and the Grounder pulse tell draw larger than their damage zones. They are generous, visual-only, and in the closeout audit.
- **Telegraph sizes, the Shatter rate on mini-bosses, and the Erasure boss fallback:** device watches from A7b.
