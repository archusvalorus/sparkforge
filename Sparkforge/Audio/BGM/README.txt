Sparkforge BGM drop folder (v2.1)
=================================
Drag Suno tracks in here (Xcode picks them up automatically) named:

  bgm_title_<anything>.mp3   -> title screen pool
  bgm_run_<anything>.mp3     -> in-run pool
  bgm_boss_<anything>.mp3    -> boss-fight pool
  bgm_<anything>.mp3         -> in-run pool

mp3 / m4a / wav all work. Pools shuffle (no immediate repeats), context
changes crossfade, empty pools fall back (boss -> run -> anything).
Volume + crossfade dials: GameConfig.BGM. No code changes needed, ever.
