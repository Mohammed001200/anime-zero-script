# Single-file distribution

## Deliverables

| File | Purpose |
| --- | --- |
| `loader.lua` | The GitHub raw entry point; a complete readable client bundle |
| `dist/MohammadAndAli.client.lua` | Identical bytes, named for ordinary LocalScript installation |
| `dist/manifest.json` | All 25 module sources, dependency edges, deterministic order and SHA-256 hashes |
| `scripts/bundle.py` | Standard-library-only builder and freshness check |
| `standalone.project.json` | Packages just the standalone LocalScript, with no shared module hierarchy |
| `build/MohammadAndAli-Standalone.rbxlx` | Generated Studio place containing that single client LocalScript |

The client embeds the GUI, core, movement driver, detectors, integration bindings, Studio adapter, and contract module. It excludes the server fixture, tests, build tools, and source `main.client.lua`. A client download cannot install a running server script in an existing game. To exercise the five-area fixture, use the separate demo place build.

## Exact command

Once `loader.lua` is published on the accessible `main` branch:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mohammed001200/anime-zero-script/main/loader.lua"))()
```

This command performs one initial download. The downloaded file contains no further HTTP fetches or calls to loadstring. It defines private module factories and a cached dependency resolver, then starts Bootstrap after all factories have been registered. No executor APIs, hidden GUI parenting APIs, or server-validation bypasses are added to the bundle.

Download/outer compilation errors happen **before** `loader.lua` can handle them. A 404, inaccessible repository, missing HttpGet, or missing loadstring must be diagnosed by the host. Inside the file, preflight, module and initialization failures include context and a traceback, are warned, and are rethrown. Partial session resources are cleaned up on construction failure.

An earlier raw-URL check returned HTTP 404; the user subsequently reported that the loader and GUI run in Anime Zero. This task has not published the updated v1.1.0 bundle. Publishing the reviewed update is separate from preparing the local files.

## Runtime matrix

| Environment | What is supported / actually verified |
| --- | --- |
| Ordinary Roblox LocalScript | The **complete standalone source** can be installed as a LocalScript in StarterPlayerScripts; no loadstring/HTTP is needed internally. Engine execution is pending a Studio playtest |
| Exact one-line command in an ordinary LocalScript | Unsupported; normal client scripting does not expose this remote loadstring workflow |
| Roblox server Script with LoadStringEnabled | Server loadstring is a separate feature. The GUI bundle deliberately rejects server execution and requires LocalPlayer |
| Studio Play with the demo place | Modular client + separate demo server are packaged; actual engine navigation, UI and replication playtest pending |
| Client host providing HttpGet + loadstring + ordinary client services | The user reports the GUI working in their host; the agent has not exercised or certified it or the rebuilt update |
| Lune/plain Luau process | Cannot display a Roblox GUI. Explicit no-runtime errors are tested; headless mocks verify client startup and lifecycle |
| Live Anime Zero | GUI startup is user-reported. No gameplay integration is verified; empty bindings do not provide NPC/rubble/combat/progression/replay APIs |

Roblox documents `loadstring` as disabled by default; `ServerScriptService.LoadStringEnabled` applies to **server scripts**. It does not authorize client execution. Documented experience HTTP methods are on HttpService and operate from experience servers. References: [Luau globals](https://create.roblox.com/docs/reference/engine/globals/LuaGlobals), [ServerScriptService](https://create.roblox.com/docs/reference/engine/classes/ServerScriptService), [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService).

No host or game access restrictions are changed by this project. This distribution change does not create authority to damage enemies, interact with rubble, enter areas, or replay in someone else's game.

## Install without a development environment

1. Open your own Roblox Studio place.
2. Insert a LocalScript under StarterPlayer → StarterPlayerScripts.
3. Paste the entire `dist/MohammadAndAli.client.lua` into it. Do not also install `main.client.lua` or the modular package for this installation.
4. Press Play. The bundle explicitly opens the GUI and leaves the controller stopped.
5. In Studio with empty bindings, Start waits for the project's demo server. Install/use the demo place for actual fixture progression, or supply verified bindings and rebuild for your own mechanics.

No VS Code, Python, Rojo, HTTP setting, or client loadstring is required at runtime. Opening the prebuilt standalone `.rbxlx` is an alternative to copying the source.

## Duplicate initialization and unload

The shared `MA_ControllerLifetime` BindableEvent is parented to the local PlayerGui and tagged with the project owner and `Starting`/`Ready` status. It is the cross-bundle lock; there is no dependency on shared executor globals.

- A ready session is reused and its window shown, retaining preferences and current run state.
- A second initialization while the first is starting fails clearly rather than constructing another GUI/heartbeat.
- Unknown/older markers fail closed and are preserved. Unload the older script or rejoin before trying again.
- Startup failure destroys the marker, partial GUI, controller, listeners and heartbeat, allowing a clean retry.
- Destroying the GUI or marker unloads the associated session.

The chunk returns a session handle with `:Show()` and `:Destroy()`. A duplicate run can return a small proxy to the existing session; callers should rely only on these methods, not internal controller/window fields. No settings change or repeated load automatically starts farming. To load a newly built version, first unload the old session and wait for its GUI/marker to disappear; loading again while it is ready simply reveals the existing version.

## Build and release checks

```powershell
python scripts/bundle.py
./scripts/verify.ps1
```

The builder tokenizes comments and strings so text mentioning require is not rewritten. It accepts the project's explicit `script.Parent...` requires and dual Roblox/Lune static requires, verifies that both forms resolve to the same file, and rejects missing modules, cycles, dynamic requires, duplicate module keys, unsupported interpolation, or leftover executable `script` references. This is a deliberately scoped project bundler, not a general Luau compiler.

Every artifact is deterministic, uses LF endings, and contains no timestamps. The SHA-256 manifest is a build/review aid, not an integrity check enforced by the one-line download command. That command follows a mutable branch and runs the bytes the host retrieves.

Review the diff for `src/Bootstrap.lua`, `src/UI/MainWindow.lua`, the bundler/tests, README/docs, and generated distribution before publishing. CI checks freshness instead of silently rebuilding stale tracked artifacts. The local verification script also checks all modules, three Rojo builds and formatting.

## Remaining Anime Zero work

`src/Game/Integration.lua` supplies a place-scoped, guarded M1 input trial. The user confirmed 1.2 NPC combat; the local 1.3 rubble/Pulse/opening-walk changes require a live test. See [INPUT_TRIAL.md](INPUT_TRIAL.md) for setup and remaining HP/death, checkpoint and replay gaps, and [SABLE_AUDIT.md](SABLE_AUDIT.md) for the public-source review. The trial has client-local observation identity, not a server run binding. Rebuild both distribution files after source changes, and verify actual behavior before claiming compatibility.
