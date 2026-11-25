# Bot playtest simulator: spec

Written 25/11/2026. Status: not started. Audience: the agent building it.

## Goal

Let bots play Asteroid Inc from a new game through to the end, in several **personas**, much faster than real time. Each run produces a save file whose `day_log` can be analysed for balance and progression across every tier.

Success means:
- One command runs N personas × M seeds unattended and leaves one JSON log per run.
- A Python report compares the personas tier by tier.
- With bot mode off, normal play is unchanged: same feel, same saves, no new UI.

## What already exists (reuse it)

- **Balance log.** `daylog_record()` in `scripts/scr_save/scr_save.gml` adds one record per day to `global.day_log`. Each record includes run, day, result, tier, haul, bank at the start and end of the day, accuracy, kills, damage taken by source, hull, bosses, damage and DPS per weapon, Overcharges, chart, conditions, perf, total upgrade levels and `bought_before`. `daylog_buy()` records each purchase. The log is saved in `asteroid_inc_save.json` (`SAVE_FILE` in `scr_config`) under `%LOCALAPPDATA%\Asteroid_Inc\`. **Don't build a second logger.** Add fields to the existing record only if the analysis needs them, and tag them with a `bot` / `persona` / `seed` field.
- **Logic runs per frame.** Wall-clock time (`current_time`) only appears in Draw events. Timers are frame counts derived from `game_get_speed(gamespeed_fps)`.
- **Collector auto-launch.** `global.stats.ship_ai` in `obj_game/Step_0.gml` already holds launch logic the bot can copy.
- **Firing is automatic.** The player only **aims** the active weapon (`_cursor = point_direction(x, y, mouse_x, mouse_y)` in `obj_station/Step_0.gml`). Passive weapons aim themselves. Check `laser_firing` to see whether the laser needs a held input.
- **Tree API:** `upg_can_buy(_u)`, `upg_cost(_u)`, `upg_affordable(_u)`, `upg_visible(_u)`, `upg_buy(_u)`, `upg_raises_tier(_u)`, `upg_level(id)`.
- **Exchange API:** `ex_goods()`, `ex_options(r)`, `ex_price(opt, qty)`, `ex_affordable(p)`, `ex_trade(r, qty, p)`.
- **Charts and surveys:** `survey_cycle(slot, dir)`, `slot_pick`, `slot_costs`, `survey_affordable`, `survey_commit` (in `scr_charts`).
- **Pirate reward:** `pirate_reward_options()`, `pirate_reward_apply(opt)`.
- **Debug hooks:** `DEBUG_KEYS` and the F-keys in `obj_game/Step_0.gml`. Leave them alone.

## Game flow the bot must drive

`rm_menu` → (New Game) `rm_game` day 1 with tutorial → `rm_tree` → (optional) `rm_exchange` → `rm_tree` → `launch_day()` → `rm_game` → … repeat.

`obj_game.state` goes from `"playing"` to `"recalling"` (time up, ships coming home) to `"over"` (results screen and the pirate reward pick). It goes to `"ending"` when the singularity triggers at `ENDING_TIME` (300 s into a day). Rooms change through `transition_to()` (`scr_juice`), which plays a screen wipe in `obj_post`.

Things that block progress and need the bot to act or skip them:
- The day-one tutorial (`global.tutorial`, `tut_day_*`) and the tree tutorial (`tut_tree_*`). The bot should start with `global.tutorial = 2`.
- Tips that pause the day (`tip_check` / `tip_step`, `TIP.*`) and the `ctip_*` chart tips. Suppress them in bot mode.
- The results screen click (`over_timer`) and the pirate reward pick.
- The ending click (`ENDING_CLICK_AT`).

## Every player input today (all must be routable to the bot)

| Input | Where | Effect |
|---|---|---|
| `mouse_x/y` | `obj_station/Step_0.gml` (~line 96, ~190) | active weapon aim, Tesla splash point |
| `mouse_x/y` | `obj_collector/Create_0.gml:17` | launch heading |
| `mouse_x/y` | `obj_flagship/Step_0.gml:38` | flagship reacts to the cursor |
| `mouse_x/y` | `scr_pirates` `missile_fire()` | missile target point |
| LMB pressed | `obj_game/Step_0.gml` ~155 | launch collector |
| Space / MMB | `obj_game/Step_0.gml` ~185 | Overcharge |
| RMB / R | `obj_game/Step_0.gml` ~190 + `missile_input()` | missiles or recall |
| Esc | `obj_game/Step_0.gml` ~214 | abandon day |
| LMB on results | `obj_game/Step_0.gml` ~253–258 | reward pick / continue to tree |
| Tree clicks | `obj_tree/Step_0.gml` ~85+ | buy, exchange, chart slots, weapon picker, launch |
| Exchange clicks/keys | `obj_exchange/Step_0.gml` | trade, back |

`obj_starfield` and `obj_post` cursor and visual reads don't need routing.

## Build plan

### 1. Bot mode and headless fast-forward

- **Launch config.** Read `parameter_string()` / `parameter_count()` (e.g. `--bot persona=economy seed=42 maxdays=400 out=run_economy_42`). Store it in `global.bot` (undefined when off). Bot mode only switches on with these command-line flags. Nothing in normal play should switch it on.
- **Decouple logic time from frame rate.** Add `#macro LOGIC_FPS 60` and replace the ~63 `game_get_speed(gamespeed_fps)` calls (28 files) used for seconds-to-frames maths. `daylog_record`'s `_fps` is one of them. **This replacement must be behaviour-neutral**: at 60 fps, normal play must be identical. Then in bot mode, call `game_set_speed(9999, gamespeed_fps)` (or the highest that holds up) so the game runs as fast as the CPU allows.
- **Headless.** In bot mode, call `draw_enable_drawing(false)`, mute audio (`audio_master_gain(0)` or skip `sfx`/music), make `transition_to` jump straight to `room_goto`, and skip screen shake and juice where it costs CPU. Leave a 1 Hz status line (`show_debug_message`) with day, tier and bank.
- **Separate save path per run.** In bot mode, `SAVE_FILE` becomes `bot/<out>.json` (make it a function or a global, not a macro). This keeps the player's real save safe. Never call `reset_save()` on the real file.
- **Reproducible.** Call `random_set_seed(seed)` at run start. Check whether anything calls `randomise()`. Same persona plus same seed should give the same log.

### 2. Input layer

Add `scr_input` with `input_aim_x()`, `input_aim_y()`, `input_launch()`, `input_overcharge()`, `input_missile_pressed()`, `input_missile_held()`, `input_recall()`. With bot mode off they return exactly what the current code reads. With bot mode on they return `global.bot` intent values set by the brain each step. Swap every row in the table above over to these. Menus, the tree and the exchange don't need the input layer: in bot mode, call the APIs directly and skip the UI.

### 3. Bot brain (in-day), `scr_bot` + a `obj_bot` controller (persistent)

Each step during `"playing"`:
- **Targeting.** Score asteroids, enemies, fighters, raiders, bosses and Cores by threat (distance and speed towards the station), value (resource tier and size) and persona weights. Re-target on a reaction timer, not every frame.
- **Aim.** Lead the target using the projectile speed of the active weapon. Add aim error (Gaussian jitter) and turn-rate limits from the persona's skill.
- **Collectors.** Launch towards the best loose loot when a slot is free (copy the `ship_ai` logic). Recall when the hull is low or a threat is near.
- **Overcharge.** Use it by policy: when ready, when the hull is low, or held for bosses.
- **Missiles.** Aim at clusters or bosses when ammo is available.
- **Results screen.** Pick the pirate reward by persona, then continue.

### 4. Between days, in `rm_tree` (bot calls the APIs, no clicks)

- **Buy loop.** Repeatedly pick the best affordable visible upgrade by the persona's scoring until nothing worth buying is affordable, then save.
- **Exchange.** Optionally convert surplus by persona rules.
- **Charts/surveys.** Pick slots by persona, `survey_commit()`, then choose the active weapon.
- Then `launch_day()`.
- **Stop when** the singularity ending is reached, `maxdays` is hit, or the run stalls (no tier change in K days; log it as `"stalled"`). Write a final summary record, then `game_end()`.

### 5. Personas (data, not code branches)

A persona is a struct of weights and skill parameters in `scr_bot_personas`:

- **Skill:** reaction frames, aim jitter (degrees), lead accuracy, Overcharge policy.
- **Buy priorities:** weights by node group (economy/collectors, weapons, defence/hull, utility/time, prospecting/tier unlocks). Also a saving style: greedy-cheapest, or saving for the next tier unlock.
- **Risk:** recall threshold, whether it buys charts, and which pirate reward it prefers.

Starting set:

| Persona | Notes |
|---|---|
| `average` | calibrated to the developer's own `day_log` accuracy |
| `novice` | slow reaction, high jitter, greedy-cheapest |
| `economist` | collectors, cargo and prospecting first |
| `gunner` | weapons first |
| `turtle` | hull and defence first |
| `rusher` | buys tier unlocks the moment they're affordable |
| `tree_order` | buys in Tech Tree.drawio layout order |

**Calibration:** before trusting any results, run `average` and adjust jitter and reaction until its accuracy and haul in tier 1 roughly match the real save's `day_log`.

### 6. Runner and analysis (Python, in `../tools/`)

- `run_bots.py`: launch the built exe (`Asteroid Inc.exe`, or a YYC build for speed) with `--bot` args, several processes at once. Collect each `bot/<out>.json` into `bot_runs/<date>/`.
- `analyse_bots.py`: load every `day_log` and output a single HTML or Markdown report covering, per persona:
  - days and real seconds per tier
  - bank and haul curves
  - death or abandon rate by tier
  - accuracy and DPS by weapon
  - the first day each node was bought, and nodes never bought
  - day length versus `base_secs`
  - stall points
  - spread across seeds
- Python only, reading JSON. No game data is personal data, so there are no GDPR concerns.

## Constraints

- **Normal play must not change.** Gate everything behind `global.bot`. Confirm the 60 fps refactor is neutral by playing a day before and after, and by comparing a seeded bot run before and after.
- Follow the project's sprite-driven visuals rule only if you add visuals. You shouldn't need to.
- The project isn't under git. Make a backup or run `git init` before starting step 1.
- Don't invent balance conclusions. The report presents data; the developer decides.

## Open questions for the developer

1. What `maxdays` cap is sensible? How many days does a real full run take?
2. Should bots ever use New Game+ (`new_game_plus()`), or only fresh runs?
3. Should the exchange be in scope for v1, or left out?
4. Which personas matter most if time is short?

## Suggested phases

- **Phase 1:** steps 1–2, a minimal brain (nearest-threat aim, auto-launch, greedy buys) and `run_bots.py`. You get usable logs at the end of this phase.
- **Phase 2:** full brain, all personas, calibration, `analyse_bots.py` report.
