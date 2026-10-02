Sparkforge BGM (v2.1, geometry Unit 4)
=====================================
Every bgm_*.mp3 / .m4a / .wav in this folder joins ONE shuffled deck
(MusicManager + BGMDeck). The rules are Brandon's settled plan
(docs/arena6-geometry-reconciliation.md, section 5, Unit 4 audio subunit):

  * Each track plays once per cycle, then the deck reshuffles. A new cycle
    never opens with the track that just played.
  * The deck lives for the app session: starting a run, a restart or the
    title never resets it, and it is not saved (a relaunch reshuffles).
  * Continuous: title, run and boss share the same song. A new track is
    drawn only when one finishes.
  * Resume: an OS interruption, backgrounding and BGM OFF -> ON all resume
    the same song where it was.
  * A track that can't be opened is dropped for that session and logged
    (DEBUG); the next track is drawn. A start the system refuses keeps the
    track for the next try, unless the same track is refused twice in a row
    (then it's dropped).
  * The player's own audio still wins, and the silent switch is respected.

NAMING: bgm_<lowercase_title_with_underscores>_<first 8 of the Suno ID>.mp3
(e.g. bgm_final_form_frenzy_dc68b53c.mp3). Two recordings that share a title
are two distinct tracks. Prefixes carry NO context any more: there are no
title/boss/run pools.

The 20 tracks here are byte-identical copies of the verified Suno downloads
(source folder "Sparkforge BGM - Suno", its manifest.csv and verification.json
left untouched), copied with the verified import map and its SHA-256s.

Adding a track: copy it in with a bgm_ name. That is enough; it joins the
deck. Changing the deck's RULES is a code change in BGMDeck / MusicManager,
proven by tools/bgm-harness.

Volume + crossfade dials: GameConfig.BGM.
