# Lyra Creative Specs — Arenas 3–5 (FUTURE CANON, v1.7–v1.9)

*Delivered July 8, 2026 via Brandon, same session as the v1.6 Quench pass. Binding creative direction for future versions; not v1.6 scope. Claude's build annotations at bottom.*

## The Arc

Arena progression as a forging process becoming mythic. Each arena teaches a different survival language — never "new background, same fight":

| # | Arena | Element | Tests | Ships |
|---|-------|---------|-------|-------|
| 1 | The Crucible | Heat | Survival | live |
| 2 | The Quench | Pressure | Positioning | v1.6 |
| 3 | The Coilworks | Current | Routing / rhythm | v1.7 |
| 4 | The Mirrorwound | Reflection | Perception / trust | v1.8 |
| 5 | The Star Anvil | Gravity | Mastery | v1.9 |

v2.0 = facelift / cohesion pass / progression framing — "package the first five arenas as a real product spine instead of a pile of cool configs."

## Arena 3 — The Coilworks (v1.7)

*"A living forge engine where sparks become current, and every step completes or breaks the circuit."* The arena is not chasing you, it is calculating you.

- **Palette:** floor `#121315` blackened machinery · boundary `#5B4A22` tarnished brass · particles `#F6D36B` pale static motes (jittering sideways hops, vanish/reappear) · line pulses along floor motif
- **Color rule:** Shock effects lean yellow-white / pale gold, NOT blue (blue = utility pickups)
- **Motif:** circuit rings with gaps (incomplete circuits), angular conduit lines, embedded floor nodes, node-to-node pulses, broken segments
- **Enemies:** **Relay Imp** (chain pressure — arcs danger lines between nearby imps; teaches connection-reading) · **Circuit Wasp** (angular orbiter — snaps between four directional points; learnable rhythm) · **Grounder** (plants itself, periodic danger pulses; living no-go zones)
- **Boss: The Dynamo Choir** — ceremonial machinery, "ancient, rhythmic, slightly holy in the worst possible way." Three incomplete rings at different speeds + four attached choir nodes. Patterns: **Circuit Litany** (danger lines connect floor nodes — read the circuit map), **Polarity Hymn** (pull, push, then snaps enemies inward), **Broken Measure** (rotating arcs with one misfiring node = safe rhythm gap). Enrage **Full Current**: more precise, not louder.
- **Cards direction:** Shock, Void, Neutral mobility — Spark Step, Copper Vein (chain range), Relay Burn (fire↔shock hybrid), Overclock (level-up speed burst), Dead Circuit (void zone duration), Grounded Core (standing still builds DEF)
- **Node names:** Broken Conduit, Static Chapel, Copper Vein, The Relay Pit, Dead Circuit, Spark Junction, Engine Choir

## Arena 4 — The Mirrorwound (v1.8)

*"A cracked reflective chamber where the forge shows every shape you almost became."* The arena is watching you make assumptions. Strangest arena without becoming unreadable.

- **Palette:** floor `#17161A` dark smoked glass · boundary `#B8B0A4` dull mirror-silver · particles `#C9C1B6` glass dust with occasional mirrored duplicates drifting opposite
- **Color rule:** purple may appear — but only as danger (hostile mirror effects, boss tells)
- **Motif:** irregular triangular shards, offset ring fragments, reflection lines echoing player movement, "wrong symmetry" between arena halves
- **Enemies:** **Shard Twin** (decoy pair — only one body real at a time) · **Pane Stalker** (phases intangible, reappears offset; disrupts kiting) · **Silver Leech** (attaches a draining tether; forces priority targeting)
- **Boss: The Faceted Lie** — "less a monster, more a verdict the player almost believes." Five asymmetric shard plates; no stable face at idle. Patterns: **False Safe** (silver vs hostile-purple floor shards — color truth over shape panic), **Reflection Volley** (delayed mirrored copy of each volley), **Pane Shift** (teleports between marked mirror points + radial burst). Enrage **No More Masks**: the lie stops pretending.
- **Cards direction:** Void, Bleed, Chill, reactive defense — Mirror Edge, Glass Blood, Silver Skin, Cold Read, False Opening, Red Smile
- **Node names:** Split Reflection, Glass Confessional, False Exit, The Silver Cut, Echo Pane, Witness Hall, The Almost Self

## Arena 5 — The Star Anvil (v1.9)

*"The forge's hidden heart, where sparks are hammered into stars or swallowed by their own weight."* The center of something that has been waiting without moving. First "deep game" milestone.

- **Palette:** floor `#090A0D` near-black star iron · boundary `#D6A94A` old stellar brass · particles `#F0E2A0` star motes drifting INWARD (gravity collecting them) · rare ember heartbeat pulses from boundary
- **Color rule:** avoid galaxy-purple; black, brass, pale starlight, ember. Forge core, not space wallpaper.
- **Motif:** orbital paths, star-node dots, hammer-strike cracks radiating from center, abstract central anvil mark
- **Enemies:** **Gravemote** (micro pull field affecting player AND enemies) · **Anvilborn** (mass-identity armored unit, knockback-resistant) · **Star Needle** (marks a danger line, pauses, darts along it)
- **Boss: The Unmade Star** — "immense, patient, almost sad. Too heavy to let anything leave unchanged." Ember core, incomplete orbital rings, central eye. Patterns: **Accretion Rings** (rotating ring segments with moving safe gaps), **Collapse Points** (delayed gravity zones — pull then burst), **Starfall Measure** (projectiles fall in the sequence the nodes flashed — pattern memory over reflex). Enrage **Become Weight**: not chaotic — inevitable.
- **Cards direction:** Void, Guard, Fire, late-run conversion — Starve the Dark, Heavy Crown, Event Horizon*, Last Ember*, Black Hammer, Star Temper* (*see annotations)
- **Node names:** Gravity Scar, The First Hammer, Star Crucible, Accretion Gate, The Heavy Choir, Ember Singularity, Center Without Mercy

## Lyra's Pressure-Test Rules (binding)

- Arena 3 is NOT "blue lightning world" — blue stays utility
- Arena 4 mechanics must be readable first, clever second
- Arena 5 is a forge core, not outer-space wallpaper
- No mechanics requiring mid-run text parsing
- No boss reuses charge / slam / summon as core identity

---

## Build Annotations (Claude)

**Implementation risk conveniently ascends with the sequence:** Coilworks mechanics (danger lines, planted pulsers, angular orbits) mostly recombine existing systems; Mirrorwound (decoys, phasing, tethers) and Star Anvil (gravity fields, pattern-memory volleys) introduce genuinely new tech. The order is buildable as specced.

**Name/effect collisions to resolve in future briefs (no action now):**
- *Event Horizon* (Arena 5 card) collides with the existing Void tier-5 synergy name "Event Horizon" — one needs a rename.
- *Cold Read* (Arena 4, "slowed foes take more damage") is effect-identical to existing *Permafrost* (chill_3). Needs differentiation or stacking rules.
- *Last Ember* (Arena 5, "survive lethal damage once") overlaps *Brace* (guard_1) — same `lethalSaves` mechanic, different tag. Fine if intentional (stacking saves), needs a rules call.
- *Live Wire*-style near-duplicates: watch for these in every future card drop.

**Two structural hints in Lyra's spec worth a deliberate decision later:**
1. **"Node names" per biome** imply a possible run-map / route-selection structure (nodes as chambers within an arena). That's a v2.0-scale identity question: do arenas stay parallel selectable modes, or does a deep run *travel* them?
2. ***Star Temper* ("each boss kill grants max HP") implies multiple boss kills in one run** — same question. Current architecture: one boss per run at 90s. A multi-arena "gauntlet run" would be the natural v2.0 Endless Forge shape.
