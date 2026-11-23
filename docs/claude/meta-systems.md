# Meta / retention systems

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Daily rewards, group reward, tasks (daily/weekly/monthly), career stats, lucky wheel, level rewards: the reusable designs and the pitfalls each one hit. Odds, shops and receipts are in `economy-and-analytics.md`.

## Shared shape for every meta system

- **A service split `Shared` / `Server` / `Client`.** `Shared` holds the math both sides must agree on (day index, cooldown, period keys, slot progress), so the UI never offers a claim the server refuses.
- **The catalog is a data module** under `ReplicatedStorage.Data.DataLibrarys`, and nothing hardcodes its length.
- **One reward vocabulary across catalogs** (`Cash | Item | Spins | Crate ...`). Pillow Battles had `Ability` in one catalog and `Abillity` in another and needed a translator at the boundary. Pick one spelling on day one.
- **Every payout goes through one reveal queue** (a `DisplayRollNReward`-style packet, with `SkipRoll` for non-random rewards). One busy flag means popups never overlap, and the client owns the timing.
- **Write the "progress" field before the timestamp the client repaints on.** Daily Rewards writes `CurrentDay` before `LastClaimTime`, so the repaint sees the new day.
- **Stamp before paying.** Write the claim marker (timestamp, refilled slot) in the same step as, or before, the grant, so a double-click or a retry can't double-pay.
- **Time passing isn't a data change.** A 1s client loop is needed to flip a countdown to "Claim" the moment a cooldown expires.
- **Release checklist:** a test-time cooldown was once found at `CLAIM_COOLDOWN = 0` in a shared module. Grep cooldown constants before publishing.
- **Ask which extras Redpillars wants** rather than tracking speculative stats or rewards. They declined most of the extras offered on career stats.

## Daily rewards

- **Catalog:** an *array* of `{Type, Amount?, Id?}`. The cycle loops past the last entry, and both the UI and the claim math read `#DailyRewards`, so adding a day is adding an entry.
- **Keep indexes 1..N with no gaps.** A duplicated `[4]` and a missing `[6]` made `#` read 8 while the cards (built with `pairs`) showed 7. Every claim past day 5 was refused and those players were stuck. Validate the catalog at boot (contiguous, known types).
- **Rules:** a claim unlocks 24h after the last one (a rolling, per-player cooldown, not a UTC reset). **Missing days never resets progress.**
- **Save:** `{LastClaimTime, CurrentDay}`, where `CurrentDay` = last claimed index and 0 = none.
- **Swaps for owned items:** granting an item they already own was a silent no-op while the reveal still showed it. Now an owned item day pays an **unowned item of the same type and rarity**, drawn from items some other source can roll. If everything is owned, it pays half the rarity's sell price in cash.
  - Save swaps per day as `Swaps["<Day>"] = {From, Type, Id?, Amount?}`. `From` = the catalog id it replaced, so a swap left over after the day is re-authored is ignored.
  - A swap is rolled once and stands until they own its item. Only days still to come refresh, so a claimed card keeps showing what it paid.
  - `Claim` re-resolves on the spot, saves the swap, then grants it, so the reveal matches.
- **Editing the catalog shifts live saves by a cycle** (removing day 7 moved who gets the day-8 crate). That's acceptable, but think it through before removing or reordering days.
- **Crate days** open the crate on the spot (no crate inventory) and play the full reel. Other days play the reveal without a reel.
- **UI:**
  - One card per entry, cloned from the panel's `Assets.RewardTemplate`.
  - Two authored buttons per card: green Claim and grey Locked. Locked-but-upcoming still shows the green one, uninteractable, and only claimed days show the grey "CLAIMED" (Redpillars' call).
  - Claiming closes the panel so the reveal lands on a clear screen.
  - The countdown is written onto the owed day's button by the 1s loop.
  - On open, it scrolls so the owed day sits where day 1 does at rest (measured off day 1's laid-out AbsolutePosition).
  - Cards are dyed by reward (rarity colour, green cash, a crate colour). A white HUD notifier wiggles on the bar button while a claim is ready, driven from the same `Refresh`.
- **Fresh profiles get the panel auto-opened on join.** Plan for that in tests: it can force other HUD panels out.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.DailyRewardService`, `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.DailyRewardsUI`.

## Group reward

- A flat daily cash payout for members of Redpillars' Roblox group, on a rolling 24h per-player cooldown. `LastClaimTime` is stamped **before** the cash is paid.
- **Membership check:** `Player:IsInGroup` is cached for the session, so a false falls back to `GroupService:GetGroupsAsync` (fresh). That's what lets someone join mid-session and claim without rejoining. It yields, so the request handler `task.spawn`s it, and a `ClaimsInFlight` set stops a double-click getting two claims past the cooldown check.
- **Non-members:** the client pre-checks and shows `GroupService:PromptJoinAsync`. `Joined` / `AlreadyMember` sends the claim. `JoinRequestPending` shows a notification and doesn't claim.
- **A one-time first-claim bonus with no new save key:** "first" = `LastClaimTime == 0`, read after the membership check and before the stamp. Players who claimed before the bonus existed never get it.
- **Don't let code overwrite authored copy.** The panel had five TextLabels all named `Description`, and `FindFirstChild("Description")` wrote the amount over "Join the Group!". Let Redpillars own panel wording, and leave the button green on cooldown with only its text changed.
- **Walk-in zone:** the same poller as the other lobby zones, and the HitBox must be Anchored (an unanchored one fell out of the world).
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.GroupRewardService`.

## Tasks (Daily / Weekly / Monthly quests)

- **Slot system:** each tier has a **pool** of `{TaskType, TaskAmount, RewardAmount}`, and each player holds N slots per tier (4), each dealt a random pool entry.
  - **Claiming pays out and instantly deals a new task into that slot.** There's no cap, and the period reset rerolls every slot.
  - A new deal avoids every task still showing and the one just claimed. The rule relaxes when the pool is too small, so **keep each pool well above the slot count.**
  - **Slots save their own copy of the task,** so pool edits and reorders never disturb a task in progress. A reward rebalance only applies to newly dealt slots, which is worth telling Redpillars when they retune.
- **Progress per slot = counter − `Baseline`,** where Baseline is the counter's value when the slot was dealt. Every new task starts at 0, and two slots of the same type progress independently. The counter is one running total per TaskType per period.
- **Periods are fixed UTC calendar windows** (daily 00:00 UTC, weekly Monday 00:00 UTC, monthly on the 1st) with readable keys (`"2026-08-23"`, the Monday's date, `"2026-08"`). A key mismatch wipes the tier. Every entry point re-checks the period, so progress across a rollover lands in the new period. A 60s server sweep resets idle players too.
- **One progress API, fed from one place:** `TaskService.Server.AddProgress(Player, TaskType, Amount)` feeds all three tiers. No tier is named at the call site: a kill feeds the daily, weekly and monthly kill tasks. It's wired from the central metric function (`LeaderboardService.Server.AddMetric`), so **gameplay code never calls TaskService directly.** Don't add parallel increments.
  - `SetProgress` forces the same figure on every tier. It's for corrections and dev tools only, since running totals differ per tier.
  - An unknown TaskType is logged but still recorded, so a typo shows up without dropping progress.
- **Claim:** write the refilled tier in one set **before** paying, so a finished task can't be claimed twice.
- **Row text is generated** from a TaskType → verb/noun map ("Get 5 Kills"), so changing an amount rewords the row for free. The HUD row itself is the claim button.
- **HUD:**
  - A PC panel on the right and a separate touch panel top-left (switched live by device through HUDVisibility).
  - A Close tab slides the panel off the screen edge. The slid-out offset is measured from the **camera viewport edge**, not the HUD edge, which stops short on notched phones. Recompute it on resize.
  - The open/closed choice is session-only. **Collapsed when a round starts.** The tab opens it for that round only, and leaving the round restores the lobby choice.
  - **A Close tab must be a GuiButton.** Redpillars re-authored one as an ImageLabel and the collapse silently did nothing. Warn at build if it isn't.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.TaskService`, `StarterPlayer.StarterPlayerScripts.UI.GameUI.Systems.Tasks`.

## Career stats (Stats page)

- **`Shared.Build(PlayerData)`** turns a whole save into the page's numbers. Every derived number (K/D, win rate, favourites) is computed there and nowhere else.
  - `Client.GetStats()` reads the local replicated save. `Server.GetStats(Player)` serves other players (the profile inspect).
  - `Client.OnChanged(cb)` listens on the stat paths and **folds bursts into one call per frame** (3 quick kills = 1 redraw). It returns a stop function.
- **Save:** lifetime totals in `Tracking` (kills, deaths, damage dealt/taken, wins, matches, cash earned, playtime minutes). Records and favourites go in a `CareerStats` key: `MostKillsInRound`, `BestKillStreak`, and `{[ItemId]: rounds}` maps.
- **Redpillars' counting rules (Pillow Battles):**
  - **Live rounds only.** The tutorial round, lobby, dev area and dummies never count.
  - **Kills = real players only. Deaths = every death, whatever caused it.** `KD = Kills / max(Deaths, 1)`. Redpillars accepted that K/D drops in NPC-heavy rounds rather than adding a separate NPC kills stat.
  - **Per-round records live in server memory, raised live on each kill,** so a disconnect keeps the record. A streak ends on death and at round end, and both counters clear on round start and end.
  - **Damage is measured as Health actually removed** (no overkill), off one `DamageLanded(Defender, Attacker?, Amount)` signal. Dealt = to real players only. Taken = everything, including NPCs, burning and self-damage.
  - **Favourites** = the item equipped at round **entry** (+1 per entry, mid-round swaps ignored). Ties go to the alphabetically first id, and ids no longer in the catalog are skipped.
- **Statistics panel:**
  - The order is a `STATS` table in the module (Redpillars picked "Wins first").
  - One authored row template cloned per stat.
  - Short number format under/over 10K, K/D to 2 decimals, win rate to 1, time as "12h 30m".
  - "Owned x/N" counts real copies only (session items never count).
  - Full-row transparent buttons for controller navigation.
  - Long values get extra left padding only on the rows that need it.
- **Global rank beside a stat** ("17 (#1)", "(#1000+)", nothing at score 0), from a read-only pager over the AllTime OrderedDataStores:
  - Rank = 1 + the number of players scoring **strictly more than the live score** (in-server players by their live score, everyone else by their board entry). So ties share a rank and an unflushed score still ranks right.
  - Stop paging once past the lowest live score in the server, so small boards cost one read. Cap at 10 pages per board (#1000).
  - Wait for `GetSortedAsync` budget above a reserve (4), so the top-50 refresh always has room. A pass cut short keeps the old ranks.
  - Run one pass per leaderboard refresh (180s), shared by the server, plus one on join (at most every 30s). The rank can trail the number beside it by ~3 minutes.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.CareerStatsService`, `ReplicatedStorage.System.Services.LeaderboardService` (`Ranks`), `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.StatisticsUI`.

## Lucky wheel

- **Spin currency:** a saved resource (`Resource.LuckyWheelSpins`), 1 per spin. Sources in Pillow Battles: round wins, daily reward days, crates, level rewards, the group first-claim bonus, admin "free spins" events and Robux spin bundles. The Spin button reads "Spin (N)" and goes uninteractable at 0 or mid-turn. It stays green (Redpillars).
- **Server authority:** `SpinLuckyWheel(Player)` charges the spin, weighted-rolls the catalog, grants, and returns the result plus `WinningIndex`, behind a cooldown gate. A duplicate item converts to its rarity's sell price through the same grant function crates use. **A crate slot opens on the spot** (no crate inventory) and the client then runs the full crate reel.
- **One packet carries both where to stop and what was won,** so the client owns the timing and a reward can never be revealed before the wheel lands on it.
- **The stop angle comes from the authored wedge's own `Rotation`,** not from its index, so re-arranging wedges in Studio moves the landing point with them. Keep the jitter inside the half-wedge (±21° of 60°).
- **Keep icons upright through a spin:** step the turn by hand on `RenderStepped` with `TweenService:GetValue` (same duration and easing) and counter-rotate the icons in the same step. Driven off a Tween plus the Rotation-changed signal, they trailed by up to 44°, because the deferred signal lands a frame late.
- **Hide the panel during the reveal, don't close it,** so a player with a stack of spins carries straight into the next one. A walk-in zone must not close it mid-spin.
- **Physical lobby wheel:** paint a clone of the live, already-dressed panel onto the model's SurfaceGui (inert, never turns, buttons stripped). Build it after GameUI init.
- **Robux spin bundles:** explicit `PromptPurchase` calls. Don't use the auto-wired buy-button tag, which would overwrite the "+5 Spins" label with the price. Test grants with admin EmulateProduct, since Studio never completes a Robux purchase.
- **⚠ Odds disclosure (verify):** Pillow Battles blanked the wheel's chance labels (Redpillars' call) while also selling spins for Robux. Roblox's paid random items policy requires disclosing odds before purchase for random rewards bought directly or indirectly with Robux. Check the current policy before copying that choice.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.RNGService` (`SpinLuckyWheel`), `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.LuckyWheelUI`, `ReplicatedStorage.System.Classes.Lobby.LuckyWheelStand`.

## Level rewards (track)

- A rewards track by player level. A reward is granted on **reaching** the level, with no back-pay for levels passed before the system existed (they still show as claimed/grey).
- **The `Custom` reward type** (`{Type = "Custom", Name, ImageId}`) shows on the track but **grants nothing.** Redpillars hands it out manually, and the code only sends a held "LEVEL n REWARD: Name!" notification. It's useful for prizes that can't be automated.
- Keep "giant" milestone slots visually bigger, and avoid two neighbouring levels with the same reward type (Redpillars' rule).
- A sideways track needs the mouse-wheel binding (`ui-and-input.md`).
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.PlayerLevelInfoUI`, `LevelingService.Server.LevelRewards`.
