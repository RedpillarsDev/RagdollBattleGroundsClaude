# Economy, monetization and analytics

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

## Currency rules

- **One cash entry point:** `DataEditorService.AddCash(Player, Amount, CountsAsEarned?)`, which counts toward `Tracking.TotalCashEarned` by default. **Every non-gameplay source passes `false`:** Robux packs and bundles, admin grants, dev commands, tutorial top-ups, tutorial-round kills. Otherwise earned-cash funnels and leaderboards lie.
- **Validate at the request boundary, on the server.** The client's save mirror and NPData are presentation, not wallets.
- **Distinguish the catalog `Id` from the per-copy `UniqueId`** in inventories. Equip and sell handlers act on the UniqueId. Don't assume helpers validate ownership: check the request handler.
- **Friends boost:** +10% per in-server friend, capped at +50%, expressed as `1 + fraction`. It applies to kill and round payouts only (not crates, dailies, products or task claims) unless Redpillars says otherwise.
- **Multipliers stack additively** through named stat modifiers (`CashMultiplier` +1 "AADoubleCash" alongside gamepass boosts). Show each one as its own receipt line so a popup always adds up to what was paid.
- **Price formatting** in one shared helper: `$150K`, `$1.75M`.

## Rarities and RNG

- **Rarity catalog:** per rarity `PrimaryColor`, a two-stop `ColorGradient`, `BaseRollWeight` and `ItemSellPrice`. One styling helper dresses any label or card by rarity.
- **`RNGService` is the single roll authority:**
  - `OpenCrate(CrateId, Player)` validates the catalog and cash, applies a 5s gate, charges, weighted-rolls the `RewardPool` (an explicit `Rollweight` per entry; rarity names don't stand in for weights) and grants.
  - `OpenCrateFree(CrateId, Player, Rules?, CountsAsEarned?)` is the no-charge path for daily days, wheel slots, admin events and **paid Robux insta-buys**.
  - `SpinLuckyWheel` reuses the same grant.
  - **Server roll results decide the award, never the visual reel position.**
- **Duplicates convert to the rarity's `ItemSellPrice` in cash,** while the result keeps the originally rolled item for display (`DisplayType` / `DisplayPillowId` beside the granted `Type` / `Amount`). One result shape (`CrateRollResult`) is shared by crates and the wheel, which adds `WinningIndex`.
- **Roll `Rules`** (exclude owned, rarity filters, excluded ids) for guaranteed-good first rolls such as a tutorial gift.
- **Luck:** named saved and session sources summed and capped (`MaxLuckBoost` 100), applied by `BoostWeightTableForPlayer`. **The odds display calls the same function** (`GetRewardChances(CrateId, Player)`), so what's shown is the viewer's own luck-adjusted odds and can't disagree with a paid roll. Fall back to base odds until the data replicates.
- **Cap pool size to the display's slot count** (6 in Pillow Battles), and rank the display by base weight (rarest last, top 2 in red).
- **First-purchase discount per crate:** a saved `FirstCrateDiscountUsed[CrateId]` flag, and **one pricing function** (`CratePricing.GetPriceForPlayer`) used by both the server charge and the world display. The label reads "(50% OFF)" while it stands.
- **Kill switch for a whole feature (`GameConfig.CratesArchived`):** one flag refuses cash buys, moves the world podiums into ServerStorage **at runtime** (the Edit place keeps them), and drops crate lines from "where to get it". Every catalog reward that pointed at it was swapped, with a `was ...` comment. **`OpenCrateFree` stays open,** because a paid receipt must still be granted. Copy this shape for any feature Redpillars wants paused but not deleted.
- **Session-only items** (admin-granted for one session) must be ignored by every "already owns" check (rolls, purchases, duplicate conversion). See `admin-and-dev-tools.md`.
- **⚠ Paid random items:** Roblox's policy requires showing odds before purchase for random rewards bought directly or indirectly with Robux (crates with a Robux insta-buy, wheel spins sold for Robux). Verify the current policy before shipping anything random that's Robux-adjacent.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.RNGService`, `ReplicatedStorage.System.Utils.CratePricing`, `ReplicatedStorage.Data.DataLibrarys` (`Rarities`, `Crates`, `LuckyWheel`).

## Shops

- **Shop catalogs separate from item catalogs:** `Shops.<Kind>Shop = {[Id]: {ForSale, BuyPrice, CanStock, StockChance, RequiredLevel?}}`. A new item needs a shop entry to be buyable for cash.
  - `ForSale` → listed in the permanent grid.
  - `CanStock` → may roll as a daily special offer. `CanStock` true with `ForSale` false = **offer-only**.
  - `StockChance` → a percent acceptance roll on each uniform draw.
- **Daily special offers, identical for everyone, with no DataStore:** seed the roll off the day number, from a **sorted** pool. 3 offers per tab, reset at a fixed UTC hour (10:00 UTC all year, Redpillars' pick), sold at 20% off.
  - Publish shop state as Attributes on a `ReplicatedStorage.ShopState` instance (`<Tab>Offers` "Id,Id,Id", `NextResetAt`, `Overridden`). A watcher restocks at the reset and broadcasts "The Shop has restocked!".
  - Publishing a catalog change mid-day changes the roll on new servers only. Old servers keep theirs until the reset.
  - Admin `!Shop Reroll` / `!Shop Reset` (per server, Admin+, server-checked).
- **One pricing authority:** the purchase handler prices only through `ShopService.Server.GetPrice`. The order of checks:
  1. Owned (non-session): refused.
  2. Not priceable: "That isn't for sale!".
  3. Level lock.
  4. Cash.
  A live offer sells at the discount wherever it's bought (card or grid), even when `ForSale` is false.
- **Level locks:** below `RequiredLevel`, the grid shows the slot's Lock and the button reads "LV. n". **A special offer ignores the lock.** The Robux button is hidden below the level **client-side only**: the server can't tell where a receipt came from, and refusing a paid receipt is wrong. Never lock the tutorial's starter item.
- **Redpillars' shop UX calls:** cash buys have no confirmation. Unaffordable prices are red with a black outline. OWNED stays green and unpressable (no grey-out). Offers show the full price crossed out (RichText) before the offer price. Daily offer cards are never red.
- **"Quick buy" elsewhere** (in the inventory): send the shop's own purchase request so the same server pricing applies.
- **"Where to get it"** lines are generated from the live catalogs (`Utils.ItemSources`). See `ui-and-input.md`.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.ShopService`, `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.ItemShopUI`.

## Gamepasses, dev products, receipts

- **`RbxPaymentService` (Server / Client / Packets / Dependencies)** owns `MarketplaceService.ProcessReceipt` and gamepass purchase handling. The catalog is `PassesNDevProducts` (`{Id → AssetId, ...}`) with callback modules:
  - **`DevProductCallbacks`:** grant per receipt.
  - **`GamepassCallbacks`:** run **every join** (ownership re-check). They set session flags only (`Other.OwnsX` on the replica) and **must not write saved data.**
  - **`GamepassPurchaseCallbacks` (`OnPurchased`):** run **once** on a real purchase (and on admin EmulateProduct), never on the join re-grant, so they may write saved data (turn settings on, show a "head to Settings" toast).
  - **Per-item insta-buy callbacks** (`PillowInstaBuyCallbacks`, `CrateInstaBuyCallbacks.<Id>`...).
  - **One-time bundles:** a client-readable `Bundles` data module (`{[ProductId]: {DisplayName, Rewards}}`) drives the grant, the reveal popups and the sources list. It's gated by a saved `Purchases.<ProductId>` flag. A hand-dressed shop card must be updated by hand when the list changes.
- **Receipts:**
  - If the player's data isn't loaded, return `NotProcessedYet`.
  - Grant first, then record the receipt id in a **bounded** `GrantedReceipts` list (50). That's not transactional exactly-once, so review the retry behaviour on any change.
  - Robux spent → `AddMetric("RobuxSpent")` for the leaderboard.
- **A `PurchaseCompleted` server signal** fires once per fresh grant, never on a retried receipt or the join re-grant. Hook game logic to it (the tutorial's "bought something else" check).
- **`AssetId = 0` = a prepared placeholder:** nobody owns it, no web calls, skipped when building the AssetId lookup (no duplicate warnings). This lets Redpillars create the Roblox product later and drop the id in.
- **Client `PromptPurchase` is not authorization.** `GetProductInfo` returns a Promise.
- **The tag-driven buy button (`RbxBuyButton` tag + `Id` attribute)** auto-wires the price label and prompt, and owns the button's hover. It overwrites the label text, so don't tag buttons with custom labels ("+5 Spins"). Strip the tag and `Id` from authored buttons copied into cash contexts: a copied Robux button sold `TwoXCash` from a cash card.
- **Rebranding a gamepass:** reuse the asset id under the new catalog entry, and previous buyers own the new pass.
- **Studio never completes a Robux purchase** (`PromptProductPurchaseFinished` fires with false). Test grants with admin **EmulateProduct**, which fires the real callback without pretending a receipt was processed.
- **Insta-buy fallback:** offer the Robux product only when the player's cash is short and the product's AssetId > 0. Otherwise send the cash request and let the server answer.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.RbxPaymentService`, `ReplicatedStorage.Data.DataLibrarys.PassesNDevProducts`.

## Analytics: Roblox AnalyticsService

- **Use `game:GetService("AnalyticsService")`.** Pillow Battles also had an empty game module named `AnalyticsService`, which confused readers. Don't name a module after a Roblox service.
- **Master switch** `GameConfig.FunnelsEnabled`: false = nothing is sent or saved.
- **Platform:** the client reports once on join (`ReportPlatform`): Console if `GuiService:IsTenFootInterface()`, Mobile if touch without a keyboard, otherwise PC. The server stores it as a `Platform` Player attribute and every event carries it.
  - **The platform hold:** the server sent "Joined" before the client had reported its device, so most users logged as "Unknown". Hold onboarding steps in order while `Platform` is nil, and flush when it arrives, after 30s, or on PlayerRemoving.

### Funnels

- **Roblox rules that shape a funnel:**
  - Sending step N counts every step below N as done, so a funnel holds only the steps every player passes through. Optional moments become custom events.
  - 100 steps per funnel, 10 funnels per experience.
  - Nothing is sent from Studio (it only prints).
  - **Never reorder, rename or insert steps.** A change means a new funnel (`OnboardingV2` → `V3`), with old names kept for dashboard history.
- **Send steps by name** through a wrapper (`LogOnboardingStep(Player, StepName)`): each step once per player per server, and never an earlier step after a later one. A name in no funnel warns.
- **Finish the funnel on alternative routes.** A player who reaches the end another way (joined a round from mid-tutorial, bought something else) gets all missing steps sent at once (`LogOnboardingThrough(Player, "Joined First Round")`), so conversion isn't falsified as drop-off. How they left is recorded separately with a custom event.
- **Progression funnels** (cash, rounds, kills targets): thresholds are parsed off the step names ("1K Cash" → 1000), so renaming retunes them. The highest step sent is saved in `PlayerData.Funnels`. **Seed existing players silently at their current step** on first join, so only progress from now on is sent.
- **First-round funnel** (one-time, the first real round after the tutorial): Spawned In, Stayed 10s/20s/30s/45s, then every 15s to 240s, Round End. A round ending with them still in it sends every remaining step.
- **One funnel per experiment cohort** (Experiments doesn't split custom funnels by variant). See `onboarding-and-lobby.md`.

### Custom events

- **A catalog module** (`TrackingService.CustomEvents`): every event keyed by its exact name, with a comment saying when it fires, what `Value` measures, and `Fields` in slot order.
  - `LogCustomEvent(Player, EventId, Value, {Platform = ..., Stage = ...})` maps names to slots, **refuses unknown events, drops unlisted fields** (with warnings), and returns `(Sent, SlotTable)`.
  - Senders (tutorial, first-round module) go through it and never call Roblox directly.
- **Rules:**
  - Never rename an event or move a field to another slot. The dashboard keys history by name and slot.
  - At most 3 fields per event.
  - **Field values are a few fixed words with no apostrophe, comma or quote.** Roblox rejects them ("Event field CustomField03 is invalid"), and "Hadn't moved" never reached the dashboard.
- **Hook analytics through Signals** (`SwingStarted`, `CastStarted`, `DamageLanded`, `KillAwarded`, `PlayerEnteredRound`...) so no gameplay module requires the analytics module.
- **Patterns that paid off:**
  - **Firsts:** `FirstRound_FirstSwing/FirstDash/FirstAbility/FirstHitLanded/FirstGotHit/FirstKnockedOff/FirstKill`, with value = seconds since spawn.
  - **Summary at the end of a round:** counts, with fields `Opponents` ("NPCs only" / "Real players") and `Ending` ("Stayed to end" / "Left the game" / "Returned to Lobby").
  - **Why they left** (sent on leaving the *game* mid-round). Reason = the first that fits:
    - "Knocked off just before" (a death within 5s)
    - "Had not moved" (never 8 studs flat from a spawn)
    - "Never landed a hit"
    - "Playing normally"
    It's reused for the tutorial round (`Tutorial_RoundLeft`). Read it as Count ÷ the funnel's matching "Started" step.
  - **Per-map leave rate:** `Map_RoundJoined` (each real round entry) vs `Map_LeftGame` (quit the game mid-round, value = seconds in), with a Map field. Rate = LeftGame ÷ RoundJoined per map. Don't count Return to Lobby, AFK, round end or server shutdown.
  - **Off-script exits from a funnel:** `Tutorial_EndedEarly` {Stage, Purchase}, `Tutorial_JoinedRoundBeforePillow` {Stage}.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.TrackingService` (`Funnels`, `CustomEvents`), `ServerStorage.System.Main.FirstRoundAnalytics`, `ServerStorage.System.Main.MapLeaveAnalytics`.

### Funnel lessons from Pillow Battles

- Instrument a step's drop-off reasons before redesigning it. The tutorial round silently lost ~14% in 45s until a leave-reason event existed.
- Shorter tutorial segments retained better, so Redpillars kept cutting them. Run the next cut as an experiment, not a guess.
- Funnel holes were usually design bugs: a "wrong" purchase ending the tutorial, a manual equip step, the tutorial staying open after joining a round. Fix the flow, then backfill the funnel steps.
- Data recorded before a fix keeps its flaws (the "Unknown" platform). Note the publish date of every analytics fix.
