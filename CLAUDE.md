# Sparkforge — Claude Code Rules

Arena survival roguelite. Swift / SpriteKit / iOS. Live on the App Store at **v1.5** (bundle `com.brandon.Sparkforge`, App Store ID 6760272178). This file governs every Claude Code session in this repo.

## Workflow (non-negotiable)

1. **Scope before code.** Every sprint has a kickoff doc in `docs/` with a unit sequence and DoDs. Don't build what isn't scoped; don't relitigate decided questions (each kickoff has a "decided — do not relitigate" section).
2. **One unit at a time, DoD gate between.** Build the unit, run the quality gates, then STOP. Brandon validates on-device or in simulator and approves before the next unit begins.
3. **One commit per unit, at DoD-pass, with explicit approval. Never push without approval.**
4. **Real-device testing is the final gate.** Simulator pass ≠ device pass.
5. **Division of labor on validation.** Claude builds and runs the quality
   gates (build + zero-new-warnings), deterministic validators, and *static*
   sim checks (launch, screenshot reachable menus, confirm no-crash/60fps).
   **Brandon owns the interactive playthrough** — driving the joystick, playing
   like a real player, feeling in-run states. It's his design instrument, not
   just a test. Don't puppeteer gameplay in the simulator to validate in-run
   behavior; hand that to Brandon's device pass.

## Quality gates

- `xcodebuild -project Sparkforge.xcodeproj -scheme Sparkforge -destination 'generic/platform=iOS Simulator' build` must succeed with zero warnings introduced.
- No force-unwraps in new code; match existing patterns (weak self in closures, config-driven tuning via `GameConfig`).

## Design canon (LOCKED — from the Game Design Decision Log)

- **Dynamic joystick recentering: NEVER revert.** Most impactful change ever shipped.
- **Health orbs are non-magnetized.** Walking to them is a positioning decision.
- **Magnet orbs are blue, never purple. Purple = danger** (ranged enemies, enemy projectiles).
- HP/ATK/DEF replaced binary death (v1.4). Cards design against this system.
- Build identity hints give players ownership of combos — extend, don't remove.
- **Monetization: every ad optional and player-initiated (rewarded only — interstitials are banned in this studio), every IAP additive. No paywalls, no gates, no energy systems.** Free path must stay whole.

## Technical conventions

- All tuning values live in `GameConfig.swift` — never scatter magic numbers.
- Physics categories are a bitmask ladder; **next free bit is `0x1 << 8`**. Update the App Portfolio Registry in Notion when claiming a bit.
- Always fully qualify `BossNode.slagTitan` (never `.slagTitan` shorthand) — codified in iOS Patterns & Gotchas.
- Singleton managers (`ProgressionManager.shared`, etc.) persist via `UserDefaults` with `sf_`/`sparkforge_` key prefixes. Never rename existing keys (live-player data).
- AdMob: publisher `ca-app-pub-3734133983597932`; ad unit IDs must match the App Portfolio Registry in Notion (registry is canonical).

## Reference

- Studio hub: Notion "Forgebound Labs" → App Portfolio Registry, Game Design Decision Log, Chat ↔ Code Workflow Playbook.
- Team: Brandon (product/orchestration/playtesting) · Lyra, ChatGPT (creative/design briefs) · Claude (build/documentation).
