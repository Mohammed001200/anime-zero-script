# Development and Studio setup

## Requirements

- VS Code with Luau Language Server, StyLua, and Rojo extensions (`.vscode/extensions.json`).
- Roblox Studio and the Rojo Studio plugin for actual engine tests.
- Lune 0.11.0, Rojo 7.7.1, StyLua 2.6.0. Versions are pinned in `aftman.toml`.
- Python 3.10+ for the deterministic bundler and its tests (standard library only).

Install the official binaries from [Lune releases](https://github.com/lune-org/lune/releases/tag/v0.11.0), [Rojo releases](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1), and [StyLua releases](https://github.com/JohnnyMorganz/StyLua/releases/tag/v2.6.0), or use `aftman install`. Local Windows binaries may live in `.tools/`; this folder is ignored. No npm packages or proprietary UI libraries are needed.

Run commands from the repository directory, `anime-zero-script`, rather than its parent workspace folder.

```powershell
python scripts/bundle.py
./scripts/verify.ps1
```

If PowerShell execution policy prevents running the file, run the individual commands in README.md using the binaries on PATH. No system policy change is required.

## Open the demo

1. Run verification to generate `build/MohammadAndAli-Demo.rbxlx`.
2. Open that file in Studio, or run `rojo serve default.project.json` and sync to a fresh empty place through the Rojo plugin.
3. Press **Play** (client and server), not **Run** (server only).
4. Wait for the character and demo server. Dashboard displays **STUDIO DEMO**.
5. Choose **START RUN**. Default movement is Pathfinding; default follow distance is 5 studs, attack range 8 studs, and attack interval 0.6 seconds.
6. Watch area progression and Studio Output. Areas 1–4 have a rubble barrier; area 5 completes the run.

The demo's `MA_StudioDemo`, `Action`, and snapshot attributes are explicitly defined **by this fixture**. They are not Anime Zero object/remote names. Demo code runs only while `RunService:IsStudio()` is true.

## Studio acceptance pass (pending execution)

Record the Studio version, viewport, test date, and observations in VALIDATION.md after running these steps:

| Scenario | Expected observation |
| --- | --- |
| Default full run | Three training NPCs per area, four barriers broken, all five areas completed, movement stops |
| Two-second wave delays | “Waiting for NPC spawn”; no return toward area 1 |
| Auto Break Rubble off | Controller pauses at the barrier; enabling resumes it |
| Auto Next Area off | Current objective finishes, entrance movement pauses; enabling resumes |
| Auto Farm off | Enemy attacks and pursuit stop; unrelated progression only happens if state allows it |
| Auto Retry on | Completion followed by one server replay request, new run identity, then a fresh run |
| End / footer emergency stop | Character navigation and attack requests stop; GUI reports IDLE |
| Character reset mid-run | Wait for respawn, cancel old navigation, then resume the server's current area |
| Manual recovery | Recheck current area without creating another heartbeat/controller |
| Hide, minimize, Right Shift, floating restore | Controls restore the same GUI and status; automation continues while hidden |
| Dropdown, sliders, settings mirrored between tabs | Values update the same configuration; follow distance respects attack range |
| Save, unload, then reload GUI | Saved demo values load within the same server session; new run remains stopped |
| Repeat bootstrap/bundle while moving | Same GUI is revealed; the existing controller and heartbeat are reused |
| Two overlapping bootstrap calls | The second fails with initialization-in-progress instead of creating another session |
| Phone/tablet emulation and resize | Compact navigation, scrolling content, window fully on screen, usable input |
| Two-player Studio server | Each client affects only its own lane, targets, run and preferences |
| Remove an NPC during pursuit | Stale navigation cancels; no attacks against that ID |
| Stop during path calculation | Completed stale computation never issues movement |
| Block a navigation route | Path error/stuck/timeout causes bounded recovery or ERROR |
| Increase follow range beyond demo server's 9-stud range | Server rejects damage; health-progress timeout reports the mismatch |

The server resets a character into its **current** demo area after respawn. The controller itself never selects a spawn destination. Demo replay uses a deliberate server-side reset as its legitimate next-run mechanism.

## Integration build

`production.project.json` includes the client and shared modules but excludes the demo server. Empty integration bindings remain inactive and report the missing setup. In Studio, empty bindings select the demo adapter; without the demo server it reports that it is waiting. Supply verified bindings to select a custom adapter in Studio.

Do not sync a generated place over an existing game without reviewing its Rojo mapping. The demo project sets `Workspace.StreamingEnabled` to false for a consistent fixture. The production mapping does not set it.

## Single-file installation

For installation without VS Code/Rojo, paste `dist/MohammadAndAli.client.lua` into a LocalScript under StarterPlayerScripts in your own place, or open `build/MohammadAndAli-Standalone.rbxlx`. This only installs the client; it does not install the demo server or provide live game bindings. The exact GitHub command, supported environments and pending runtime checks are documented in [DISTRIBUTION.md](DISTRIBUTION.md).

## Useful official references

- [Roblox data model and script placement](https://create.roblox.com/docs/projects/data-model)
- [Roblox pathfinding](https://create.roblox.com/docs/characters/pathfinding)
- [Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [GuiButton input](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
- [Lune Luau compiler API](https://lune-org.github.io/docs/api-reference/luau/)
