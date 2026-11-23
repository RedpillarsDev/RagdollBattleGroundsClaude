# Asset pipeline: Blender -> FBX/glb -> Roblox

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Codex did the modeling in Pillow Battles (`docs/claude/agent-workflow.md`), so this is mostly what Claude needs to know to
**receive** an asset, plus the conventions any modeler on this project should keep. Part-built maps don't go through
this pipeline; see the `building` skill.

## Budgets (Redpillars' Pillow Battles numbers; confirm for this game)

- **Standalone props and ability models:** 3,000-5,000 triangles target, **9,000 maximum**. Count the final
  triangulated export including every decorative mesh; presentation objects excluded.
- **Complete arena maps:** 150,000 soft target, **300,000 maximum**, counting visuals, decoration and exported collision.
  A budget is a limit, not a target: the clean desert map was a quality benchmark at ~80,000. Report a soft-target
  overrun plainly; never treat it as the new minimum.
- **Per exported visual chunk:** ≤8,500 triangles (a packaging preference, not a Roblox limit).

## Export conventions

- **Export the asset alone** as FBX: no presentation cameras, lights or floor. GLB as an alternate. Keep the editable
  `.blend`, with source, prepared export meshes, collision proxies and presentation objects in separate named
  collections; never export source and prepared duplicates together.
- **Apply transforms**, unit scale, one modeled unit per intended stud. FBX Unit Scale, Z forward, Y up. Then **verify
  the importer's scale** against the target dimensions written in the import notes (use the 3D Importer's stud scale).
- **Pivots:** props at bottom centre; maps share one ground-level origin across visual and collision files. Moving
  assemblies (a crate lid) are separate meshes with their own sensible pivot (hinge at the rear edge).
- **Semantic recolor groups.** Combine disconnected pieces that should recolor together into named MeshParts
  (`<Asset>_Wood`, `<Asset>_Hoops`); keep moving parts separate. **One material per exported mesh**: multiple Blender
  material slots don't become convenient Studio recolor controls.
- **Prefer texture-free solid colours** set by `MeshPart.Color`. When PBR or emission is needed, use neutral tintable maps
  plus `SurfaceAppearance.Color`. No baked multicolour atlas across recolor groups unless Redpillars chooses one. For
  painterly textured maps, ship a coloured default export plus a clearly labelled neutral tintable alternative.

## Studio import: what actually happens

- **FBX import loses constant material colours.** Never claim a texture-free FBX preserves its palette. After import,
  apply each group's Color/Material from the manifest (via MCP), then **serialize a native `.rbxm`** and verify it with
  a `SerializationService` round trip. Insert that rbxm as a model file, not through the 3D Importer; its mesh ids point
  at meshes already uploaded for the project. Keep the original import untouched beside the coloured copy.
- **Custom FBX properties and Blender visibility don't configure Roblox properties.** Collision proxies imported as
  **opaque white geometry**, nearly coincident with the terrain, causing z-fighting and hiding textures.
  - Default import link is the coloured **visuals-only** file, named explicitly (`<Asset>_VISUALS_ONLY.fbx`); collision is
    a separate, clearly labelled file. Never hand off an unconfigured combined FBX as ready to use.
  - Proxies (`COL_*`): `Transparency = 1`, `CastShadow = false`, `Anchored = true`, `CanCollide = true`, `CanQuery` and
    `CanTouch` true, `CollisionFidelity = Hull`. Keep each convex piece separate: merging them into one hull closes the
    knockout gaps.
  - Visuals: `CanCollide`, `CanTouch`, `CanQuery` false when proxies exist.
- **Grouped recolor meshes + Default/Hull collision = invisible floors.** A recolor batch spans distant pieces, so its
  hull covers the gaps between them. Use dedicated proxies with non-colliding visuals, **or**
  `PreciseConvexDecomposition` on structural meshes with decorative groups (flowers, moss, tufts, foliage, small metal)
  `CanCollide = false`. Never silently combine both systems. Read collision back after the engine has finished updating
  it, and test a **fresh clone** of the template, not the edited original.
- **Moving ability props:** one simple invisible physics proxy, visual meshes welded to it and non-colliding. Don't use
  small convex hulls (hoops, rivets) as colliders.
- **SurfaceGui input raycasts skip `CanQuery = false` parts.** A leaderboard's 50-row list wouldn't scroll until its
  mount part had CanQuery on. Author GuiMount parts with `CanQuery = true`.

## Mesh-level failure modes

- **Ground z-fighting:** don't stack coplanar grass patches, path sheets and terrain tops. Trim or partition so each
  visible region has one owner; remove buried and coincident faces. A tiny height offset is not dependable for meshes
  (unlike native parts, where the 0.06-stud rule works). Check transitions at shallow angles and at range.
- **Black edges:** the desert map's black cliff band was a bake-only **vertex-colour mask exported with the FBX**, not
  texture padding. Strip intermediate colour attributes from export meshes and disable vertex-colour export unless the
  final material uses it; keep the masks in the editable source. Replacing a texture doesn't remove a bad colour
  attribute already baked into an imported mesh.
- **Fixing the source but exporting an old copy** is not a repair: verify the exported file.

## Verification and the honesty rule

- **Blender:** closed/manifold meshes, finite coordinates, no zero-area faces, UVs in 0-1, one material per group, unit
  scale, shared pivots, triangle counts per group.
- **Export:** re-import the actual FBX and compare mesh count and names, UVs, triangle count, bounds; check the GLB count.
- **Collision:** physics-ray grids over the template: hits over empty gaps (should be 0), missing ground (0), lanes
  along main routes and both ends of every bridge, body-height rays through gates. A large height discrepancy on a steep
  cliff face (hit normal Y < 0.2) is not a flat invisible floor; check normals before "fixing" it.
- **Never claim one check as another.** A Blender render is not the concept art; a Blender re-import is not a Studio
  import; static rays are not a walk/jump/knockback playtest. Every handoff states which checks ran, and the manifest's
  `studio_import_verified` stays `false` until a Studio import was actually inspected.

## Deliverable layout and manifest

```
assets/<asset_snake>/
  <asset>.blend                 editable source (+ build_<asset>.py / export_and_verify.py if procedural)
  <asset>.fbx                   visuals (or <asset>_VISUALS_ONLY.fbx)
  <asset>_collision.fbx         proxies at the same origin, if any
  <asset>.glb                   alternate export
  <asset>_colored.rbxm          native, coloured, round-trip verified (after Studio import)
  <asset>_preview.png           render of the actual mesh, not the concept
  asset_manifest.json
  ROBLOX_IMPORT.md
  build_YYYY_MM_DD/ , revision_YYYY_MM_DD_<what>/   later passes; never overwrite a previous revision
```

`asset_manifest.json` (Pillow Battles shape):

```json
{
  "name": "Classic Barrel", "concept": "A - Classic Barrel",
  "pivot": "Bottom center", "height_studs": 4.2,
  "texture_free": true, "total_triangles": 4912,
  "recolor_groups": { "ClassicBarrel_Wood": { "triangles": 1440, "color_rgb": [174, 112, 43], "material": "SmoothPlastic" } },
  "bounds": [[-1.76, 1.76], [-1.76, 1.76], [0.0, 4.2]],
  "fbx_roundtrip_verified": true, "glb_triangle_count_verified": true,
  "studio_import_verified": false
}
```

`ROBLOX_IMPORT.md` sections: **Contents** (each file, triangle counts), **Import** (importer, target dimensions, pivot,
axes, what not to merge), **Recolor groups** (table: mesh suffix, RGB, Studio material), **Collision setup** (exact
properties per group), **Physics and verification** (which checks ran), **Scope** (what is NOT done: Studio import,
playtest, catalog wiring).

## Native-part asset kits (built in Studio, no meshes)

Codex also built prop libraries from native Parts in the building place. Conventions worth keeping for anything a
script or Redpillars will recolor or place:
- **Flat semantic finish groups** directly under each asset Model: `Body`, `Frame`, `Trim`, `Accent`, `Glow` (**every**
  Neon part directly inside it), `Recesses`, plus `Screens` / `Upholstery` / `Foliage` where used. Every part in a group
  shares one Color and Material; no nested construction groups. Recoloring = select the group's children, edit Color.
- `GuiMounts`: invisible display parts (`Transparency = 1`, `CanCollide = false`, `CanQuery = true`), SurfaceGui face
  Back (+Z), suggested canvas size stored as attributes.
- `Utility`: `PlacementPivot` (the PrimaryPart, at ground centre), plus `WallMount` / `CeilingMount` helpers.
- One `.rbxm` per asset plus a combined one, each round-trip verified, with a README listing the inventory.
- **Naming contracts code relies on get written into the handoff** (Pillow Battles: a board's metric was read from its
  Model name, `Leaderboard<MetricId>`, so a mis-named board showed the wrong metric).

## Handoff

Importing does not put an asset in the game. The modeler reports the instance path, intended catalog, recolor groups,
moving parts and unverified checks in `.coop/to-claude.md`; Claude wires the catalog entry when Redpillars asks
(`docs/claude/agent-workflow.md`, "The handoff that matters").
