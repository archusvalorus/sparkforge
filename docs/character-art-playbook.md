# The Character Art Playbook

*Written Jul 27 2026, from the v2.0 Panda Kaiju art pass — the first raster art
ever put into Sparkforge. The panda is the worked example; **everything above
the example is the reusable mold.** When the next ridiculous Spark glow-up gets
slotted into a sprint, start here instead of rediscovering all of it.*

---

## 0. What Sparkforge is, visually

Everything except character sprites is **procedural**: `SKShapeNode` paths,
glows, `.add` blending, self-lit colour on near-black. There is no general art
pipeline and there shouldn't be — the vector look IS the game's identity.

Raster art is the exception, reserved for **characters with presence**: the
thing you become, the thing that walks calmly toward a target, the thing that
towers. Not for terrain, effects, UI, or ambience.

---

## 1. Decide the SIZE before commissioning anything

The single most expensive mistake available is drawing beautiful art for a
footprint nobody checked.

**The method:**

1. Pick the on-screen size in **points**, as part of a ladder against Spark
   (`GameConfig.Player.visualRadius` = 16, so Spark is **32pt across**).
2. Multiply by 3 for @3x device pixels. **That is the entire detail budget.**
3. **Prove the ladder with placeholders first.** Emoji and shapes cost nothing
   and answer "does this crowd the arena / read at a glance" in one play session.
4. Only then commission.

**The v2.0 ladder** (iPhone, points across):

| | Points | @3x px | Notes |
|---|---|---|---|
| Spark | 32 | 96 | the reference for everything |
| Nature Canon animal | 50 | 150 | proven legible in play; funnier oversized |
| Mountain lion / panda | 76 | 228 | "a large animal wandered in" |
| Panda kaiju | 96 | 288 | biggest thing on the field, so T5 reads as escalation |

**Detail dies fast.** The kaiju's 1024×1536 source displays at 288px — about 3%
of the original pixel area. At that budget only four things survive: silhouette,
high-contrast masses, a glowing point (eyes), and one accent shape. Everything
else is money spent on pixels nobody sees.

⚠️ **When a body grows, everything it TOUCHES must grow with it.** Resizing art
without resizing contact radii is the classic art-pass bug — it shipped past us
once already (enemies standing visibly *on* the lion without being mauled,
pandas rolling *through* enemies). Grep the character's radii when you change
its size.

---

## 2. Pipeline conventions (established by the kaiju — follow them)

- **Size sprites in POINTS from `GameConfig`, never from the texture's own
  dimensions.** The asset can then be re-exported at any resolution without
  changing how big the creature is in play.
- **Body is raster. Effects stay procedural.** The kaiju's fire is still drawn
  in code so it pulses and keeps the game's glow language — that's what stops a
  sprite reading as pasted-in. **It also means source art never needs baked
  effects**, which simplifies every request.
- **Hide the procedural parts underneath.** Spark's ember body and eyes are set
  to alpha 0 while transformed, restored on revert.
- **Keep animation channels separate** so they can't stomp each other. On the
  kaiju: facing owns `xScale`, gait owns `position.y` + `zRotation`, breathe
  owns `yScale`.

### Asset prep (mechanical, ~5 minutes)

1. Verify alpha is genuinely transparent — check corner pixels, don't trust a
   preview. "Renders transparent, gains a background on download" is common; a
   white matte and true alpha look identical in a viewer and behave completely
   differently over a dark arena.
2. Find the opaque content bounds and **crop to them**, so the sprite's box
   equals the creature and its size stays predictable.
3. Emit at `size`, `size×2`, `size×3` px into a `.imageset`.
4. **Look at it at display resolution before committing.** Downsample, magnify
   with no smoothing, and check what actually survived.

### ⚠️ Animation frames crop to a SHARED box, never individually

The single-sprite rule ("crop to content bounds") is **wrong for a frame set**
and will produce a bug that looks like broken art.

Frames drawn independently land in different places on the canvas. Measured
across the kaiju's nine:

| Frame | Content | Position on canvas |
|---|---|---|
| Front 1 | 898×1150 | (63, 164) |
| Right 1 | 674×1216 | (201, 140) |
| Right attack | 965×901 | (21, 317) |

Cropping each to its own bounds re-centres every frame differently, so the
character **teleports between frames** — a walk cycle jitters because frame 2's
feet land where frame 1's head was.

**Always compute the UNION box across the whole set and crop every frame to it.**
Relative position is preserved, and poses that extend past the standing
silhouette (an outstretched arm) still get their room.

Two consequences:

- **The union box is wider than the body**, so sizing the sprite to the ladder's
  point width would render the body slightly small. Size the box so the STANDING
  BODY hits the ladder number, and let action poses spill into the margin.
- **Ask the artist to anchor frames deliberately** (same ground contact, same
  body centre). A shared crop box compensates, but it can't recover registration
  the art never had.

### Style note

A "pixel art" source is usually not chunky pixels — the kaiju's finest features
were ~2px in a 972px-wide image. That takes a **high-quality downsample with
normal filtering**, not nearest-neighbour. Only use nearest for genuinely
low-resolution art authored at its native grid.

---

## 3. Tier animation by SCREEN TIME, not by importance

The instinct is to animate everything to the same standard. Don't — the numbers
are wildly lopsided.

| Subject | On screen | Treatment |
|---|---|---|
| The thing you BECOME (kaiju) | ~10s, and it's the player | Full suite |
| A performance (Panda Samurai) | walks, strikes, bows | Real frames — the deliberateness IS the joke |
| Wanderers (pandas, lion) | seconds at a time | Idle + walk. No attack. |
| Projectile-scale (Nature Canon animals) | **~0.45s of flight** | **One frame.** Two at most. |

Nine woodland animals × 12 frames is ~100 assets no player will ever perceive.
They need **character**, not animation — proven by the emoji placeholders being
funny at 50pt before any art existed.

---

## 4. The animation suite, when a subject earns one

| State | Frames | View | Why |
|---|---|---|---|
| Idle | 2–3 | front | breathing loop; code already adds subtle scale, so frames can be minimal |
| Walk / lumber | 4–6 | **side** | the money animation — weight shift and follow-through |
| Attack | 3–4 | side | wind-up → strike → recover, timed to the code's existing lunge |

**Side view matters for walk and attack specifically**, because that's when
direction is legible. Idle can stay front-facing, which gives a free "turns to
face you at rest" beat for nothing.

**Why front-facing art alone isn't enough:** mirroring a pose horizontally only
reads as *turning* when the pose is asymmetric. A symmetrical hero stance
flipped just looks flipped. The kaiju's `xScale` facing is a working placeholder
that needs directional art to land.

**Not yet built** (build when frames exist, not before): a sprite animation
state machine (idle ↔ walk ↔ attack, driven by the gait code already in
`PlayerNode`), and `.spriteatlas` packing rather than loose imagesets — fewer
draw calls, which matters because Growth already pushes 600+ nodes.

---

## 5. Checklist for the next glow-up

1. [ ] Pick the point size against the ladder; compute the @3x budget
2. [ ] Prove it with placeholders in a real run **before** commissioning
3. [ ] Scale contact radii to match the new body
4. [ ] Decide the animation tier from screen time
5. [ ] Request: transparent alpha, tight crop, **no baked effects**, side view
       for walk/attack
6. [ ] Verify alpha at corners; crop to content; emit 1×/2×/3×
7. [ ] Check at display resolution before committing
8. [ ] Wire it: size from `GameConfig`, hide procedural parts, keep effects in
       code, keep animation channels separate

---

## The panda kaiju, as built

96pt across (`kaijuScale` 3.0 × Spark's 32pt). Body raster, fire procedural and
hugging the silhouette. Procedural life with no extra art: idle breathe, walk
bob, lean into travel, `xScale` facing, and an eased settle on stop — that
settle does more for the sense of weight than the 0.7× move speed does.

**Outstanding:** the directional suite in §4. Front-facing flip is a placeholder.
