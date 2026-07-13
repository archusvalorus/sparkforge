# Arena Geometry — Future-State Vision (roadmap seed)

*Brandon's seed, July 13 2026. NOT scoped — not in v1.8, no version assigned
yet. Planted so it isn't lost. Requires a refactor + likely fundamental
arena/engine changes; treat as a multi-sprint evolution, not a smidge.*

## The insight

The minimalist geometric look began as a placeholder and has become a
**feature.** The spark glow-up + v1.7 polish flipped Brandon from "meh" to
"RAD" on the style. The direction now: **lean into and expand** the
minimalist-geometric identity, not replace it. The shapes are the art.

## The problem it solves

A single small circular arena gets **boring fast** — even with the
per-release enemy variety, the play space is compact and same-y. The game
wants **more rooms and arena types**: *spatial* variety, not only enemy
variety.

## The vein: shape-flavored arenas

Each geometric arena **shape** carries its own mechanic / hazard identity —
the silhouette becomes a promise about how that arena plays:

- **Circles (arena 5+):** random hole-shaped pitfalls open in the floor.
- **Triangles:** 3 random lightning strikes around the battlefield.
- **Squares:** rooms + traversal areas (multi-space arenas, not one bound).
- *(room to invent more per shape — hexagons, etc.)*

## Engineering reality (why it's not a smidge)

- Current arenas are a single bounded (circular) play space; "rooms /
  traversal" implies larger or multi-region spaces → camera, spawn
  distribution, **dynamic joystick recenter** behavior (LOCKED — must survive
  any refactor), and AI navigation all get touched.
- Floor pitfalls = a new terrain/hazard layer + player/enemy fall
  interactions (new physics category? fall = damage / relocate / death?).
- Per-shape hazards want a **hazard framework**, not one-off scripts.
- Realistically a genuine **arena-system refactor** precedes the first
  shaped arena.

## Relationship to the current roadmap

- v1.8 Mirrorwound = arena 4, still circular-family. Shape-flavor could
  **begin at arena 5+**, which aligns with the circle-pitfall idea.
- Extends / partly supersedes `docs/lyra-future-arenas-3-5.md` thinking.
- Sits alongside the banked Generalist synergy as a "big leap" — Brandon
  frames both as post-v2.0-era, though a shaped arena could arrive sooner if
  an arena refactor lands first.

## Status

Banked. Not scoped. Revisit when planning a post-Mirrorwound arena cycle or a
v2.0+ engine pass.
