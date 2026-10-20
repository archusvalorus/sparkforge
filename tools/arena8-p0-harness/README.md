# Arena8 P0 host proof

Run `sh tools/arena8-p0-harness/run.sh`; controls: `python3 tools/arena8-p0-harness/run-controls.py --output /tmp/arena8-p0-controls`.

This executes the actual DEBUG bounds/model plus unchanged shared Footprint, exact wall LOS, pathShove and route graph. It also compiles the unchanged reviewed Rainbow model and exact damage/credit dependencies to prove the new rectangle/walls are usable black-box consumers. No live player/enemy, arena registry, saves or combat is activated.

Declared fixture radii14/26/40 and oversized refusal70 are proof inputs, not the final Arena8 roster or universal creature clearance. The fixture has two rooms, a200pt-long120pt-wide permanently open corridor and two solid wall blocks. Body clearance applies to bounds, doors, routes and safe candidates. Seeded4500 endpoint moves and bidirectional route runs are executed, not source-name checks.

Walking uses X-then-Y swept sliding. A supporting plane skips an axis-aligned zero-corner wall only when the straight walking segment is tangent/outward, avoiding initial-contact sticking. This special case is limited to these authored fixture boxes. Instant shove remains a separate straight shared pathShove stop-before-wall contract: an L-shaped walk is not a straight knock proof. Large fixtures approach a wall-adjacent small Spark via a validated bounds/resolve point; that adapter is not production enemy targeting. Invalid placement/route results defer; no unsafe fallback.

Fifteen sequential controls alter temporary model/bounds copies. Only executable FAIL output + exit1 counts as a kill; compiler errors/crashes/timeouts are errors. Circle defaults, body inset, translated circles, walking tunneling/support, straight shove, route/body clearance, small-player approach, spawn rejection, walls/LongShot, retirement, hold and hitch controls are retained. Scene/entry/source isolation checks supplement model proof; they do not prove native touch, memory, device FPS or owner feel.

See [preview guide](../../docs/v2.3-arena8-p0-preview.md). All P0 source and entry are DEBUG opt-in. Existing production circle consumers and the eight reviewed Rainbow inputs remain byte-identical.
