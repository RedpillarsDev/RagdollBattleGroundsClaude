# Onboarding, lobby, winner display, player profile

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Funnel/event mechanics are in `economy-and-analytics.md`. HUD hiding is in `ui-and-input.md`.

## Tutorial architecture

- **One service, `TutorialService` (`Config` / `Server` / `Client`).** `Server.Init()` runs last in server service init. All text, timings and choices live in `Config`.
- **Who gets it:** any save without `Tutorial.Completed`, existing players included. `Config.ForceOnJoin` (**Studio only**) sends everyone in for testing.
- **Save as little as possible:** `Completed`, plus checkpoint flags for the later steps (`ShopPending`, `PlayZonePending`, the chosen starter item id, `Cohort`). Leaving before a checkpoint restarts at Phase 1, and a rejoin resumes at the last checkpoint. Add new keys only, with no version bump. When a step is retired, convert its old flag forward on the next join.
- **A per-player instanced map:** the authored map (`ServerStorage...Maps.Other.Tutorial`) is the clone template and is never edited. Each session clones it to `SlotOrigin + Slot * SlotSpacing` far from everything (Z −6000). Client-side assets are *copied* to ReplicatedStorage at boot. Keep tutorial and arena maps in an `Other` folder so they never roll as live maps.
- **Player state flags as attributes:** `InTutorial`, `TutorialPhase`, plus a `TutorialTarget` ObjectValue. Other systems read these:
  - combat allows swings/casts (`CanStartCombat` isn't a victim rule)
  - the round system won't queue them or apply its lobby state
  - spawn allocation leaves respawns to the tutorial
  - Return to Lobby is hidden and refused server-side
  - the innate dash checks it
- **Test hooks are first-class:**
  - `RestartTutorial(Player, Cohort?)` (CAN YIELD: leaves any session, round or queue and waits out the transition first, so a delayed lobby move can't land on the tutorial map).
  - `StartPillowShopStep(Player, Arrive?)` drops a player straight onto a later step.
  - `Config.StudioCohort`.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.TutorialService`, `ServerStorage.System.Main.TutorialRound`.

## Tutorial flow and design lessons (Pillow Battles V2)

The sequence: hit Dummy 1 off the map (basic attack) → Dummy 2 (ability only) → starter ability pick (3 cards) → reward reveal → a short private round vs easy NPCs → winner panel → guided purchase + equip of a starter item in the lobby shop → guide to the queue → **the first real round entry completes it.**
- **Training dummies never die.** They're healed after every hit and **destroyed** at a depth below the anchor, before the global out-of-bounds kill, so they never pay kill rewards. Shoved off by the wrong source, a dummy respawns. Check the source through a `LastHitSource` attribute that the ability stamps on its victim.
- **Fake the kill feedback:** a counted knock-off bumps a `TutorialKills` attribute. The client plays the real kill VFX, a non-positional death sound and a camera shake.
- **The first dummy at 50% health, launch scaled ×0.5:** the low-health amplifier doubles knockback at half health, and the dummy flew ~500 studs. With the ×0.5 scale it went ~100 (distance isn't linear in force). Compensate whenever knockback scales with health.
- **Force controls per phase** (attack on and ability off, then the reverse), and put the inventory slot's Lock overlay over the disabled HUD control. Halve the ability cooldown for the session with a temporary stat modifier.
- **Every step has a far line AND a near line** in the banner ("Walk to the Dummy!" / "Hit the Dummy off the map!"). A step with no text until in range felt broken.
- **Guides:**
  - A Beam plus a bobbing Arrow to the world target.
  - A `Highlight` on the dummy that fades out within 18 studs and back in beyond.
  - A `ButtonArrow` bouncing over the exact HUD button the step needs, sized off its AbsoluteSize so it can be resized freely. It points sideways when the controls layout is vertical.
  - Raise the Tutorial ScreenGui's DisplayOrder above Main so arrows draw over panels.
- **Click highlight (spotlight):** a see-through Frame with a huge `Outer` UIStroke (black, 0.3 transparency) dims the whole screen except the button. It's not Active and the stroke has no hit area, so clicks and hover still reach the button.
  - Fit it to the button's box cut to any clipping ancestor, rounded out to whole pixels.
  - Raise the stroke thickness until the dim reaches the screen corners.
  - Don't use it on combat steps (it would hide the dummy).
- **HUD:** on the tutorial map, hide everything except Controls and the Tutorial ScreenGui (`HUDVisibility.Hide("Tutorial")`).
- **Hold level-up reward popups while `InTutorial`.** Rewards are granted at once, and the popups come out in order back in the lobby after the winner panel.
- **Robustness:**
  - A choice the server hasn't confirmed within 4s is offered again.
  - With no GUI at all, the first choice is auto-sent so nobody is stranded.
  - A fallback timer releases the HUD hold.
  - Leaving before the pick redoes the dummies (nothing saved).
  - Serial numbers (`PickSerial`) guard timers that outlive the UI.
- **Validate tutorial packets server-side:** the pick is refused unless the `TutorialAbilityPick` attribute is set and the id is one of the listed choices (a forged id was refused).
- **The private tutorial round** (`RoundSystem.Arenas`):
  - A registered arena that live-round broadcasts skip. It sends its own top bar, leaderboard and kill feed to its one player.
  - It sets `Round.InRound` so HUD, controls, combat and permissions behave exactly as in a round.
  - NPC count ramps (3 → 6, +1 every 20s). NPCs are **one team**: before that they ragdolled and killed each other all round.
  - Avoid NPC loadouts that litter the map (banana peels slipped everyone with no attacker).
  - Cash only, not counted as "earned", with a per-round cash limit past which kills pay ×0.5 (shown as its own receipt line so the popup adds up).
  - Winner = most kills, then the winner panel with no engagement prompts.
  - `Stop` (every exit path) removes modifiers, despawns NPCs, destroys the map, unregisters the arena, zeroes round stats and heals.
- **Shorter won.** Redpillars cut the tutorial round 120 → 90 → 60 → 45s, and the V3 experiment tests 30s. It lost ~14% of players in 45s before anyone knew why, which prompted the `Tutorial_RoundLeft` leave-reason event. Instrument first, then cut.

### Funnel-driven fixes worth copying up front

- **Accept any equivalent action.** The shop step accepted only the item it led to. Buying another starter ended the tutorial with no equip, and the player entered round 1 with the default weapon. Now any listed starter counts and becomes the starter.
- **Auto-equip what they bought** (with a "<Name> equipped!" toast). The manual equip step only runs as a fallback.
- **Any off-script purchase, or joining a real round mid-step, ends the tutorial early** (`EndTutorialEarly`: Completed true, flags cleared, guides removed). Log it with a custom event that carries the stage. Without this, the "TUTORIAL" indicator stuck through rounds and levels/quests stayed hidden.
- **Hide the "TUTORIAL" indicator at the final "go play" step,** keyed off the phase attribute, not a saved flag.
- **New-player buffs apply in the tutorial round too,** so the first fight feels good.
- **After the tutorial:** keep the Beam and Arrow (no banner) pointing at the queue zone for the first 3 matches. Hide them in a round and when within range.
- **Purchase hook:** the shop, crate and Robux paths all call `TutorialService.Server.OnPurchase(Player, Kind, ItemId)`. Robux comes through a `PurchaseCompleted` signal that fires once per fresh grant, never on a retried receipt or the join re-grant.

## A/B testing the tutorial (Roblox Experiments + cohort pattern)

- **Roblox Experiments** (Creator Hub → Experiments, in-experience, on a config key) splits players 50/50. Its page compares D1/D7 retention, playtime, session length, ARPU and payer conversion per cohort.
- **Custom funnels are NOT broken down by variant there.** So give each cohort its own funnel (`OnboardingV2`, `OnboardingV3`), and pick it per player with `TrackingService.SetOnboardingFunnel`.
- **Deciding the cohort (`DecideCohort`, called before the first funnel step):**
  1. A forced cohort (admin "Play Tutorial V2/V3"): saved, never asks the experiment.
  2. `Config.StudioCohort`: Studio only, not saved.
  3. The saved `Tutorial.Cohort`.
  4. Otherwise `ConfigService:GetConfigForPlayerAsync(Player):GetValue(Config.ExperimentConfigKey)`: true = variant, false = control, saved.
  - **A failed call or a non-boolean (key missing) plays control and saves nothing.**
  - **The first `GetValue` is what enrolls a player.** Only ask fresh tutorial starts. Never ask a save that is already past the start, or you pollute the cohort.
  - Re-apply a saved cohort on join (a `TutorialCohort` attribute plus the funnel choice) for rejoins at any step.
- **Configs are per experience.** A separate test place (its own universe) has no such key: `GetValue` returns nil with a "Config value not found" warning.
- **Testing the real config path:** `ConfigService:SetTestingValue(key, value)` from a server Script in a Studio playtest works immediately (no refresh). `ClearTestingValue` undoes it. Verified: key unset → nil; true + fresh save → variant; saved control + true → stays control.
- **Variant funnel:** reuse the control's step names word for word where they're shared, so the two compare.

## New-player protection (quiet, no FX)

Redpillars wanted these invisible: no indicator, no VFX.
- **Knockback reduction:** a `NewPlayerProtection` Multiplier modifier of −0.3 on incoming knockback while `TotalMatchesPlayed <= 3`. It stacks additively with other shields. **It's re-decided on every round entry,** after the rounds-played credit, so rejoins are covered and it switches off on round 4 by itself.
- **Bigger hitbox:** +30% on the attack hitbox size stat for the first 3 rounds. **Every consumer must read the same stat:** the client swing hitbox, the server reach check (or it refuses the bigger hits) and aim assist.
- **Damage buff and NPC easing** for the first 3 rounds follow the same pattern.
- Apply the damage and hitbox buffs in the tutorial round too. The knockback protection stays real-rounds only when the tutorial round has its own reduction.
- **They come back by themselves** after an admin data reset (the rounds count returns to 0).
- For a ragdoll knockback game, this is the main lever for first-session retention. Make the values configs.

## Lobby patterns

- **Never hardcode a lobby path.** A `LobbyPaths` util searches down from `Workspace.Lobby` by name (`GetPointsOfInterest`, `GetPointOfInterest(Name)`, `GetCoreSpawn`, `FindInLobby(Name)`), so regrouping the lobby costs no code. Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.LobbyPaths`.
- **Authored anchors are the truth.** Pillow Battles once moved its `MapAnchor` from config on every boot, which silently undid Redpillars' Studio placement. Read the part's position. Never override it from config.
- **Container Models, not Folders,** for `PlayerCharacters` / `LiveNPCs`, so one batch `Highlight` per container can outline everything inside (OverlapParams, `IsDescendantOf` and `DescendantAdded` behave the same).

### Walk-in zones

- A point-of-interest Model carries an invisible `HitBox`. Stepping in opens a panel, and stepping out closes it.
- **Poll, don't use Touched:** a point-in-box test on the HumanoidRootPart every 0.15s. `Touched`/`TouchEnded` flicker on non-colliding parts. Look the HitBox up on each check, so a streamed-out box reads as "outside". Reference impl (Pillow Battles): `ReplicatedStorage.System.Classes.Lobby.GroupRewardArea` (a generic poller despite the name).
- **One line per zone:** `PANEL_ZONES[ModelName] = "ScreenUIKey"` or `{ScreenUI = key, Tab = "Pillows", RequiredLevel = 25, LockedMessage = "Reach Level %d to ..."}`.
- **The cooldown trap:** `ScreenUI:Open()` is silently ignored inside its 0.55s cooldown, so a quick out-and-back-in left the player inside with the panel shut. `OpenForZone` retries once after 0.6s if they're still inside.
- **Never close mid-action:** a wheel mid-spin stays open, then closes itself after the reveal if the player has left.
- **Level-locked zones:** an error toast (rate-limited to once per 3s) and no panel. **The zone check is client-side, so the server must refuse the panel's actions on its own.**
- The poller only acts on a change, so a player who levels up while standing inside must step out and back in.
- **Authoring traps (all hit in Pillow Battles):**
  - A HitBox that's unanchored with CanCollide off falls out of the world, and the zone silently never fires. Keep HitBoxes **Anchored**.
  - Invisible `Center` mounts for billboards and lights shipped **unanchored and collidable**, so a jumping player bumps into them. Check every new one.
  - **Copied zones carry tags.** Shop zones copied from the Queue zone kept its `RoundEntryPoint` tag, and walking into a shop teleported the player into a round. Check tags on every copy.

### Global leaderboards (world boards)

- **One OrderedDataStore per metric × window:** `Leaderboard_<Metric>_<Window>_<Suffix>`. Scope is `Global` for AllTime, and the week's Monday date for Weekly. Entries are key = UserId, value = absolute score (SetAsync). Names live in a separate normal DataStore (UserId → Name, DisplayName).
- **The suffix matches the save-data key environment** (a testing suffix in Studio, live in production), so Studio never pollutes live boards.
- **Board Model → metric:** a `MetricId`/`WindowId` attribute wins, else parse the name (`Leaderboard<MetricId>`), with the window defaulting to AllTime. A new board is a Studio-only change.
- **Refresh:** top 50 every 180s, resolving up to 100 names per cycle (so a cold server names everything at once). **The first refresh waits for the first player:** a boot refresh on an empty server (every live server at boot) left boards blank for 90s.
- **Composite scores:** rank equal Levels by EXP with `(Level − 1) × 1,000,000 + EXP`, and decode for display. A fresh player scores 0 and is never written.
- **Scrollable SurfaceGui:** a SurfaceGui under a Workspace part takes no input. Clone it into PlayerGui with `Adornee` = the part (disable the authored one), set the part's `CanQuery = true` client-side (otherwise the input raycast skips it and the wheel zooms the camera), and re-adorn when the part streams in again.
- **A player's own rank past the top 50:** page the AllTime store read-only (see `meta-systems.md` → Career stats).
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.LeaderboardService`, `ReplicatedStorage.System.Classes.Lobby.LobbyLeaderboard`.

### World shop podiums (crate podiums)

- **Built client-side,** because `ProximityPrompt.PromptShown/PromptHidden` never fire on the server. Each podium declares its product with an attribute (`CrateId`), so adding one is a Studio-only change. The model is cloned onto a `CrateAttach` attachment and the prompt goes on `PromptAttach`.
- **Close-together prompts misfire:** Roblox shows the prompt whose attachment is nearest, which isn't always the podium the player is at (a player opened the cheap crate while reading the expensive one's display). The fix: one Heartbeat loop picks the single nearest podium by a centre anchor, and only that podium's display shows and prompt is enabled. Name the product in the prompt text.
- **The odds display uses the server roll's own function** (`RNGService.GetRewardChances(CrateId, Player)`, including the viewer's Luck), so the display and a paid roll can't disagree. Order slots most-common-first, colour the rarest 2 chances red, and refresh on Luck changes.
- **Hover bob:** move the *Model* on a sine (never the attachment, so the authored rest point is recoverable), with the phase derived from world position so neighbours don't bob in lockstep. Disconnect first in `Destroy()`.
- **Entrance and exit:** fade every transparency plus a Back pop on a `UIScale`, slots popping in staggered, and a `DisplayToken` dropping superseded steps. No white flash.
- **Custom prompt UI** (`Style = Custom` + a BillboardGui in PlayerGui + a full-billboard ClickButton):
  - Use a `ShowToken` so a stale hide can't switch off a re-shown prompt (it left prompts live but invisible).
  - Count a press only when `InputBegan` is `Begin` on the billboard, and end the hold on release anywhere.
  - The badge reads `TAP` on touch.
- **Insta-buy fallback:** when the player's cash is short and a DevProduct exists (AssetId > 0), the prompt offers the Robux product instead of sending a doomed cash request.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Classes.Lobby.CratePodium`, `ReplicatedStorage.System.Libs.ProximityPromptService.PromptClass`.

### Lobby wall glow via Beams

- **Don't put a SurfaceGui on a very long part** for a big soft effect. Roblox skipped drawing it from many ordinary camera angles, with a hard edge. It wasn't GUI memory, and it wasn't PixelsPerStud.
- **Use a Beam** between two attachments just inside the wall face: `FaceCamera = false`, no Texture, LightInfluence 0, width = the wall length, and a transparency curve fading upward. **A non-FaceCamera Beam's width follows the attachment's SecondaryAxis (Y),** so turn the attachments 90° about the wall normal, or the beam is edge-on and invisible. Beams draw from both sides, so one per wall covers inside and out.
- Redpillars' taste: subtle, with only the bottom glowing (a ~12-stud fade, Brightness 1.5, transparency 0.55 → 0.8 → clear). Tune `Color`/`Transparency`/`Brightness` and the top attachment's height.

### Kill height per area (ring-outs)

Relevant to any knockback game.
- **Every area gets its own kill height** = `FallDepth` (100) under its lowest spawn marker. It's marked at runtime with an `OutOfBoundsArea` tag and `KillHeight`/`AreaMin`/`AreaMax` attributes on the area instance, so server and clients read the same values.
- A body takes the nearest area's height (measured flat to the footprint). Any other area within 100 studs also counts, and the **lowest** wins. Without that, a player knocked off one map toward a higher lobby died in mid-air.
- Expect ~30 studs of overshoot from a 0.2s sweep. Keep `Workspace.FallenPartsDestroyHeight` ~500 below the lowest kill height (warn within 300), since a fast body covers ~160 studs per sweep.
- **Keep round knockback from landing anyone in the lobby:** kill in-round bodies within 15 studs (flat) of the lobby footprint. Arm the rule only after 1s seen away from the lobby, because `InRound` is set while the player still stands in the lobby. Credit the kill to the last attacker.
- A map with no spawn markers gets no kill height of its own (warn).
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.OutOfBounds`.

## End-of-round winner display

- **The server resolves the winner and sends one packet per player, with the stats inside it.** It's sent *before* the round data wipe, because reading the replica client-side races that wipe. Everyone in the server gets it, lobby watchers included (their own stats read 0).
- **Winner = most round kills,** with a tie going to whoever holds the *older* `LastKillTimeStamp` (they got there first). **No kills → "Nobody won this round!"** and the avatar slot hides, rather than crowning someone on 0.
- **Round stat fields:** `RoundKills`, `RoundDeaths`, `RoundCashEarned` (incremented at the kill-award site, not inside AddCash, so lobby rewards never leak in), `LastKillTimeStamp`, `BestKillStreak`. All are cleared together at round end.
- **The panel:** close any open panel first, blur 24, hide the HUD. Icon cards pop in one by one on a `UIScale` (Back) and count up, with glow flares spinning slowly.
- **It always removes itself after a fixed 8s, counted from the start of the slide-in,** so slides and reveals happen inside it and can never overrun the intermission. Close / tap / B only cut the hold short, so the HUD and blur always come back down one path. Taps count only once every card is in.
- **After the panel:** the winner's reward reveal (Pillow Battles: +1 wheel spin), then the engagement prompt.
- **Engagement prompt (Favorite / Join Group):**
  - The server adds `EngagementPrompts` (Favorite|Group minus what the save says is done) to the packet on a participant's 1st round and every 3rd after.
  - The client waits out any reward reveal, drops Group if already a member (and saves that), picks 50/50, then shows Roblox's dialog: `AvatarEditorService:PromptSetFavorite` or `GroupService:PromptJoinAsync`. Accepting reports back and is saved.
  - **Use the real game's place id from config for Favorite, never `game.PlaceId`,** which is the test place's id in a test universe.
  - **There is no Like/upvote prompt API.** Redpillars chose Favorite.
  - Neither dialog completes in a Studio playtest.
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.Systems.WinnerAnouncement` (sic), `GameUI.Systems.EngagementPrompt`.

## Player profile inspect (lobby)

Click (mouse), tap (touch) or press Y (controller) on another player in the lobby. A profile billboard appears beside them (level, kills, wins, K/D, loadout with levels), plus a white outline Highlight. Only the clicker sees either.
- **Placement:** a BillboardGui adorned to their HumanoidRootPart. `StudsOffset` is camera space, so the authored −4.2 X keeps it on the same screen side whichever way they face.
- **Data:** other players' saves don't replicate, so the server answers once per open: career stats, equipped ids, level attributes. Rate limit 4/s with a burst of 6. Show the name and "..." at once, fill in on reply, and drop a late answer for a different target. It doesn't live-update.
- **Click detection:** `UserInputService.InputBegan` MouseButton1 (not gameProcessed), plus `TouchTapInWorld` (not processedByUI). Then a ray whose include-list holds **only other players' characters**, so props and invisible zone parts can't block it. Climb from the hit part to the character. Max reach 30 studs.
- **Controller:** the nearest other player in reach whose root is within 0.3 screen-height of screen centre. Ignore the input while `GuiService.SelectedObject` is set (a menu owns the controller).
- **Hover (mouse only):** a white outline plus a faint fill (0.85) on whoever a click would open. Skip it when an Active GuiObject is under the mouse: `GetGuiObjectsAtPosition(mouse − GuiService:GetGuiInset())`, because `GetMouseLocation` includes the top-bar inset and GUI space doesn't. One Highlight at a time.
- **It closes** when the target leaves or respawns, the viewer enters play, or they move more than 30 studs apart.
- **Public `Show(Player)` / `Hide()`** skip the click checks. `Show(LocalPlayer)` is how a solo playtest sees the panel.
- **Unverified:** the touch-tap ray conversion (`ViewportPointToRay` vs `ScreenPointToRay`; an inset mismatch would aim ~58px off), and a real second player.
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.Systems.PlayerProfile`.
