# art/source — raw art drop

**Brandon drops Lyra's exports here. Claude cuts them into
`Sparkforge/Assets.xcassets/` imagesets.** Nothing in this folder ships in the
app; it's the archive the shipped assets are derived from.

One folder per character, matching the briefs in `docs/art-briefs.md`:

| Folder | Brief | Render size | Status |
|---|---|---|---|
| `panda-kaiju/` | — | 96pt | ✅ shipped, animated |
| `panda-ordinary/` | 1 | 76pt | awaiting art |
| `panda-samurai/` | 2 | 76pt | awaiting art |
| `mountain-lion/` | 3 | 76pt | awaiting art |
| `nature-canon/` | 4 | 50pt | awaiting art — 9 animals, one frame each |
| `skins/` | 5 | 32pt | awaiting art |

---

## Dropping files

**Filenames don't matter — drop them as they export.** Claude renames and
reorders into the animation sequences. Don't spend time tidying.

The only thing worth flagging when you drop a batch is **anything ambiguous**:
which frame is which, or whether two similar images are two *directions* or two
*frames*. That exact ambiguity cost a round trip on the kaiju, where the attack
recovery frame was sitting on disk named `Right-facing attack 2` and got missed.

If a folder's contents are self-evident (`walk-1..4`, `idle-1..3`), no note
needed.

## What actually matters (from `character-art-playbook.md`)

These are the things that can't be fixed after the fact:

1. **Transparent background** — a white matte and true alpha look identical in
   a viewer and behave completely differently over a dark arena. Claude verifies
   corner pixels on every batch, but catching it at export is cheaper.
2. **Same canvas size across a set.**
3. **Consistent registration** — same ground contact and body centre on every
   canvas. Frames that drift make the character teleport, and no amount of
   cropping recovers registration the art never had.
4. **No baked effects** — no fire, glow, shadow. The game draws those in code.

## What Claude does with them

1. Verifies alpha and measures content bounds on every frame.
2. Computes the **union box across the whole set** and crops every frame to it,
   so nothing shifts between frames. (Single sprites crop to their own bounds;
   frame sets never do.)
3. Emits `@1x/@2x/@3x` imagesets sized so the **standing body** lands on the
   size ladder.
4. Wires the animation and verifies on device.

**Sources are committed deliberately.** They're regenerable in principle, but
having them in-repo means assets can be re-cut at any size without going back to
Lyra — and re-cutting is likely as sizes get tuned.
