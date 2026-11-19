# PROJECT_AUDIT.md — "The Last New Year" (LastNewYear)

**Audit date:** 2026-11-19
**Audited snapshot:** git `main` @ `37c74fa` (2026-11-17, "Notes, safe keypad, workshop bolt door, new main menu…"), working tree clean (no uncommitted changes).
> **Note (after Step 0):** this audit describes the code *before* the Step 0 refactor. File paths here are the old ones (`game/…`, `level/…`, `maniac/…`, root `player.*`, `world.tscn`, `main_menu.*`), and bugs B1, B2, B3, B6, A1, A2, A3 (toggles + HUD split), A6 (FaceAnchor, inline Ogg), A8 and A10 are fixed. The current layout and status are in `CLAUDE.md` §3–§6 and §12.

**Engine used for verification:** official Godot **4.7.2.stable** Linux build (`4.7.2.stable.official.ed1daf0bf`), run headless on a *copy* of the project. No game file in the delivered project was modified.

---

## 0. How this audit was done

1. Every `.gd` script (20 files, 2,521 lines) was read in full.
2. Every `.tscn` was inspected: small scenes in full; `level/level.tscn` (2,700+ lines, 548 nodes) was parsed with a script that dumped the node tree, scripts, groups and exported properties, and all key nodes were then read directly.
3. `project.godot`, `.gitignore`, `.gitattributes`, `.editorconfig`, all `.import` files and the git history (7 commits) were read.
4. The project was opened headless in Godot 4.7.2 (`--editor --quit`) to import it and surface load errors.
5. Every script was compiled with **all default-on GDScript warnings promoted to errors** to list real warnings.
6. Each scene was run headless (`main_menu`, `world`, `ritual`, `game_over`).
7. A throw-away probe scene was run inside the copy to check runtime facts: group registration, maniac activation, navigation, chase and catch.

**Not inspectable / not verifiable:**
- Binary audio content (`.wav`, `.ogg`, `.aup4`) was only measured (size, duration, references), not listened to.
- Visual quality, lighting mood, frame rate and feel. Headless mode has no renderer, so anything visual or performance-related is marked UNKNOWN.
- `.godot/` (local editor cache, git-ignored) was not analysed beyond confirming it is a cache.
- The nested `last-new-year/` folder (§2.2) was compared to the git history but not audited as live code, because Godot ignores it.

---

## 1. Executive summary

The project is **much further along than the brief describes**. Besides the menu, the player, the world and the house, it contains a **complete, playable stealth/escape loop**:

> Arrive on foot next to the car (the tank is empty) → enter the house → the front door slams and locks → after 25 s a masked stalker ("the Keeper"/"маньяк") starts hunting with navmesh AI, sight, hearing and wardrobe checks → find 4 children's drawings → open the father's safe (code **4817**) → basement key → petrol canister in the boiler room → crowbar in the workshop → pry the boards off the back door → refuel the car → **dead end**: "the final scene is the next step" (`game/car.gd:15`).

There is also lore (8 notes) that already sets up the planned ending: a cult ("ЖАТВА ГРЕХОВ", the Harvest of Sins) has taken the other seven members of the Lone family, and the protagonist (Heathcliff, "Хит") must be "at the stone, alive, by the last hour".

**Overall code quality is good for a prototype.** The scripts are small, commented (in Russian), and use a consistent duck-typed interaction protocol. Under Godot 4.7.2 there are **no compile errors** and only **3 warnings**. The maniac AI was verified at runtime: it activates on schedule, navigates stairs and catches the player.

**The main risks for the next stage** are not crashes. They are **missing foundations** that the planned cinematics depend on:

1. There is no way to take control away from the player cleanly. Player state is set from other scripts through string metadata and `set_physics_process(false)`.
2. All input is hardcoded to keycodes. There are no InputMap actions.
3. There is no cutscene, camera-switching or scene-transition infrastructure.
4. Gameplay, HUD and story state all live in one node (`game/game.gd`) inside `level/level.tscn`.
5. There is repository hygiene debt: a stale nested copy of the project, a 66 MB Audacity project in git, and unused raw WAVs.

**Verdict:** keep the existing systems. The plan in `DEVELOPMENT_ROADMAP.md` has three steps: **Step 0** cleanup, refactoring, structure and architecture (including the cutscene framework); **Step 1** the car, driving, the road and the exit from the car; **Step 2** the capture at the car and the ritual ending.

---

## 2. Project structure (actual)

### 2.1 Tracked files (excluding `.uid`/`.import` sidecars)

```
project.godot                 Engine config (autoload Settings, Jolt, Forward+, D3D12 on Windows)
icon.svg
main_menu.tscn / .gd          Main scene (run/main_scene = uid://b3slmqio8150c)
world.tscn                    Gameplay root: ground, Player, WorldEnvironment, Level, wind ambience
player.tscn / .gd             First-person CharacterBody3D
game/
  game.gd                     Central "Game" node: interaction raycast, inventory, flags, HUD, objectives
  settings.gd                 Autoload "Settings" (sensitivity, volume, fullscreen; user://settings.cfg)
  settings_panel.gd           Settings UI block (used by main menu and pause menu)
  ui_style.gd                 class_name UIStyle: palette, fonts, button/box helpers
  pause_menu.gd               Esc pause menu (built in code)
  note_window.gd              Note/letter/drawing reader (built in code)
  keypad_window.gd            4-digit safe keypad (built in code)
  door.gd                     Hinged door: open/close, lock+key, slam, bolt-trap for the maniac
  front_door_trigger.gd       Area3D: slams and locks the front door on entry
  pickup.gd                   Item pickup
  safe.gd                     Father's safe (code, reward, letter)
  boards.gd                   Boarded back door (needs crowbar)
  car.gd                      Car interaction (refuel; ending placeholder)
  note.gd                     Readable note / drawing
level/
  level.tscn                  House + exterior + interactables + Game node + Maniac + Notes + NavMesh
  tree.tscn                   Primitive pine (2 cones + trunk + collider), instanced 180×
  ritual.tscn                 Static ritual diorama (UNREFERENCED, no script)
  flicker_light.gd            Random-energy OmniLight3D flicker
  hide_spot.gd                Wardrobe hiding spot (CSGBox3D)
  flat.gdshader               Flat-shading shader (UNREFERENCED)
maniac/
  maniac.tscn / .gd           Stalker AI (CharacterBody3D + NavigationAgent3D), primitive model
  game_over.tscn / .gd        "ТЕБЯ ЗАБРАЛИ…" screen (Retry / Menu)
  jumpscare.wav
audio/
  winter wind.ogg             Ambient (5 min 36 s), autoplay in world.tscn
  footstep_hero.ogg           Referenced by player.tscn but never played
  footstep_maniac.ogg         Unreferenced (maniac.tscn embeds its own inline Ogg stream)
  613849__…snow_walk_mono.wav, 835154__…wood-creaky…wav, 837389__…robot-footsteps.wav   Unreferenced (≈11 MB)
  winter wind home.aup4       Audacity project, 66 MB, unreferenced
ui/fonts/                     Amatic SC Bold, Caveat (+ OFL licence texts)
last-new-year/                STALE nested copy of the project (see 2.2)
```

There are **no addons, no `.tres` resource files, no `export_presets.cfg`, no `default_bus_layout.tres`, no `[input]` section, and no tests.**

### 2.2 The nested `last-new-year/` folder — stale duplicate (Critical hygiene issue)

- It was added to git in commit `503ecd3` ("Level v4") and is still tracked (26 files). It is a **byte-identical snapshot of the project at `503ecd3`**: `main_menu.gd`, `player.gd`, `hide_spot.gd` and `maniac.gd` match that commit's blobs exactly. It has its own `project.godot`.
- Godot 4.7.2 prints `WARNING: Detected another project.godot at res://last-new-year. The folder will be ignored.` So it does **not** break the game today.
- **Why it matters:** its `.uid` files duplicate the live ones (`uid://da40o14lx3pi`, `uid://djogpoq6am727`). Every text search (and every AI agent) finds two versions of `player.gd`, `maniac.gd`, `level.tscn` and so on, and the stale one is an older, simpler version. If someone deletes the nested `project.godot`, Godot will start importing duplicate UIDs and scripts. **Recommendation:** `git rm -r last-new-year/` in a dedicated commit. Nothing references it.

### 2.3 Repository weight

`.git` pack = 67 MB, `audio/` = 81 MB. Most of this is `audio/winter wind home.aup4` (66 MB, an editor source file) and three raw freesound WAVs (≈11 MB) that nothing uses. Git history already contains them, so removing them only stops further growth. Recommend moving source/raw audio out of the repo, or into a git-ignored `_source/` folder (or Git LFS if the team wants them versioned).

---

## 3. Configuration (`project.godot`)

| Setting | Value | Notes |
|---|---|---|
| `config/features` | `"4.7", "Forward Plus"` | Matches the stated Godot 4.7.x. |
| `run/main_scene` | `uid://b3slmqio8150c` → `main_menu.tscn` | OK. |
| Autoload | `Settings="*res://game/settings.gd"` | The only singleton. |
| Physics | `3d/physics_engine="Jolt Physics"` | Fine. Characters use `CharacterBody3D`. |
| Navigation | `3d/default_cell_size/height = 0.1` | Matches the baked NavigationMesh. |
| Rendering | `rendering_device/driver.windows="d3d12"` | Development is on Windows (the shader cache is D3D12). |
| Display | stretch `canvas_items` / `expand` | OK for code-built UI. |
| **Input map** | **none** | All input is hardcoded keycodes (§6.2). |
| Audio buses | **none** (Master only) | The volume setting is global. There are no SFX/Music/Ambience buses. |

---

## 4. Scenes, dependencies and runtime contracts

### 4.1 Scene flow

```
main_menu.tscn ──Play (fade 0.8 s)──► world.tscn ──maniac catches player──► maniac/game_over.tscn
      ▲                                  │  ▲                                   │ Retry → world.tscn
      └─────── Pause ▸ "Выйти в меню" ───┘  └───────────────────────────────────┘ Menu  → main_menu.tscn

level/ritual.tscn  — not referenced by anything (only mentioned in a comment in game/car.gd:3)
```

All transitions use `get_tree().change_scene_to_file()` with hardcoded paths, in 5 places: `main_menu.gd:53`, `pause_menu.gd:50`, `game_over.gd:19-20`, `maniac.gd:662`. Only the main menu fades.

### 4.2 Scene composition

```
world.tscn (Node3D "World")
├─ CSGBox3D (100×0.2×100 ground)  └─ BasementHole (subtract, hardcoded at x=6, z=-22 to match the house)
├─ Player        (instance player.tscn)  spawn (0, 1.26, 0)
├─ WorldEnvironment (dark blue ambient, fog 0.05)
├─ Level         (instance level/level.tscn) at y=0.1
└─ AudioStreamPlayer ("winter wind.ogg", autoplay, -10 dB)

level/level.tscn (Node3D "Level")   — 548 nodes, 202 CSGBox3D, 180 tree instances
├─ Moon (DirectionalLight3D, 0.15, shadows)
├─ Exterior
│   ├─ Path      (CSGBox 2.4 × 12.9 m footpath from spawn toward the porch) — NOT a road
│   ├─ Car       (CSGCombiner3D: Body, Cabin, 4× CSGCylinder wheels; script game/car.gd) at (4, 0, 1)
│   ├─ MapBorder (4 invisible box walls at ±49.5 m)
│   └─ Forest    (180 × tree.tscn)
├─ House (group "nav_source") at z = -22
│   ├─ Structure  — basement, ground floor, upper floor, 3 staircases with ramp colliders,
│   │               window holes + glass, boarded ground-floor windows (CSG blockout)
│   ├─ Rooms_F1   — LivingRoom (fireplace, flicker light, Christmas tree), DiningRoom, Kitchen,
│   │               Study (Safe, code "4817"), Pantry, Workshop (Crowbar)
│   ├─ Rooms_F2   — Corridor, ParentsBedroom, KidsRoom, GrandparentsRoom, SisterRoom, Bathroom,
│   │               LinenRoom; 5 × HideSpot_Wardrobe in total
│   ├─ Rooms_B    — BasementCorridor, BoilerRoom (Canister), Storage, SecretRoom (Altar, candles)
│   └─ PatrolPoints — 20 Marker3D (group patrol_point; 4 also in patrol_basement)
├─ Navigation (NavigationRegion3D, pre-baked mesh, bake AABB = house only)
├─ Interactive — FrontDoor (door.gd), FrontDoorTrigger, BasementDoor (locked, key basement_key),
│                BackDoorBoards (boards.gd), WorkshopDoor (door.gd with bolt), WorkshopRoom (Area3D)
├─ Game (Node, game/game.gd)
├─ Maniac (instance maniac.tscn) spawn (-0.8, 3.65, -24) on the upper floor
└─ Notes — 8 notes + 4 drawings (note.gd)
```

### 4.3 Script dependency graph

```
main_menu.gd ─► UIStyle, game/settings_panel.gd ─► Settings (autoload)
player.gd ─► Settings
game/game.gd ─preload─► level/hide_spot.gd, game/pause_menu.gd, game/note_window.gd, game/keypad_window.gd
             ─uses────► UIStyle (via windows)
pause_menu.gd ─preload─► settings_panel.gd
door.gd ◄──► maniac.gd   (door asks maniac state for the bolt trap; maniac calls door.break_open/set_open)
hide_spot.gd ◄──► maniac.gd (on_player_hid / open_doors / close_doors / front_point)
hide_spot.gd ─► player (writes metadata, disables physics, moves the player)
maniac.gd ─► player (reads metadata/noise_radius/flashlight; writes "dead" meta; drives the jumpscare camera)
maniac.gd ─► game_over.tscn (by path)
```

### 4.4 Implicit runtime contracts (stringly-typed; break silently if renamed)

| Kind | Name | Written by | Read by |
|---|---|---|---|
| Group | `player` | player.gd | game, maniac, pause_menu, front_door_trigger |
| Group | `game` | game.gd | maniac, door, front_door_trigger |
| Group | `maniac` | maniac.gd | door, hide_spot |
| Group | `door` | door.gd | maniac (auto-opens doors) |
| Group | `hide_spot` | hide_spot.gd | maniac |
| Group | `patrol_point`, `patrol_basement` | level.tscn | maniac |
| Group | `note_drawing` | note.gd (in `_ready`) | game.gd (**see bug B1**) |
| Group | `nav_source` | level.tscn (House) | NavigationMesh bake |
| Node path | `Head`, `Head/Camera3D`, `Head/Camera3D/Flashlight`, `CollisionShape3D` | player.tscn | game, hide_spot, maniac |
| Metadata | `dead`, `hidden`, `hide_spot_node` | hide_spot, maniac | player, game, pause_menu, maniac |
| Static var | `HideSpot.hidden_in` | hide_spot.gd | game.gd (reset manually in `game._ready`) |
| Interaction protocol | `get_prompt(game) -> String`, `interact(game)` | 8 scripts | game.gd raycast walks up parents |
| Flags | `front_locked`, `safe_seen`, `safe_open`, `basement_open`, `boards_removed`, `car_fueled` | various | game.gd objectives, maniac (`front_locked`, `basement_open`) |
| Items | `crowbar`, `basement_key`, `canister` | pickup.gd / safe.gd | door, boards, car |

---

## 5. Inventory of functionality

Legend: **IMPLEMENTED**, **PARTIAL** (partially implemented), **PLACEHOLDER**, **NOT IMPLEMENTED**, **UNKNOWN**.

| System | Status | Evidence / notes |
|---|---|---|
| Main menu | IMPLEMENTED | `main_menu.tscn/.gd`: code-drawn house silhouette with flickering window, snow particles, vignette, fade-in/out, Play/Settings/Exit, embedded settings panel. Runs headless with no errors. |
| Settings (autoload) | IMPLEMENTED | Mouse sensitivity, master volume, fullscreen (F11), saved to `user://settings.cfg`. The game **starts fullscreen by default**. |
| Pause menu | IMPLEMENTED | Esc; Continue / Settings / Exit to menu; blocked during the jumpscare. |
| Player controller | IMPLEMENTED | Walk 4 / sprint 6.5 (forward only, stamina with exhaustion) / crouch 2 (capsule resize + ceiling check) / jump / flashlight F / head bob / `noise_radius` for AI hearing. |
| Player footsteps audio | PARTIAL | `player.tscn` has a `Footsteps` AudioStreamPlayer with `footstep_hero.ogg`, but **no script ever plays it**. |
| Input mapping | NOT IMPLEMENTED | No InputMap actions. Keys are hardcoded (§6.2). No gamepad. |
| Interaction system | IMPLEMENTED | 2.3 m camera raycast; finds the first ancestor with `interact`+`get_prompt`; HUD prompt; E key. |
| Inventory & story flags | IMPLEMENTED (minimal) | Dictionaries in `game.gd`; inventory shown as a text line. |
| Objectives HUD | IMPLEMENTED | Hardcoded `if/elif` chain in `game.gd:_update_objective` (8 states). |
| HUD | IMPLEMENTED | Built in code: crosshair, prompt, message, inventory, objective, stamina bar. |
| Notes / letters / drawings | IMPLEMENTED | 8 notes + 4 drawings with procedural crayon art; the game pauses while reading. |
| Safe keypad puzzle | IMPLEMENTED | Code 4817 from drawings red 4 / green 8 / blue 1 / yellow 7; mouse + keyboard; shake on a wrong code. |
| Doors | IMPLEMENTED | Hinged tween doors, lock + key + unlock flag, front-door slam, workshop bolt that traps the maniac for 15 s. |
| Boarded back door | IMPLEMENTED | Needs the crowbar; removes the blocker. |
| Hiding (wardrobes) | IMPLEMENTED | 5 wardrobes; the view is through a slit, yaw locked, pitch ±20°; the maniac can open and check them. |
| Maniac / "Keeper" AI | IMPLEMENTED | 6 states (PATROL, INVESTIGATE, CHASE, SEARCH, CHECK_HIDE, TRAPPED), FOV + raycast sight, longer sight range with the flashlight on, noise hearing, stuck recovery, give-up, auto-opens doors, avoids the basement until it is unlocked. **Verified headless:** it activated after the delay, reached the player on another floor and triggered the catch in ~5 s. |
| Maniac model | PLACEHOLDER | Capsule robe, cone hood, box mask and eyes. |
| Jumpscare + game over | IMPLEMENTED | Lunge, camera shake, red flash, sound, fade → `game_over.tscn` (Retry / Menu). |
| Navigation | IMPLEMENTED | Pre-baked NavigationMesh covering **only the house**. Must be re-baked after any house geometry change. |
| House | IMPLEMENTED as **PLACEHOLDER geometry** | Full 3-level CSG blockout, 17 named rooms plus halls, stairs, windows, furniture boxes. Gameplay-complete. Art is placeholder. |
| Exterior / environment | PARTIAL | 100×100 m snow ground, 180 primitive trees, invisible border, moon light, fog, wind ambience, short footpath. |
| Road to the house | NOT IMPLEMENTED | Confirmed. Only the 12.9 m footpath strip exists. |
| Car | PLACEHOLDER (visual) + IMPLEMENTED (interaction) | `CSGCombiner3D` of 2 boxes + 4 cylinders inside `level.tscn` (not its own scene). Refuel interaction works. It cannot move. |
| Vehicle mechanics | NOT IMPLEMENTED | No movement, path, lights or engine audio. |
| Ending / win state | NOT IMPLEMENTED | `car.gd:15` shows "…(финальная сцена — следующий шаг)". **The game cannot currently be finished.** |
| Ritual scene | PLACEHOLDER | `level/ritual.tscn`: 30×30 floor, altar, **7 pedestals**, **6 torches** (flicker, shadows), **5 static primitive cultists**, a `HeroPOV` camera, its own red environment. No script, no bonfire, unreferenced. |
| Cultist characters | NOT IMPLEMENTED (models); PLACEHOLDER (primitives) | Confirmed: no real models. There are 5 capsule+cone stand-ins in `ritual.tscn`. |
| Intro cinematic | NOT IMPLEMENTED | The game starts with the player standing next to the parked car. |
| Cutscene system | NOT IMPLEMENTED | — |
| Camera management | NOT IMPLEMENTED | A single player camera; the maniac script drives it directly during the jumpscare. |
| Scene transitions | PARTIAL | Raw `change_scene_to_file`; fade only in the main menu. |
| Audio management | PARTIAL | No buses; ambience does not loop (bug B2); hero footsteps unused. |
| Save / checkpoints | NOT IMPLEMENTED | Only settings are saved. Retry restarts the whole world. |
| Localization | NOT IMPLEMENTED | All UI and story text is hardcoded Russian (no `tr()`). |
| Character animation | NOT IMPLEMENTED | No AnimationPlayer or skeletons anywhere. |
| Export configuration | NOT IMPLEMENTED | No `export_presets.cfg`. |
| `flat.gdshader` | Unused asset | Not referenced by any scene or material. |
| Visual quality / performance on target PCs | UNKNOWN | Cannot be assessed headless. |

### 5.1 Verification of the "known project details" from the brief

| Claim | Result |
|---|---|
| A main menu scene exists | ✅ True (`main_menu.tscn`, the main scene). |
| A player character and controller exist | ✅ True, and more complete than implied (stamina, crouch, noise, flashlight). |
| A game world scene exists | ✅ True (`world.tscn` instancing `level/level.tscn`). |
| A house is present | ✅ True: a full 3-floor CSG blockout with gameplay inside. |
| The car is simple rectangular primitives | ✅ Essentially true: 2 boxes + **4 cylinders** (wheels), combined in a `CSGCombiner3D`. It already has a working refuel interaction. |
| No road to the house | ✅ True, but note that a 2.4 × 12.9 m **footpath** runs from the spawn/car toward the porch. |
| No actual cultist models | ✅ True. Primitive placeholder cultists exist in the unused `ritual.tscn` (5, not 10), and the maniac is also a primitive robed figure. |
| Final models/animations come later | ✅ Consistent: no imported models (`.glb`/`.fbx`) exist at all. |
| **Not mentioned in the brief** | The full stalker AI, hiding, notes, safe puzzle, item chain, game over, lore, pause/settings. Future work must preserve all of it. |

---

## 6. Technical audit — issues

Severity: **High** (fix before building on top of it), **Medium** (fix while working in that area), **Low** (nice to have).

### 6.1 Bugs found

**B1 — Drawing count works only by accident (Medium).** `game/game.gd:47-51` counts the `note_drawing` group in `_ready`. The notes add themselves to that group in their own `_ready`, and the `Notes` node comes *after* `Game` in `level.tscn`, so the count is always 0. *Verified:* an instrumented copy printed `counted drawings in _ready: 0`. The fallback `drawings_total = 4` hides this. Adding or removing a drawing will silently show "x из 4". Fix: count deferred (`call_deferred`), or put drawings in the group from the scene file.

**B2 — Ambient wind stops after 5 min 36 s (Medium).** `world.tscn` autoplays `audio/winter wind.ogg`, but its import has `loop=false`. After 336 s the world goes silent. Fix: set loop in the import settings.

**B3 — Hero footsteps never play (Low).** `player.tscn:30-31` defines `Footsteps`; `player.gd` never references it. Footstep sound was clearly intended.

**B4 — No ending (High, design).** Refuelling and "getting in the car" only shows a message (`game/car.gd:14-16`). Players reach a soft-lock state.

**B5 — Retry replays everything.** Retry reloads `world.tscn`. That is fine today, but once an intro cinematic exists, every death would replay it unless the intro can be skipped (needs state that survives the scene change).

**B6 — `pause_menu.gd` stores `_mouse_was_captured` but never uses it (Low).** `resume()` always captures the mouse.

**B7 — Exiting a wardrobe teleports without a free-space check (Low).** `hide_spot.gd:137` puts the player at `front_point(0.55)`, which can overlap the maniac standing at 0.9 m. Collision resolves it, but it may jitter.

**B8 — Exit-time leak warning (Low, likely benign).** Quitting from `world.tscn` reports 4 leaked objects and 2 resources, all belonging to the autoplaying `winter wind.ogg` stream. Probably shutdown order and not a gameplay problem, but worth re-checking once audio is reorganised.

### 6.2 GDScript warnings (Godot 4.7.2, default warning set)

There are no compile errors. With default-enabled warnings treated as errors, only:
- `game/game.gd:187` and `:192` — parameter `name` shadows `Node.name` (SHADOWED_VARIABLE_BASE_CLASS).
- `level/hide_spot.gd:79` — loop variable `sign` shadows the built-in `sign()` (SHADOWED_GLOBAL_IDENTIFIER).

These are trivial renames. Note that the "unsafe" and "untyped" warnings are off by default, and the code relies heavily on untyped duck-typing (`game` parameters, `player.get(...)`), which is acceptable at this size.

### 6.3 Architectural problems

**A1 — No player control API; state is pushed in from outside (High).** Three external scripts manipulate the player directly:
- `hide_spot.gd` sets metadata, calls `set_physics_process(false)`, disables the collider, moves and rotates the player and toggles the flashlight.
- `maniac.gd` sets `dead` and drives the camera's `h_offset`/`v_offset`.
- `game.gd` and `pause_menu.gd` read the metadata.

*Why it matters:* the intro needs to disable control, hide the player, and then enable control; the ending needs to remove control and move the camera. A third and fourth external script would each have to replicate this ad hoc. That leads to bugs such as the flashlight turning back on, the collision staying disabled, or the pause menu opening mid-cutscene. **Fix first:** give `player.gd` an explicit API (`set_control_enabled()`, `is_hidden`, `is_dead`, `get_camera()`, `get_flashlight()`), and migrate the current call sites to it without changing behaviour.

**A2 — Hardcoded input (High).** `player.gd:92-106,139,156` (WASD/arrows, Shift, Ctrl, Space), `player.gd:66` (F), `game.gd:123` (E), `pause_menu.gd:19` (Esc), `settings.gd:21` (F11), plus the note and keypad windows. *Why it matters:* cutscenes need a "skip" input; menus need consistent confirm/cancel; non-QWERTY layouts (e.g. AZERTY) break WASD because `Input.is_key_pressed` uses layout-dependent keycodes; there is no remapping and no gamepad. **Fix:** define InputMap actions with *physical* keys and use `Input.is_action_*`.

**A3 — `game.gd` is a god-node living inside the level (Medium).** One 302-line node owns the interaction raycast, inventory, flags, objectives text, HUD construction and window management, and it is a child of `level.tscn`. That is acceptable now. It becomes a problem when (a) a second scene such as the ritual needs a HUD/fade but not inventory, (b) cutscenes need to hide the HUD (no API exists), and (c) the objective chain grows. **Recommendation:** do not rewrite. Add `set_hud_visible(bool)` and `set_interaction_enabled(bool)` now; consider extracting the HUD into its own CanvasLayer script later.

**A4 — Story progression is an if/elif chain of string flags (Low → Medium).** It is fine for one linear chapter. Keep it, but keep flag and item ids in one documented place (they are listed in §4.4).

**A5 — The car is not a scene (Medium).** It is a CSGCombiner inside `level.tscn`. The intro needs a car that moves along a road, with lights, sound and camera anchors, and the art team will replace the model. **Extract it into its own scene** (`vehicle/car.tscn` or similar), keeping `car.gd`'s interaction.

**A6 — Hardcoded geometry coupling (Medium).**
- `world.tscn` cuts a basement hole in the ground at a fixed position (x=6, z=-22) that must match the house's basement. Moving the house breaks it.
- The maniac jumpscare positions the body using magic offsets `1.57` and `0.31` (`maniac.gd:649`) that match the placeholder Mask mesh. A real model will misalign. Add a `FaceAnchor` Marker3D to the maniac scene and use it.
- `maniac.tscn` defines the `Footsteps` stream as an **inline embedded Ogg** instead of referencing `audio/footstep_maniac.ogg`, so the file on disk is dead and edits to it have no effect.

**A7 — Global/static state that must be reset by hand (Low).** `HideSpot.hidden_in` is a `static var` that survives scene reloads. `game._ready` resets it. Any new entry point into `world.tscn` must remember to do the same.

**A8 — Scene files apparently written outside the editor (Low, but relevant for AI work).** `level.tscn`, `tree.tscn`, `ritual.tscn`, `game_over.tscn` have no `uid=` in their headers, and their references to each other are path-only. `main_menu.tscn` has no `unique_id`s. They load fine, but moving or renaming any file will break path-only references. When convenient, open and re-save these scenes in the editor (in a dedicated commit, because the diff will be large).

**A9 — The navmesh covers the house only (Note).** This is correct for the maniac. Anything that should path-find outdoors (it is not needed for the scripted cultists) would need its own region.

**A10 — Scene changes are scattered (Medium).** Five hardcoded `change_scene_to_file` calls, with a fade only in the menu. The intro → gameplay → ending → credits flow needs consistent fades. A tiny transition autoload solves this.

### 6.4 Code duplication

- `main_menu.gd:_style_button` (lines 64-77) duplicates `UIStyle.menu_button` almost line for line.
- `pause_menu.gd:_title/_label/_button` and `settings_panel.gd:_label` re-implement label and button styling that `UIStyle` partly covers. The pause menu also does not use the project fonts, so it looks different from the main menu.
- Player lookup (`group` → `find_child("Player")` fallback) is duplicated in `game.gd:56-63` and `maniac.gd:111-113`.
- Gravity lookup and `move_and_slide` boilerplate are duplicated between player and maniac (acceptable).
- Hardcoded node paths to the flashlight and camera appear in 3 scripts.

None of this justifies a rewrite. Consolidate opportunistically when touching those files.

### 6.5 Naming and organisation inconsistencies

- The antagonist is called **"Maniac"** in code and file names, **"Хранитель" (Keeper)** in comments and door UI, and "Он" in messages. Pick one term for docs (this audit uses "maniac/Keeper").
- Root-level `player.*`, `main_menu.*`, `world.tscn` versus folders `game/`, `level/`, `maniac/`. `game/` mixes systems (settings, UI windows) with level interactables (door, car, safe). Not urgent. A future layout could be `ui/`, `systems/`, `interactables/`, `characters/`. Do not move files casually (path-only references, §A8).
- File names are snake_case, node names PascalCase, ids lowercase snake: consistent.
- Code comments and all player-facing text are Russian; the git history is English.
- One node named generically: `World/CSGBox3D` (the ground).

### 6.6 Performance notes (UNKNOWN until profiled on target hardware)

- **CSG everywhere:** 202 `CSGBox3D` nodes plus 9 combiners with `use_collision`. CSG is a prototyping tool: meshes and collision are rebuilt on load and on any change. It is fine for the blockout. Before final art (or if load time or hitching appears), bake CSG to meshes and static colliders (the editor's CSG "Bake Mesh Instance" / "Bake Collision Shape" tools).
- **Forest:** 180 instances × 3 MeshInstance3D + a StaticBody3D each, so about 540 separate draw items. If profiling shows a draw-call cost, convert them to `MultiMeshInstance3D` (collision can stay as cheap shapes).
- **Shadowed lights:** 11 shadow-casting OmniLights in the house, plus the moon and the player flashlight. Omni shadows are the most expensive kind. Profile in the living room and corridor; consider disabling shadows on small fill lights.
- **Main menu** redraws the house silhouette every frame for the window flicker. Trivial cost.
- **Settings** writes `settings.cfg` on every slider tick while dragging. Trivial, but easy to debounce.
- The maniac does one raycast per physics frame plus a door scan every 0.2 s. Fine.

### 6.7 Systems to refactor **before** adding features

All of these are part of **Step 0** in `DEVELOPMENT_ROADMAP.md`:
1. Remove the nested `last-new-year/` copy; set loop on the wind; fix the warnings and bug B1 (Step 0.1).
2. Re-save the scenes in the editor so every reference uses UIDs, then move files into a clear folder layout (Steps 0.1 and 0.2).
3. InputMap actions (A2), the player control API (A1), the HUD split with HUD/interaction toggles (A3), and the scene transition helper with session flags (A10, B5) (Step 0.3).
4. Separate the maniac model with a `FaceAnchor` (A6) (Step 0.3), and the cutscene framework (Step 0.4).

The car scene (A5) is built in Step 1. HUD polish, CSG baking and MultiMesh are optional polish after Step 2.

## 7. Narrative facts already in the data (useful for the cinematics)

Taken from note texts in `level/level.tscn` and `maniac/game_over.gd`:
- The protagonist is **Heathcliff "Хит" Lone**, estranged son, returning on **31 December** alone (the courier's note on the receipt).
- The car ran out of petrol "right by the house" (`car.gd:22`). This fits the planned intro: the car slowing and the engine dying can be the fuel running out.
- The cult ("ЖАТВА ГРЕХОВ") took **seven** family members before sunset. **Seven pedestals** in `ritual.tscn` likely represent them.
- The Keeper's orders: do not harm him in the house; let him run; "there is no road out of the valley"; he must be **at the stone, alive, by the last hour**. Game-over text: "Он не убивает в доме. Ты нужен ему живым — к полуночи, у камня."
- `car.gd:3` records the intended ending trigger: the killer in the back seat → `ritual.tscn`.
- The house has a secret basement room with an altar and the Keeper's note.

**How the roadmap resolves these** (decisions taken with the owner; see `DEVELOPMENT_ROADMAP.md` → "Decisions"):
1. Being caught **inside the house** keeps the current game-over / retry flow. The ending starts with a **scripted capture at the car** after refuelling.
2. The capture at the car (the Keeper appears, e.g. in the back seat, as `car.gd:3` intends) is the trigger for the final cinematic.
3. "The stone" is the separate ritual scene (`ritual.tscn`, upgraded), not a location in the world map.

## 8. Summary scorecard

| Area | State |
|---|---|
| Code health | Good (0 errors, 3 trivial warnings, readable, commented) |
| Gameplay loop | Playable until the ending |
| Foundations for cinematics | Missing (control API, input actions, cameras, transitions) |
| Art | 100 % placeholder (CSG and primitives) — expected |
| Audio | Basic; ambience bug; no buses |
| Repo hygiene | Needs cleanup (nested copy, 77 MB of unused source audio) |
| Tooling | None (no tests, no export presets); headless Godot verification works and is documented in CLAUDE.md |
