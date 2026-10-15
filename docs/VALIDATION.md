# Validation record

Date: **2026-10-15** (Europe/Stockholm)

## Current input trial

The user supplied full-run and weaker-sword recordings plus a screenshot confirming
that M1 press/release and window-focus functions exist in their Solara session.
The recordings show numbered enemy models, four rubble barriers losing HP,
five areas, a final boss wave, victory and a manual reset. Enemy Humanoid HP never
changed in these captures. See [INPUT_TRIAL.md](INPUT_TRIAL.md) for the exact evidence
boundary and user-run acceptance procedure.

This change runs focused `tests/input.luau` checks, compilation/formatting of changed
Luau and generated bundles, and bundle freshness checks. It does not rerun the full
suite or execute a real Solara input call. The rebuilt gameplay remains unverified.

Executed result: **34 focused checks passed**, **18 changed/generated Luau files
compiled**, changed-file formatting and bundle freshness passed, and Git whitespace
checks passed. Input calls and Roblox services in these checks are mocks. No real
enemy damage, navigation, rubble attack, checkpoint entry, or replay was performed.

## Prior v1.1.0 verification (historical)

| Check | Result |
| --- | --- |
| Lune 0.11.0 compilation including both distribution files | 41 files compiled |
| Lune behavioral/startup/diagnostics suite | 64 passed, 0 failed; contract data and mocked services, not live gameplay |
| Python dependency/build suite | 8 passed, 0 failed |
| Deterministic distribution freshness | Passed; 25 embedded modules; both Lua deliverables identical |
| StyLua 2.6.0 formatting | Passed |
| Rojo 7.7.1 demo build | Passed; `build/MohammadAndAli-Demo.rbxlx` |
| Rojo 7.7.1 integration build | Passed; `build/MohammadAndAli-Integration.rbxlx` |
| Rojo 7.7.1 standalone client build | Passed; `build/MohammadAndAli-Standalone.rbxlx` |
| Standalone place XML inspection | Exactly 1 LocalScript, 0 ModuleScripts, 0 server Scripts |
| Earlier raw GitHub loader URL HEAD | HTTP 404 at the earlier check; superseded by the user's report that the loader now runs |

## User-provided live evidence

The user reports successful loader execution and a working custom GUI inside Anime Zero. The same session reports `Anime Zero integration is not configured`; none of its automation works. Auto Retry is also reported unresponsive. The user has only the running player client, with no developer APIs/source supplied. This is GUI-shell evidence only; the agent did not observe or control that session.

The v1.1.0 changes were checked locally for immediate missing-binding refusal with zero recovery attempts, per-feature binding requirements, permanent block handling, Kill Aura range/OFF/no-pursuit policy, replay once/new-run confirmation, missing-replay GUI feedback, and diagnostics exclusions/budgets/cancellation/read-error reporting/before-after comparisons. They do not verify any live game action. No new simulated dungeon was added as a substitute for the live integration.

Tests cover target scope/priority/range/death/disappearance, invalid positions and game state, explicit area clear, pending waves, rubble discovery/destruction, all five areas in order, missing objectives, final completion, replay once/new-run/rejection/timeout, settings pauses, respawn, unexpected area entry, manual recovery, no-damage combat, emergency stop, movement stand-off/timeout/stuck/driver failure, and idempotent cleanup.

The standalone five-area fixture uses one enemy per wave to keep assertions compact; the Studio fixture creates three NPCs per area. Both use four barriers followed by explicit final completion.

Loader tests execute the complete generated `loader.lua` with actual project modules and mocked client services. They verify that GUI objects are constructed and shown without native require, script instances, loadstring or HTTP inside the bundle; independent loads share one GUI and heartbeat; construction failure cleans partial resources and permits retry; simultaneous loads are rejected; server/missing-player/missing-GUI/plain-runtime errors are explicit; and GUI/marker destruction unloads the session.

Python tests check all source dependencies/order, deterministic artifacts, matching distribution files, handling comments/strings, missing modules/entry, duplicate keys, cycles, unsupported dynamic requires, leftover script references, and Roblox/Lune path mismatch. This does not certify the builder for arbitrary Luau outside its documented supported syntax.

## Implemented but not executed in Roblox

- Actual Studio server/client fixture, request validation and replication.
- Humanoid pathfinding, waypoint traversal, blocked paths, stand-off geometry, speed restoration, cancellation of in-flight ComputeAsync results.
- GUI appearance, dragging, resizing/compact layout, desktop/touch/gamepad interactions, notifications, and actual engine bootstrap/duplicate behavior (headless lifecycle tests pass).
- Demo server-session preference saving and reloading.
- Multiplayer lane isolation and live character respawn timing.
- The agent has not run the exact GitHub command in a live client host. The user's earlier GUI load is recorded separately; the rebuilt v1.1.0 diagnostics and gameplay are not live-tested here.

Luau compilation and Rojo packaging do not validate Roblox runtime properties, server/client timing, rendered appearance, or full Roblox static types. Perform the acceptance pass in SETUP.md to verify these behaviors.

## Blocked by missing game evidence

Server dungeon/run identity, NPC HP/death, authoritative wave-clear state, input delivery/damage, automatic checkpoint entry and replay remain unverified. The user-provided path/HP/HUD observations described above support the guarded input trial, not a live compatibility claim.
