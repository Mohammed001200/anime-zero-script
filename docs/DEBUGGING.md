# Debugging

Turn on **Settings → Debug logging**, then inspect Studio Output. The logger retains at most 150 entries and exposes a `Message` signal. State transitions log once when the phase changes; target acquisitions are debug-only. Last Error remains visible until an explicit Start/Manual Recovery clears it.

| Symptom / error | Meaning and next check |
| --- | --- |
| Waiting for Studio demo server | Use the default demo project with Play, and confirm the Studio-only server script is running |
| Anime Zero integration is not configured | Supply verified bindings in Game/Integration.lua; the project has no guessed live integration |
| Waiting for wave or area-clear confirmation | Empty targets did not prove the area is clear; inspect `spawnPending` and authoritative `areaCleared` |
| Enemies are outside target distance | Living current-area targets exist, but acquisition range excludes them |
| Waiting for rubble, entrance, or completion state | Area is explicitly clear, but the next objective is unavailable; inspect cached progression evidence |
| Waiting for next-area entry confirmation | Character reached the entrance; adapter has not confirmed an area change |
| No navigation path / Path blocked | Check solid target geometry, approach point, agent size, route clearance, and streaming; recovery replans |
| Character stuck / Movement timeout | Movement did not make progress or exceeded its destination budget |
| Combat made no health progress | Requests were queued but damage did not occur; check verified range, target ID, rate rules, required equipment and server validation |
| No verified replay mechanism | Adapter does not expose a supported replay action; disable Auto Retry |
| Replay requested, but no new run | Request was rejected/lost, or run identity was not updated; no second request is sent |
| Preference persistence unavailable | This adapter has no save binding; values still apply to the current GUI session |
| Action/controller cleanup failed | An integration callback threw while stopping; other owners are still disposed; fix that callback |

The controller deliberately has no “go to spawn” fallback. If the player moves toward spawn, inspect another script controlling the humanoid, the game's respawn behavior, or an incorrectly supplied entrance point. The Studio fixture resets respawns to the current area and replay to area 1 on the server.

## Useful evidence

Capture the state, reason, run/dungeon IDs, area, character identity, pending/clear/completed flags, target ID/health/position, character position, selected ranges, capability flags, and the first error. Record snapshots around transitions rather than assuming UI text proves server state. Avoid dumping credentials or unrelated player data.

## Recovery and teardown

- **Emergency Stop / End:** disable controller, cancel movement and combat, retain preferences.
- **Manual Recovery:** cancel current actions, reset the bounded recovery budget and error, then inspect the current area.
- **Reset Configuration:** restore defaults and cancel current actions; an enabled controller reevaluates on the next tick.
- **Hide/Minimize:** preserve the active run; restore through Right Shift or the floating button.
- **Repeated bootstrap/bundle load:** reveals the existing ready GUI and reuses its controller/heartbeat. Overlapping initialization is rejected.
- **New build/version:** unload the old session and wait for its GUI/marker to disappear before loading; a duplicate load does not replace a running session.
- **Destroy GUI:** disconnects the heartbeat, actions, UI listeners, signals, and owned path job.

Already-sent one-shot requests cannot be recalled. A binding that starts held-input or asynchronous combat must implement immediate cancellation itself.

## Reproduce without Roblox

```powershell
lune run tests/run.luau
```

`tests/MockDungeon.lua` supplies a deterministic clock, target deaths, rubble, area entry, delayed waves, replay, and movement driver. It can freeze movement, suppress damage, remove entrances, reject replay, or throw combat errors. This fixture verifies decision/cancellation behavior without claiming engine navigation or replication works.

`tests/MockClient.lua` constructs the actual bundled GUI code against mocked services/events. Loader tests check GUI startup, one heartbeat across independent bundle copies, construction rollback/retry, concurrent startup, missing client/player/GUI, and teardown. They do not render the GUI or verify Roblox engine behavior. A raw URL 404 or missing host HttpGet/loadstring occurs before the bundle can run; see DISTRIBUTION.md.
