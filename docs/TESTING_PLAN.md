# Testing Plan

The goal is that every design change and every commit gets checked
automatically, and that a rule change can't break the game without a test
going red.

## 1. Principles

- **Test the rules, not the pixels.** Gameplay lives in `scripts/core/`
  (no nodes), so most tests are fast, headless unit tests. Scenes get a thin
  layer of smoke tests.
- **Determinism makes tests reliable.** Fixed ticks plus a seeded RNG mean a
  battle can be replayed exactly. Tests should never depend on wall-clock time
  or unseeded randomness.
- **Tests use fixtures, not tuning.** `Fixtures.config()` builds a known
  config, so rebalancing `data/` doesn't break rule tests. Separate data tests
  check that the authored content itself is valid.
- **A bug fix starts with a failing test.**

## 2. Test layers

| Layer | Location | What it covers | Speed | Status |
|---|---|---|---|---|
| Unit: rules | `tests/unit/test_grid_model.gd`, `test_deck.gd`, `test_plan_gauge.gd`, `test_card_resolver.gd`, `test_battle_state.gd` | Grid bounds and ownership, movement, deck draw/discard/recycle/reshuffle, card conservation, targeting and mirroring, damage, plan/confirm validation, gauge, cooldowns, win/lose | ms | ✅ in place |
| Unit: enemy AI | `tests/unit/test_enemy_brain.gd` | Movement styles and intervals, staying on the enemy side, per-seed determinism, cooldown → telegraph → hit timing, dodging aimed and projectile attacks, no movement during wind-up, alignment gating, enemy kills end the battle, dead enemies cancel attacks, frozen while planning, spawning from config | ms | ✅ in place |
| Determinism / replay | `tests/unit/test_replay_determinism.gd` | Same seed + same scripted inputs → identical state, including wandering/tracking enemies and their hits | ms | ✅ in place |
| Data validation | `tests/unit/test_game_data.gd` | Every card, enemy attack and enemy loads, has an id matching its file name and sane numbers; enemies with attacks have a wind-up; default spawns are in bounds, on the enemy side and not stacked; default config is internally consistent | ms | ✅ in place |
| Scene smoke / integration | `tests/integration/test_battle_scene.gd` | Main scene boots, input actions exist, real InputMap actions drive plan → move → attack | ~1 s | ✅ in place |
| Golden replays | `tests/replays/*.json` (planned) | Recorded input logs from real play sessions replayed headless; final state compared to a stored snapshot | s | 🔜 next |
| Balance simulations | `tools/simulate.gd` (planned) | Thousands of seeded bot-vs-bot or bot-vs-dummy battles; report win rate, time-to-kill, card usage; flag regressions beyond a threshold | min | 🔜 later |
| Visual snapshots | (planned) | Render key scenes under `xvfb-run` and diff screenshots against approved images | s | 🔜 once art exists |
| Manual playtest checklist | §6 below | Feel: responsiveness, readability, fun | — | ongoing |

## 3. Running tests

```bash
tools/run_tests.sh                 # everything
tools/run_tests.sh --filter=deck   # only files whose path contains "deck"
```

The script:
1. finds Godot (`$GODOT_BIN`, `$GODOT_PATH`, `godot`, or `godot4`; exits with code 127 if none is found),
2. runs `godot --headless --import` so `class_name` scripts resolve,
3. runs `tests/run_tests.gd`, which discovers `test_*.gd` files and runs
   each `test_*` method on a fresh instance (`before_each`/`after_each`
   supported, async tests allowed),
4. **fails if the engine logged any script error.** GDScript has no
   exceptions: a null access inside a test logs an error and carries on, so
   the runner alone would report PASS. This log scan is what turns those into
   failures. Don't remove it. It also fails on leaked objects or resources
   at exit, which almost always means a reference cycle.

Windows: run it from Git Bash with `GODOT_BIN` pointing at the `.exe`, or run
the two `godot` commands in the script by hand.

## 4. Automation: when tests run

| Trigger | Mechanism | Behaviour |
|---|---|---|
| **Claude finishes a turn** | Stop hook in `.claude/settings.json` → `tools/claude-stop-hook.sh` | Only when `.gd/.tscn/.tres/.godot/.cfg` files have uncommitted changes. On failure it returns the failures to Claude (exit 2) so Claude fixes them before handing back. It tries once per turn to avoid loops, and skips silently if Godot isn't installed. |
| **Every commit** | Git pre-commit hook `tools/git-hooks/pre-commit` | Runs the suite when game files are staged and blocks the commit if it fails. Enable once per clone: `git config core.hooksPath tools/git-hooks`. Bypass with `--no-verify`. |
| **Every push / PR** | GitHub Actions `.github/workflows/tests.yml` | Downloads Godot 4.7.2 (cached), runs `tools/run_tests.sh` on Ubuntu. The source of truth: make it a required check on `main`. |
| **Before merging a design change** | Manual playtest checklist (§6) | Recorded in the PR description. |

## 5. What to add next (in order)

1. **Input recording → golden replays.** Have `battle.gd` optionally log
   `(tick, action)` pairs plus the seed to `user://replays/`. Add a test that
   replays each file in `tests/replays/` through `BattleState` and compares
   the final state (HP, cells, piles) with a stored snapshot. Re-record
   intentionally when a design change is meant to alter outcomes. This catches
   "I changed one number and something unrelated broke".
2. **Invariant checks after every tick** in a debug build (a
   `BattleState.check_invariants()` called from tests): every combatant
   stands on its own side's tile, at most one occupant per tile,
   `deck.card_count() + queued_cards.size()` is constant, HP stays within
   `[0, max_hp]`, and the gauge stays within `[0, fill_ticks]`.
3. **Randomised (fuzz) tests:** run thousands of random-but-seeded input
   sequences and assert the invariants hold. Print the failing seed so it can
   be turned into a golden replay.
4. **Enemy behaviour scenarios** as the roster grows: one table-driven test
   per enemy type that loads its real `.tres` and checks its signature
   behaviour (for example, "the gunner fires within N ticks of aligning").
   The basic AI tests are already in place.
5. **Balance simulation report** in CI as a non-blocking job that posts
   the numbers as an artifact. Make it blocking only for agreed thresholds,
   e.g. no card deals more than X% of total damage.
6. **Performance guard:** simulate 10,000 ticks with a full field and fail if
   it exceeds a time budget, to catch accidental O(n²) work in `step()`.
7. **Visual snapshots** under `xvfb-run` once real art and UI exist.

## 6. Manual playtest checklist (per design change)

- [ ] Movement feels responsive; holding a direction repeats at the intended rate.
- [ ] Can't walk onto the enemy half or into occupied tiles.
- [ ] Battle opens in planning with a full hand; confirming with nothing selected works.
- [ ] The gauge fills in the expected time; planning can't open early.
- [ ] Selected cards queue in selection order; the HUD shows the queue.
- [ ] Reshuffle works only while planning and respects the per-battle limit.
- [ ] Hit tiles flash where expected for each card (including the row projectile).
- [ ] Enemy wind-ups are readable: the warning tiles appear early enough to react, and dodging works.
- [ ] Enemies never stand on player tiles or overlap; the Gunner follows your row.
- [ ] The battle ends correctly on a win or a loss; no input is accepted afterwards.
- [ ] The godot MCP debug output shows no errors or warnings during a full battle.

## 7. Conventions for new tests

- File `tests/unit/test_<area>.gd` (or `tests/integration/`), `extends TestCase`.
- Methods are named `test_<behaviour>`. Build state in `before_each`.
- Assertions: `assert_true/false/eq/ne/null/not_null`, `fail(msg)`. Pass a
  message for anything inside a loop.
- Integration tests reach the tree through `tree`, wait with
  `await tree.physics_frame`, and drive input with `Input.action_press`.
- If you need a feature the framework lacks (parameterised tests, mocks),
  extend `tests/framework/` or switch to the GUT addon. Keep `run_tests.sh` as
  the single entry point either way.
