# Collect the real Anime Zero evidence

## What is and is not fixed

The reported error originates in an empty `src/Game/Integration.lua`, not a broken loader. The GUI can render without the data/actions needed by its controller. There is currently **no verified Anime Zero integration**. Merely identifying a humanoid or a button with “Replay” on it does not establish its current dungeon ownership or a supported programmatic action.

The v1.1.0 update fixes unavailable-binding recovery behavior and Auto Retry's silent disabled control, and adds diagnostics and a Kill Aura policy. It does not claim to make damage, rubble, area progression or replay work in Anime Zero. With only a running player client available, developer-only/server information cannot be supplied by this agent.

## Load the updated version

The updated `loader.lua` and standalone client are built locally; this task does not push them. Publish the reviewed files yourself when ready. **A repeated load reuses an existing GUI**, so rejoin the game before testing the new version, or unload the current session and wait for its window/marker to disappear. Hiding or minimizing the GUI does not unload it. Version 1.1.0 is shown in the sidebar/Credits and adds a Diagnostics tab.

Once using 1.1.0, Settings → **UNLOAD SCRIPT (STOP AND CLOSE)** stops and disposes the session. Older versions without that control can be removed by rejoining. Loading a newer bundle over an older tagged session now warns that it is still showing the old version.

## Capture from the real player client

1. Leave automation stopped. Open **Diagnostics**. Read the missing binding list.
2. Stand near a living dungeon enemy. Choose **Before manual attack**, then **CAPTURE READ-ONLY DIAGNOSTICS**. Wait for “Captured …”.
3. Use the game's normal attack once. Choose **After manual attack** and capture again. The report includes differences from the previous capture.
4. Copy the report text, or choose **PRINT LAST CAPTURE TO CONSOLE** and copy the text between the begin/end markers. Reports stay on your client; nothing is automatically uploaded or sent.
5. Finish the current area's enemies normally. At the rubble, capture **Area cleared / rubble**.
6. Break the rubble normally. Capture **After manual rubble break**, then **Next area entered** after using the normal checkpoint.
7. At final completion, capture **Dungeon complete** before pressing the game's own Replay/Retry button. Press it normally, then capture **After manual Replay** in the new run.

Alongside those reports, record the normal attack keys/buttons, whether a Tool is equipped, what action actually breaks rubble, and whether Replay is a GUI button, prompt, or other supported interaction. Record whether the next run starts in the same place or teleports to a different place. The report includes PlaceId/GameId so the exact game can be identified without guessing.

The scan is read-only: it does not attack, activate a Tool, trigger a prompt, click another GUI, fire/invoke a remote, inspect script source, modify health, or change bindings. It samples at most 4,000 queued objects / 3 seconds, yields periodically, and can be cancelled. It excludes player characters from NPC candidates and excludes this project's own GUI. Equipped Tool metadata is collected separately. Streaming, limited budgets, custom NPC formats and access restrictions may cause incomplete observations; “not observed” does not mean dead or destroyed.

## Exactly what is missing

| Required feature | Missing facts / supported mechanism |
| --- | --- |
| Kill Aura | Which living NPC models belong to the active dungeon/run/area; their health/root positions; the supported combat action and its range/rate/equipment requirements |
| Auto Farm | The same NPC/combat data plus valid approach positions and confirmation that Humanoid movement is usable in this dungeon |
| Auto Break Rubble | Authoritative area-clear/wave state; actual barrier identity, ownership, remaining health/progress and destruction fact; supported attack or interaction action |
| Auto Next Area | An enterable checkpoint position for the immediately following area, and a reliable area-entry/pending-wave signal |
| Areas 1–5 / completion | Stable dungeon identity, new identity per run, current area, total areas, explicit wave/area clear and final success state |
| Auto Retry | The game's supported replay action; confirmed completion before requesting it; confirmed new run or place transition afterward |

Visible UI text is useful observation evidence, but does not by itself make a coherent authoritative dungeon snapshot. The collection captures are deliberately non-atomic, with candidate scope marked UNKNOWN. They are not fed into automation.

If the game uses a normal Roblox Tool or ProximityPrompt, its documented mechanism can be considered only after the correct object and effect are confirmed. The generic existence of `Tool:Activate()` does not prove that an equipped Tool implements this game's attacks. If the game uses custom controls and exposes no supported callable API, player-client observations alone may be insufficient; the missing action must remain manual or require developer-authorized API information. Do not infer RemoteEvent names/arguments from object names, hook traffic, or bypass validation.

## Binding interfaces after evidence is available

The source adapter expects these **project interface names**, not assumed game APIs:

- `snapshot()` — coherent cached dungeon/run/area, wave, character, targets, barrier, entrance and completion record.
- `attack(id, runId)` — re-resolve a scoped living target and perform the confirmed one-shot combat action.
- `breakRubble(id, runId)` — re-resolve the confirmed active barrier and perform the supported action.
- `requestReplay(runId)` — use the confirmed next-run action once per completed run.
- `cancelCombat()` / `destroy()` — release any owned asynchronous work/held inputs and subscriptions.

See GAME_INTEGRATION.md for the exact schema and non-yielding callback requirements. Supply only the confirmed bindings and rebuild with `python scripts/bundle.py`; candidate discovery is never used to silently manufacture these functions.

## Auto Retry and Kill Aura controls

Auto Retry is a preference for **after confirmed completion**, not a “restart now” command. Without `requestReplay`, clicking it shows the precise unavailable reason, leaves the preference off, and opens Diagnostics. A working replay binding alone is still insufficient if completion/new-run identity is unknown. Once all required state/actions exist, the controller sends one request and waits for a new run; it does not spam the Replay action.

Kill Aura is available in Dashboard and Auto Farm. It uses the Attack Range slider and the existing single combat controller/cooldown. Turn Auto Farm off for attacks without NPC pursuit; other Dungeon toggles still govern rubble/entrance movement. Start Run is required. Without snapshot/combat bindings, Start fails immediately with the missing names; a Kill Aura toggle does not bypass that requirement.

## What was actually checked

Local regression tests cover immediate stops for the empty real adapter, refusal to recover missing bindings, per-feature binding requirements, missing replay feedback through the actual GUI code, limited-range Kill Aura policy, one-shot replay requests, and bounded/cancellable read-only captures and comparisons. These use supplied contract data and mocked client objects. No real enemy was damaged, rubble broken, checkpoint traversed, or replay requested by this agent. The user's successful GUI load is separately recorded as a user observation.
