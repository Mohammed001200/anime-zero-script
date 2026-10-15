# Public Sable loader review

Review date: 2026-10-15. This was a static, unauthenticated text inspection.
No downloaded Lua was compiled, executed, decoded, or copied into this project.

## What was accessible

The [GitHub entry](https://github.com/raphaelmaboi/wayout/blob/main/loader.lua)
and its [raw text](https://raw.githubusercontent.com/raphaelmaboi/wayout/main/loader.lua)
were readable. The 280-byte file contains a banner and a request to
`https://flowauth.net/v1/ui/sable.lua`; it contains no Anime Zero targeting,
combat, rubble, or progression implementation.

A normal GET of the [FlowAuth endpoint](https://flowauth.net/v1/ui/sable.lua)
returned **HTTP 403 Forbidden**, with a short warning/error stub rather than
the game implementation. The browser retrieval tool also could not access it.
No alternate headers, client impersonation, credentials, key requests, or other
attempts to defeat that restriction were used. The stub's escaped strings were
not decoded. This result does not establish whether any withheld game payload is
readable or obfuscated; that payload was not served to this inspection.

The public repository tree was also inspected: root tree SHA
`75f428eb11e017edcde932ad536399ec4dc290c2`, 15 entries, not truncated.
It has no Anime Zero-named module. This is a filename observation, not a claim
about the contents of every unrelated script. The readable `anotherloader.lua`
and `newloader.lua` wrappers reference the same external Luarmor loader. No
protected payload was retrieved, unpacked, or deobfuscated from those wrappers.

**Result: no game-specific mechanism was verified from Sable's code.** Public
reviews advertising a feature do not establish its object paths, input contract,
checkpoint location, or compatibility with our runtime.

## Independent evidence used instead

| Feature | User-supplied evidence | Implementation / remaining boundary |
| --- | --- | --- |
| NPC candidates | Numbered models directly in `Workspace.enemies`; nearby positions | Only rooted Humanoid models in that container; exclude player characters, roots outside the model, allies/assets elsewhere. Real HP/death and per-model ownership remain unknown. |
| Normal combat | Holding M1 attacks without abilities; host press/release/focus functions exist; user then reported Auto Farm reaching and fighting NPCs | Existing normal M1 input with range checks, cancellation, focus/UI guards and bounded attempt time. No remotes or private combat API. New Pulse timing still needs a live test; it does not alter server cooldowns. |
| Rubble | `Workspace.World.Map.Border1` through `Border4`; recorded HP changes to zero; later Diagnostics identify `RubbleHealth` and `RubbleMaxHealth` attributes | Read finite HP/max HP, reject inconsistent values, approach actual geometry, attack through normal M1. Fix the old exact-zero-counter gate using objective/final-wave observations. Live automatic rubble attack remains to be validated. |
| Area and phase | Recorded area/wave/remaining labels; Diagnostics identify `RunSide.Container.Title`, `RoundHUD.WaveTemplate.Title`, and `NextAreaChip.Frame.Title` under PlayerGui | Read the actual labels, reject conflicting explicit entry destinations, preserve the current area during entry, and never interpret a GUI title as a world-space position. |
| Next area | Recorded `Enter area N/5` after rubble HP reaches zero | Optional via Auto Next Area: bounded normal walk through a simple upright broken-border opening, then require the HUD to confirm entry. The geometric waypoint is a local movement plan, not a verified checkpoint binding. Unsupported geometry waits for manual entry. This traversal is not live-verified. |
| Completion / replay | Victory text and a later manual reset were recorded | Stop on visible victory. Replay remains manual; no supported replay action or exact button interaction was supplied. |

No Sable code, loader dependency, authentication material, or external script
download was added to the project. The Mohammad & Ali GUI is retained.

## What is still needed

- A short live test of this rebuilt version reaching and damaging the active
  border, followed by the area-entry label and new enemies. The agent has not run
  Roblox or Solara.
- If rubble still waits: the **exact current text** of the objective/counter/next
  labels and the active border's class, bounds and HP/max-HP values. The existing
  Diagnostics can collect candidates/attributes/UI text; a brief capture at the
  stalled border is more useful than repeating a full run.
- If the ordinary opening walk stops short or chooses no route: the actual
  checkpoint's object/class/position and activation condition, or a developer
  documented supported transition. No authoritative checkpoint object was found
  in Sable's accessible wrapper or supplied recordings.
- Meaningful enemy HP/death/ownership information for health-based targeting and
  confirmed kills. Presence changes alone do not provide those facts.
- A supported Replay interaction and new-run signal for Auto Retry. A UI click
  followed by a reset does not identify a callable replay action.

There is currently no missing attack input function in the user's tested M1
path. If those host functions are absent or fail in another session, preflight
and the input fault guard stop instead of inventing a replacement API.

See [INPUT_TRIAL.md](INPUT_TRIAL.md) for setup and verification limits.
