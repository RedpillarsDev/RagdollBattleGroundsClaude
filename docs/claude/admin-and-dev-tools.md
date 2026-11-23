# Admin and dev tools

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

## Staff gating (the one hard rule)

- **Ranks come from one module:** `AdminWhitelist` (Owner / Admin / Mod), with `RankAtLeast(Player, "Admin")`. Reference impl (Pillow Battles): `ReplicatedStorage.System.Misc.AdminWhitelist`.
- **Every dev or admin entry point checks the rank on the server.** A client check only decides what to show. Pillow Battles' dev-area teleport was once an ungated client teleport, so anyone could use it. **A new dev tool must check a rank server-side, never only on the client.**
- Client dev-key handlers ignore keys typed while a TextBox (chat) has focus.
- The Pillow Battles gates, as a template:
  - Chat commands that mint or edit data (`!Set/Add/Remove/Spawn`): Admin+.
  - Dev mode packet: Mod+, and `ToggleDevMode` itself refuses to turn Dev mode on for anyone with no role, whoever calls it.
  - Dev-area key, fly, panel actions: per-action `MinRank`.
  - Ban/unban, reset own data, emulate product: Admin+.
  - Global (cross-server) events: Owner.
- **Ban refuses every staff UserId,** so an Admin can't ban staff or the Owner.
- **Studio runs as Owner,** so Admin-rank behaviour can't be tested solo. Say so when reporting.

## Admin action framework

- **Action metadata in `AdminService.Shared`:** `{MinRank, Risk = Safe|Permanent|Destructive, NeedsTargetInServer, StringArg?, NumberArg?...}`. **The server gate and the panel's buttons both read `MinRank`,** so changing a rank is a one-line edit. Handlers carry no extra rank checks of their own.
- **One server listener** for `AdminPackets.AdminAction`:
  - The actor comes from the network callback, **never from the payload**.
  - It `task.spawn`s `PerformAction`, because handlers may yield.
  - `PerformAction` validates and sanitizes arguments, resolves the rank, dispatches, and writes an **audit entry** (bounded: 60,000-char payload, 250 entries/day).
- **Offline edits by UserId:**
  - The panel can target any username or UserId. Resolved on the client, the target is kept by UserId, and a target who leaves stays targeted.
  - Save-data actions (grants, cash, spins, titles, product emulation) work for someone not in this server. The handler validates, refuses a UserId with no saved profile, then sends a **ProfileStore global message** (`DataService.server:sendGlobalMessage`, key `AdminEdit`).
  - The **same handler** applies it inside their own session: within seconds if they're online elsewhere (ProfileStore pings that server), otherwise when their save next loads. **Never write their DataStore directly.**
  - Only a whitelist (`OFFLINE_ACTIONS`) may arrive that way. A forged KickPlayer message was refused.
- **Edit-equipped-item actions** (set level / add EXP on the equipped weapon) need `NeedsTargetInServer = true`, because there's no offline queue for "what they hold right now". Show a live readout of the target's levels off their attributes.
- **"Reset MY data" (own save only, Admin+):**
  - Two presses within 4s ("Press again to confirm"), refused while in the dev area, and the panel closes on success.
  - The wipe writes through the live data API (`WriteOverWithTemplate`), recursing into dictionaries so path listeners fire, writing arrays whole, and **deleting keys the template lacks**. Then it re-initializes derived state (equipped passives, fresh task slots), calls `profile:Save()` and restarts the tutorial.
  - Leaderboard stores, owned gamepasses and session NPData stay untouched.
  - New-player buffs come back by themselves (the rounds count resets to 0).
  - A **"Play Tutorial V2 / V3"** variant shares the wipe and forces a cohort (`onboarding-and-lobby.md`).
- **Chat commands:** a `!Action Subject` parser (`ChatCommands.CMDs.*`), server-checked. Reference impl (Pillow Battles): `ReplicatedStorage.System.Misc.ChatCommands`.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.AdminService` (`Shared`, `Server`), `ReplicatedStorage.Communication.Networking.AdminPackets`.

## Admin panel UI

- **Built in code,** not authored: `UIInitCallBacks.AdminUI` + `.Theme` (the look) + `.Builder` (the widgets).
- **The look Redpillars approved: "outlined, slate & sapphire".** Dark slate fills. Colour lives in outlines and text: sapphire = Safe, amber = Permanent, crimson = Destructive, violet = Owner, grey = neutral, and a sapphire→violet gradient on the panel's own outline. No edge-bar markers and no filled rank chips (the no-dashboard rule applies to dev UI too).
- **Button state lives in the Builder:** `Active = false` paints a button dead, and `Builder.SetSelected(Button, true)` gives a sapphire outline (selected tab, targeted player row). Never set a button's colours by hand, because Paint overwrites them.
- **Touch = full screen:** fills the safe area, with no drag or resize, 40px controls, +2 text, 48px player rows, the console folded to one line with a "Show log" toggle. Following the device live, a **stacked layout** (tabs in a scrolling top bar) kicks in on touch or under 820px wide.
- **Grids:** compute `CellSize` by subtracting each cell's exact share of the padding. A fixed scale gutter overflowed below ~444px and wrapped buttons behind the next row.
- **Draggable by its header** (mouse or touch), clamped on screen. Each drag step updates the `UICache` origin, or `ScreenSlide` snaps it back on close. **Resizable** from a corner grip, with the size saved in Settings.
- **Starts targeting yourself:** set the target once at build time (not on open, which would overwrite a pick made before the first open). After that it keeps whatever was last picked.
- **Mobile DEV button:** staff on touch get a small top-left `DEV` button. It's built *after* the non-admin early return, so it only exists for staff, and it hides while the panel is open.
- **Name rows and buttons uniquely** (`PillowRow`, "Ability LV +1"), so test clicks by path aren't ambiguous.
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.AdminUI`.

## Dev keys and dev area

- **Pillow Battles keys:** 0 admin panel, 6 fly (Admin+), 7 spawn dummy (Mod+), 9 dev area (Admin+). The client key is advisory and the server re-checks the rank.
- **Dev area ("DevConstruct"):** a sandbox in `Workspace.DEV` with its own spawn point. Entering:
  1. unqueues the player and sets the `InDevPlace` attribute
  2. leaves the tutorial (abandoned, nothing saved) or the round through the normal transition
  3. turns Dev mode on and grants every item
  4. opens the inventory after the transition
  Respawns there while `InDevPlace` is set. Leaving reverses it.
  - The out-of-round function takes an optional `Destination: CFrame?` for this.
  - A server gap (transition length + 0.5s) stops a second press racing a pending move.
- **`InDevPlace` counts as "in play"** for shift lock, the controls layout and closing the lobby profile view.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Misc.Dev.DevTools` (`Server`, `Client`).

## Fly (Admin+)

- A `DevFly` Player attribute is set by a server action (always the actor). The client flies off it:
  - `LinearVelocity` along the camera, plus `AlignOrientation` to the camera heading.
  - **Humanoid `PlatformStand`, never the Physics state:** the ragdoll system's safety net "recovers" a Physics-state humanoid.
  - The `ControlModule` move vector, so keyboard, gamepad and touch all work.
  - Jump/Space up, Q/LeftCtrl down, LeftShift 2x. Speed in config (60).
  - **It lets go while ragdolled, dead or anchored.**
- Redpillars likes the walk animations that keep playing while flying. Leave them.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Misc.Dev.DevFly`.

## Dummies and test spawns

- **Three kinds, all landing 8 studs in front of the player** in the live NPC container:
  - **Normal.**
  - **1-hit:** max health 1, destroyed 3s after death.
  - **Immortal:** healed to full a frame after every hit. If an overkill or out-of-bounds still ends it, a fresh one spawns on the same spot.
- Each wears the normal name + health billboard, and their kills pay like normal dummy kills.
- Reference impl (Pillow Battles): `DevTools.SpawnDummy(Player, Kind)`.

## Session-only items

Admin "Session: every item" grants items for this session only, never saved.
- They go in as ordinary inventory entries with `Session = true`.
- **Before every save** (ProfileStore `OnSave`), point `profile.Data` at a stripped deep copy (no session entries, and an equipped session item swapped for a real one in the copy). Point it back at the live table on `OnAfterSave`. **The live table is never edited.**
- A REAL grant of an item held as a session copy clears the flag in place, so it's kept.
- **Anything that checks "owns this item" for a duplicate or a refusal must ignore `Entry.Session == true`:** rolls, shop purchases, admin "already owns", career "owned x/N". Session items can't be sold and don't count for keep-at-least-one rules.
- Verified: forced saves stored none of them, while the live game kept them. A real roll of the same item wasn't a duplicate and was saved, and a rejoin loaded no session items.
- Reference impl (Pillow Battles): `ServerStorage.System.Main.SessionGrants`.

## Admin Abuse events (live-ops fun)

- **Server vs Global:** `Server*` actions (Admin+) affect this server. `Global*` (Owner) go over a MessagingService topic to every server.
  - A Global publish from a Studio test universe reaches only that universe's servers, never the live game.
  - Servers with no live round skip round-only events.
- **Round-only events** (bounty, moon jump, no cooldowns, clone army, barrel rain) are refused without a live round and **tied to the map Model they started on,** so they stop when that round ends and never carry into the next.
- **Implement them as named stat modifiers:** `JumpHeight` Multiplier "AAMoonJump", `CooldownMultiplier` Flat −1 "AANoCooldowns", `CashMultiplier` +1 "AADoubleCash". Follow round membership every 0.25s and remove at round end. **Don't let two cooldown cuts stack below zero:** half-cooldowns is refused while no-cooldowns runs, and no-cooldowns replaces it.
- **Timed global buffs** (double cash for N minutes) cover joiners too, with an explicit early-stop action that disarms the timer.
- **Bounty:** a red tag billboard on the target, paid to the credited killer, not counted as earned. An uncredited death keeps it, and round end clears it.
- **Environmental hazards with no attacker** (dropped barrels) use an explicit `EnvironmentalBlast` path: neutral knockback, respecting parry and spawn protection, **with no kill credit**. It's the one opt-in exception to "no attacker → no knockback".
- **Free crate / free spins for everyone:** each player gets their own roll and luck, saved at once. Players in a round get the reveal 9s after they're back in the lobby (re-checked, so a straight re-queue waits again).
- **Announcements are signed `Name[Rank]`.** The newest message takes over the banner instantly (`ShowToken`), whatever the rank.
- Reference impl (Pillow Battles): `ServerStorage.System.Main.AdminAbuseEvents`, `ServerStorage.System.Main.BarrelRainSpawner`.

## Other admin and dev pieces worth porting

- **Item drop pickups** (Owner): a pickup tossed in front of the dropper with a 1.5s arming delay (so the dropper doesn't grab it back). The first living toucher who doesn't own it gets it, with a reveal. It despawns after 120s. Reference impl (Pillow Battles): `ServerStorage.System.Main.ItemDropSpawner`.
- **Max NPCs per server** (Round tab): overrides the solo player's NPC count until the server closes.
- **Custom titles** (Admin+): see `ui-and-input.md` → Overhead tags.
- **EmulateProduct:** fires a product or gamepass's real grant (and the `OnPurchased` hook) without faking a receipt. It's the only way to test Robux grants in Studio. Pair it with an undo (reset a one-time bundle's purchase flag).
- **Level tools:** set level / level up / add EXP on the target's equipped weapon, equipped ability and player level, through the leveling service, so passives and VFX re-apply like a real level-up.

## Testing gotchas

- In a round the mouse is locked to the centre. "Select + Return" on admin panel buttons closed the panel without firing them. Return to the lobby and use explicit mouseButtonDown, wait, mouseButtonUp.
- Single click events didn't switch the panel's top-bar tabs. Explicit down, wait, up did.
- Restore a test save after destructive tests (snapshot the whole profile first, then compare afterwards).
