# Work log: gutsontopp2

Append-only, newest at the bottom. Format and rules: "Work log" in `CLAUDE.md`.

## 2026-11-23 | Cloned the repo and got live sync working on this machine

- Cloned `RedpillarsDev/RagdollBattleGroundsClaude` (main at `9485782`) and read `CLAUDE.md`, `.claude/settings.json`,
  `.claude/hooks/git-sync.sh`, the `.coop/` files and `docs/claude/agent-workflow.md`. The live-sync hook already
  existed in the repo, so nothing new was built for it.
- Set a repo-local git identity (GitHub noreply address). There was none, and `git-sync.sh` swallows commit errors, so
  every sync would have silently done nothing. Global git config untouched.
- Checked line endings: `git-sync.sh` is checked out as CRLF on Windows, but Git Bash runs it fine (tested with a CRLF
  script), so no change was needed.
- Observed that the PostToolUse hook did **not** fire when this session edited files: the session's workspace was the
  parent folder, not this repo, so `.claude/settings.json` was never loaded. Until a session is opened with this repo
  as its workspace, sync is run by hand with `bash .claude/hooks/git-sync.sh push`.
- Docs: added the "Work log" section to `CLAUDE.md`, created this file, and rewrote the stale "Auto-commit hooks (not
  ported)" section of `docs/claude/agent-workflow.md` (it said the project had no git repo and no hook).
- Verified end to end: ran `git-sync.sh push` once with `bash -x`. It committed the three files above as
  `Auto-sync: ...` under this identity, pushed, and local `HEAD` matched `git ls-remote origin main`. Push access for
  the stored GitHub login is confirmed.
- Not touched: Roblox Studio (nothing connected, nothing edited), game scripts, the `.coop/` files, Play mode.
- Open: the hook's commit trailer is hard-coded to `Co-Authored-By: Claude Opus 5.5`, which names the wrong model for
  sessions running on another one. Left as is because the script is shared with the other machine.

## 2026-11-24 | Ragdoll Park map (sandbox test park) in Ragdoll Battlegrounds

- **Ask (Guts):** watch his newest recording of a ragdoll sandbox game and build a similar map in our style with
  hand-painted textures. Guts chose to build **in Ragdoll Battlegrounds** (the building place in CLAUDE.md is still
  undecided; this was his call for this map). Mid-build corrections from Guts: "more realistic"; no round or textured-box
  foliage, use his paid Enchanted Forest pack for trees and bushes; a hole in the cannon; "not 1-1", add unique
  stations; unions and meshes are OK but not many.
- **Where:** `Workspace.Map.RagdollPark` (Model, PrimaryPart `Center` 10 under ground, `SpawnPoints` x12, `LogicPoints`
  empty, `Content/*`). Ground top at world (3000, 20, 0), lawn +-280, terraced hills beyond. Folders: Ground, Paths
  (concrete slab paths + round plaza), Pool (sunken pool, dive tower, loungers), Crusher (hydraulic press, cannon with a
  CSG bore, sand pit), JumpTower (ski jump, open stairs, landing pit, 3 gym trampolines), Hazards (sunken lava + acid
  pits with attribute `Hazard`, plank bridge, bleachers), Props (8 lamps, 8 benches, 4 union bins, crates), Unique
  (giant bowling lane with `Pin` models, tumble stairs to a 24-stud tower), Foliage (70 pack trees + 70 pack bushes).
  ~1,420 parts, 637 colliding, 6 unions, 254 MeshParts. Static props only: no scripts. Scripted names/attributes:
  Press.Ram, PressButton (attr Press), Cannon.Barrel (attr Cannon), trampoline Mat (attr Bounce), Pin (attr Pin),
  Water (attr Water), `Station` attribute on each station folder.
- **Chunks:** `.claude/skills/building/ragdollpark/00_Assets .. 08_Foliage` (rerunnable, each clears its own folder),
  `ParkKit.luau` (installed as `ServerStorage.ClaudeParkKit`), `zscan.luau` (ZFightScan copy). Run order: 00_Assets
  first (rebuilds `ServerStorage.RagdollParkAssets`), then 00..08.
- **Local-only, NOT uploaded (Guts' no-upload rule):** the 20+ hand-painted textures are served from this PC's Studio
  content folder (`rbxasset://ragdollpark2/...`). On any other PC (Redpillars) those faces show their fallback flat
  colour. They break when Studio updates its version folder. To ship: Guts uploads the PNGs, then set
  `K.TexIds[name]` and run `K.Retexture(workspace.Map.RagdollPark)`. The pack foliage kit is also loaded from a local
  file (`rp_src/forest_kit.rbxm`), but once in the place it saves with it.
- **Verified:** all chunks run clean; ZFightScan: the remaining near-coplanar pairs are all hidden (buried bottoms,
  faces under the deck or ground); 12 spawns clear (6-stud box) and on plaza/paths. Screenshots of every station
  except the tumble stairs (that capture timed out).
- **Not verified:** no playtest (none asked). The game's own Lighting (Atmosphere density 0.52, sky-tinted diffuse)
  washes the map blue-grey at range; left untouched (shared setting, Redpillars' call). Foliage is non-colliding.
- **Pending:** Blender hero props (giant bowling pins first), more "crazy" test stations (crash sled, range, pendulum,
  blast pad, giant mousetrap/dartboard ideas), refresh 08_Foliage keep-out list after new stations.

## 2026-11-24 | Ragdoll Park: Blender hero models, rigged to animate and break

- Guts: "put the blender pins in now", "crazy models like the bowling thingies in blender", "make sure they are
  animatable and breakable". Process he set: think, then reference (one real photo per model), then build.
- **Built in Blender (headless) and placed by the generated chunk `ragdollpark/09_CrazyModels.luau`:** giant bowling
  pins (10, free physics props, each 3 welded chunks), GiantMousetrap (armed, SE at 30,50), GiantDartboard (behind the
  cannon's sand pit, facing it, 3 darts), PunchMachine (spring-loaded boxing glove, SW at -24,48, punches west). Bowling
  lane widened to 20 studs for real pin spacing (07). Lamps (06) now stand off the paths with the arm over the path.
- **Rig contract (for scripting):** each model has `Root` (anchored, PrimaryPart) + AnimationController/Animator.
  All visible parts are unanchored and held by WeldConstraints named `Break` (break = destroy them) or Motor6Ds at the
  real pivots: `HammerHinge` + `PedalHinge` (mousetrap), `Dart1Joint`..`Dart3Joint` (dart tips), `PunchSlide` (rod;
  glove, band and plate are welded to the rod). Attributes: Breakable, Animatable, Chunk, TrapHammer, TrapPedal,
  DartTarget, PunchGlove, PunchRod, Pin. `LogicPoints/DummySpot` per station (attr Station).
- **Run order:** 00_Assets, 00..08, then 09 (09 replaces the pins inside 07's BowlingLane).
- **Verified (Edit mode):** every unanchored part is held by a weld or motor; C0 tests on HammerHinge, PedalHinge,
  PunchSlide and Dart1Joint move the right parts around the right pivot and revert exactly; exploded clones show clean
  capped chunks. **Not verified:** breaking and pin physics at runtime (no playtest; Guts' call).
- **Local-only:** the meshes are local files in this PC's Studio content folder (a missing mesh renders nothing), so
  other PCs see invisible props until Guts imports them with Import 3D. The Blender sources, generator and textures
  are on Guts' PC only (not in this repo).

## 2026-11-24 | Ragdoll Park: R6 sizing, anchored, realistic wood, map doubled + 4 outer zones

- Guts' calls this round: models "fitting to r6 size"; pins "look off" (smooth-shading seams on the fractured pins);
  plaza "just make it with a painted on texture" (no raised slab rings); "use more realistic wood textures"; ramp
  "colourful simple texture"; "anchor all stuff and place them correctly"; "make the map bigger add more stuff like
  places for cool animals or ideas" (picked all four zones, "Build zones first": animals later).
- **Sizes (R6 = 5 studs):** pins 5 tall on a 14-wide lane, mousetrap x0.55, dartboard x0.7, punch machine x0.65
  (generator `scale` per model). Fracture cuts are now sharp edges and the pin seam is welded (no shading seams).
- **Anchoring:** every part in `Workspace.Map.RagdollPark` is anchored (2,480 parts, audit 0 loose). The hero rigs keep
  their Break welds + Motor6Ds: a script unanchors the pieces before breaking/animating them (Root stays anchored).
- **Textures:** ParkKit 2026-11-24.3 serves `rbxasset://ragdollpark3/` (still local-only, not uploaded). New realistic
  woods `r_wood` (deck), `w_lane` (maple lane), `w_birch` (mousetrap board), `w_dark`; `w_ramp` = orange/yellow/blue
  boards on the ski-jump ramp; `r_plaza` = flat painted concrete with thin joint lines.
- **Map doubled:** lawn +-520, hills at r 470/560, avenues continue to an outer loop at +-250, 16 spawns.
  New chunk `10_Zones.luau`: NE rodeo arena (fence, 3 bucking chutes, grandstand, floodlights, mechanical-bull mat),
  NW shark pier (80x80 sea basin 14 deep, pier on piles with T head + walk-the-plank, buoys, lifeguard tower),
  SE boxing ring (ropes, corner pads, light truss) + gorilla pen (wall + rail, rocks, log frame, tyre swings, pack
  plants), SW rocket yard (pad, lattice tower, rocket on `RocketLift`, strap-on rocket chair, giant fan on `FanSpin`
  blowing over a stage into a foam pit). Animal spots: `LogicPoints/AnimalSpot` (attr Animal = MechanicalBull, Bull,
  Shark x3, Kangaroo, Gorilla). Foliage rerun: 144 pack trees + 140 bushes, none inside a zone.
- **Run order now:** 00_Assets, 00..08, 09, 10, then 08 again if zones moved (08 holds the keep-out list).
- **Not done:** animals (Guts: later), no playtest, repo push still blocked by the permission check.

## 2026-11-24 | Ragdoll Park: gorilla pen deleted, one round trampoline, traced shark + pteranodon

- Guts: "delete" (gorilla pen: gone from 10_Zones and the place, its AnimalSpot too; the boxing ring stays);
  "make trampoline round bigg 1 not three" (04: one 26-across round backyard trampoline, padded ring, W legs, ladder);
  "make animal models trace their shapes 1-1 and make them realistic make shark, the flying dinosaur with references".
- **Great white shark x3** (`CrazyModels.GreatWhite1..3`, in the shark basin, one with its dorsal fin at the surface):
  outline + fins traced 1:1 from a side-view drawing (Wikimedia Commons, Carcharodon carcharias drawing), body lofted
  from the traced profile with real width ratios, the drawing projected as the skin. 4.5 m real = 12.9 studs at R6
  scale. Joints: `Swim` (Root->Body), `HeadJoint`, `Spine` (Body->Rear), `TailJoint` (Rear->Tail).
- **Pteranodon** (`CrazyModels.Pteranodon1`, gliding 26 studs over the pier): wing planform traced from a 6 m
  size-comparison silhouette, skull side profile traced from Marsh's skull drawing; 17-stud span. Joints: `Glide`,
  `NeckJoint`, `RightShoulder`, `LeftShoulder` (flap tested symmetric).
- Shark basin water made clearer so the sharks show. All parts anchored (joints work once a script unanchors).
- Local meshes again (Import 3D needed for other PCs). Sources: RagdollPark/models/{shark,ptero} on Guts' PC.
