# Grid Arena — project guide for Claude

Grid-based real-time battle arena prototype in **Godot 4.7 / GDScript**.
Two sides fight on a shared tile grid; the player moves tile to tile, uses a
basic attack, and plays cards drawn from a deck. Combat pauses for **Focus**,
where the player picks which cards to queue next.

## Game vocabulary

Use these terms in code, comments, and conversation.

| Term | Meaning |
|---|---|
| **Field** | The 7×4 battle grid. `GridModel`, `Vector2i(column, row)`, (0,0) top-left. |
| **Side** | A combatant is `GridModel.Side.PLAYER` or `ENEMY`. Tiles can also be `NEUTRAL`. Default layout: columns 0–2 player (blue), column 3 neutral (gray, `NEUTRAL_COLUMN`), columns 4–6 enemy (red). |
| **Neutral column** | Either side may move onto a neutral tile, but not through it onto the other side's tiles. |
| **Tile ownership** | Each tile belongs to a side or is neutral. Combatants may stand on their own side's tiles and on neutral tiles. Ownership is per-tile so it can change mid-battle. |
| **Occupancy** | Every tile, neutral included, holds at most one combatant. A tile frees up when its occupant moves off or dies (dead combatants are removed from the grid). Nothing pushes occupants yet. |
| **Facing / forward** | Player faces +x, enemies face −x. Card patterns are written for the player and mirrored automatically. |
| **Combatant** | Anything on a tile with HP (player, enemies, later obstacles). |
| **Card** | A `CardData` resource in `data/cards/`. Has damage, a targeting mode (`TILES` pattern, `ROW_FIRST_HIT` projectile, `AIMED` at the nearest opponent's tile), and a tile pattern. |
| **Enemy** | An `EnemyData` resource in `data/enemies/`: HP, a movement style (`STATIONARY`, `WANDER`, `TRACK_ROW`), and an attack (a `CardData` in `data/enemy_attacks/`). Placed by `BattleConfig.enemy_spawns`. |
| **Enemy brain** | `EnemyBrain`, one per spawned enemy, stepped by `BattleState` in spawn order. It uses its own seeded RNG stream, separate from the deck's. |
| **Wind-up / telegraph** | Before an enemy attack lands, its target tiles are shown for `attack_windup_ticks`. The enemy doesn't move while winding up. Area and aimed attacks hit the telegraphed tiles, so stepping off them dodges. Projectiles hit whoever is in the row when they fire. |
| **Deck / draw pile / hand / discard pile** | `Deck`. Hand refills to `hand_size` when Focus opens. The discard pile is recycled into the draw pile when it runs out. |
| **Queue** | Cards chosen during Focus, used front-first during combat. Unused cards carry over and trigger before new picks. The in-battle **Next widget** shows the front card, or "Empty". |
| **Focus** | `BattleState.Phase.FOCUS`: combat is paused (simulation does not step) and the Focus screen shows the hand. The player picks up to `max_cards_per_focus` cards; the order picked is the order they trigger. Battles start in Focus. Formerly called "planning". |
| **Focus gauge** | `FocusGauge`. Fills during combat. When it is full, the player may enter Focus. |
| **Reshuffle** | During Focus only: return the hand to the draw pile, shuffle, and draw a new hand. Limited by `reshuffles_per_battle` (−1 = unlimited). |
| **Tick** | One fixed simulation step (60/s). All gameplay timing is counted in ticks. |

## Architecture rules

1. **Rules live in `scripts/core/`, not in nodes.** Core classes are
   `RefCounted`/`Resource` with no node or rendering dependencies, so tests
   can run them headless. `BattleState` is the single owner of battle state.
2. **Nodes in `scripts/battle/` are thin.** `battle.gd` maps input to
   `BattleState` calls and steps it from `_physics_process`. `grid_view.gd`
   only reads state and draws. Views never change state.
3. **Fixed ticks, never frame delta, for gameplay.** Cooldowns, gauges and
   durations are integer tick counts. `delta` is only for cosmetic animation.
4. **Deterministic.** All gameplay randomness goes through the seeded RNG
   (`BattleConfig.rng_seed`; `Deck` uses its own `RandomNumberGenerator`).
   Never use `randi()`, `randf()` or `Array.shuffle()` in gameplay code.
   Same seed + same inputs must produce the same battle (see
   `tests/unit/test_replay_determinism.gd`).
5. **Content is data.** New cards are new `.tres` files in `data/cards/`,
   with the file name equal to `id`. Tunables go in `BattleConfig`
   (`data/battle_config_default.tres`), not as magic numbers.
6. **Static typing everywhere.** Typed vars, params, returns and typed
   arrays (`Array[CardData]`). Use `class_name` for core types.
7. **Placeholder art** (`draw_rect`, `draw_circle`) until visuals are a
   focus. Don't add asset pipelines unasked.

## Layout

```
project.godot                  input map, 640x360 canvas_items stretch, 60 physics ticks
scenes/battle/battle.tscn      main scene (Battle -> GridView, Hud/{StatusBar, NextCard, FocusPanel, KeyHints})
scripts/core/                  pure rules: grid_model, combatant, card_data, card_resolver,
                               deck, focus_gauge, battle_config, battle_state,
                               enemy_data, enemy_spawn, enemy_brain
scripts/battle/                nodes: battle.gd (input + stepping), grid_view.gd (drawing)
scripts/ui/                    focus_menu.gd (pure cursor/pick logic, unit-tested),
                               focus_panel / next_card_widget / status_bar (read-only
                               views), card_art.gd (shared placeholder card drawing)
data/cards/*.tres              player card definitions
data/enemies/*.tres            enemy definitions (training_dummy, gunner, lobber)
data/enemy_attacks/*.tres      enemy attacks (CardData, not deckable)
data/battle_config_default.tres  default tunables, starter deck, enemy spawns
tests/framework/               TestCase base class + Fixtures builders
tests/unit/                    headless tests of scripts/core and data
tests/integration/             scene smoke tests driven through InputMap actions
tools/run_tests.sh             runs everything; used by hooks and CI
docs/TESTING_PLAN.md           what we test, when, and how
```

## Controls (input actions)

Two action buttons, placed on the two bottom numpad keys:

| Action | Keys | In battle | In Focus |
|---|---|---|---|
| `button_a` (A) | `0`, numpad `0` | Use the next queued card | Pick/unpick the highlighted card, or press the highlighted button (Reshuffle / OK) |
| `button_b` (B) | `.`, numpad `.` | Basic attack | Undo the last pick |
| `move_up/down/left/right` | WASD, arrows | Move | Move the cursor (up/down switches between cards and buttons) |
| `open_focus` | Space, Enter, numpad Enter | Enter Focus when the gauge is full | Confirm (same as OK) |
| `reshuffle` | R | — | Reshuffle (same as the button) |

Key hints are shown in a bar at the bottom of the screen and change with the phase.

## Workflow

- **Run tests:** `tools/run_tests.sh` (optionally `--filter=deck`). Needs
  Godot on PATH or `GODOT_BIN`/`GODOT_PATH` set. Exit code 0 = green.
- **Every gameplay change gets a test.** Rules → a unit test against
  `BattleState`/core classes with `Fixtures.config()`. Input or scene wiring
  → `tests/integration/`. New card → `test_game_data.gd` already covers it.
  Bug fix → a test that fails before the fix.
- Tests are `extends TestCase`, files `test_*.gd`, methods `test_*`. Use
  `Fixtures` (`config()`, `card()`, `enemy()`) instead of depending on
  tuned values in `res://data`.
- Integration tests run the real scene with a **random seed** (it's printed
  as "Battle started with seed N"). Their assertions must hold for every
  seed: check "did X ever happen", not "is the end state different", because
  random movement can return to where it started. To debug a CI failure,
  replay the logged seed through `BattleState`.
- GDScript lambdas capture locals **by value**: collect results into an
  Array, not a bool. Don't capture an object inside a lambda connected to
  that object's own signal: it creates a reference cycle, and the runner
  fails on the resulting leak report.
- After editing, use the **godot MCP** to run the project and check the
  debug output for errors and warnings.
- A Stop hook (`.claude/settings.json`) runs the suite when game files
  changed and reports failures back. Don't end a task with a red suite.
- New `class_name` scripts need an import pass before headless runs;
  `tools/run_tests.sh` does this. Commit the generated `*.gd.uid` files.

## Open design questions (ask before deciding)

- Enemy roster and behaviours beyond the first three, and whether enemies
  should coordinate (e.g. not wind up at the same time). Current defaults:
  every enemy attack is telegraphed, and there are no invincibility frames after a hit.
- Whether Focus can also be opened at will, at a cost, or only when the gauge is full.
- Whether unused queued cards carry over across Focus rounds (currently they do).
- Tile-ownership mechanics (stealing or cracking tiles), pushing combatants
  off tiles (planned for later), and status effects.
- Card cost/energy, card rarity, and deck-building between battles.
