# Game adapter contract

## Verification boundary

The user's recordings identify candidate enemies, rubble HP, area/wave labels and a victory result. Later Diagnostics supplied RubbleMaxHealth and the RunSide/WaveTemplate/NextAreaChip labels. The user confirmed normal held-M1 Auto Farm reaching and fighting NPCs in 1.2. [INPUT_TRIAL.md](INPUT_TRIAL.md) describes the 1.3 changes and their limits. New automatic rubble attacks, Pulse input, actual checkpoint entry, meaningful enemy HP/death and replay remain unverified. The Studio adapter remains separate. [SABLE_AUDIT.md](SABLE_AUDIT.md) records why no Sable implementation was available from the public loader chain.

The user has only player-client access; no developer combat/replay API or source was supplied. The trial explicitly marks its snapshot as client observation and its run ID as client-local. It uses the recorded enemy folder for presence-based candidates without claiming HP or confirmed kills. Diagnostics do not automatically promote names or paths into bindings.

## Audit of the reported failure

| Code | Actual responsibility / live gap |
| --- | --- |
| `Integration.lua` | Creates the guarded observation/input trial only at the recorded place/universe; empty bindings elsewhere |
| `ObservedIntegration` / `M1Input` | Observed enemy candidates, HUD/rubble HP/max-HP reads, guarded Hold/Pulse M1 and bounded geometric opening-walk trial; no verified server HP/death, checkpoint or replay API |
| `AnimeZeroAdapter` | Detects supplied functions, now reports exact missing names and preflights enabled features |
| `NPCDetector` | Chooses living, scoped snapshot records; does not discover Anime Zero's world hierarchy |
| `CombatController` | Rate-limits/revalidates calls to `attack`/`breakRubble`; has no built-in Anime Zero attack API |
| `RubbleDetector` | Selects active scoped barrier records; requires confirmed identity and health/progress data |
| `AreaDetector` / progression | Need explicit area/run/wave/clear/completion/entrance state; empty enemies are insufficient |
| `MovementController` | Navigates to supplied points, with stand-off/stuck/timeout/cancellation; cannot infer the correct area destination |
| Auto Retry control | Previously disabled silently by `capabilities.replay == false`; now explains missing `requestReplay` and opens Diagnostics |

`preflight(config)` refuses Start without functions needed by enabled features: `snapshot` always, `attack` for Auto Farm/Kill Aura, `breakRubble` for automatic rubble, and `requestReplay` for Auto Retry. This checks presence, not live correctness. A supplied function is not automatically a verified game API. Missing bindings stop with ERROR and zero recovery attempts. A known permanent runtime blockage may return `ready = false, blocked = true, reason = ...`; transient replication/spawn waits should not set `blocked`.

Do not derive game authority from UI text such as “Break the rubble!”, object name guesses, missing replicated enemies, or a distance label. These may help locate evidence during an authorized inspection, but they are not authoritative progress/completion signals.

## First integration step

In a developer-authorized test place, observe one complete run and document these facts before editing bindings:

| Required observation | What the implementation needs |
| --- | --- |
| Active dungeon and run identity | Stable dungeon scope; run ID changes on every replay |
| Current area and final area | Integer area index, total area count, reliable area entry confirmation |
| Wave state | Explicit spawn-pending and area-cleared facts, including delays between waves |
| NPC collection | Confirmed ownership, ID, alive/health state and root/world position |
| Rubble objective | Confirmed current-area ownership, health or normalized remaining progress, destruction fact |
| Next entrance | Position and destination area, exposed only when progression permits entry |
| Completion | Explicit server-backed success/completion state |
| Combat and rubble interaction | Supported developer API, input action, or server request; range, rate and target rules |
| Replay | The game's supported next-run mechanism and new-run confirmation |
| Optional preferences/speed | Authorized storage and permission to override WalkSpeed |

Record actual inspected references, ownership, replication behavior, and evidence here. Leave unknown fields marked unknown. If a necessary mechanism is unavailable legitimately, that feature remains unsupported.

## Snapshot

`src/Game/Contracts.lua` defines the Luau records. `snapshot()` returns one coherent cached record, without yielding:

| Field | Contract |
| --- | --- |
| `ready` | False with `reason` while bindings/state are unavailable |
| `dungeonId`, `runId` | Nonempty strings. Never reuse a run ID for a replay |
| `area`, `totalAreas` | Integers, `1 <= area <= totalAreas` |
| `completed` | Explicit authoritative completion, never inferred from an empty list |
| `areaCleared` | No remaining waves/enemies in this area according to authoritative state |
| `spawnPending` | True during known pending waves or entry/spawn transitions |
| `characterReady`, `characterId` | Living usable character and identity that changes on respawn |
| `position` | Current character point `{ x, y, z }`, all finite numbers |
| `npcs`, `rubble` | Collections of target records; use empty tables when genuinely empty |
| `nextEntrance` | Optional entrance record for exactly `area + 1`, within the same dungeon/run |

A target record contains `id`, display `name`, `dungeonId`, `runId`, `area`, `position`, finite numeric `health`, and boolean `alive`. IDs must be unique within a run and must not be reused for a different object. For non-health rubble mechanics, expose remaining progress as decreasing positive health; set `alive = false`/health 0 or remove the target when destruction is confirmed.

An entrance contains `id`, `dungeonId`, `runId`, destination `area`, and `position`. Its presence must mean movement is permitted. For gates requiring another supported interaction, implement that mechanism in the adapter/driver before reporting an enterable entrance. This controller does not invent an “enter area” remote.

Snapshot target points must belong to the active dungeon. The core additionally filters foreign run/area/dungeon IDs and invalid/dead targets. Streamed-out objects do not prove death or area clear. If replication is incomplete, report not-ready or a pending/non-cleared state until it is coherent.

## Binding functions

Populate `src/Game/Integration.lua` with implementations of this interface. Names below describe this project's binding contract, not game APIs:

| Binding | Purpose and return |
| --- | --- |
| `snapshot()` | Return the cached snapshot above; required for any real integration |
| `attack(id, runId)` | Re-resolve a current living NPC, invoke the verified one-shot combat action; return `true` if accepted/queued, or `false, reason` |
| `breakRubble(id, runId)` | Re-resolve active rubble and invoke the supported action; same return convention |
| `cancelCombat()` | Release owned held inputs/background work immediately; idempotent |
| `requestReplay(runId)` | Invoke the supported replay mechanism once; return `true` if accepted/queued, otherwise `false, reason` |
| `loadPreferences()` | Optional: return a cached `{ version = 1, values = ... }` configuration envelope |
| `savePreferences(envelope)` | Optional: request/perform authorized persistence; return truthful `accepted, message` |
| `movementSpeed` | Boolean permission/capability flag for this driver's optional WalkSpeed override |
| `destroy()` | Disconnect subscriptions and release binding-owned resources; idempotent |

All callbacks must return promptly **without yielding**. Subscribe to legitimate game events ahead of time and keep cached snapshots. Do not call `WaitForChild`, `InvokeServer`, unbounded waits, or HTTP requests inside controller callbacks. Any asynchronous work must own cancellation/generation checks and must not issue actions after `cancelCombat()`/`destroy()`.

Capabilities are enabled only for supplied functions. There is no universal combat fallback. Requests queued to a server are not confirmed damage; the controller watches health and uses `combatProgressTimeout` to catch no-progress requests. The server must continue to enforce all range, rate, ownership and progression rules.

The runtime checks for a new run identity after replay and errors if it never arrives. Merely clearing `completed` with the same run ID is insufficient. Auto retry never repeatedly fires replay requests for the same completed run.

## Movement

`RobloxMovementDriver` uses `Humanoid:MoveTo` and `PathfindingService`. It computes a stand-off destination outside the target, and generation-checks asynchronous path results. Path errors route through bounded controller recovery. Speed overrides are opt-in, capability-gated, and restore the prior value on cancellation. The game can still reject/override movement or speed.

The driver interface is `moveTo(point, config)`, `cancel()`, `getError()`, and `destroy()`. Add an alternate supported driver only after observing actual behavior. Do not add teleport loops. Tune agent dimensions for unusual rigs and use floor/approach positions verified in the real dungeon.

## Error policy and integration acceptance

Missing state waits, then enters bounded recovery; malformed snapshots cannot trigger navigation. Combat rejection, blocked/stuck movement, missing objectives and stale replay all become visible errors when recovery is exhausted. Integration cleanup failures are logged while the controller continues disposing other owners.

1. Validate snapshots alone while watching all five areas.
2. Enable navigation with combat paused; verify the active scope and approach points.
3. Enable NPC combat, then rubble, then next-area movement.
4. Test delayed spawns, target despawn, character death, unexpected entry, stop, and reload.
5. Test replay last, observing a new run ID.
6. Record engine observations in VALIDATION.md before claiming live compatibility.

The fixture's `demo/Dungeon.server.lua` and `StudioDemoAdapter.lua` show an end-to-end server/client implementation whose names and mechanics are fully defined by this repository. They must not be copied into another game's integration as assumed internals.
