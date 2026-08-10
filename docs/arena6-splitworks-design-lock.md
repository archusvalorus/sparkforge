# Sparkforge v2.1 Design Lock

## The Broken March, Arena 6: The Splitworks

**Status:** Creative direction locked, technical discovery ready  
**Release target:** Sparkforge v2.1  
**Design role:** First geometry arena, first bounded release in the Levels 6 through 10 bridge arc  

---

## 1. Executive lock

Levels 6 through 10 are **The Broken March**, an advance through the forge's fractured outer defenses. These defenses were also industrial transit works, built to move armies, fuel, machinery, and unfinished creations away from the central forge. Their collapse gives every arena a different failure of passage.

The arc borrows the machinery, transit language, and kinetic character of **The Iron Pilgrimage**, but preserves the clearer spatial curriculum of **The Broken March**.

The governing arc thesis is:

> The first five arenas taught the player how Sparkforge fights. The next five teach the battlefield how to fight back.

Arena 6 is **The Splitworks**. A derailed pilgrim carrier has cleaved an old mustering yard into two unequal routes. It introduces one new combat truth: threats can leave the player's immediate line of engagement without leaving the fight.

Arena 6 must make terrain meaningful, readable, and enjoyable without turning combat into a navigation chore.

---

## 2. The Broken March arc grammar

### Arc identity

The player has passed the forge's established proving grounds and reached the infrastructure that once carried its power outward. The route is broken, but the systems built to defend and operate it are still obeying their final instructions.

This is not yet Verdant Treescape. The Broken March should feel increasingly exposed, fractured, and transitional, but remain visually dominated by stone, iron, ash, rails, gates, signal fires, and ruined machinery.

### High-level arena sequence

| Arena | Working title | Spatial lesson | Primary pressure |
|---|---|---|---|
| 6 | **The Splitworks** | A central obstruction creates two unequal routes | Enemies disappear from one engagement and reappear through another |
| 7 | **The Twin Channels** | Two broad lanes with limited crossings | Players must choose when to hold a lane and when to cross |
| 8 | **The Lockworks** | Connected chambers with open thresholds | Pressure must be forecast before it migrates between rooms |
| 9 | **The Long Breach** | Deliberately bounded left-to-right progression | The battle has a moving front, with pursuit and reinforcement pressure |
| 10 | **The Last Rampart** | Prior geometry returns in simplified boss-controlled forms | The arc's spatial vocabulary becomes a readable monument-boss ritual |

### Enemy-family progression

The Broken March enemy ecosystem is organized by function rather than simple escalation:

- **Arena 6:** route-takers, firing-line holders, and mobile obstructions
- **Arena 7:** crossing controllers and lane punishers
- **Arena 8:** signalers, carriers, and chamber migrants
- **Arena 9:** pursuers, forward defenders, and breach-point ambushers
- **Arena 10:** the complete defensive organism, subordinated to the monument boss

The enemies should become more spatially coordinated across the arc. Arena 6 introduces individual jobs. Later arenas create combinations and hierarchy.

### Arena 10 boss fantasy

The arc culminates in **The Rampart Sovereign**, a colossal living siege engine embedded into the upper third of The Last Rampart.

It does not chase the player. It controls the fortress around itself by opening deployment gates, firing through lanes, sealing routes, and sacrificing portions of its own platform as the battle escalates. The spectacle comes from dismantling a monument that believes the battlefield belongs to it.

When it falls, the ruined platform reveals immense roots beneath the old defensive works. Verdant Treescape is not previewed through a partial forest season. It is revealed as the living world that the Rampart had kept beyond, beneath, or contained.

---

## 3. Arena 6 identity

### Name

**The Splitworks**

### Core fantasy

An old pilgrim carrier lies broken across a mustering yard. Its armored body divides the battlefield into a narrow, dangerous passage and a broader, more exposed route. Transit rails terminate inside the wreck. Signal standards still issue orders to a procession that no longer exists.

The player has crossed beyond the formal arenas. This is the first place that feels like part of a larger world rather than a purpose-built combat bowl.

### Arena test

> Can you fight what you cannot hold in one sightline?

### Arena voice

> The road broke. The march did not.

### Player lesson

The player learns that:

1. Terrain can interrupt movement and direct fire.
2. A threat moving behind terrain remains strategically active.
3. The short route is not always the safe route.
4. Repositioning can be an offensive decision, not merely an escape.

The lesson should be understood through play during the first encounter sequence, without a tutorial card or explanatory modal.

---

## 4. Arena geometry

### The Fallen Carrier

The arena's defining feature is a single permanent central obstacle called **the Fallen Carrier**.

Its footprint is asymmetrical and slightly offset from the arena center. It creates:

- A **narrow route**, shorter and easier to read, but vulnerable to body-blocking and committed charges
- A **broad route**, longer and more exposed, with cleaner firing lines and more room for swarms
- Two generous merge spaces where the routes reconnect

Exact dimensions should be tuned against the existing camera, player speed, largest enemy footprint, Growth summons, and common projectile patterns. The initial prototype should target a carrier footprint of roughly one third of the usable arena length, but no percentage becomes final until movement and build compatibility are tested.

### Collision policy

For v2.1, the Fallen Carrier should:

- Block the player and ordinary ground-bound enemies
- Block direct, travel-based projectiles when visually coherent
- Reject spawn points and target points inside its footprint
- Preserve global, rain, orbit, aura, and clearly supernatural effects unless a technical audit reveals an exploit or contradiction
- Never create a pocket that can permanently trap the player or the largest active enemy

It should not:

- Move
- Break
- Change shape
- Open and close passages
- Inflict contact damage
- Require an arena-specific interaction prompt

Those are later spatial verbs. Arena 6 earns only one.

### Readability rules

- The carrier's collision footprint and painted footprint must agree.
- The camera angle and sprite layering must not allow the carrier to hide enemy bodies completely.
- Route entrances must remain readable beneath procedural effects.
- Spawn warnings must be visible even when the spawn occurs beyond the carrier.
- Telegraphs may cross the carrier only when the underlying attack can also cross it.
- Effects must not appear to strike through solid cover unless their visual language clearly communicates an arcing, falling, global, or supernatural attack.

### Anti-cheese behavior

The obstacle is cover, not sanctuary.

Enemies should be able to take alternate routes, relocate, or use attacks explicitly designed to preserve pressure. The player may gain a moment by breaking line of fire, but should not be able to invalidate the encounter by circling one corner forever.

---

## 5. Arena 6 enemy roster

The roster contains three standard enemies and one arena boss. Each standard enemy teaches one aspect of the same geometry rather than introducing an unrelated gimmick.

### 5.1 Spurhound

**Role:** Fast flanker  
**Spatial verb:** Go around  

The Spurhound is a low industrial hunting construct built to run beside moving forge columns. It selects a route around the Fallen Carrier, accelerates while out of direct engagement, and commits to a short, readable lunge when it emerges.

#### Behavior lock

- Selects a viable route at a decision point rather than recalculating every frame
- Prefers the route that creates a flank, subject to crowding and path validity
- Gives a clear emergence tell before lunging
- Commits to the lunge once telegraphed
- Becomes briefly punishable after a miss or collision

#### What it teaches

Breaking sightline does not erase a fast threat. The player must remember what went behind the carrier and anticipate where it can emerge.

#### Visual grammar

Low silhouette, forward-canted chassis, wheel-spur or rail-skate details, bright exhaust tell before acceleration. It should read as speed before the first move occurs.

### 5.2 Linekeeper

**Role:** Ranged anchor  
**Spatial verb:** Hold a line  

The Linekeeper is a walking firing standard that establishes itself along the broad route and projects a narrow, high-clarity attack line. The Fallen Carrier can interrupt its ordinary shot, making hard cover tactically useful.

#### Behavior lock

- Seeks a valid firing anchor rather than stopping at an arbitrary point
- Telegraphs a narrow line before firing
- Respects direct-fire collision with the Fallen Carrier
- Relocates if it has been denied a valid shot for too long
- Does not fire through other solid arena geometry unless later systems explicitly permit it

#### What it teaches

Terrain can protect the player, but remaining behind the same protection gives other enemies time to change the engagement.

#### Visual grammar

Tall, narrow tripod or standard-like body, surveying head, luminous barrel seam, grounded stance during aim. It should resemble a boundary marker that developed hostile opinions.

### 5.3 Ramplate

**Role:** Mobile obstruction and lateral displacer  
**Spatial verb:** Occupy a route  

The Ramplate is a broad armored construct built from a gate segment or transport plow. It enters a passage, braces briefly, and commits to a short shove or charge that temporarily makes the obvious route unsafe.

#### Behavior lock

- Chooses a passage with adequate clearance
- Telegraphs its facing and charge footprint
- Pushes or displaces on a clean hit rather than relying on extreme burst damage
- Cannot pivot freely during a committed charge
- Exposes a vulnerable recovery after impact or miss

#### What it teaches

The narrow route is efficient until something else owns it. The correct answer may be to rotate through the longer side.

#### Visual grammar

Wide plated face, furnace seams, battered gate hardware, heavy rear drive assembly. It should look like a wall that became impatient.

---

## 6. Arena boss: The Marchwarden

### Boss fantasy

The Marchwarden was built to keep war columns moving through the Splitworks. The column is gone. The road is broken. The Marchwarden continues clearing the route, and now categorizes the player as an obstruction.

It is a substantial arena boss, but not a monument boss. Its scale should preserve room to navigate both routes and leave Arena 10's upper-third spectacle untouched.

### Boss thesis

> The boss does not change the arena. It demonstrates mastery over the arena that already exists.

### Core attacks

#### Right of Way

The Marchwarden declares one route with high-contrast floor signals, then commits to a powerful passage charge. The narrow route creates a shorter reaction window but a more predictable path. The broad route creates more lateral room but allows follow-up pressure.

The boss does not turn sharply after commitment.

#### Standardfall

The Marchwarden launches a small sequence of arcing standards or forge-spikes that land on the player's side of the Fallen Carrier. This attack is explicitly able to cross the obstacle, preventing permanent cover abuse. Landing zones are individually telegraphed and should not fill both escape routes simultaneously.

#### Muster Signal

The Marchwarden issues a signal to outer deployment points. A small, bounded reinforcement packet enters from a clearly marked gate, preferably favoring the route opposite the boss's current position.

This attack validates reusable spawn-zone signaling without turning the boss into a summon flood.

### Escalation state: The Column Advances

At the final health threshold, the Marchwarden increases cadence and begins chaining two of its existing verbs, such as Standardfall into Right of Way. It does not gain a fourth ruleset.

The signal standards and the Fallen Carrier briefly ignite in sequence, making the dead procession appear to move again without changing collision geometry.

### Fairness constraints

- The boss may pressure both routes in sequence, never seal both without a readable escape.
- A charge, reinforcement entrance, and Standardfall impact may not resolve simultaneously in the same safe region.
- Reinforcement count must remain low enough that route logic stays legible.
- The boss must recover visibly after its strongest commitment.
- No attack should depend on the player knowing an offscreen position that the game failed to communicate.

---

## 7. Encounter teaching sequence

Exact wave counts and spawn numbers remain implementation-tuning data. The authored encounter should nevertheless follow this teaching order:

### Beat 1: Read the split

Use familiar enemies or low-pressure movement so the player encounters the Fallen Carrier before the new roster demands mastery. The player should naturally travel around at least one side.

### Beat 2: Remember the flank

Introduce the Spurhound in isolation or near-isolation. Let it disappear behind the carrier and re-emerge with an unmistakable tell.

### Beat 3: Discover cover

Introduce the Linekeeper with enough breathing room for the player to observe that the carrier interrupts its firing line.

### Beat 4: Surrender the short route

Introduce the Ramplate where its occupation of the narrow passage encourages a deliberate rotation rather than trapping the player.

### Beat 5: Cross-pressure

Combine two enemy roles. The key combination is Linekeeper plus Spurhound: cover answers one threat while creating attention pressure from the other.

### Beat 6: The Marchwarden

The boss restates all three lessons through route declaration, cross-obstacle pressure, and bounded reinforcements.

The first clear should feel like the player learned a battlefield, not memorized a script.

---

## 8. Reward and content package

### v2.1 first-clear reward

**Marchworn**, an earned cosmetic skin.

The skin should reuse the established cosmetic and raster-character infrastructure. Its visual language is charcoal iron, worn pale markings, oxidized teal accents, and narrow ember-lit fractures. It grants no mechanical effect.

This reward serves three purposes:

1. Makes the first post-Arena-5 clear feel materially commemorative
2. Validates the earned-skin pipeline alongside the new IAP catalog
3. Gives The Broken March an immediately recognizable visual token

### Card policy

Arena 6 should not add a new tree, capstone, or terrain-dependent card package.

No new card is required for v2.1 unless a separate balance review identifies a genuine arsenal gap. Geometry itself is the release's mechanical addition. Adding a card merely to satisfy a content cadence would dilute the lesson and create unnecessary compatibility work.

### Codex package

Arena 6 ships with four bestiary entries, using the Arena 5 finalization process and live UI constraints.

Provisional copy direction:

- **Spurhound:** “It learned the shortest distance between two points. Then it learned to hunt around corners.”
- **Linekeeper:** “A firing line given legs. It mistakes patience for permission.”
- **Ramplate:** “A barricade with forward momentum. The forge forgot that walls should stay put.”
- **The Marchwarden:** “The march ended long ago. Its warden still clears the road for an army that will never come.”

These lines are editorially strong but remain **provisional until implemented behavior, final art, and the live text wrapper are reconciled**.

### Recommended arc-wide reward cadence

Every arena should receive its own bestiary set, progression record, and authored boss or miniboss identity. Cards and skins should remain milestone content rather than compulsory arena taxes.

The reward cadence beyond Arena 6 should be locked only after v2.1 telemetry and production cost are known. Arena 10 should retain the largest package in the arc.

---

## 9. Art and sound direction

### Arena palette

- Charcoal iron
- Kiln orange
- Ash-gray stone
- Oxidized teal signal paint
- Pale ceramic route markings
- Restrained violet residue as a distant visual inheritance from The Star Anvil

### Environmental anchors

- The Fallen Carrier as the dominant readable silhouette
- Rails or procession grooves that terminate inside the wreck
- Broken signal standards
- Outer-wall masonry and deployment gates
- Old route markings that help communicate the two passages

### Verdant restraint

Arena 6 contains no overt forest, roots, vines, moss wall, plant enemy, or green territorial mechanic. Verdant Treescape deserves its entrance.

If a microscopic future seed is desired, it should be invisible during normal play and limited to non-green cracks or unexplained pressure beneath the stone. The actual reveal belongs to Arena 10.

### Sound

The arena should suggest a procession failing to complete:

- Distant interrupted hammer cadence
- Rail strain and cooling metal
- A signal horn that never receives an answer
- Spurhound acceleration whine
- Linekeeper aim tone
- Ramplate brace impact
- Marchwarden muster call

A new full music track is optional. A restrained ambience or stem variation is sufficient for v2.1 if bespoke music would expand the release.

---

## 10. Reusable systems that must pay rent

Arena 6 should establish the smallest reusable geometry foundation capable of supporting Arenas 7 and 8.

### 10.1 Data-driven arena geometry descriptor

An arena definition should be able to declare:

- Static blocked footprints
- Route or navigation anchors
- Spawn zones
- Boss spawn and phase anchors
- Safe margins
- Environmental art references
- Optional route labels for debugging and telemetry

The data shape should not hard-code The Splitworks or the Fallen Carrier.

### 10.2 Lightweight route graph

Sparkforge does not need a generalized navigation research project for Arena 6. A small authored waypoint or route graph is preferable if it can support:

- Choosing between valid routes
- Reserving or weighting congested passages
- Committing to a route until the next decision point
- Recovering when an actor is displaced or a target changes sides
- Expanding into lane crossings and connected chambers later

The technical spike should compare this against the current direct-chase behavior and existing SpriteKit collision model before final architecture is selected.

### 10.3 Geometry-aware target and spawn sampling

All systems that choose world points must be able to reject blocked geometry and invalid margins. This includes enemies, bosses, drops, summons, telegraphs, and procedural effects where applicable.

### 10.4 Projectile collision policy

Projectile and effect classes need explicit, testable interaction rules with solid arena geometry. Visual logic and collision logic must agree.

### 10.5 Debug visibility

Development builds should be able to display:

- Blocked footprints
- Route nodes and connectors
- Selected actor route
- Spawn zones
- Rejected spawn or target points
- Stuck or recovery events

This will save disproportionate time across Arenas 7 through 10.

---

## 11. Claude technical discovery request

Before implementation begins, Claude should return a compact technical reconnaissance packet covering:

1. How current enemies pursue and steer toward the player
2. Current physics bodies, collision masks, and contact assumptions for players, enemies, bosses, projectiles, pickups, and summons
3. How spawn locations and random world points are selected
4. Which attacks and card effects assume an unobstructed rectangular arena
5. How Growth summons, Panda effects, orbitals, dashes, knockback, and large bosses behave near blocked geometry
6. Whether any existing arena or Boss Mode code assumes a single open playfield
7. The smallest reusable data structure for static obstacles and two-route navigation
8. Performance risks on the oldest supported device class
9. Existing test or debug infrastructure that can validate movement, collision, and point sampling
10. Recommended implementation-unit boundaries, with touched files and proof criteria

Claude should not implement the full arena during reconnaissance. The deliverable is an evidence-backed map of the existing seams, the recommended architecture, and any design conflicts requiring resolution.

---

## 12. Proposed bounded execution sequence

The final unit boundaries may change after technical discovery, but the intended production sequence is:

### Unit 0: Geometry reconnaissance and compatibility matrix

No player-facing content. Confirm architecture, collision policy, affected systems, and proof plan.

### Unit 1: Static geometry foundation and Splitworks shell

Implement the data-driven obstacle, route graph, spawn rejection, debug overlays, and a playable arena shell using existing enemies only.

**Proof:** The player and representative enemies traverse both routes without clipping, trapping, invalid spawns, or build-specific failures.

### Unit 2: Arena 6 standard roster

Implement and validate Spurhound, Linekeeper, and Ramplate one at a time, then test combinations.

**Proof:** Each enemy independently teaches its intended spatial verb, and combinations create pressure without unreadable overlap.

### Unit 3: The Marchwarden

Implement the boss using the established arena geometry and spawn-zone systems.

**Proof:** All attacks remain readable across both routes, no state seals every escape, and cover neither trivializes nor invalidates the fight.

### Unit 4: Progression, reward, codex, art, and sound integration

Add unlock flow, Marchworn skin, bestiary entries, arena presentation, final art, sound cues, and Boss Mode support where technically compatible.

### Unit 5: Integration, tuning, and release closeout

Run compatibility, performance, progression, persistence, and telemetry checks. Finalize copy against the shipped behaviors and capture the Arena 6 production closeout for reuse.

---

## 13. v2.1 scope lock

### In scope

- Arena 6: The Splitworks
- One static central obstacle with two unequal routes
- Reusable geometry descriptor and route foundation
- Geometry-aware spawn and target sampling
- Spurhound, Linekeeper, and Ramplate
- The Marchwarden
- Four bestiary entries
- Marchworn earned cosmetic skin
- Arena progression and presentation
- Relevant Boss Mode compatibility
- Geometry telemetry and debug tools
- Compatibility and performance validation

### Explicitly out of scope

- Arena 7 or later playable content
- Destructible, moving, opening, or closing terrain
- Lane-switch machinery
- Connected chambers
- Scrolling stages
- Verdant enemies or visible biome reveal
- New card tree or capstone
- Terrain-exclusive cards
- New paid IAP
- Reworking established v2.0 systems without a demonstrated conflict

---

## 14. Telemetry and tuning questions

Arena 6 should record enough information to guide the rest of The Broken March without creating a surveillance cathedral.

Useful measurements include:

- Player time spent in each route and merge space
- Route chosen during high-pressure moments
- Death and damage locations
- Linekeeper shots blocked by terrain versus landed
- Spurhound emergence hits and misses
- Ramplate charge hits, misses, and push outcomes
- Marchwarden attack hit rates by move and route
- Actor stuck, route-failure, and path-recovery events
- Invalid or rejected spawn and target samples
- Effects or pickups attempted inside blocked geometry
- Clear rate, clear time, and performance by device tier
- Player time spent circling the obstacle without meaningful engagement

### Design questions telemetry should answer

1. Does the obstacle create choices or merely add travel time?
2. Is either route dominant across most builds?
3. Does cover produce tactical relief or degenerate safety?
4. Do enemy combinations make route memory satisfying or exhausting?
5. Which route and spawn systems are stable enough to reuse in Arena 7?

---

## 15. Acceptance criteria

Arena 6 is ready to ship when:

- A first-time player can infer the arena's spatial lesson through play
- The Fallen Carrier materially changes combat decisions without slowing the game into a maze
- Every supported build remains functional and useful
- Player, enemy, boss, summon, projectile, pickup, and effect interactions with geometry are visually coherent
- No route can be permanently sealed by normal encounter combinations
- New enemies are readable alone and coherent together
- The Marchwarden synthesizes Arena 6's lesson without previewing Arena 10's monument scale
- The arena performs within the game's established targets on supported devices
- Progression, persistence, bestiary unlocks, earned cosmetic reward, and Boss Mode behavior are verified
- The reusable geometry foundation can express Arena 7 without being rewritten

---

## 16. Production principle carried forward

Arena 6 is not successful because Sparkforge can now contain an obstacle.

It is successful if the player sees an enemy vanish behind the Fallen Carrier, hears metal begin to accelerate on the other side, and realizes that the battlefield has learned suspense.
