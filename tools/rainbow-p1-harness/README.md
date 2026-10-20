# Isolated Rainbow P1 proof

```sh
sh tools/rainbow-p1-harness/run.sh
python3 tools/rainbow-p1-harness/run-controls.py --output /tmp/rainbow-p1-controls
```

The host runner compiles the actual DEBUG model, exact geometry, damage, kill-credit and Chain Reaction queue sources with the existing geometry host stubs and extracted real configuration. It does not launch an app or simulator. The twenty sequential fault controls mutate only temporary model copies; compilation errors, crashes and timeouts are ERROR, never a kill. A kill requires executable FAIL output and exit1.

Coverage includes clock/empty launches, hold composition, resume/board/end/reset, subframe snapshotting, continuous moving body contact, Spark-aimed one-third-height lane bounds/clipping, visibility changes inside a contact interval, overlapping convex shadows, a deterministic rotated/rounded-wall oracle, target input ordering, per-cycle hit identity, launch attacker/crit/Long Shot snapshots, contact-time defenses, zero/rounding/Whiteout entry, full capstone kill credit and nonboss Chain Reaction eligibility, plus150 populated-state retirement/reset cycles.

The oracle is an independent dense-time reference for misses and directly checks emitted contacts for body overlap and clear line of sight. It is not treated as proof that a narrower valid visibility gap cannot exist. The exact solver uses one contact interval and convex footprint shadows rather than fixed temporal substeps.

Fixture `ordinaryBasis`, target `defenseFactor`, health/status and kill receipts are declared test inputs/outputs. They are not production PlayerStats, boss DEF entry, on-kill or save integrations. The prototype scene deliberately has no access to those systems. Native Debug/Release compilation and source guards cover the scene/entry; a host model pass does not prove pixels, touch feel, device performance or native scene memory behavior.

Lane additions prove Spark-centered warning proposals, launch interpolation, frozen postlaunch aim, top/bottom clipping without shifting, board-clipped height basis, whole-body exclusion/partial-body overlap, moving entry/crossing/early exit, and Long Shot never widening the lane. The same exact captured rectangle supplies the renderer and contact segment.

For presentation and controls see [the owner preview guide](../../docs/v2.3-rainbow-p1-preview.md). Normal launch and every Release build exclude the P1 entry. No live Rainbow catalog entry, production combat or persistent state is modified.
