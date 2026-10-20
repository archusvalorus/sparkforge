# Rainbow R0 host proof

From repository root:

```sh
sh tools/rainbow-harness/run.sh
python3 tools/rainbow-harness/run-controls.py --output /tmp/rainbow-r0-controls
```

The first command compiles the actual policy, catalog, effects, PlayerStats and UpgradeManager with the established host stubs. The test-only extractor adds six guarded diagnostic insertions to a temporary manager copy so tests can observe actual production guarantee claims. It does not replace draw/eligibility logic. A changed extraction anchor fails closed.

The second command executes twelve sequential fault controls on temporary source copies. Only exit 1 with printed executable FAIL checks counts as a kill. Compilation failure, crash or timeout is an error. It keeps per-control logs/results and verifies original policy/manager bytes stayed unchanged. The runner's two explicit source overrides exist only for these controls and independent review.

Coverage includes real palette and acquisitions, bridge/signature/repeated-tier counting, reduced palettes, frozen/reset behavior, fresh spreads, protected seats, rerolls, declines/deferment, ordinary pick budgets, 15/20 cap boundaries, first-acquired-wins gates, stale offers, preserved unrelated paths, newly stalled Polar Vortex focus release and actual ordinary/bonus/random-opener candidates. Seeded production-draw traces demonstrate a deliberate breadth-seeking strategy can select the proof reward within both existing run caps. They do not measure natural offer rates or balance.

The proof's special one-rank descriptor is deliberately not an UpgradeCard or a catalog entry. No production scene or draw invokes RainbowPolicy. The opt-in manager admission overload applies the same additional next-tier predicate to focus and final acquisition; existing callers use their original path. R1 still needs final-spread protection metadata, live draft/guarantee/bonus/stale-choice wiring, gateway bookkeeping after reward seating, choice-budget integration, truthful catalog/UI representation and complete effects before enabling a Rainbow card.

The harness executes a composed admission seam over actual source candidates; it does not prove that unmodified production callers already route through that new seam. Granted-level/Extra Pick budgets are policy inputs, not a new scene queue. Existing Neutral queue regressions remain the evidence for the unchanged queue. No game, simulator, device, framerate or Switch validation is performed here.
