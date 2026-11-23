# Roblox engine gotchas

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Running list of engine/Studio behaviour that bit Pillow Battles. One bullet per gotcha: **topic**, what happens, why / what to do. "Measured" = observed in a PB playtest or Studio run; anything else is source reading or general knowledge and says so. Append under the closest section (or add one).

## Signals and property events

- **Deferred signals (measured; PB ran `Workspace.SignalBehavior = Deferred`):** event handlers run at the next resumption point, not inline at the write. Code that writes a property and also listens to that property sees its *own* write arrive later, indistinguishable from an outside write. Fix: count your pending own writes and skip that many events (PB's HUD visibility manager did this after restoring elements hidden).
- **No-op writes fire nothing:** setting a property to the value it already has fires no `Changed` / `GetPropertyChangedSignal`. A "wanted visible = false" written while something is already force-hidden is lost. Record the desired state separately from the current state.
- **Library signals vs engine signals:** GoodSignal-style Lua signals run handlers immediately on `Fire`, regardless of `SignalBehavior` (library design). Don't assume engine events and Lua signals share ordering.

## Sandboxing and requires

- **Sandboxed threads can't require non-sandboxed modules** (measured): "cannot require ... the calling thread is sandboxed". A container with `Sandboxed = true` (PB: the Replica library) runs your callbacks on its sandboxed thread, so a handler that lazily requires anything fails. Build objects up front; only toggle them in the handler. Other capabilities still worked, including `BindToRenderStep`.
- **Recursive require errors:** a registry module required by a service must never require that service back (PB: VFX sequence registry vs VFX service). Have leaf modules require the low-level lib directly.
- **Requiring is not always passive:** a module body runs once per Lua VM and can install listeners. Module state is per VM: the command bar / MCP `execute_luau` has its own copy, separate from running game scripts.

## Streaming (StreamingEnabled)

- **Instance arguments arrive as nil** (measured) when the receiving client hasn't streamed that instance in. Nil-check every Instance in client remote handlers, and never fall back to a global parent: PB's sound handler fell back to `SoundService` and played round sounds in the Lobby at full volume.
- **Far characters arrive as empty shells** (measured): the Model and Humanoid with 0 BaseParts and no HumanoidRootPart. Bubble chat and anything adorned to another player's body drew at the world origin. Fix: set the character Model's `ModelStreamingMode = Persistent` first thing on CharacterAdded. Cost: bandwidth for far-apart pairs (PB: MaxPlayers 60, fine).
- **Instance-valued attributes read back as an `InstanceHandle`** (measured in PB, 2026), not the Instance: call `:Get()` inside a `pcall` (target may be gone or not streamed). `typeof(v) == "Instance"` is false for it.
- **Solo playtests can't reproduce cross-player streaming bugs:** with one player nothing is far away. Reason from the streaming rules or test with multiple clients.

## Humanoids and characters

- **`Humanoid:SetStateEnabled` does not replicate.** Apply state disables on the server *and* on the client that simulates that humanoid.
- **`Humanoid.UseJumpPower` picks the live property:** writing `JumpHeight` does nothing while `UseJumpPower` is true, and vice versa. Check it before debugging jump values.
- **A custom `StarterCharacterScripts.Animate` replaces the stock one.** Inside it, the character is `script.Parent` (a fresh copy per respawn), not `LocalPlayer.Character`. Reuse loaded tracks instead of reloading per state change.
- **Never stop a Player's animation tracks from the server** (measured): the server's copy of that Player's Animator is what every *other* client sees. A server-side Stop on ragdoll killed that Player's idle for everyone else until they next moved, while their own client looked fine. Stop/pause tracks on the owning client; the server only drives server-run rigs (NPCs, Dummies).
- **Stopping all tracks breaks "is playing" flags:** anything caching its own playing state (an NPC animator) never restarts after a ragdoll stops every track. Re-check `AnimationTrack.IsPlaying`.
- **`Humanoid.Died` never fires on a client for a server-simulated body** (measured); `Health` changes do. Watch Health for client-side death FX on NPCs.
- **`HumanoidStateType.Physics` is sticky:** nothing leaves it on its own. A Humanoid stranded there lies on the floor playing normal animations (PB: a ragdoll message for a corpse arrived after respawn and put the new character into Physics). Reserve Physics for the ragdoll only, use `PlatformStand` for anything else (fly, cutscenes), and run a watchdog that recovers Physics-without-ragdoll after ~1s.
- **An anchored HumanoidRootPart still takes movement input** (measured): the walk animation plays in place. To freeze a Player, also disable the PlayerModule controls and zero `Humanoid:Move` / `Jump`.
- **`AutoRotate` fights scripted facing:** turn it off, re-apply the yaw every frame at `RenderPriority.Camera + 2` (after other camera-bound writers such as a mobile shift lock at +1), and only restore AutoRotate if you turned it off.
- **Root heights (measured, R6-style rig):** a standing HumanoidRootPart sits ~3 studs above the floor, a ragdolled one lying flat ~0.5. A standing-size box cast carried from a lying body's root sinks into the floor and reports the floor as a wall; aim such checks ~2.5 studs above a downed root.
- **`PlayerAdded` in Studio solo:** the LocalPlayer joins *before* server Scripts connect `PlayerAdded`, so a handler that only connects the event never sees them (PB: every solo-test death went unprocessed). Always backfill `Players:GetPlayers()` at Init.

## Physics and network ownership

- **Take ownership before you anchor or pin from the server.** A client-owned assembly fights server position writes, and the ownership API refuses anchored parts (general engine rule). Order: `SetNetworkOwner(nil)`, anchor/move, unanchor, then a frame later hand back (players: `SetNetworkOwnershipAuto()`; server-driven NPCs: keep server). PB found this on a time-stop freeze and a grab/carry.
- **Velocity writes right after an unanchor/unpin:** PB waited one Heartbeat after restoring `Anchored` (or releasing a welded anchored pin) before writing `AssemblyLinearVelocity`, otherwise the write was lost. Its hit-freeze `Release` returns whether the caller must wait.
- **A ragdolled rig is several assemblies** (general engine rule): once Motor6Ds give way to BallSocketConstraints each limb is its own assembly, so writing velocity on the root alone leaves the limbs behind. Write every assembly/part (PB's `Launch` does).
- **Client writes to replicated properties don't replicate and stick** (measured): a client-side `Anchored = true` on its own root doesn't stop the server's teleport, and the client value stays until the *server* next changes that property. So restoring a captured value can silently undo a server change made in between (PB: a Player stayed frozen forever after a thaw landed during a client-side wipe). Only undo your own write; leave a value you didn't set alone.
- **The server's view of a client-owned character lags and can stall** (measured): a client-driven rise replicated to the server as one jump; a fast turn during a 0.35s wind-up still faced the old way on the server. Don't gate server events on "seeing" the client arrive; schedule them on the server clock, or accept client geometry and clamp it.
- **Shapecasts ignore parts they start inside** (`Blockcast` / `Spherecast` / `Shapecast`): add a centre `Raycast` when the cast can begin inside a wall.
- **Spatial queries return every part, helpers included:** `GetPartBoundsInBox/Radius` found a server hitbox Part parented inside an NPC, so "parent has a Humanoid" counted it as the NPC (hittable 12 studs out). Set `CanQuery = false` on hitbox/VFX helper parts and keep them out of character models.
- **`Touched` fires only on new contact:** someone already standing in a zone when it becomes active never fires it. Sweep with `GetPartsInPart` for occupancy (queue boxes, heal pads coming off cooldown).
- **Collision groups are per part, per character instance:** set the group on `CharacterAdded` **and** `DescendantAdded` for every respawn (PB grouped only the first character, so respawns collided with everything), and set it on spawned objects' own parts.
- **`Workspace.FallenPartsDestroyHeight` deletes fast bodies before your out-of-bounds sweep sees them:** a body at 800 studs/s moves ~160 studs per 0.2s sweep. Keep it ~300+ studs below the lowest kill height.
- **Launch distance is not linear in force** (measured): 1.45x the force went 2.4x as far (more airtime), and a limp ragdolled body launched with the same force travelled ~58% as far as a standing one (floor friction on the limbs).

## Rendering, particles and camera

- **Writing `ParticleEmitter.Rate` restarts its spawn timing** (measured): rewriting it every frame as speed wobbles makes the effect come out in bursts. Change Rate in steps with hysteresis, and rarely.
- **`EmissionDirection` defaults to `Top` (+Y) while `CFrame.lookAt` points −Z:** a bare lookAt aims the rig's front while particles still fly out of its top. For Top emitters use `CFrame.lookAt(O, O + Dir) * CFrame.Angles(-math.pi/2, 0, 0)`. `lookAt` is degenerate for straight up/down: use `CFrame.fromMatrix`. Verify with `UpVector:Dot(Dir) == 1` against a non-axis-aligned Dir.
- **A Part parented under another Part keeps its own world CFrame:** moving the parent doesn't move it (only `Model:PivotTo` moves descendants). Place every nested BasePart by its offset when positioning a cloned rig.
- **Particle quirks** (measured): `Size` is about half the drawn width; on a flat `VelocityPerpendicular` particle `RotSpeed` turns the opposite way to `Rotation`; a very low `Rate` can wait up to `1/Rate` seconds for the first particle; `Clear()` right before `Emit(1)` lost the new particle. A long-lived ground decal (a spinning circle) is more reliable as a SurfaceGui ImageLabel than as a particle.
- **Highlights are colour-corrected with the world** (measured): under a white `ColorCorrectionEffect` a black Highlight fill rendered white. A `SurfaceGui` with `AlwaysOnTop` draws after colour correction; ViewportFrame clones work for silhouettes.
- **`LocalTransparencyModifier`** fades parts for one client without touching `Transparency`, so it never fights other writers (good for i-frame flicker).
- **Writing `Camera.CFrame` under the Custom camera sticks** (measured), and the default camera reads its look direction back from `Camera.CFrame` each frame. To hold the camera, re-assert after the camera step every frame and keep `CameraType = Custom`.
- **Shift lock / first person (`MouseBehavior == LockCenter`) snaps the character to the camera heading:** after a scripted turn or teleport, rotate the camera to the new heading too (keep pitch).
- **Frame-counted effects stretch at low FPS:** Studio playtests ran ~16fps, so a 14-frame shake took 0.9s instead of 0.23s. Drive durations by time.
- **`AnimationTrack.Length` is 0 for an animation published without baked keyframes** (measured: one empty keyframe plus plugin folders). Check Length after loading a new id. Higher priority (`Action` over `Movement`) overrides instead of blending.

## Luau

- **A `local function` defined further down the file is not in scope above it:** an earlier call resolves to a nil global ("attempt to call a nil value", measured at runtime in PB). Define helpers above their first use.

## Sound

- **Parent decides 3D vs 2D** (measured): a Sound under a BasePart or Attachment is positional; under a Model, Player, Folder or SoundService it plays 2D for everyone at full volume. Resolve "the character" or "the model" to its root part before parenting.
- **`RollOffMode` Inverse falls off fast** (measured): from `RollOffMinDistance` 10 it is about 3% at 300 studs. For arena-wide combat audio use `Linear` with an explicit `RollOffMaxDistance` sized to the arena, and keep other areas (lobby, other arenas) outside that range.
- **A Sound saved as Playing in the place's `SoundService` plays for everyone on join** (measured). Keep nothing playing there; music comes from a music service.

## DataStores, saves and publishing

- **Studio playtests use the experience's real DataStores** (with API access on). Use a separate Studio store key so tests never touch live saves.
- **DataStores are per experience (universe).** A separate testing experience never sees live players' saves; export copies to test migrations on real data.
- **JSON key order is not stable:** compare tables with a deep-equal, never by `JSONEncode` string. An empty table encodes as `[]` and decodes back to `{}` (fine for dictionaries).
- **Old servers keep running old code after a publish** until shut down. When the save layout or a packet's wire format changes, publish with "Migrate To Latest Update" (or shut down servers).
- **`ProcessReceipt` retries until you return `PurchaseGranted`** (engine docs). Return `NotProcessedYet` while the player's data isn't loaded, and dedupe by receipt id in the profile.

## Time

- **`os.time()` has 1-second resolution**: don't use it for sub-second countdowns. `os.clock()` is high resolution but per machine. For timestamps shared between server and client use `workspace:GetServerTimeNow()` (general knowledge).

## UI layout and input

- **Inside a frame that grows** (AutomaticSize, or a section of an auto canvas), child heights must never be Scale of that frame: use an aspect constraint (width-driven), Offset or content size. Direct children of a ScrollingFrame are fine: their Scale is of the window, not the canvas (measured).
- **The mouse wheel never scrolls a horizontal ScrollingFrame** (measured). Bind the wheel through `ContextActionService` at high priority and sink it while the panel is open (also stops camera zoom); unbind on close.

## Studio and MCP tooling

- **`execute_luau` returns nil if you only print.** Return a table with what you need (e.g. `{ActiveScript = S:GetFullName(), Source = Src}`).
- **`_G` and connections made in `execute_luau` persist across calls** (measured) in Studio's VM, and outlive the chat session. Clear them deliberately when done.
- **`execute_luau` loads its own fresh module copies** (measured: ByteNet's `packetIDs` was empty there while the client knew all 86 ids). Inspect live runtime state from a LocalScript/Script in Play.
- **Edit-mode requires can hang `execute_luau` for its full 120s** when a module pulls in network modules or large catalogs. Test from a Play-only script, or load a fresh copy with stubbed requires.
- **`require(Module:Clone())`** gives an unshared, fresh module instance for Edit-mode unit tests.
- **A `task.spawn`ed loop in a server `execute_luau` keeps running after the call returns** (measured). Useful to pin a test dummy on the server; write results to attributes; stop it afterwards. Two `execute_luau` calls in one message run one after the other, not in parallel.
- **Undo can revert agent edits:** `ChangeHistoryService:TryBeginRecording` returns nil from `execute_luau`, yet a Ctrl+Z in Studio reverted a whole MCP fix at once (measured). Re-verify edits if the developer has been using undo.
- **Editor buffer vs saved source:** `ScriptEditorService` documents' `GetText()` is the unsaved buffer; `.Source` / `script_read` can be stale against it. `StudioService.ActiveScript` is the focused tab (nil means none); `GetScriptDocuments()` lists every open tab. Screenshot breadcrumbs are not a reliable "active script".
- **Injected clicks don't always land on GUI buttons** in tests. Set `GuiService.SelectedObject` to the button and press Return.
- **Studio solo playtests have no network latency, and Client and Server share `os.clock`** (measured): handy for timing comparisons, but race conditions (ragdoll message vs respawn, ownership hand-offs) don't reproduce. Force the state to verify a fix and say live timing is unverified.
- **`screen_capture` never shows `AlwaysOnTop` GUIs**, and an Adornee'd SurfaceGui outside PlayerGui doesn't render in Edit mode (parent a copy under the Part to check placement).
