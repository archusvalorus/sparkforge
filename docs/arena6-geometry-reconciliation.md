# Sparkforge v2.1 Geometry Reconciliation

## The Splitworks: technical rulings and revised execution boundaries

**Status:** Design decisions locked after geometry reconnaissance  
**Inputs:** Arena 6 Design Lock and Claude's reconnaissance against commit `953fe51`  
**Purpose:** Resolve the six design conflicts, canonize geometry interaction policy, and refine the implementation sequence before execution begins

---

## 1. Reconciliation verdict

Claude's reconnaissance validates the Arena 6 direction and materially lowers the architectural risk of the Fallen Carrier itself.

Sparkforge already treats solidity as manual spatial resolution rather than physics-solver collision. The Unmade Star monument established this house pattern. Arena 6 should generalize that precedent into a reusable, data-driven geometry layer.

The core implementation challenge is broader than obstacle collision:

- Enemy movement currently assumes direct pursuit.
- Auto-aim and summon targeting currently assume universal visibility.
- Projectiles currently assume unobstructed travel.
- Random placement is distributed across many call sites without shared rejection.
- Pulls, knockback, teleports, and scripted motion can currently bypass spatial validity.

The correct v2.1 investment is therefore a small geometry contract shared by movement, placement, targeting, and travel. It should not become a generalized physics or pathfinding project.

The recommended architecture is approved:

- One authored convex rounded-rectangle footprint for the Fallen Carrier
- Manual displacement resolution, following the monument precedent
- One shared geometry-aware placement sampler
- One small authored waypoint graph
- Segment-based travel and visibility tests
- Explicit per-actor footprint radii for route clearance
- Debug visualization and telemetry built with the foundation

No navmesh, GameplayKit pathfinding, polygon mesh, destructible geometry, or SpriteKit collision solver is authorized for v2.1.

---

## 2. Locked design rulings

### Ruling 1: Auras and non-travel radius effects pass through the Carrier

**Decision:** Approved.

Auras, player-centered radius effects, orbit-derived damage, and other positionless or supernatural area effects ignore static geometry unless a later ability explicitly establishes a different rule.

This includes the current Everglow, Windchill, Tesla, Static Field, Aegis, kaiju aura, and Apex-style families.

The distinction is behavioral, not merely visual:

- If damage must travel along a segment, the Carrier can block it.
- If damage is evaluated as an aura, global pulse, manifestation, or supernatural field, it passes.

This avoids fifteen expensive and inconsistent occlusion insertions while preserving a clear player-facing rule.

### Ruling 2: Growth visuals may overlap, but blocked geometry has no zone membership

**Decision:** Approved.

Growth and cultivated-ground visuals may paint beneath or appear to meet the Fallen Carrier. Their mechanical membership must subtract the blocked footprint.

Consequences:

- The Carrier cannot count as cultivated ground.
- No actor can receive zone benefits while spatially inside the Carrier.
- Placement previews and rooted objects must use geometry validity where they require a reachable point.
- Decorative visual overlap is permitted when it makes the environment feel integrated rather than cut out with scissors.

### Ruling 3: Void beams pierce reality, but their origins must be valid

**Decision:** Approved.

Erasure Rift Cannon and Erasure Echo origins must reroll or resolve outside blocked geometry. Their beams may cross the Carrier and are canonized as reality-piercing Void effects.

The visual language should support this exception. A Void beam crossing solid terrain must look like it is violating space, not accidentally forgetting the wall exists.

### Ruling 4: Legacy ranged enemies must seek line of sight

**Decision:** Approved for all geometry-enabled arenas.

Any legacy ranged enemy included in The Splitworks must continue approaching or relocate while direct line of sight is blocked. It may not stop at preferred range and fire forever into the wreck.

This behavior should be implemented through the shared targeting and route seams, not as a Linekeeper-only exception. Open-field arenas should retain existing behavior because their visibility result is unchanged.

### Ruling 5: Iron Maiden and lasso effects may visually cross

**Decision:** Approved.

Iron Maiden T5 and lasso-style tether effects are classified as supernatural attachments rather than ordinary travel projectiles. Their mechanics and tracers may cross the Carrier.

No geometry clipping or bespoke occlusion work is required for these effects in v2.1.

### Ruling 6: Canonical exemption list, with a Panda safety amendment

**Decision:** Approved with amendment.

The following may ignore travel occlusion:

- Mote's scripted entrance
- Event Horizon and other positionless global effects
- Skybeam, Starfall, Collapse Marks, Standardfall, bamboo rain, and the broader falling or sky-strike family
- Panda attacks, manifestations, and scripted movement when their fiction or comedy depends on spatial disrespect

However, no exemption may create invalid persistent state.

Therefore:

- Mote and Panda entrances may cross the Carrier, but their final resting positions must be valid.
- Panda `.pin` may cross geometry during the effect, but the pinned actor's resolved destination must be outside the footprint.
- Random Panda destinations must use or pass the shared placement-validity check.
- Effects may overlap the Carrier visually, but ground-bound actors may not remain embedded inside it.

The canon rule is: **Pandas may violate geometry as spectacle, not as save-state corruption.**

---

## 3. Canonical geometry interaction matrix

| System family | Carrier interaction | Required implementation behavior |
|---|---|---|
| Player and ground-bound enemies | Solid | Resolve outside the footprint after movement, pulls, displacement, and teleports |
| Ground-bound bosses | Solid unless explicitly authored otherwise | Use actor footprint radius and route-clearance rules |
| Ordinary direct projectiles | Blocked | Use swept segment testing to prevent tunneling |
| Enemy direct projectiles | Blocked | Same segment policy as player projectiles |
| Auto-aim and summon target selection | Occluded | Exclude targets without valid direct line of sight, then fall back cleanly |
| Legacy ranged pursuit | Geometry-aware | Continue routing or relocating while line of sight is blocked |
| Auras and player-centered radius effects | Pass | No occlusion scan required |
| Global and positionless effects | Pass | No geometry interaction unless explicitly authored |
| Falling, arcing, and sky-strike effects | Pass | Landing point must be valid if it creates a persistent object |
| Void beams | Pass | Origin must be outside blocked geometry; visuals must communicate reality-piercing behavior |
| Growth and cultivated zones | Visual overlap allowed | Mechanical zone membership excludes blocked footprint |
| Pickups, wells, flowers, rooted objects, and ground zones | Cannot originate inside | Use shared rejection sampler with system-specific margins |
| Knockback and pulls | Cannot embed actors | Run solid resolution after displacement is applied |
| Teleports and pin destinations | Cannot end inside | Validate or resolve destination before committing |
| Orbitals and spirit familiars | Pass | Visual corner clipping is acceptable for v2.1 |
| Mote entrance | Scripted pass | Final resting state must be valid |
| Panda systems | Spectacle pass | Final persistent positions must be valid |

---

## 4. Architecture lock

The minimum reusable contract is approved in this form:

```text
ArenaGeometry
  blockedFootprints: [Footprint]
  routeNodes: [RouteNode]
  routeEdges: [RouteEdge]
  spawnZones: [SpawnZone]
  safeAnchors: [SafeAnchor]

Footprint
  center
  halfExtents
  cornerRadius
  rotation

Required operations
  contains(point, margin)
  resolve(point, actorRadius)
  intersectsSegment(start, end, travelRadius)
```

For Arena 6, the descriptor contains exactly one blocked footprint. The API may support an array so Arena 7 and Arena 8 can reuse it, but implementation and performance proof should remain centered on the one-Fallen-Carrier case.

Route selection uses an authored waypoint graph:

1. Test whether the direct segment to the target is blocked.
2. If clear, retain current pursuit behavior.
3. If blocked, choose a valid authored next node using route suitability and optional congestion weighting.
4. Commit until the next decision point.
5. Re-evaluate after meaningful displacement, target-side change, invalid progress, or arrival at a decision node.

This is route guidance, not continuous shortest-path solving.

### Physics bit decision

Do not create a physics body for the Fallen Carrier.

The declared but unused `boundary` physics bit may be renamed or reclaimed for semantic cleanliness only if Claude determines that doing so improves debug or future contact plumbing. It is not required by Arena 6 and should not become work for its own sake.

### Actor footprint decision

Introduce an explicit geometry footprint radius independent of sprite scale and existing contact-body size.

This radius governs:

- Clearance through routes
- Resolution against blocked footprints
- Segment or passage fit where applicable
- Ramplate and Marchwarden navigation validity

It must not silently replace combat hitboxes or damage-contact radii.

---

## 5. Revised execution sequence

Claude's proposed split between foundation and routing is accepted. The original Unit 1 becomes two bounded units so collision, placement, and performance can be proven before route behavior is layered on top.

### Unit 1A: Geometry foundation and Splitworks shell

**Scope**

- Add the minimal `ArenaGeometry` and `Footprint` data structures.
- Add required vector and segment math.
- Generalize manual player solidity from the monument precedent.
- Resolve the player after ordinary movement and forced displacement.
- Add enemy post-move footprint resolution.
- Introduce explicit actor geometry footprint radius.
- Introduce the shared geometry-aware placement sampler.
- Route interior pickups, wells, Rift origins, Terra placement or preview, and other identified persistent point selections through the sampler or validity contract.
- Add a safe player anchor for Boss Mode arena swaps.
- Fix the frozen `spawnDistance` behavior so it respects the current arena scale.
- Add the DEBUG geometry overlay and diagnostics.
- Build the Splitworks shell with existing enemies only.

**Not in Unit 1A**

- Route graph behavior
- Projectile blocking
- Auto-aim visibility
- New enemies
- Marchwarden
- Final art, rewards, or codex integration

**Proof criteria**

- The player traverses both routes without clipping, sticking, or entering the Carrier through ordinary movement or forced pulls.
- Representative small, medium, and large existing enemies cannot remain embedded in the Carrier.
- No validated pickup, well, rooted object, persistent ground zone, or relevant random origin is committed inside the blocked footprint.
- Boss Mode enters at a valid safe anchor.
- Spawn distance changes correctly with arena radius.
- The overlay accurately displays footprint, margins, spawn zones, safe anchors, rejected samples, and resolution events.
- A documented worst-case swarm remains within the established performance target on the oldest available test device. If no true device floor is available, record device, OS, build, enemy count, average FPS, low-observed FPS, and node count rather than asserting an invented baseline.

### Unit 1B: Authored route graph and recovery

**Scope**

- Add route nodes, edges, route labels, and decision points.
- Add blocked-segment detection before pursuit.
- Add choose, commit, arrive, re-decide, and recover behavior.
- Add optional lightweight congestion weighting only if needed to prevent obvious route collapse.
- Route representative existing melee enemies around the Fallen Carrier.
- Add stuck and oscillation diagnostics.

**Proof criteria**

- An enemy on either side of the Carrier reaches a player on the opposite side through a valid route.
- The enemy does not oscillate between route choices at a decision point.
- A displaced enemy recovers without teleporting through the Carrier.
- Direct pursuit resumes when line of sight and traversal are clear.
- Route choice and recovery are visible in DEBUG mode.
- The system remains authored and deterministic enough to tune without becoming a pathfinding black box.

### Unit 2: Visibility, projectile policy, and Arena 6 standard roster

Unit 2 retains Spurhound, Linekeeper, and Ramplate, with two mandatory shared-system prerequisites:

- Swept segment collision for ordinary direct projectiles
- Line-of-sight filtering in player auto-aim and summon priority targeting

Legacy ranged enemies used in geometry arenas must also approach or relocate while occluded.

The roster should be implemented one enemy at a time and proven individually before combination tuning begins.

### Unit 3: The Marchwarden

No structural change. Right of Way reuses committed charge and wall-termination precedent. Standardfall uses the canonized sky-strike exception. Muster Signal uses authored spawn zones.

### Unit 4: Progression and presentation

No structural change. Includes Marchworn, bestiary, arena registry and progression, final art, sound, presentation, and Boss Mode compatibility.

### Unit 5: Integration and closeout

No structural change. Includes compatibility, tuning, performance, telemetry review, persistence verification, bestiary finalization against shipped behavior and art, and the reusable Arena 6 production closeout.

---

## 6. Telemetry additions from reconnaissance

The original telemetry lock remains valid. Add the following development diagnostics:

- Resolution count by actor and cause: movement, pull, knockback, teleport, scripted motion
- Segment blocks by system family: player projectile, enemy projectile, auto-aim, summon targeting
- Placement rejection count by system and requested margin
- Route decisions, reversals, recovery events, and oscillation warnings
- Invalid destination corrections for Panda and teleport effects
- Worst-case geometry frame sample with device, OS, enemy count, node count, average FPS, and low-observed FPS

These diagnostics should be cheap, DEBUG-gated where appropriate, and removable or suppressible for release builds. Product telemetry should remain limited to the questions that inform Arena 7 design and real player outcomes.

---

## 7. Compatibility principles

1. **Open arenas should behave as before.** Geometry-aware funnels should return the current result when no blocked footprint exists.
2. **Combat hitboxes remain separate from geometry footprints.** Arena routing must not accidentally rebalance damage contacts.
3. **No supported build becomes useless because cover exists.** Direct travel is blocked; auras, globals, sky effects, and supernatural attachments retain their identities.
4. **Visuals and mechanics tell the same story.** Ordinary shots stop at iron. Void tears through it. Sky attacks descend over it.
5. **Persistent state is always valid.** No actor, pickup, summon destination, rooted object, or long-lived effect may remain committed inside solid geometry.
6. **The Fallen Carrier is the first consumer, not the architecture.** Every new seam must be named and structured for later arenas without prebuilding their unconfirmed mechanics.

---

## 8. Ability rework handoff requested for future design

When the existing elemental-tree rework is finalized, retain a canonical design packet containing:

- Tree names and thematic identities
- Base abilities and tier progression
- Capstone names, behaviors, durations, cooldowns, and scaling
- Summons, orbitals, projectiles, auras, zones, globals, teleports, pulls, and displacement effects by travel family
- Targeting rules and any manual or automatic selection behavior
- Terrain or geometry interaction policy where implemented
- Cross-tree synergies and known balance sensitivities
- Visual and audio grammar
- Stable implementation identifiers, if available

That packet becomes required input before designing the next tree and a compatibility reference for Arenas 7 through 10. It will let future arena mechanics pressure the arsenal intentionally without producing accidental hard counters or duplicating existing flavor.

---

## 9. Handoff instruction

Claude may treat the six rulings and the revised unit boundaries in this document as design-locked.

When Brandon authorizes implementation, begin with **Unit 1A only**. Return:

- Touched-file summary
- Final data structures and insertion seams
- Proof results for every Unit 1A criterion
- Performance sample with named device context
- Any discovered incompatibility requiring a design ruling
- A short recommendation for whether Unit 1B can proceed unchanged

Do not pull projectile collision, route behavior, the Arena 6 roster, or later-unit presentation work into Unit 1A merely because an adjacent seam is visible.

The objective is not to finish geometry quickly. It is to establish a geometry contract sturdy enough that The Twin Channels, The Lockworks, The Long Breach, and The Last Rampart can inherit it without another excavation.
