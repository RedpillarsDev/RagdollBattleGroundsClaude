---
name: building
description: Build Ragdoll Battlegrounds maps, arenas, buildings and props out of native Roblox parts, in one consistent house style - stylized, professional and clean. Big chunky readable shapes, a cool base with warm accents, slab architecture with dark caps over light walls, clean light textures, outlined props in cover clusters, numbers and emblems only (no words), no wear; futuristic themes add glowing linework. Ships the ClaudeBuildKit, PropKit, IslandGround and ZFightScan Luau toolkits, 15 style reference screenshots (references/), gameplay rules for knockback/ragdoll arenas, a raycast + screenshot + z-fight verification loop and hard-won part-building gotchas. Use whenever Redpillars asks to build, make, design, block out, model or dress a map, arena, island, area, building or prop with parts. Building happens ONLY in the building place named in CLAUDE.md, never in the live game.
---

# Building

Part-built maps and props for Ragdoll Battlegrounds. The goal is that **players are blown away by the quality and
level of detail**, so every build follows one house style. "Detail" means craft (shape, depth and finish), not
clutter. This file is that style, plus the workflow, verification and gotchas that keep it consistent.

> Harvested from Pillow Battles (2026-11-23), where Claude built five maps and a set of ability props with these
> kits in October 2026. Technique, quality bars and gotchas are proven there. Anything game-specific (movement
> numbers, map contract, lighting values) is marked **PB value**: re-read it from the live Ragdoll Battlegrounds
> place before relying on it.

## Status (read first)

- **Style: carried over from Pillow Battles, not yet confirmed for Ragdoll Battlegrounds.** Redpillars approved it
  for Pillow Battles on 2026-10-10 ("yep. this is super nice i want you to keep this type of style") on a small
  container-port test map. Treat it as the default here. **Before the first full map, build a small sample piece and
  get Redpillars' OK**, then record the verdict in this section (date + quote).
- The process rule stands: **a sample must be approved before any full map.** In Pillow Battles the first two full
  maps (City, Train Station) were built before a style was agreed and were rejected: "I want my builds to look
  really stylized and professional." The sample-first rule exists because of that wasted work.
- If a style question comes up that the guide doesn't answer, ask Redpillars. Don't improvise a new look.
- **No theme carry-over.** Nothing from Pillow Battles' pillow/sleep theme belongs in this game. Pick each map's
  theme on its own merits.

## Where: the building place only

- **All building happens in the building place named in CLAUDE.md.** In Pillow Battles that was a separate sandbox
  place, distinct from the dev place where scripting and playtests happen. If CLAUDE.md doesn't name one yet, ask
  Redpillars before building. Don't default to the dev place, and never to the live game.
- Match the place by the `name` in a fresh `list_roblox_studios`, never by a remembered `studio_id` (an id has been
  seen to report a different place after a switch).
- If the building place isn't connected, say so and wait. Never build anywhere else, even if it's the only place
  connected.
- Getting a finished map into the game (moving it into the dev place and wiring it up) is a separate step that
  Redpillars asks for. See "Map contract".

## Before you start

1. **Coordinate** (full protocol: `docs/claude/agent-workflow.md`). If Codex is active on this project it may share
   the building place, and it's invisible to `ListAgents`: read the tail of `.coop/to-claude.md`, append a claim to
   `.coop/STUDIO.md` (place, model name, X range) and a heads-up to `.coop/to-codex.md`. Tell peer Claude sessions
   which place you're in. Release the claim when done.
2. **Pick an empty area.** List `workspace` children with bounding boxes. Floating maps go well outside the
   Baseplate (±1024 by default) so screenshots show open sky, not grey baseplate. Pillow Battles gave each map its
   own X slot at Y 150, about 1,400-2,000 studs apart (3000, 4400, 5800, 7400, 9000, 11000, 13000). Keep that
   convention.
3. **Install or refresh the kit.** `BuildKit.luau` (next to this file) is the source of truth. Check
   `ServerStorage.ClaudeBuildKit` exists and that its `Kit.Version` matches the file's. If it doesn't, install the
   file by pasting its full text into this execute_luau (the kit contains no `]==]`):
   ```lua
   local Src = [==[ <full contents of BuildKit.luau> ]==]
   local F, Err = loadstring(Src)
   if not F then return "COMPILE ERROR: " .. tostring(Err) end
   local K = game.ServerStorage:FindFirstChild("ClaudeBuildKit") or Instance.new("ModuleScript")
   K.Name = "ClaudeBuildKit"; K.Source = Src; K.Parent = game.ServerStorage
   return "installed " .. F().Version
   ```
   Every build call then starts with `local Kit = loadstring(game.ServerStorage.ClaudeBuildKit.Source)()`.
   Use **loadstring, not require**: require caches across execute_luau calls, so an edited kit wouldn't reload.
   When you improve the kit, edit the repo file, bump `Kit.Version` and reinstall it. `PropKit.luau` installs the
   same way as `ServerStorage.ClaudePropKit` and loads on top:
   `local PK = loadstring(game.ServerStorage.ClaudePropKit.Source)()(Kit)`.
4. **First build on this project only: fix the preview lighting.** `Kit.PreviewLightingOn()` still holds Pillow
   Battles' Lighting (ClockTime, Ambient, Atmosphere, Sky, Bloom, ColorCorrection, SunRays; read 2026-10-09). Read
   Ragdoll Battlegrounds' real Lighting and its children from the dev place, put those values into `BuildKit.luau`,
   bump `Kit.Version` and reinstall. Until then every preview screenshot shows the wrong game's look. Also update
   the kit headers that name Pillow Battles places.
5. **Ask first for a whole map** (one `AskUserQuestion` batch): theme, roughly how open or full, the hazards (holes,
   edges, water), and anything that must be in it. Fill in tuning values yourself and say which ones you picked.

## Workflow

1. **Plan the layout as coordinates first.** Lay out zones on a local grid around an origin `O`, with street level at
   `O.Y`. Give each zone one job (open fighting plaza, vertical climbing area, landmark, hazard) before placing parts.
2. **Build in chunks, one Content subfolder per chunk.** Each chunk `Kit.Clear`s its own folder first, so it can be
   rerun after a fix without duplicating anything. Typical chunks: Ground/Underside (`IslandGround.luau`), Rims,
   FloorDetail, Buildings, Yard/Props, SkyDressing, SpawnsAndPads. **Save every chunk script in the repo** next to
   this skill (`<mapname>/00_Ground.luau` ...). The first Pillow Battles City lived only in a session transcript and
   had to be dug back out of it.
3. **Validate placement with raycasts, not by eye.** Before placing a building or spawn, raycast its footprint down
   onto `Content.Ground` and move it if any sample misses (the island edge is noisy). For spawns, also run
   `GetPartBoundsInBox` above the spot to check nothing collidable stands there.
4. **Build a test look early.** Two or three eye-level screenshots after the first building catch wrong tints, text
   sizes and flat facades before the rest of the map is built the wrong way.
5. **Screenshot after every chunk, under the game's lighting.** A sandbox place's own Lighting is usually grey and
   hazy and makes every colour look wrong. `Kit.PreviewLightingOn()`, capture from several angles (one wide aerial,
   at least one at Character eye height, ~8 studs above the ground), fix, then **always** `Kit.PreviewLightingOff()`
   when the captures are done: the place is shared.
6. **Run the verification checklist** (below) and fix everything before showing the map.
7. **Finish with a report:** part count by folder, colliding part count, SurfaceGui count, spawns and pad
   placeholders, the placeholders to swap on import, and every tuning value you picked.

## Verification checklist (every build)

- [ ] **Footprints:** every building, prop cluster and spawn raycast onto ground at all corners plus centre.
      Re-check every footprint after moving or adding a hole (a crane leg ended up over a moved hole's rim).
- [ ] **Spawns:** clear box ~6 studs wide above each; ~3 studs above open ground; spread over every zone.
- [ ] **Floor paint over void:** sample every painted line every 0.25 studs and raycast for ground under each sample.
      Zero samples may leave the ground (see the `a and b or c` gotcha).
- [ ] **Gaps:** measure the narrowest gap between islands after generating them; every hazard gap wider than the
      jump length (PB: 12 studs). Edge noise ate 10 of 20 planned studs once.
- [ ] **Z-fight scan:** `ZFightScan.luau` (set `MapName`, `O`, `GAP`) and fix every listed pair (see "Z-fighting").
- [ ] **Keep-clear volumes** (anything that will move through the map later): every map part's corners tested by hand.
- [ ] **Screenshots** under preview lighting: aerial + eye height + a look along each main lane.
- [ ] **Cleanup:** `Kit.PreviewLightingOff()`, no `TEMP_` parts left, `.coop/STUDIO.md` claim released.

## Style guide (agreed with Redpillars for Pillow Battles, 2026-10-10)

**What was wrong with the first maps** (Redpillars ticked all four):
- Too blocky: it looked like default Roblox parts stacked together.
- Too cluttered and noisy.
- Colours not cohesive.
- It looked generated rather than hand-made.

The target is "really stylized and professional".

**The references: `references/`.** 15 screenshots from two maps, probably by one builder:
- Map A, a daytime construction-site rooftop (`rooftop-01..07`).
- Map B, a futuristic neon arena (`arena-01..07` and `style-target-01.png`).

Redpillars: "that's the exact vibe I'm going for", but "don't take it 1:1, it's more the vibe". **Read
`references/README.md` and open several of the images with the Read tool before every build.** The two maps share one
way of building, and that is what to copy. Their themes are only examples.

### The vibe in one line
Big, chunky, readable shapes. A cool base with warm accents. Slab architecture with dark caps over light walls.
Clean, light textures. Chunky iconic props in cover clusters. Graphic decals instead of words. A vivid sky and crisp
shadows.

### Universal rules (every map, any theme)
1. **Chunky and readable.** Every object reads from far away. A few big shapes rather than many small ones, crisp
   edges. Nothing smaller than about 0.5 studs.
2. **Colour: a cool base with a few warm accents.** Pick the map palette before building and write it at the top of
   the chunk scripts:
   - 2-3 base colours (cool greys, navy or charcoal, white),
   - 2-4 warm or saturated accents (orange, coral, raspberry, a bold building colour),
   - one hazard yellow.

   Nothing outside that set. Orange against blue is the signature contrast.
3. **Slab architecture.**
   - Thick floor slabs, roofs and canopies stick out past the walls, often with **rounded corners seen from above**.
   - **Dark caps over light walls:** navy or charcoal slabs, roof caps and base bands over lighter walls.
   - Wall corners stay sharp. Upper floors are set back. Props and frames get chamfered edges.
4. **Clean, light, stylized textures.** Light brick (white, peach), square floor tiles with a soft grid, metal panels
   with seams and small screw dots, smooth cladding. All low-contrast and tidy. Roblox materials tinted with palette
   colours are fine (Brick, Concrete, Metal, DiamondPlate, Slate, Cobblestone). Gritty or dirty looks are not.
5. **Medium detail, made from depth.** Big openings (window walls with a dark grid of bars over reflective glass, or
   deep dark doorways and near-black glass in thick frames), recessed panels and balconies. Trim is the slab edges
   and bands, not stuck-on clutter. No rooftop junk.
6. **Props in cover clusters.** Chunky, iconic, instantly recognisable props in **clusters of 2-5 that work as
   cover**, with open lanes between them. Each prop gets a **darker frame or rim (a cartoon outline)**, or lighter
   panels inset in a dark frame. No story or joke props (tipping cars, food trucks, newsstands). A few clusters per
   zone, not a scatter of singles.
7. **Graphic decals, never words.** Allowed: big numbers in a squared sci-fi font, line-art emblems, a helipad "H",
   warning triangles, hazard stripes and lane lines. No words, names or puns.
8. **Clean surfaces, no wear.** Buildings look new. Theme mess is fine only as props or flat decals that also play a
   part (broken brick walls as cover, a few planks, a plaster spill patch).
9. **Varied building shapes.** L-shapes, setbacks, stacked and stepped volumes, rounded footprints, mixed heights. All
   buildings on a map share one language; their accents vary.
10. **Depth and framing.**
    - Fences frame the play area (chain-link with white razor wire, or dark slatted).
    - Distant scenery is simplified and fades into haze (a skyline of plain blue towers, glowing silhouettes). On a
      floating island use clouds and far floating chunks instead: a ring of plain towers around a floating island
      read as odd floating pillars.
    - One focal point per zone, made by silhouette and height.
11. **Low-poly nature:** faceted pines in layered tiers, gem-shaped shrubs in square planters, grass tufts, faceted
    dark slate-grey rock.
12. **Floating island base** (if the game uses floating maps): rocky strata, boulders, broken edges, clouds below,
    floating chunks in the distance, no force-field dome. Where rock shows near the play area, make it faceted
    low-poly like `arena-04`.
13. **Lighting stays the game's own** (copied by `Kit.PreviewLightingOn()` once it holds this game's values). Design
    for shadows: tall slabs and overhangs throw shapes across the open floors.

### Theme kits (pick one per map, or adapt one)
- **Daytime urban or industrial** (Map A). **No glow**: the look comes from colour, brick and tile textures, and
  shadows. Office blocks with window walls, thin protruding floor slabs and light-brick columns; a stadium-shaped
  helipad building with a navy roof slab and an outside stair; navy-brick blocks with cyan or raspberry bands; coral
  lattice cranes with hanging loads; hazard-striped concrete columns with rebar out of the top; orange outlined
  crates, plank pallets and pink pipe stacks with pale rims; white road barriers, white scaffold trestles and broken
  raspberry brick walls; chain-link and razor wire, blue-grey tiles, a skyline backdrop.
- **Futuristic or night** (Map B). **Glowing lines are linework:** white glowing strips along the rounded slab edges,
  glowing lines set flush into the floor along paths and to doors, glowing bands round towers, square lights in slab
  undersides. Bloom is usually weak, so make lines bold (at least 0.3-0.4 studs thick, fully saturated) and check them
  under preview lighting from ~60 studs away. The rest: charcoal and white base with one bold colour per building and
  seamed cladding; big numbers, line-art emblems, louvred panels; white round columns holding up protruding roof
  corners; curved dark roof shells; cover crates of a dark frame around light panels; light towers, glowing tanks,
  striped antennas; curved white walkways set into the floor; gem shrubs, pines, slatted fences.
- **Japanese festival** (approved in Pillow Battles, 2026-10-10: "i like the style"). Its theme kit `JapanKit.luau` was
  **not** ported; copy it from the Pillow Battles repo if this theme is wanted (installs as
  `ServerStorage.ClaudeJapanKit`, loaded on top of BuildKit). What made it work: white plaster + charcoal-navy roof
  tiles (the dark cap) + slate + warm wood, accented by vermilion, lantern orange, cherry pink and gold; hip-roof
  tiers with a gold edge line and upturned horns; lanterns as the only glow (Neon core inside 0.3-transparent paper);
  a five-petal crest as the only emblem (no kanji, no rising-sun motif: politically loaded); trees with visible
  branches and many small (2-3 stud) blossom clumps at the twig tips (Redpillars rejected big gem-shaped canopy blobs:
  "more detailed, smaller leaves, visible branches").
- **Other themes:** follow the universal rules. Write a short kit for the theme (palette, architecture, 5-8 prop
  types) into this section and get Redpillars' OK before building.

**Scale** (PB value: a Character is ~5 studs tall; check this game's rig): ground floors 14 studs, upper floors 12,
doors 8, window openings ~4x6, cover crates and blocks 3-5 tall.

### How to build the reference's pieces
- **Rounded slab:** two crossing boxes (W-2r × D and W × D-2r) plus a cylinder of radius r at each corner
  (`Kit.RoundedSlab`).
- **Glowing edge that follows the curves:** a second rounded slab in Neon, ~0.35 thick and 0.12 bigger all round,
  sandwiched at mid-height inside the dark slab, so only a thin glowing band shows.
- **Cladding seams:** thin dark strips (0.1-0.15 wide) on the wall, or panels with small gaps over a darker backing.
- **Numbers and emblems:** SurfaceGui digits (`Kit.PaintNumber`), emblem lines as thin white Detail parts. Never
  behind Glass material (see gotchas).
- **More recipes** (window walls, pipe stacks, cranes, chain-link, skyline, faceted rock, gem shrubs, pines, floor
  decals, curved walkways) are in `references/README.md`, section 4.

**Old kit helpers make the old look.** `Kit.Building`, `Kit.Tower`, the shop fronts with striped awnings, `Kit.Text`
word signs, `Kit.Billboard`, `Kit.Lamp`, `Kit.Car`, `Kit.Crate` (no outline frame) and the pastel palette predate the
style guide. Don't use them until rebuilt to it. The primitives, `Kit.Pipe`, `Kit.Gear` and the island generator are
fine. Build new maps from the **style-v2 helpers** (below).

## Gameplay rules for maps

Pillow Battles was a knockback battlegrounds game where only falling out of bounds killed. If Ragdoll Battlegrounds
is also knockout-based, all of this applies directly; confirm the kill rule with Redpillars or the scripts first.

- **Open areas.** Big clear fighting spaces (plazas, car parks, wide roads). Buildings mostly on the perimeter, props
  clustered along sidewalks and walls. Redpillars: "open areas, not too full".
- **Size and density** (Redpillars on the first, too-big map: "a bit smaller, and less busy, so remove some
  streetlights and cars, and make the holes bigger"):
  - A full map is about 280-300 studs across (island Radius ~140). 350 was too big.
  - Lamps: at most 4 per road arm, staggered on alternating sides, ~20 on the whole map.
  - At most ~6 vehicles, as cover and scale only.
  - Fewer of each prop type (2 bunting strings, 2 planters, 1 bench per lawn edge).
- **Holes are a main feature, and bigger than you think.** Redpillars asked twice for holes to be "way bigger": a pit
  ~45-50 across (radius ~22), sinkholes radius 15-16 so one cuts a whole avenue. Holes go through the whole island so
  a fall goes all the way out. Dress their rims (broken slabs, cracks), but put barriers on **some sides only**, so
  players can still be knocked in.
- **Open edges.** Most of the outer edge has no railing; knockback off the edge is how kills happen.
- **Movement numbers (PB values: re-read this game's config).** Walk 23, jump power 50: a jump is ~6.4 studs high and
  ~11 long; healthy knockback travels ~35 studs, low-health up to ~100. Derived rules: fences and barriers ≤4.5 tall
  (jumpable), hazard gaps >12 wide, walkable ramps are plain wedges up to ~27°. Recompute all three from this game's
  numbers.
- **Ragdoll bodies snag** (inference for this game, verify in a playtest): a tumbling ragdoll catches on lips,
  small steps and thin ledges that a walking Character steps over. Keep floors continuous (no lips at slab joins,
  bridge decks flush or ramped), and make every small decorative piece non-colliding.
- **Verticality.** Places to climb: ramps up to platforms, stairs to terraces, rooftops reached by launch pads.
- **Collision.** Only what players stand on or bump into collides: bodies, roofs, ramps, vehicle bodies, rims, poles.
  Everything decorative is `Kit.Detail` (no collision, touch, query or shadow). Canopies and leaves use `Kit.Ghost`
  (still casts a shadow). Never leave thin decorative ledges players can snag on.

**What made the Port map fightable** (the first full map in the approved style; reuse on every full map):
- **Several kill zones of different kinds:** a water bay with a 15-stud gap each side between a moored ship and the
  quay walls (non-colliding water, so a fall goes out); two big holes, each with barriers on two sides; mostly open
  outer edges.
- **High ground on every side, each reached a different way:** a ship deck by three gangways with open rails;
  container stacks by crate steps; tank tops by stairs and open catwalks; a tower terrace by an outside stair; a
  warehouse roof by a launch pad.
- **Several routes between zones,** no dead ends. **Cover clusters over every open space** with lanes left clear.
- Visual tricks: long lanes that frame the landmark at their far end; solid concrete quay walls where water meets
  ground (not stepped rock); fenders, a coping lip, foam at the waterline, a waterfall off the island edge; one
  landmark in the far scenery instead of a skyline; big cylinders get vertical panel seams and a toned white or they
  read as default cylinders.
- Multi-island maps (the festival map): one bridge per island pair so there are no dead ends, mixing rail styles
  (rails only over the end quarters, no rails, a rope bridge) plus a launch pad across the widest gap.
- Keep the floor between a landmark and the entrance open. Props go on the rim; strings and overhead dressing hang at
  11+ studs, above head and jump height.

## Map contract

**Ragdoll Battlegrounds' contract is whatever its map loader expects** (see CLAUDE.md / `docs/claude/`). If none
exists yet, propose Pillow Battles' contract below. It worked, and the map scripts already produce it:

- One Model whose PrimaryPart is `Center`: a 1x1x1 Part, anchored, CanCollide false, Transparency 0.8, placed **10
  studs under street level**. The PB loader pivoted the map to a fixed anchor position, so this offset set where the
  floor landed. Check pivot-to-floor distance on every new map.
- `SpawnPoints`: a folder of Parts named `SpawnPoint` (1x1x1, anchored, CanCollide false), ~3 studs above open ground,
  10-12 spread over every zone.
- `LogicPoints`: gameplay pads (launch/heal). The building place won't have the real pad models, so leave neon
  placeholder spots with a `Placeholder` attribute (plus `LaunchTarget` on launchers). PB's real pads needed ~16x14
  (launch) and ~11x11 (heal) clear space.
- `Content`: all the geometry.
- Importing is Redpillars' call. In PB it was: move the Model into the server map storage and rename it, swap in the
  real pads, add the map's catalog entry **and** its Id type-union member, add a map init callback, optionally a
  music folder. The general principle: a map in storage is inert until a catalog entry names it.

## Budget and performance

- PB numbers: the rebuilt City was ~3,900 parts (~420 colliding, 42 SurfaceGuis); the too-big first version ~5,300,
  treated as a hard ceiling. Full approved-style maps landed at 3,000-4,300 parts with 460-620 colliding.
- Greedy-merge flat ground (`IslandGround.luau`): ~85 parts covers a 290-stud island.
- The underside is the biggest single consumer (~1,050 parts, mostly boulders). Lower the boulder chance first.
- Facade trim is cheap because it's `Kit.Detail`: no physics and no shadows.
- No unions or meshes unless Redpillars asks. Native parts keep everything recolourable and editable.

## Gotchas

### Roblox part geometry
- **Ball parts are always spheres** (the smallest Size axis wins). For a squashed shape use `Kit.Ellipsoid` (a Part
  with a Sphere SpecialMesh).
- **Cylinders run along the part's X axis.** Use `Kit.VCyl` for standing cylinders and `Kit.CylBetween` for pipes.
- **A WedgePart's tall face is +Z and its slope falls toward -Z.** For a ramp rising toward -Z, rotate 180° about Y.
- **A CornerWedgePart is tallest at its local +X/-Z corner.** Four make a square pyramid (`Kit.Pyramid`). A cube
  stood on its corner does not read as a gem.
- **`PivotTo` on a Model with no PrimaryPart rotates it.** The pivot starts axis-aligned, so
  `PivotTo(CFrame.lookAt(...))` adds the look rotation on top of the parts' own. To re-aim a kit prop, delete and
  rebuild it.
- **`OnFace`'s Along axis runs toward -Z on a west-facing wall** (and -X on a south-facing one): it's the face's right
  vector. Work out world positions before placing things side by side on a face.
- **From the front (-Z), +X is on the viewer's LEFT.** Numbered displays laid out along +X read backwards; put 01 at
  the highest X.
- **World Y vs local Y.** A crate built at a local height used as a world height hung 150 studs under the map. Build
  every position through one helper, `V(x, y, z) = O + Vector3.new(...)`.
- **`math.noise` returns 0 at whole-number inputs.** Divide the coordinates and use fractional seeds.

### Text, SurfaceGuis and glass
- **The Glass material hides every SurfaceGui, particle and transparent part behind it.** Departure boards went blank
  whenever a glass roof was between camera and board. Glass roofs, canopies and screens are transparent
  **SmoothPlastic** (Transparency ~0.5, Reflectance ~0.08). Keep Glass for windows set into solid walls.
- **A new SurfaceGui shows up in `screen_capture` only from the next capture on.** The first capture comes back
  blank; don't conclude text is broken from that one shot.
- **Auto-sized text never exceeds 100 pixels.** At 40 px/stud letters can't exceed 2.5 studs. `Kit.PaintNumber` uses
  12 px/stud for big digits. **Small props need high PixelsPerStud** instead (PropKit `PK.Digits` defaults to 120):
  12 px/stud gives a 1-stud screen a 12-pixel canvas.
- **A Top-face SurfaceGui lays its text along the part's Z axis.** Make floor text long in Z, turn it with yaw, check
  from where a player stands which way is up, and flip 180° if it reads upside down.
- **UIGradient hazard stripes only look right on roughly square faces.** Use `Kit.HazardTiles` (square tiles whose
  stripes line up across joins). Long door posts look cleaner in solid yellow anyway.

### Colour and materials
- **Brick warms light colours** to beige or pink. For cool white brick tint it blue: `186, 202, 244` reads white.
  Peach brick reads right at about `246, 200, 188`.
- **Under bright game lighting pure white SmoothPlastic glares and coral looks pale salmon.** Use about
  `196, 204, 224` for structural white and `226, 86, 72` for coral. (PB lighting; re-check under this game's.)
- **Bright Neon washes out to pale yellow/white** under bloom and colour correction, worse behind glass. An orange
  `255, 138, 26` core behind 0.45-0.6 glass read peach; `220, 70, 0` behind 0.7 glass read clearly orange. Pick glow
  colours darker than you'd think and check in a preview capture.

### Z-fighting (the rule that fixed ~2,000 pairs)
Redpillars walked a finished map and saw z-fighting; the scan found ~2,000 near-coplanar pairs. **Two faces that point
the same way and overlap must sit at least 0.06 apart.**
- **Floor paint stacks in layers 0.06 apart:** ground top 0 → L1 0.06 (tile seams, lane lines) → L2 0.12 (safety
  lines, hazard rings, warning diamonds) → L3 0.18 (marks painted on L2). Each paint part runs from -0.02 up to its
  layer, so no side gap shows. Neighbouring hazard-ring segments overlap at inner corners, so alternate colours go on
  alternate layers. Floor numbers (transparent part + SurfaceGui) sit above the paint (top 0.125).
- **Every stuck-on piece stands 0.06+ proud of what it sits on, on every face it shares** (`Kit.Outline`,
  `Kit.Stairs` nosings and rails, `Kit.JerseyBarrier`'s notch, since kit 2026-10-10.4). Outline bottoms are the
  exception: they sit 0.06 ABOVE the box's bottom, so a hanging box keeps a clean underside and stacked boxes' outlines
  only touch.
- **Bands that wrap a building collide with everything on the wall they cross.** Bands stand 0.2-0.25 off the wall;
  door recesses 0.1 (behind the bands), doors 0.35 (in front). Lintels 0.1 proud of the jambs' fronts AND ends.
- **Where two generated volumes share cells, inflate one** (quay walls 0.1 bigger all round than the rock strata
  behind them: soil was showing through concrete in jagged patches).
- **Equal tops where a stair meets a slab:** rise to slab + 0.06. Keep a stair's side off a wall's bands.
- **Same-size trims on the same part** (a stripe 0.05 bigger than its body): make trims 0.1 bigger each side.
- **Equal undersides** (an overhang sharing a slab's underside): sink one 0.1 into the other.
- **Bridge decks sit 0.1 above the ground they land on.** A flush deck end shares the ground's top face.
- **Bar ends flush with their panels fight:** make bars 0.12 longer than the panel they cross.
- **A stand-off that scales with a prop shrinks below 0.06** (`0.06 * Scale` = 0.045 at Scale 0.75). Keep stand-offs
  as fixed studs, outside the scaling.
- **Static screenshots only prove gap-0 fights.** 0.01-0.05 gaps look clean in close captures but flicker at range and
  in motion. Trust the scan and fix them all. For a before/after, clone the backup to an empty X and capture both from
  the same relative camera.
- **ZFightScan at large coordinates:** offsets from the world origin let normals 1e-4 apart turn a 0.4 gap into
  "0.04" at X 11000. The scanner measures from the map origin `O` and takes the gap from one face's plane; set `O`.

### Lua pitfalls
- **`a and b or c` falls through when `b` is nil or false.** A floor-paint helper used
  `(Axis == "X") and SurfAt(t, Fixed) or SurfAt(Fixed, t)`; where there was no ground `SurfAt` returned nil, so Lua
  sampled the **mirrored** point and painted seam lines out over the void (25 lines on one map, found only on a final
  aerial). Write a plain `if ... then ... else ... end`. The over-void check in the verification list catches it.
- **Test the instrument before blaming it.** Raycasts were blamed first for that bug; they matched the ground parts'
  footprints at all 4,598 sample points.

### Process
- **To resize a map, rebuild it from its chunk scripts.** Don't scale or move existing models: buildings keep their
  size, so squashed positions make them overlap. Back up the old Model into ServerStorage first.
- **Fixing a kit helper means rebuilding every chunk that uses it.** Chunks are deterministic (seeded), so a full rerun
  reproduces the map with the fixes. **First check the live map still matches the scripts** (part counts by folder vs
  the last build report), or a rerun wipes Redpillars' hand edits.
- **Count what a filtered bulk fix touched.** A "shift everything at z+3 on the east face" fix also moved 10 clock
  marks. Print the count and names and compare with what you expected.
- **Keep-clear volumes:** when something will move through the map later (trains, vehicles, a hazard sweep), put an
  invisible marker Part over its space and test every map part's corners against it. Parts with CanQuery off are
  skipped by `GetPartBoundsInBox`, so test by hand.
- **Footprint gotchas:** a superellipse island's corners sit at ~0.84 × Radius, so keep buildings well inside them.
  Street trees on a 6-stud sidewalk never pass a radius-3 clearance check (the curb is within 3 studs; the City's
  local `Safe` helper skipped every tree in both builds); check with radius 2 or leave them out.
- **Repetition merges.** A torii on every step (2.5 apart) read as one dark roof slab; every second step read as a row
  of gates. Space repeated overhead elements so each one reads.
- **A spawn's clear box is 6 studs wide.** A shrine forecourt with a gate at its edge was too tight; put the spawn
  beside the building.

## Ability props (`PropKit.luau`)

Small props for abilities (first used for three C4 explosive concepts). A prop follows PB's thrown-prop contract,
which is a sensible default here too: a Model whose PrimaryPart is `Center` (the only anchored part, so it stands still
on display; unanchor it to throw), a flat `Content` folder of parts each welded to Center, and a black outline
Highlight on the Model. Local frame: Y up = away from the surface it sits or sticks on, front = -Z. Props are seen
close, so "nothing under 0.5 studs" relaxes, but keep them chunky and keep the 0.06 stand-off. Name every part a script
will drive (`Content.Light`, `Content.Screen.Display.Digits`, `Led1..Led8`, `Content.Core`) and list them in the
report. Pick the Highlight's DepthMode on purpose (`Occluded` vs `AlwaysOnTop`, which shows through walls). Present
concepts on a numbered display pad with a clone of Redpillars' rig for scale. VFX rigs are Redpillars' to add.

## Files (this folder)

- `references/`: the 15 style screenshots and `README.md`, the written breakdown. Read both before every build.
- `BuildKit.luau`: the kit. Primitives (Box, Wedge, VCyl, CylBetween, BeamBetween, Ball, Ellipsoid), flags (Detail,
  Ghost), facades (FaceCF, OnFace, Text, Awning), old-look helpers (Building, Tower, street furniture), industrial
  pieces (`Pipe`, `Gear`, `GasLamp`, `Valve`, `Gauge`, `Crate`, `Steam`: keep emitters to ~8 per map), and
  `PreviewLightingOn/Off`. **Style-v2 helpers** (build new maps from these): `Shade`, `RoundedSlab`, `ChamferBox`,
  `Outline` (the 12-edge cartoon outline), `Container`, `OutlinedCrate`, `JerseyBarrier`, `Bollard`, `Pyramid`,
  `GemShrub`, `FloodMast`, `WindowWall`, `Stairs`, `HazardPaint`, `HazardTiles`, `PaintNumber`, `ChainLink`.
- `IslandGround.luau`: the floating-island generator (greedy-merged surfaces, foundation slab, strata stepping in from
  every edge and hole, boulders, curbs, hole rims). Edit its CONFIG block (MapName, O, cell size, Radius, Squareness,
  Bites, `InHole`, `SurfType`, `Types`) for a new map. Its CONFIG still holds the PB City as an example.
- `PropKit.luau`: ability-prop helpers, loaded on top of BuildKit (see "Ability props").
- `ZFightScan.luau`: finds same-direction, near-coplanar, overlapping faces of different colour or material and lists
  them by folder. Its header says which gap-0 pairs are hidden and fine. Run after every build.
- `<mapname>/NN_*.luau`: this project's map chunk scripts, once you build some.

## Worked examples (Pillow Battles repo, read-only)

Not ported (they build Pillow Battles maps), but they are the best reference for how a chunked map script is written.
Path: `C:\Users\betee\Desktop\Claude\PillowBattlesClaude\.claude\skills\building\` (read only; never edit that repo).

| Folder | What it is | Look at it for |
|---|---|---|
| `portmap/00..07` | Full Port map, ~3,515 parts, the first full map in the approved style | **The main example.** Kill-zone recipe, ship + cranes, tank farm, floor paint layers, z-fight fixes |
| `port/00..05` | Container-port test map: the sample Redpillars approved | Palette blocks, slab buildings, outlined props in cover clusters, floor graphics |
| `festival/00..06` + `JapanKit.luau` | Three-island Japanese festival map, ~4,260 parts | Multi-island layout, island-gap measurement (`00` prints narrowest gaps), bridges, a theme kit |
| `festival_sample/00..04` | The festival sample piece (pagoda corner) | What a sample-before-full-map looks like |
| `city/01..07` (+ `IslandGround.luau` CONFIG) | The first City, **rejected look** | Layout, holes, raycast placement, spawns/pads chunk; `04_Construction` has a crane |
| `station/00..08` | Train Station, **rejected look** | Two-platform island generator with a straight gap; a keep-clear volume for moving trains |
| `c4_concepts/00..03` | Three C4 ability props on a display pad | PropKit usage, scripted-part naming |
