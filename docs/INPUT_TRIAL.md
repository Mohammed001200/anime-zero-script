# M1 input trial (1.2.0-input-trial)

This build connects the existing GUI/controller to observed enemy models and normal
M1 input. It is ready for a user-run trial, not verified live automation. No remote
events, private combat functions, ability calls, health writes, teleports, or
security-bypass fallbacks are used.

## Evidence and limits

The supplied recordings identify place `109151342576374`, universe `10512942223`,
`Workspace.enemies`, `Workspace.World.Map.Border1` through `Border4`, and these HUD paths:

- `PlayerGui.RoundHUD.Container.TopPart.RemainingFrame.EnemyCount`
- `PlayerGui.RunManage.Sheet.Title.Info`
- `PlayerGui.EndScreen.Holder.ConstraintedHolder.ResultText`

The user reports that holding M1 alone repeatedly attacks without abilities, and
checked that `mouse1press`, `mouse1release`, and `isrbxactive` are functions in their
Solara session. Presence does not prove those calls deliver input successfully.
All calls are protected and failures stop the controller. No fallback to a private
input service or another host API is attempted.

Enemy Humanoid health remained 100 in both the strong- and weak-sword captures.
The trial therefore records **HP unknown**, never substitutes 100 HP, and uses
positive-Humanoid models still present directly in the observed enemy folder as
eligible candidates. That filters out allies and GUI preview rigs; it does not
establish ownership, actual HP, confirmed death, or invulnerability. When a model
is removed, the controller switches targets because the old target is unavailable.
Disappearance is not reported as a confirmed kill. Nearest targeting is supported;
LowestHealth refuses Start because meaningful enemy HP is unavailable.

The trial's dungeon/run IDs are explicitly **client-local observations**, not
server identifiers. Visible area/counter labels are used as hints. Empty enemy
collections alone never prove an area clear. Rubble is eligible only when the
recorded current-area border has readable positive `RubbleHealth`, no enemy
candidates remain, and the HUD reports zero remaining. Stale counters therefore
pause rubble progress. The recorded `Enter area N/5` phase waits for **manual
checkpoint entry**; no checkpoint path or position has been verified. Auto Retry
remains unavailable. A visible victory result stops the controller.

## Run the trial

1. Load `loader.lua` using the GitHub command in README in the same client host,
   or execute the complete contents of the local file.
2. Unload the previous GUI in Settings first (or rejoin). Repeated loads reuse an
   existing GUI; confirm the sidebar says **1.2.0-input-trial**.
3. Equip the sword and enter a dungeon with NPCs. Use **Nearest** targeting,
   **MoveTo** movement (the trial default), attack range **8**, follow distance
   **5**, and attack interval **0.6** seconds initially. A range slider cannot
   increase the sword's actual server-enforced reach.
4. For **Auto Farm**, turn Auto Farm on. With both farm and aura enabled the input
   trial still approaches to Follow distance. For **Kill Aura without NPC pursuit**, turn Auto
   Farm off and Kill Aura on. To test only NPC combat, turn Auto Break Rubble and
   Auto Next Area off.
5. Click **Start Run**, release your physical M1, then move the pointer into the
   game view, away from the GUI. The Roblox window must have focus. Pause reasons
   appear in the existing controller status. Sword direction and damage follow
   the game's ordinary combat rules; no automatic aiming/facing override is added.
6. Confirm actual sword swings and enemy damage. If it follows but does not hit,
   press **End** and report that result; successful input calls do not prove damage.
   Do not interpret changing target names as verified kills.
7. **Stop Run**, **End**, unloading, target loss, focus loss, menus, text fields,
   or pointer entry over interactive/script/result UI release M1. The input has a
   1.5-second lease renewed by combat ticks, with an independent heartbeat watchdog.
   It does not start automatically when the loader runs.

The **Combat progress timeout** is the maximum attempt time per unknown-HP enemy
(default 15 seconds). A persistent candidate times out with **Unverified damage**
and bounded recovery; it cannot cause an unlimited attack loop. Rubble instead
uses its observed health changes. Attack interval must be at most 1 second to
renew the lease. Focus/UI pauses do not consume recovery attempts or send input.

If the host's release function throws, the controller refuses further presses and
shows the release error. Manually release M1 and unload the session in that case.

## Verification

Run focused checks after rebuilding:

```powershell
python scripts/bundle.py
.\.tools\lune.exe run tests/input.luau
python scripts/bundle.py --check
```

Checks use mocked input/services, including actual generated-bundle startup at
the recorded place ID. They check acquisition/movement/range, target switching,
unknown-HP timeout, input lease/release, focus/UI pause, cleanup/duplicate startup,
victory/manual reset observations, and missing replay support. They do not execute
Solara, deliver a real click, navigate the actual map, or verify server damage.
The full test suite is deliberately not run for this change.
