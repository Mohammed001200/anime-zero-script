# M1 input trial (1.3.0-input-trial)

This build connects the existing GUI/controller to observed enemy models and normal
M1 input. The user confirmed that 1.2 reaches and fights NPCs. The new rubble,
opening-walk, closer-follow and Pulse changes require a live trial. No remote
events, private combat functions, ability calls, health writes, teleports, or
security-bypass fallbacks are used.

## Evidence and limits

The supplied recordings identify place `109151342576374`, universe `10512942223`,
`Workspace.enemies`, `Workspace.World.Map.Border1` through `Border4`, and these HUD paths:

- `PlayerGui.RoundHUD.Container.TopPart.RemainingFrame.EnemyCount`
- `PlayerGui.RunManage.Sheet.Title.Info`
- `PlayerGui.EndScreen.Holder.ConstraintedHolder.ResultText`
- `PlayerGui.RunSide.Container.Title` (additional user Diagnostics)
- `PlayerGui.RoundHUD.WaveTemplate.Title` (objectives)
- `PlayerGui.NextAreaChip.Frame.Title` (next-area information)

The user reports that holding M1 alone repeatedly attacks without abilities, and
checked that `mouse1press`, `mouse1release`, and `isrbxactive` are functions in their
Solara session. The user subsequently confirmed normal M1 farming in version 1.2;
that does not verify the new Pulse timing or automatic rubble/progression changes.
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
candidates remain, and an observed rubble instruction, zero remaining with no
known pending wave, or a final wave whose observed enemies have been absent for
0.25 seconds. The last condition also requires a final-wave enemy to have been
seen in that scope. A stale `1 left` counter no longer blocks that transition.
`RubbleMaxHealth`, when available, validates HP and is included in the snapshot.
Conflicting explicit entry labels pause; the next-area chip cannot bypass a
still-positive border.

With Auto Next Area on, the `Enter area N/5` phase (or a matching next-area chip
after confirmed border destruction) can attempt a **normal walk through the
broken opening**. A route is derived only from a simple upright thin border's
actual bounds and approach side, cached before it disappears. Its waypoint lies
8 studs beyond the far face, inset from the edges. This is an independent,
geometric movement plan, **not a verified checkpoint location or game API**.
Deletion alone does not authorize it: zero HP or the entry phase must also be
observed. Unsupported geometry pauses for manual entry. Normal collisions, stuck
checks and timeouts apply; a new area must be confirmed by the HUD. Automatic
traversal through all five actual areas has not been tested. Auto Retry remains
unavailable. A visible victory result stops the controller.

The [Sable audit](SABLE_AUDIT.md) found a readable download wrapper and an HTTP 403
at its downstream endpoint. No Sable implementation was executed or copied.

## Run the trial

1. Run the GitHub command from README in the same client host, or execute the
   complete contents of the local `loader.lua`.
2. Unload the previous GUI in Settings first (or rejoin). Repeated loads reuse an
   existing GUI; confirm the sidebar says **1.3.0-input-trial**.
3. Equip the sword and enter a dungeon with NPCs. Use **Nearest** targeting,
   **MoveTo** movement (the trial default), attack range **8**, follow distance
   **3**, and attack interval **0.15** seconds (new trial defaults). A range slider cannot
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
   Keep Hold mode for the previously user-tested input behavior, or choose
   **Pulse** on Auto Farm and a **0.15-second M1 pulse interval** to test repeated
   ordinary clicks. Faster input is not a promise of faster server damage.
7. **Stop Run**, **End**, unloading, target loss, focus loss, menus, text fields,
   or pointer entry over interactive/script/result UI release M1. The input has a
   1.5-second lease renewed by combat ticks, with an independent heartbeat watchdog.
   It does not start automatically when the loader runs.

The **Combat progress timeout** is the maximum attempt time per unknown-HP enemy
(default 15 seconds). A persistent candidate times out with **Unverified damage**
and bounded recovery; it cannot cause an unlimited attack loop. Rubble instead
uses its observed health changes. Attack interval must be at most 1 second to
renew the lease. Focus/UI pauses do not consume recovery attempts or send input.
Pulse alternates press/release on the heartbeat, never catches up in bursts, and
uses the same focus/UI/lease cancellation. A valid current target stays locked
until unavailable; selecting the next candidate does not wait for a refresh
interval. MoveTo updates moving destinations more promptly. These changes do not
increase WalkSpeed, teleport, or add unsupported flying/hovering.

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
